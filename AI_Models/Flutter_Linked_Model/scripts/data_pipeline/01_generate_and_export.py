#!/usr/bin/env python3
"""Export Firebase telemetry and generate realistic synthetic IoT data.

The script is intentionally resilient:
- If Firebase credentials are not configured, it generates synthetic data.
- If optional progress libraries are missing, it falls back to plain printing.
- Data is streamed to CSV so a full one-year run does not need large memory.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import os
import random
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, Iterator, List, Optional, Tuple


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "data" / "raw"
REPORT_DIR = ROOT / "reports"

DOMAINS = ("water", "bridge", "building", "agriculture")
GATEWAY_ID = "gw_lora_001"
READING_INTERVAL_MIN = 5

BASE_COLUMNS = [
    "timestamp",
    "node_id",
    "domain",
    "battery_pct",
    "rssi_dbm",
    "snr_db",
    "is_anomaly",
    "anomaly_type",
]

DOMAIN_COLUMNS = {
    "water": [
        "pressure_bar",
        "flow_rate_lpm",
        "water_level_m",
        "pipe_temp_c",
        "leak_detected",
    ],
    "bridge": [
        "vibration_hz",
        "tilt_angle_deg",
        "load_weight_ton",
        "crack_index",
        "temp_c",
        "humidity_pct",
    ],
    "building": [
        "temp_c",
        "humidity_pct",
        "co2_ppm",
        "power_kwh",
        "occupancy_count",
        "smoke_level",
    ],
    "agriculture": [
        "soil_moisture_pct",
        "soil_temp_c",
        "air_temp_c",
        "air_humidity_pct",
        "irrigation_active",
        "ndvi_index",
    ],
}

TELEMETRY_COLUMNS = [
    "timestamp",
    "node_id",
    "domain",
    "pressure_bar",
    "flow_rate_lpm",
    "water_level_m",
    "pipe_temp_c",
    "leak_detected",
    "vibration_hz",
    "tilt_angle_deg",
    "load_weight_ton",
    "crack_index",
    "temp_c",
    "humidity_pct",
    "co2_ppm",
    "power_kwh",
    "occupancy_count",
    "smoke_level",
    "soil_moisture_pct",
    "soil_temp_c",
    "air_temp_c",
    "air_humidity_pct",
    "irrigation_active",
    "ndvi_index",
    "battery_pct",
    "rssi_dbm",
    "snr_db",
    "is_anomaly",
    "anomaly_type",
]

GATEWAY_COLUMNS = [
    "timestamp",
    "gateway_id",
    "connected_nodes",
    "packet_loss_pct",
    "uptime_hrs",
    "avg_rssi",
    "avg_snr",
    "data_volume_mb",
    "is_anomaly",
    "anomaly_type",
]

STATUS_COLUMNS = [
    "node_id",
    "domain",
    "online",
    "battery_pct",
    "rssi_dbm",
    "snr_db",
    "last_seen",
    "firmware_version",
    "health_state",
]

ALERT_COLUMNS = [
    "alert_id",
    "timestamp",
    "domain",
    "node_id",
    "severity",
    "title",
    "message",
    "resolved",
    "source",
]

LABELED_COLUMNS = [
    "timestamp",
    "node_id",
    "domain",
    "is_anomaly",
    "anomaly_type",
    "label_type",
]

DOMAIN_METADATA_COLUMNS = [
    "domain",
    "display_name",
    "node_count",
    "primary_sensor",
    "description",
]

ANOMALY_LABELS = {
    "normal": 0,
    "sensor_fault": 1,
    "infrastructure_issue": 2,
    "communication_issue": 3,
    "battery_critical": 4,
}


def optional_console():
    try:
        from rich.console import Console

        return Console()
    except Exception:
        return None


CONSOLE = optional_console()


def log(message: str) -> None:
    if CONSOLE:
        CONSOLE.print(message)
    else:
        print(message)


def progress(iterable: Iterable[Any], **kwargs: Any) -> Iterable[Any]:
    try:
        from tqdm import tqdm

        return tqdm(iterable, **kwargs)
    except Exception:
        return iterable


def ensure_dirs() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)


def iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def rounded(value: float, digits: int = 3) -> float:
    return round(float(value), digits)


def parse_timestamp(value: Any) -> str:
    if value is None:
        return iso(datetime.now(timezone.utc))
    if isinstance(value, (int, float)):
        number = float(value)
        if number > 10_000_000_000:
            number /= 1000.0
        return iso(datetime.fromtimestamp(number, tz=timezone.utc))
    text = str(value)
    if not text:
        return iso(datetime.now(timezone.utc))
    try:
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
        return iso(parsed)
    except Exception:
        return text


def numeric(value: Any, default: Optional[float] = None) -> Optional[float]:
    if value is None or value == "":
        return default
    if isinstance(value, bool):
        return 1.0 if value else 0.0
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def boolish(value: Any) -> int:
    if isinstance(value, str):
        return 1 if value.strip().lower() in {"1", "true", "yes", "on"} else 0
    return 1 if bool(value) else 0


def flatten_map(value: Any) -> Dict[str, Any]:
    return value if isinstance(value, dict) else {}


def load_firebase_snapshot() -> Dict[str, Any]:
    credentials = os.getenv("FIREBASE_CREDENTIALS_PATH")
    database_url = os.getenv("FIREBASE_DATABASE_URL")
    if not credentials:
        log("[yellow]FIREBASE_CREDENTIALS_PATH is not set; using synthetic data.[/yellow]")
        return {}
    if not Path(credentials).exists():
        log(f"[yellow]Firebase credentials file not found: {credentials}[/yellow]")
        return {}
    if not database_url:
        log("[yellow]FIREBASE_DATABASE_URL is not set; Firebase export skipped.[/yellow]")
        return {}

    try:
        import firebase_admin
        from firebase_admin import credentials as admin_credentials
        from firebase_admin import db
    except Exception as exc:
        log(f"[yellow]firebase-admin is unavailable: {exc}[/yellow]")
        return {}

    try:
        if not firebase_admin._apps:
            cred = admin_credentials.Certificate(credentials)
            firebase_admin.initialize_app(cred, {"databaseURL": database_url})
        root = db.reference("/").get()
        if isinstance(root, dict):
            log("[green]Firebase snapshot loaded from Realtime Database.[/green]")
            return root
    except Exception as exc:
        log(f"[yellow]Firebase export failed, continuing with synthetic data: {exc}[/yellow]")
    return {}


def infer_domain(node_id: str, data: Dict[str, Any]) -> str:
    raw_domain = str(data.get("domain", "")).lower()
    if raw_domain in DOMAINS:
        return raw_domain
    lookup = {
        "1": "building",
        "building": "building",
        "2": "bridge",
        "bridge": "bridge",
        "road": "bridge",
        "3": "water",
        "water": "water",
        "4": "gateway",
        "agriculture": "agriculture",
        "farm": "agriculture",
    }
    if raw_domain in lookup:
        return lookup[raw_domain]
    lowered = node_id.lower()
    for key, value in lookup.items():
        if key in lowered and value != "gateway":
            return value
    return "building"


def normalize_real_telemetry(snapshot: Dict[str, Any]) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    nodes = flatten_map(snapshot.get("nodes"))
    for node_id, node_payload in nodes.items():
        node_map = flatten_map(node_payload)
        domain = infer_domain(str(node_id), node_map)
        telemetry = node_map.get("telemetry")
        readings: Iterable[Any]
        if isinstance(telemetry, dict):
            readings = telemetry.values()
        elif isinstance(telemetry, list):
            readings = telemetry
        else:
            readings = []
        for item in readings:
            reading = flatten_map(item)
            values = flatten_map(reading.get("values"))
            merged = {**reading, **values}
            row = {column: "" for column in TELEMETRY_COLUMNS}
            row.update(
                {
                    "timestamp": parse_timestamp(
                        merged.get("timestamp") or merged.get("lastUpdate")
                    ),
                    "node_id": str(node_id),
                    "domain": domain,
                    "battery_pct": numeric(merged.get("battery_pct"))
                    or numeric(merged.get("batteryPercent"))
                    or numeric(merged.get("battery")),
                    "rssi_dbm": numeric(merged.get("rssi_dbm"))
                    or numeric(merged.get("rssi")),
                    "snr_db": numeric(merged.get("snr_db")) or numeric(merged.get("snr")),
                    "is_anomaly": boolish(merged.get("is_anomaly", False)),
                    "anomaly_type": str(merged.get("anomaly_type") or "normal"),
                }
            )
            aliases = {
                "pressure_bar": ["pressure_bar", "pressure"],
                "flow_rate_lpm": ["flow_rate_lpm", "flow"],
                "water_level_m": ["water_level_m", "tank1", "level"],
                "pipe_temp_c": ["pipe_temp_c", "pipeTemp"],
                "leak_detected": ["leak_detected", "leakStatus", "leak"],
                "vibration_hz": ["vibration_hz", "vibration"],
                "tilt_angle_deg": ["tilt_angle_deg", "tilt"],
                "load_weight_ton": ["load_weight_ton", "loadTon"],
                "crack_index": ["crack_index"],
                "temp_c": ["temp_c", "temperature", "temp"],
                "humidity_pct": ["humidity_pct", "humidity"],
                "co2_ppm": ["co2_ppm", "airQuality"],
                "power_kwh": ["power_kwh", "power"],
                "occupancy_count": ["occupancy_count", "occupancy"],
                "smoke_level": ["smoke_level", "smoke"],
                "soil_moisture_pct": ["soil_moisture_pct", "soilMoisture", "soil"],
                "soil_temp_c": ["soil_temp_c", "soilTemp"],
                "air_temp_c": ["air_temp_c"],
                "air_humidity_pct": ["air_humidity_pct"],
                "irrigation_active": ["irrigation_active", "pumpOn"],
                "ndvi_index": ["ndvi_index"],
            }
            for column, names in aliases.items():
                for name in names:
                    if name in merged:
                        row[column] = numeric(merged[name], merged[name])
                        break
            rows.append(row)
    return rows


def normalize_real_status(snapshot: Dict[str, Any]) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    nodes = flatten_map(snapshot.get("nodes"))
    for node_id, payload in nodes.items():
        node = flatten_map(payload)
        status = flatten_map(node.get("status")) or node
        domain = infer_domain(str(node_id), node)
        rows.append(
            {
                "node_id": str(node_id),
                "domain": domain,
                "online": boolish(status.get("online", True)),
                "battery_pct": numeric(status.get("battery_pct"))
                or numeric(status.get("batteryPercent"))
                or "",
                "rssi_dbm": numeric(status.get("rssi_dbm")) or numeric(status.get("rssi")) or "",
                "snr_db": numeric(status.get("snr_db")) or numeric(status.get("snr")) or "",
                "last_seen": parse_timestamp(status.get("lastUpdate") or status.get("timestamp")),
                "firmware_version": status.get("firmware_version", "firebase"),
                "health_state": status.get("health_state", "unknown"),
            }
        )
    return rows


def normalize_real_gateways(snapshot: Dict[str, Any]) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    gateways = flatten_map(snapshot.get("gateways")) or flatten_map(snapshot.get("gateway"))
    if not gateways:
        return rows
    if "connectedNodes" in gateways or "totalPackets" in gateways:
        gateways = {"gateway": gateways}
    for gateway_id, payload in gateways.items():
        gateway = flatten_map(payload)
        rows.append(
            {
                "timestamp": parse_timestamp(gateway.get("timestamp") or gateway.get("lastUpdate")),
                "gateway_id": str(gateway_id),
                "connected_nodes": numeric(gateway.get("connected_nodes") or gateway.get("connectedNodes"), 0),
                "packet_loss_pct": numeric(gateway.get("packet_loss_pct"), 0),
                "uptime_hrs": numeric(gateway.get("uptime_hrs") or gateway.get("uptime"), 0),
                "avg_rssi": numeric(gateway.get("avg_rssi") or gateway.get("averageRssi"), 0),
                "avg_snr": numeric(gateway.get("avg_snr") or gateway.get("averageSnr"), 0),
                "data_volume_mb": numeric(gateway.get("data_volume_mb"), 0),
                "is_anomaly": boolish(gateway.get("is_anomaly", False)),
                "anomaly_type": gateway.get("anomaly_type", "normal"),
            }
        )
    return rows


def normalize_real_alerts(snapshot: Dict[str, Any]) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    alerts = flatten_map(snapshot.get("alerts"))
    for alert_id, payload in alerts.items():
        alert = flatten_map(payload)
        rows.append(
            {
                "alert_id": str(alert_id),
                "timestamp": parse_timestamp(alert.get("timestamp")),
                "domain": alert.get("domain", "system"),
                "node_id": alert.get("nodeId", ""),
                "severity": alert.get("severity", "info"),
                "title": alert.get("title", "Firebase Alert"),
                "message": alert.get("message", ""),
                "resolved": boolish(alert.get("resolved", False)),
                "source": "firebase",
            }
        )
    return rows


def seasonal_adjustment(ts: datetime) -> Dict[str, float]:
    month = ts.month
    summer = 1.0 if month in {6, 7, 8, 9} else 0.0
    winter = 1.0 if month in {12, 1, 2} else 0.0
    # Approximate Ramadan windows for generated data around 2025-2026.
    ramadan = 1.0 if (
        datetime(2025, 2, 28, tzinfo=timezone.utc)
        <= ts
        <= datetime(2025, 3, 29, tzinfo=timezone.utc)
        or datetime(2026, 2, 18, tzinfo=timezone.utc)
        <= ts
        <= datetime(2026, 3, 19, tzinfo=timezone.utc)
    ) else 0.0
    hour = ts.hour + ts.minute / 60.0
    morning_peak = math.exp(-((hour - 8.0) ** 2) / 4.5)
    evening_peak = math.exp(-((hour - 18.0) ** 2) / 6.0)
    night = 1.0 if hour < 5 or hour >= 23 else 0.0
    return {
        "summer": summer,
        "winter": winter,
        "ramadan": ramadan,
        "morning_peak": morning_peak,
        "evening_peak": evening_peak,
        "night": night,
        "daily_wave": math.sin((hour - 6.0) / 24.0 * 2.0 * math.pi),
    }


def choose_anomaly(rng: random.Random, anomaly_rate: float) -> str:
    if rng.random() >= anomaly_rate:
        return "normal"
    return rng.choices(
        ["sensor_fault", "infrastructure_issue", "communication_issue", "battery_critical"],
        weights=[0.20, 0.42, 0.24, 0.14],
        k=1,
    )[0]


def common_signal(
    rng: random.Random, ts: datetime, anomaly_type: str, base_battery: float
) -> Dict[str, float]:
    patterns = seasonal_adjustment(ts)
    battery = base_battery - (datetime.now(timezone.utc) - ts).days * 0.005
    battery += rng.gauss(0, 0.8)
    rssi = -72 + rng.gauss(0, 4.5) - patterns["night"] * 2.0
    snr = 8.5 + rng.gauss(0, 1.4) - patterns["night"] * 0.5
    if anomaly_type == "communication_issue":
        rssi -= rng.uniform(22, 40)
        snr -= rng.uniform(8, 15)
    if anomaly_type == "battery_critical":
        battery = rng.uniform(3, 14)
        rssi -= rng.uniform(3, 10)
    return {
        "battery_pct": rounded(clamp(battery, 0, 100), 2),
        "rssi_dbm": rounded(clamp(rssi, -125, -35), 2),
        "snr_db": rounded(clamp(snr, -20, 18), 2),
    }


def water_row(
    rng: random.Random, node_id: str, ts: datetime, anomaly_type: str
) -> Dict[str, Any]:
    p = seasonal_adjustment(ts)
    demand = 0.35 + p["morning_peak"] * 0.65 + p["evening_peak"] * 0.55
    demand *= 0.88 if p["ramadan"] and 7 <= ts.hour <= 16 else 1.0
    pressure = 5.6 - demand * 1.0 + rng.gauss(0, 0.16)
    flow = 82 + demand * 78 + p["summer"] * 16 + rng.gauss(0, 6)
    water_level = 3.4 - demand * 0.45 + p["winter"] * 0.25 + rng.gauss(0, 0.08)
    pipe_temp = 21 + p["summer"] * 10 - p["winter"] * 5 + p["daily_wave"] * 4
    leak = 0
    if anomaly_type == "infrastructure_issue":
        pressure -= rng.uniform(1.8, 3.8)
        flow += rng.uniform(45, 115)
        water_level -= rng.uniform(0.55, 1.1)
        leak = 1
    elif anomaly_type == "sensor_fault":
        pressure = rng.choice([-2.0, 23.5, 0.0])
        flow = rng.choice([-12.0, 420.0, flow])
    row = {
        "pressure_bar": rounded(pressure, 3),
        "flow_rate_lpm": rounded(flow, 3),
        "water_level_m": rounded(clamp(water_level, 0, 5.5), 3),
        "pipe_temp_c": rounded(pipe_temp + rng.gauss(0, 0.7), 3),
        "leak_detected": leak,
    }
    row.update(common_signal(rng, ts, anomaly_type, base_battery=91))
    return base_row(ts, node_id, "water", anomaly_type, row)


def bridge_row(
    rng: random.Random, node_id: str, ts: datetime, anomaly_type: str
) -> Dict[str, Any]:
    p = seasonal_adjustment(ts)
    traffic = 0.25 + p["morning_peak"] * 0.8 + p["evening_peak"] * 0.75
    if p["ramadan"]:
        traffic += math.exp(-((ts.hour - 22.0) ** 2) / 8.0) * 0.45
    load = 2.8 + traffic * 18 + rng.gauss(0, 1.2)
    vibration = 3.0 + traffic * 16 + load * 0.25 + rng.gauss(0, 1.1)
    tilt = rng.gauss(0.25, 0.18) + traffic * 0.12
    crack = clamp(0.03 + load / 500.0 + rng.gauss(0, 0.015), 0, 1)
    temp = 22 + p["summer"] * 14 - p["winter"] * 5 + p["daily_wave"] * 5
    humidity = 48 + p["winter"] * 15 - p["summer"] * 10 - p["daily_wave"] * 4
    if anomaly_type == "infrastructure_issue":
        load += rng.uniform(14, 32)
        vibration += rng.uniform(18, 45)
        tilt += rng.uniform(2.5, 6.5)
        crack += rng.uniform(0.25, 0.55)
    elif anomaly_type == "sensor_fault":
        vibration = rng.choice([-4.0, 240.0])
        tilt = rng.choice([-99.0, 99.0])
    row = {
        "vibration_hz": rounded(vibration, 3),
        "tilt_angle_deg": rounded(tilt, 3),
        "load_weight_ton": rounded(max(0, load), 3),
        "crack_index": rounded(clamp(crack, 0, 1), 4),
        "temp_c": rounded(temp + rng.gauss(0, 0.8), 3),
        "humidity_pct": rounded(clamp(humidity + rng.gauss(0, 2), 5, 100), 3),
    }
    row.update(common_signal(rng, ts, anomaly_type, base_battery=88))
    return base_row(ts, node_id, "bridge", anomaly_type, row)


def building_row(
    rng: random.Random, node_id: str, ts: datetime, anomaly_type: str
) -> Dict[str, Any]:
    p = seasonal_adjustment(ts)
    occupied = 1.0 if 7 <= ts.hour <= 18 and ts.weekday() < 5 else 0.25
    if p["ramadan"] and 18 <= ts.hour <= 23:
        occupied += 0.35
    occupancy = max(0, int(rng.gauss(34 * occupied, 5)))
    temp = 23 + p["summer"] * 8 - p["winter"] * 4 + occupied * 1.8 + rng.gauss(0, 0.8)
    humidity = 46 + p["winter"] * 12 - p["summer"] * 8 - (temp - 24) * 0.7
    co2 = 420 + occupancy * 18 + rng.gauss(0, 35)
    power = 2.2 + occupied * 4.0 + p["summer"] * 2.1 + rng.gauss(0, 0.35)
    smoke = max(0, rng.gauss(55, 20))
    if anomaly_type == "infrastructure_issue":
        smoke += rng.uniform(420, 950)
        co2 += rng.uniform(450, 900)
        temp += rng.uniform(5, 13)
        power += rng.uniform(3, 8)
    elif anomaly_type == "sensor_fault":
        temp = rng.choice([-30.0, 92.0])
        humidity = rng.choice([-5.0, 140.0])
    row = {
        "temp_c": rounded(temp, 3),
        "humidity_pct": rounded(clamp(humidity, 0, 100), 3),
        "co2_ppm": rounded(max(250, co2), 3),
        "power_kwh": rounded(max(0, power), 3),
        "occupancy_count": occupancy,
        "smoke_level": rounded(smoke, 3),
    }
    row.update(common_signal(rng, ts, anomaly_type, base_battery=90))
    return base_row(ts, node_id, "building", anomaly_type, row)


def agriculture_row(
    rng: random.Random, node_id: str, ts: datetime, anomaly_type: str
) -> Dict[str, Any]:
    p = seasonal_adjustment(ts)
    air_temp = 24 + p["summer"] * 13 - p["winter"] * 6 + p["daily_wave"] * 6
    air_humidity = 58 + p["winter"] * 12 - p["summer"] * 16 - p["daily_wave"] * 6
    soil_temp = air_temp - 2.0 + rng.gauss(0, 0.7)
    soil_moisture = 56 - max(0, air_temp - 26) * 1.15 + air_humidity * 0.08
    irrigation = 1 if soil_moisture < 34 and ts.hour in {5, 6, 18, 19} else 0
    if irrigation:
        soil_moisture += rng.uniform(8, 18)
    ndvi = 0.62 + (soil_moisture - 45) / 140.0 - p["summer"] * 0.04
    if anomaly_type == "infrastructure_issue":
        irrigation = 0
        soil_moisture -= rng.uniform(24, 42)
        ndvi -= rng.uniform(0.16, 0.32)
    elif anomaly_type == "sensor_fault":
        soil_moisture = rng.choice([-10.0, 130.0])
        ndvi = rng.choice([-0.4, 1.8])
    row = {
        "soil_moisture_pct": rounded(clamp(soil_moisture + rng.gauss(0, 1.6), -20, 140), 3),
        "soil_temp_c": rounded(soil_temp, 3),
        "air_temp_c": rounded(air_temp + rng.gauss(0, 0.9), 3),
        "air_humidity_pct": rounded(clamp(air_humidity + rng.gauss(0, 2.5), 5, 100), 3),
        "irrigation_active": irrigation,
        "ndvi_index": rounded(clamp(ndvi + rng.gauss(0, 0.025), -0.5, 1.7), 4),
    }
    row.update(common_signal(rng, ts, anomaly_type, base_battery=87))
    return base_row(ts, node_id, "agriculture", anomaly_type, row)


def base_row(
    ts: datetime, node_id: str, domain: str, anomaly_type: str, values: Dict[str, Any]
) -> Dict[str, Any]:
    row = {column: "" for column in TELEMETRY_COLUMNS}
    row.update(
        {
            "timestamp": iso(ts),
            "node_id": node_id,
            "domain": domain,
            "is_anomaly": 0 if anomaly_type == "normal" else 1,
            "anomaly_type": anomaly_type,
        }
    )
    row.update(values)
    return row


def synthetic_gateway_row(
    rng: random.Random, ts: datetime, step: int, anomaly_rate: float
) -> Dict[str, Any]:
    anomaly_type = choose_anomaly(rng, anomaly_rate * 0.7)
    connected = 4
    packet_loss = max(0, rng.gauss(1.8, 0.9))
    avg_rssi = -73 + rng.gauss(0, 3)
    avg_snr = 8.2 + rng.gauss(0, 0.9)
    if anomaly_type == "communication_issue":
        connected = rng.choice([1, 2])
        packet_loss += rng.uniform(18, 42)
        avg_rssi -= rng.uniform(18, 35)
        avg_snr -= rng.uniform(7, 14)
    elif anomaly_type == "sensor_fault":
        packet_loss = rng.choice([-5.0, 150.0])
    return {
        "timestamp": iso(ts),
        "gateway_id": GATEWAY_ID,
        "connected_nodes": connected,
        "packet_loss_pct": rounded(packet_loss, 3),
        "uptime_hrs": rounded(step * READING_INTERVAL_MIN / 60.0, 3),
        "avg_rssi": rounded(avg_rssi, 3),
        "avg_snr": rounded(avg_snr, 3),
        "data_volume_mb": rounded(120 + step * 0.018 + rng.gauss(0, 0.03), 3),
        "is_anomaly": 0 if anomaly_type == "normal" else 1,
        "anomaly_type": anomaly_type,
    }


DOMAIN_GENERATORS = {
    "water": water_row,
    "bridge": bridge_row,
    "building": building_row,
    "agriculture": agriculture_row,
}


def alert_from_row(row: Dict[str, Any], serial: int) -> Optional[Dict[str, Any]]:
    if str(row.get("is_anomaly")) != "1":
        return None
    anomaly_type = str(row.get("anomaly_type", "normal"))
    if anomaly_type == "sensor_fault":
        severity = "warning"
        title = "Sensor Fault Pattern"
        message = "AI labeling found physically invalid or unstable sensor values."
    elif anomaly_type == "communication_issue":
        severity = "warning"
        title = "LoRa Communication Degradation"
        message = "RSSI/SNR dropped enough to risk packet loss."
    elif anomaly_type == "battery_critical":
        severity = "critical"
        title = "Battery Critical"
        message = "Node battery is below the safe operating threshold."
    else:
        severity = "critical"
        title = "Infrastructure Issue Pattern"
        message = "Sensor combination indicates a likely real infrastructure issue."
    return {
        "alert_id": f"syn_{row['domain']}_{serial:07d}",
        "timestamp": row["timestamp"],
        "domain": row["domain"],
        "node_id": row["node_id"],
        "severity": severity,
        "title": title,
        "message": message,
        "resolved": 0,
        "source": "synthetic_ai_label",
    }


def label_from_row(row: Dict[str, Any]) -> Dict[str, Any]:
    anomaly_type = str(row.get("anomaly_type") or "normal")
    return {
        "timestamp": row["timestamp"],
        "node_id": row["node_id"],
        "domain": row["domain"],
        "is_anomaly": row.get("is_anomaly", 0),
        "anomaly_type": anomaly_type,
        "label_type": ANOMALY_LABELS.get(anomaly_type, 2 if row.get("is_anomaly") else 0),
    }


def write_rows(path: Path, columns: List[str], rows: Iterable[Dict[str, Any]]) -> int:
    count = 0
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)
            count += 1
    return count


def append_rows(
    writer: csv.DictWriter, rows: Iterable[Dict[str, Any]]
) -> Tuple[int, Counter]:
    count = 0
    labels: Counter = Counter()
    for row in rows:
        writer.writerow(row)
        count += 1
        labels[str(row.get("anomaly_type") or "normal")] += 1
    return count, labels


def domain_metadata() -> List[Dict[str, Any]]:
    return [
        {
            "domain": "water",
            "display_name": "Water Network",
            "node_count": 1,
            "primary_sensor": "pressure_bar",
            "description": "Pressure, flow, tank level, pipe temperature, and leak state.",
        },
        {
            "domain": "bridge",
            "display_name": "Bridge & Road",
            "node_count": 1,
            "primary_sensor": "vibration_hz",
            "description": "Vibration, tilt, structural load, crack index, temperature, and humidity.",
        },
        {
            "domain": "building",
            "display_name": "Building",
            "node_count": 1,
            "primary_sensor": "temp_c",
            "description": "Indoor climate, air quality, power, occupancy, and smoke.",
        },
        {
            "domain": "agriculture",
            "display_name": "Smart Agriculture",
            "node_count": 1,
            "primary_sensor": "soil_moisture_pct",
            "description": "Soil moisture, soil temperature, air climate, irrigation, and NDVI.",
        },
        {
            "domain": "gateway",
            "display_name": "LoRa Gateway",
            "node_count": 1,
            "primary_sensor": "avg_rssi",
            "description": "Connected nodes, packet loss, uptime, RSSI/SNR, and data volume.",
        },
    ]


def make_status_rows(latest_by_node: Dict[str, Dict[str, Any]]) -> List[Dict[str, Any]]:
    rows = []
    for node_id, row in sorted(latest_by_node.items()):
        anomaly_type = str(row.get("anomaly_type") or "normal")
        rows.append(
            {
                "node_id": node_id,
                "domain": row["domain"],
                "online": 1 if anomaly_type != "communication_issue" else 0,
                "battery_pct": row.get("battery_pct", ""),
                "rssi_dbm": row.get("rssi_dbm", ""),
                "snr_db": row.get("snr_db", ""),
                "last_seen": row["timestamp"],
                "firmware_version": "synthetic-1.0.0",
                "health_state": "attention" if row.get("is_anomaly") else "healthy",
            }
        )
    return rows


def generate_and_export(args: argparse.Namespace) -> Dict[str, Any]:
    ensure_dirs()
    rng = random.Random(args.seed)
    steps = int(args.days * 24 * 60 / READING_INTERVAL_MIN)
    end = datetime.now(timezone.utc).replace(second=0, microsecond=0)
    minute = end.minute - (end.minute % READING_INTERVAL_MIN)
    end = end.replace(minute=minute)
    start = end - timedelta(minutes=(steps - 1) * READING_INTERVAL_MIN)

    snapshot = load_firebase_snapshot()
    real_telemetry = normalize_real_telemetry(snapshot) if snapshot else []
    real_status = normalize_real_status(snapshot) if snapshot else []
    real_gateways = normalize_real_gateways(snapshot) if snapshot else []
    real_alerts = normalize_real_alerts(snapshot) if snapshot else []

    real_counts_by_domain = Counter(row.get("domain", "unknown") for row in real_telemetry)
    min_rows_per_domain = max(args.min_rows_per_domain, 10_000)
    synthetic_needed = {
        domain: max(0, min_rows_per_domain - real_counts_by_domain.get(domain, 0))
        for domain in DOMAINS
    }
    # A full one-year generation produces more than the requested minimum.
    target_steps_by_domain = {
        domain: steps if synthetic_needed[domain] > 0 else 0 for domain in DOMAINS
    }

    telemetry_path = RAW_DIR / "nodes_telemetry.csv"
    alerts_path = RAW_DIR / "alerts_history.csv"
    labeled_path = RAW_DIR / "labeled_anomalies.csv"
    gateway_path = RAW_DIR / "gateways.csv"
    status_path = RAW_DIR / "nodes_status.csv"
    domains_path = RAW_DIR / "domains.csv"

    latest_by_node: Dict[str, Dict[str, Any]] = {}
    label_distribution: Counter = Counter()
    domain_counts: Counter = Counter()
    alert_count = 0

    with telemetry_path.open("w", newline="", encoding="utf-8") as telemetry_file, alerts_path.open(
        "w", newline="", encoding="utf-8"
    ) as alerts_file, labeled_path.open("w", newline="", encoding="utf-8") as labeled_file:
        telemetry_writer = csv.DictWriter(telemetry_file, fieldnames=TELEMETRY_COLUMNS)
        alert_writer = csv.DictWriter(alerts_file, fieldnames=ALERT_COLUMNS)
        label_writer = csv.DictWriter(labeled_file, fieldnames=LABELED_COLUMNS)
        telemetry_writer.writeheader()
        alert_writer.writeheader()
        label_writer.writeheader()

        for row in real_telemetry:
            telemetry_writer.writerow(row)
            latest_by_node[str(row["node_id"])] = row
            domain_counts[row["domain"]] += 1
            label = label_from_row(row)
            label_writer.writerow(label)
            label_distribution[str(label["label_type"])] += 1

        for row in real_alerts:
            alert_writer.writerow(row)
            alert_count += 1

        serial = alert_count
        for domain in DOMAINS:
            node_id = f"{domain}_node_001"
            generator = DOMAIN_GENERATORS[domain]
            total = target_steps_by_domain[domain]
            if total <= 0:
                continue
            iterator = progress(range(total), desc=f"Generating {domain}", unit="rows")
            for step in iterator:
                ts = start + timedelta(minutes=step * READING_INTERVAL_MIN)
                anomaly_type = choose_anomaly(rng, args.anomaly_rate)
                row = generator(rng, node_id, ts, anomaly_type)
                telemetry_writer.writerow(row)
                label = label_from_row(row)
                label_writer.writerow(label)
                label_distribution[str(label["label_type"])] += 1
                latest_by_node[node_id] = row
                domain_counts[domain] += 1
                alert = alert_from_row(row, serial)
                if alert:
                    alert_writer.writerow(alert)
                    serial += 1
                    alert_count += 1

    with gateway_path.open("w", newline="", encoding="utf-8") as gateway_file:
        gateway_writer = csv.DictWriter(gateway_file, fieldnames=GATEWAY_COLUMNS)
        gateway_writer.writeheader()
        for row in real_gateways:
            gateway_writer.writerow(row)
        iterator = progress(range(steps), desc="Generating gateway", unit="rows")
        for step in iterator:
            ts = start + timedelta(minutes=step * READING_INTERVAL_MIN)
            gateway_writer.writerow(
                synthetic_gateway_row(rng, ts, step, args.anomaly_rate)
            )

    status_rows = real_status + make_status_rows(latest_by_node)
    status_count = write_rows(status_path, STATUS_COLUMNS, status_rows)
    domain_count = write_rows(domains_path, DOMAIN_METADATA_COLUMNS, domain_metadata())

    report = {
        "step": 1,
        "generated_at": iso(datetime.now(timezone.utc)),
        "firebase": {
            "credentials_configured": bool(os.getenv("FIREBASE_CREDENTIALS_PATH")),
            "database_url_configured": bool(os.getenv("FIREBASE_DATABASE_URL")),
            "real_telemetry_rows": len(real_telemetry),
            "real_status_rows": len(real_status),
            "real_gateway_rows": len(real_gateways),
            "real_alert_rows": len(real_alerts),
        },
        "parameters": {
            "days": args.days,
            "interval_minutes": READING_INTERVAL_MIN,
            "anomaly_rate": args.anomaly_rate,
            "seed": args.seed,
        },
        "rows": {
            "nodes_telemetry": int(sum(domain_counts.values())),
            "nodes_status": status_count,
            "gateways": len(real_gateways) + steps,
            "alerts_history": alert_count,
            "labeled_anomalies": int(sum(label_distribution.values())),
            "domains": domain_count,
        },
        "domain_distribution": dict(domain_counts),
        "label_distribution": dict(label_distribution),
        "outputs": {
            "nodes_telemetry": str(telemetry_path.relative_to(ROOT)),
            "nodes_status": str(status_path.relative_to(ROOT)),
            "gateways": str(gateway_path.relative_to(ROOT)),
            "alerts_history": str(alerts_path.relative_to(ROOT)),
            "labeled_anomalies": str(labeled_path.relative_to(ROOT)),
            "domains": str(domains_path.relative_to(ROOT)),
        },
    }
    report_path = REPORT_DIR / "step_1_report.json"
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    log(f"[green]Data exported successfully: {report['rows']['nodes_telemetry']} telemetry rows[/green]")
    log(f"[green]Report saved to {report_path.relative_to(ROOT)}[/green]")
    return report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--days",
        type=int,
        default=int(os.getenv("SYNTHETIC_DAYS", "365")),
        help="Number of days to synthesize at 5-minute intervals.",
    )
    parser.add_argument(
        "--min-rows-per-domain",
        type=int,
        default=50_000,
        help="Minimum rows per domain before synthetic generation is skipped.",
    )
    parser.add_argument(
        "--anomaly-rate",
        type=float,
        default=float(os.getenv("ANOMALY_RATE", "0.065")),
        help="Synthetic anomaly rate. Recommended range: 0.05 to 0.08.",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=int(os.getenv("SYNTHETIC_SEED", "20260613")),
        help="Random seed for reproducible data.",
    )
    args = parser.parse_args()
    args.anomaly_rate = clamp(args.anomaly_rate, 0.05, 0.08)
    if args.days < 1:
        raise SystemExit("--days must be at least 1")
    return args


if __name__ == "__main__":
    generate_and_export(parse_args())
