#!/usr/bin/env python3
"""Clean telemetry CSVs and engineer features for model training."""

from __future__ import annotations

import argparse
import csv
import json
import math
import statistics
from collections import Counter, defaultdict, deque
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Deque, Dict, Iterable, List, Optional, Tuple


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "data" / "raw"
PROCESSED_DIR = ROOT / "data" / "processed"
REPORT_DIR = ROOT / "reports"

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

DOMAIN_NUMERIC_COLUMNS = {
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

PRIMARY_FEATURES = {
    "water": ["pressure_bar", "flow_rate_lpm", "water_level_m"],
    "bridge": ["vibration_hz", "tilt_angle_deg", "load_weight_ton"],
    "building": ["temp_c", "humidity_pct", "co2_ppm", "power_kwh"],
    "agriculture": ["soil_moisture_pct", "air_temp_c", "air_humidity_pct"],
}

COMMON_NUMERIC = ["battery_pct", "rssi_dbm", "snr_db"]
WINDOWS = {60: 12, 360: 72, 1440: 288}
LAGS = [1, 6, 12, 24]
MAX_HISTORY = max(max(WINDOWS.values()), max(LAGS), 10) + 1

LABEL_TYPES = {
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
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)


def parse_ts(value: str) -> datetime:
    text = (value or "").strip()
    if not text:
        return datetime.now(timezone.utc)
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00")).astimezone(timezone.utc)
    except Exception:
        try:
            return datetime.fromtimestamp(float(text), tz=timezone.utc)
        except Exception:
            return datetime.now(timezone.utc)


def iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def to_float(value: Any) -> Optional[float]:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip()
    if text == "":
        return None
    try:
        return float(text)
    except ValueError:
        return None


def to_int(value: Any, default: int = 0) -> int:
    number = to_float(value)
    return default if number is None else int(round(number))


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def mean(values: List[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def std(values: List[float]) -> float:
    if len(values) < 2:
        return 0.0
    return statistics.pstdev(values)


def slope(values: List[float]) -> float:
    n = len(values)
    if n < 2:
        return 0.0
    x_mean = (n - 1) / 2.0
    y_mean = mean(values)
    numerator = sum((i - x_mean) * (v - y_mean) for i, v in enumerate(values))
    denominator = sum((i - x_mean) ** 2 for i in range(n))
    return numerator / denominator if denominator else 0.0


class RollingWindow:
    def __init__(self, maxlen: int) -> None:
        self.maxlen = maxlen
        self.values: Deque[float] = deque()
        self.total = 0.0
        self.total_sq = 0.0
        self.min_values: Deque[float] = deque()
        self.max_values: Deque[float] = deque()

    def add(self, value: float) -> None:
        if len(self.values) == self.maxlen:
            old = self.values.popleft()
            self.total -= old
            self.total_sq -= old * old
            if self.min_values and self.min_values[0] == old:
                self.min_values.popleft()
            if self.max_values and self.max_values[0] == old:
                self.max_values.popleft()
        self.values.append(value)
        self.total += value
        self.total_sq += value * value
        while self.min_values and self.min_values[-1] > value:
            self.min_values.pop()
        while self.max_values and self.max_values[-1] < value:
            self.max_values.pop()
        self.min_values.append(value)
        self.max_values.append(value)

    def stats(self) -> Dict[str, float]:
        n = len(self.values)
        if n == 0:
            return {"mean": 0.0, "std": 0.0, "min": 0.0, "max": 0.0, "trend": 0.0}
        avg = self.total / n
        variance = max(0.0, self.total_sq / n - avg * avg)
        trend = 0.0
        if n > 1:
            trend = (self.values[-1] - self.values[0]) / (n - 1)
        return {
            "mean": avg,
            "std": math.sqrt(variance),
            "min": self.min_values[0],
            "max": self.max_values[0],
            "trend": trend,
        }


def is_ramadan(dt: datetime) -> int:
    windows = [
        (datetime(2025, 2, 28, tzinfo=timezone.utc), datetime(2025, 3, 29, tzinfo=timezone.utc)),
        (datetime(2026, 2, 18, tzinfo=timezone.utc), datetime(2026, 3, 19, tzinfo=timezone.utc)),
        (datetime(2027, 2, 8, tzinfo=timezone.utc), datetime(2027, 3, 9, tzinfo=timezone.utc)),
    ]
    return int(any(start <= dt <= end for start, end in windows))


def read_telemetry(path: Path) -> List[Dict[str, Any]]:
    if not path.exists():
        raise FileNotFoundError(f"Missing raw telemetry CSV: {path}")
    rows: List[Dict[str, Any]] = []
    with path.open("r", newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            domain = (row.get("domain") or "").strip().lower()
            if not domain:
                continue
            row["domain"] = domain
            row["_dt"] = parse_ts(row.get("timestamp", ""))
            row["timestamp"] = iso(row["_dt"])
            rows.append(row)
    return rows


def relevant_columns(domain: str) -> List[str]:
    return DOMAIN_NUMERIC_COLUMNS.get(domain, []) + COMMON_NUMERIC


def missing_stats(rows: List[Dict[str, Any]]) -> Dict[str, float]:
    missing = 0
    total = 0
    for row in rows:
        for column in relevant_columns(row["domain"]):
            total += 1
            if to_float(row.get(column)) is None:
                missing += 1
    return {
        "missing_cells": missing,
        "total_cells": total,
        "missing_pct": round(missing / total * 100, 4) if total else 0,
    }


def dedupe_and_sort(rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    seen: Dict[Tuple[str, str], Dict[str, Any]] = {}
    for row in rows:
        key = (str(row.get("node_id", "")), str(row.get("timestamp", "")))
        seen[key] = row
    result = list(seen.values())
    result.sort(key=lambda item: (str(item.get("node_id", "")), item["_dt"]))
    return result


def column_median(rows: List[Dict[str, Any]], column: str) -> float:
    values = [to_float(row.get(column)) for row in rows]
    numbers = [value for value in values if value is not None]
    if not numbers:
        if column == "battery_pct":
            return 75.0
        if column == "rssi_dbm":
            return -78.0
        if column == "snr_db":
            return 7.0
        return 0.0
    return statistics.median(numbers)


def fill_column(rows: List[Dict[str, Any]], column: str) -> None:
    values = [to_float(row.get(column)) for row in rows]
    if column in COMMON_NUMERIC:
        fill = column_median(rows, column)
        for idx, value in enumerate(values):
            if value is None:
                values[idx] = fill
    else:
        prev_idx: List[Optional[int]] = [None] * len(rows)
        next_idx: List[Optional[int]] = [None] * len(rows)
        last_seen: Optional[int] = None
        for idx, value in enumerate(values):
            if value is not None:
                last_seen = idx
            prev_idx[idx] = last_seen
        last_seen = None
        for idx in range(len(values) - 1, -1, -1):
            if values[idx] is not None:
                last_seen = idx
            next_idx[idx] = last_seen

        fallback = column_median(rows, column)
        for idx, value in enumerate(values):
            if value is not None:
                continue
            left = prev_idx[idx]
            right = next_idx[idx]
            if left is not None and right is not None and left != right:
                gap = (rows[right]["_dt"] - rows[left]["_dt"]).total_seconds() / 60.0
                if gap <= 30:
                    left_value = values[left] if values[left] is not None else fallback
                    right_value = values[right] if values[right] is not None else fallback
                    elapsed = (rows[idx]["_dt"] - rows[left]["_dt"]).total_seconds() / 60.0
                    ratio = elapsed / gap if gap else 0.0
                    values[idx] = float(left_value) + (float(right_value) - float(left_value)) * ratio
                    continue
            if left is not None and values[left] is not None:
                values[idx] = values[left]
            elif right is not None and values[right] is not None:
                values[idx] = values[right]
            else:
                values[idx] = fallback

    for idx, value in enumerate(values):
        if value is None:
            value = 0.0
        rows[idx][column] = value


def clean_group(rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    if not rows:
        return rows
    domain = rows[0]["domain"]
    for column in relevant_columns(domain):
        fill_column(rows, column)

    cleaned: List[Dict[str, Any]] = []
    for row in rows:
        # Remove physically impossible outliers while keeping realistic anomalies.
        pressure = to_float(row.get("pressure_bar"))
        if pressure is not None and (pressure < 0 or pressure > 20):
            continue
        temp_values = [
            to_float(row.get("temp_c")),
            to_float(row.get("pipe_temp_c")),
            to_float(row.get("soil_temp_c")),
            to_float(row.get("air_temp_c")),
        ]
        if any(value is not None and (value < -10 or value > 80) for value in temp_values):
            continue
        battery = to_float(row.get("battery_pct"))
        row["battery_pct"] = round(clamp(0.0 if battery is None else battery, 0, 100), 4)
        rssi = to_float(row.get("rssi_dbm"))
        row["rssi_dbm"] = round(clamp(-78.0 if rssi is None else rssi, -120, 0), 4)
        snr = to_float(row.get("snr_db"))
        row["snr_db"] = round(clamp(7.0 if snr is None else snr, -20, 30), 4)
        for column in DOMAIN_NUMERIC_COLUMNS.get(domain, []):
            value = to_float(row.get(column))
            row[column] = "" if value is None else round(value, 5)
        row["is_anomaly"] = to_int(row.get("is_anomaly"))
        row["anomaly_type"] = row.get("anomaly_type") or "normal"
        cleaned.append(row)
    return cleaned


def clean_rows(rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    grouped: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
    for row in rows:
        grouped[str(row.get("node_id", ""))].append(row)

    cleaned: List[Dict[str, Any]] = []
    for node_id, group in progress(grouped.items(), desc="Cleaning nodes", unit="node"):
        group.sort(key=lambda item: item["_dt"])
        cleaned.extend(clean_group(group))
    cleaned.sort(key=lambda item: (str(item.get("node_id", "")), item["_dt"]))
    return cleaned


def clean_row_for_csv(row: Dict[str, Any]) -> Dict[str, Any]:
    return {column: row.get(column, "") for column in TELEMETRY_COLUMNS}


def label_type(row: Dict[str, Any]) -> int:
    anomaly = str(row.get("anomaly_type") or "normal")
    if anomaly in LABEL_TYPES:
        return LABEL_TYPES[anomaly]
    if to_float(row.get("battery_pct")) is not None and float(row["battery_pct"]) < 15:
        return 4
    if to_float(row.get("rssi_dbm")) is not None and float(row["rssi_dbm"]) < -110:
        return 3
    return 2 if to_int(row.get("is_anomaly")) else 0


def signal_quality(row: Dict[str, Any]) -> float:
    rssi = to_float(row.get("rssi_dbm")) or -120
    snr = to_float(row.get("snr_db")) or -20
    rssi_norm = clamp((rssi + 120.0) / 90.0, 0, 1)
    snr_norm = clamp((snr + 20.0) / 50.0, 0, 1)
    return (rssi_norm + snr_norm) / 2.0


def domain_specific_features(row: Dict[str, Any], previous: Optional[Dict[str, Any]]) -> Dict[str, float]:
    domain = row["domain"]
    features: Dict[str, float] = {}
    if domain == "water":
        pressure = to_float(row.get("pressure_bar")) or 0
        flow = to_float(row.get("flow_rate_lpm")) or 0
        prev_pressure = to_float(previous.get("pressure_bar")) if previous else pressure
        features["pressure_drop_rate"] = round(pressure - (prev_pressure or pressure), 6)
        features["flow_efficiency"] = round(flow / max(pressure, 0.1), 6)
    elif domain == "bridge":
        vibration = to_float(row.get("vibration_hz")) or 0
        tilt = abs(to_float(row.get("tilt_angle_deg")) or 0)
        load = to_float(row.get("load_weight_ton")) or 0
        crack = to_float(row.get("crack_index")) or 0
        features["vibration_energy"] = round(vibration * vibration, 6)
        features["structural_stress_index"] = round(load / 35.0 + tilt / 8.0 + crack * 2.5, 6)
    elif domain == "building":
        temp = to_float(row.get("temp_c")) or 0
        humidity = to_float(row.get("humidity_pct")) or 0
        features["comfort_index"] = round(100 - abs(temp - 23) * 3 - abs(humidity - 45) * 0.55, 6)
    elif domain == "agriculture":
        soil = to_float(row.get("soil_moisture_pct")) or 0
        air_temp = to_float(row.get("air_temp_c")) or 0
        air_humidity = to_float(row.get("air_humidity_pct")) or 0
        irrigation = to_float(row.get("irrigation_active")) or 0
        ndvi = to_float(row.get("ndvi_index")) or 0
        evap = max(0.0, air_temp * (1 - air_humidity / 100.0) * (1 + ndvi))
        features["evapotranspiration_index"] = round(evap, 6)
        features["irrigation_efficiency"] = round((soil / 100.0) / max(irrigation, 0.2), 6)
    return features


def engineer_features(rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    grouped: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
    for row in rows:
        grouped[str(row.get("node_id", ""))].append(row)

    engineered: List[Dict[str, Any]] = []
    for node_id, group in progress(grouped.items(), desc="Engineering features", unit="node"):
        group.sort(key=lambda item: item["_dt"])
        domain = group[0]["domain"]
        primary = PRIMARY_FEATURES.get(domain, [])
        lag_history: Dict[str, Deque[float]] = {
            column: deque(maxlen=max(LAGS) + 1) for column in primary
        }
        rolling: Dict[str, Dict[int, RollingWindow]] = {
            column: {
                minutes: RollingWindow(steps) for minutes, steps in WINDOWS.items()
            }
            for column in primary
        }
        rssi_window = RollingWindow(10)
        previous_row: Optional[Dict[str, Any]] = None
        previous_dt: Optional[datetime] = None
        for row in group:
            dt = row["_dt"]
            output: Dict[str, Any] = clean_row_for_csv(row)
            output["timestamp_unix"] = int(dt.timestamp())
            output["hour"] = dt.hour
            output["day_of_week"] = dt.weekday()
            output["month"] = dt.month
            output["is_weekend"] = int(dt.weekday() >= 5)
            output["is_ramadan"] = is_ramadan(dt)
            output["time_since_last_reading_min"] = (
                round((dt - previous_dt).total_seconds() / 60.0, 4)
                if previous_dt
                else 0
            )
            output["is_peak_hour"] = int(7 <= dt.hour <= 9 or 17 <= dt.hour <= 20)

            for column in primary:
                current = to_float(row.get(column)) or 0.0
                previous_values = list(lag_history[column])
                for lag in LAGS:
                    output[f"{column}_lag_{lag}"] = previous_values[-lag] if len(previous_values) >= lag else current
                for minutes, steps in WINDOWS.items():
                    rolling[column][minutes].add(current)
                    stats = rolling[column][minutes].stats()
                    output[f"{column}_rolling_{minutes}m_mean"] = round(stats["mean"], 6)
                    output[f"{column}_rolling_{minutes}m_std"] = round(stats["std"], 6)
                    output[f"{column}_rolling_{minutes}m_min"] = round(stats["min"], 6)
                    output[f"{column}_rolling_{minutes}m_max"] = round(stats["max"], 6)
                    output[f"{column}_rolling_{minutes}m_trend"] = round(stats["trend"], 6)

            output.update(domain_specific_features(row, previous_row))
            output["link_quality_score"] = round(signal_quality(row), 6)
            rssi_window.add(to_float(row.get("rssi_dbm")) or -120)
            output["signal_stability"] = round(rssi_window.stats()["std"], 6)
            output["label_type"] = label_type(row)
            engineered.append(output)

            for column in primary:
                lag_history[column].append(to_float(row.get(column)) or 0.0)
            previous_row = row
            previous_dt = dt

    return engineered


def write_csv(path: Path, rows: List[Dict[str, Any]], columns: Optional[List[str]] = None) -> None:
    if columns is None:
        seen = []
        used = set()
        for row in rows:
            for key in row:
                if key not in used:
                    seen.append(key)
                    used.add(key)
        columns = seen
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def write_parquet_or_csv(rows: List[Dict[str, Any]], parquet_path: Path) -> Dict[str, Any]:
    csv_fallback = parquet_path.with_suffix(".csv")
    try:
        import pandas as pd

        df = pd.DataFrame(rows)
        df.to_parquet(parquet_path, index=False)
        return {"parquet_written": True, "path": str(parquet_path.relative_to(ROOT))}
    except Exception as exc:
        write_csv(csv_fallback, rows)
        return {
            "parquet_written": False,
            "path": str(csv_fallback.relative_to(ROOT)),
            "reason": str(exc),
        }


def feature_metadata(rows: List[Dict[str, Any]]) -> Dict[str, Any]:
    excluded = {"timestamp", "node_id", "domain", "anomaly_type", "is_anomaly", "label_type"}
    if not rows:
        return {"features": [], "target": "label_type", "feature_types": {}}
    keys = sorted({key for row in rows for key in row.keys() if key not in excluded})
    feature_types = {}
    for key in keys:
        sample = next((row.get(key) for row in rows if row.get(key) not in ("", None)), None)
        feature_types[key] = "numeric" if to_float(sample) is not None else "categorical"
    domain_features = {
        domain: [key for key in keys if key in DOMAIN_NUMERIC_COLUMNS.get(domain, []) or key.startswith(tuple(PRIMARY_FEATURES.get(domain, [])))]
        for domain in DOMAIN_NUMERIC_COLUMNS
    }
    return {
        "features": keys,
        "target": "label_type",
        "feature_types": feature_types,
        "domain_primary_features": PRIMARY_FEATURES,
        "domain_feature_hints": domain_features,
        "label_types": {
            "0": "Normal",
            "1": "Sensor Fault",
            "2": "Infrastructure Issue",
            "3": "Communication Issue",
            "4": "Battery Critical",
        },
    }


def run(args: argparse.Namespace) -> Dict[str, Any]:
    ensure_dirs()
    input_path = ROOT / args.input
    raw_rows = read_telemetry(input_path)
    before_missing = missing_stats(raw_rows)
    deduped_rows = dedupe_and_sort(raw_rows)
    cleaned_rows = clean_rows(deduped_rows)
    after_missing = missing_stats(cleaned_rows)
    engineered_rows = engineer_features(cleaned_rows)

    clean_path = PROCESSED_DIR / "clean_telemetry_all.csv"
    parquet_path = PROCESSED_DIR / "features_engineered.parquet"
    metadata_path = PROCESSED_DIR / "feature_metadata.json"
    distribution_path = PROCESSED_DIR / "class_distribution.json"
    report_path = REPORT_DIR / "step_2_report.json"

    write_csv(clean_path, [clean_row_for_csv(row) for row in cleaned_rows], TELEMETRY_COLUMNS)
    feature_output = write_parquet_or_csv(engineered_rows, parquet_path)
    metadata = feature_metadata(engineered_rows)
    metadata_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    distribution = Counter(str(row.get("label_type", 0)) for row in engineered_rows)
    distribution_path.write_text(json.dumps(dict(distribution), indent=2), encoding="utf-8")

    report = {
        "step": 2,
        "input_rows": len(raw_rows),
        "duplicates_removed": len(raw_rows) - len(deduped_rows),
        "clean_rows": len(cleaned_rows),
        "engineered_rows": len(engineered_rows),
        "features": len(metadata["features"]),
        "missing_before": before_missing,
        "missing_after": after_missing,
        "class_distribution": dict(distribution),
        "outputs": {
            "clean_telemetry_all": str(clean_path.relative_to(ROOT)),
            "features_engineered": feature_output,
            "feature_metadata": str(metadata_path.relative_to(ROOT)),
            "class_distribution": str(distribution_path.relative_to(ROOT)),
        },
    }
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    log(f"[green]Features engineered: {len(metadata['features'])} features[/green]")
    log(f"[green]Report saved to {report_path.relative_to(ROOT)}[/green]")
    return report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--input",
        default="data/raw/nodes_telemetry.csv",
        help="Telemetry CSV generated by step 1.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    run(parse_args())
