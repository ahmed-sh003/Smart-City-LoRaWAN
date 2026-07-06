#!/usr/bin/env python3
"""Build the Phase 3 real-data training dataset for SmartCity LPWAN.

The script uses only datasets that are actually present on disk. Current real
external coverage is environmental/air-quality telemetry, so bridge and water
coverage remains synthetic and is explicitly capped/documented.
"""

from __future__ import annotations

import json
import math
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Tuple

import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT / "data"
EXTERNAL_DIR = DATA_DIR / "external"
PROCESSED_DIR = DATA_DIR / "processed"
RAW_DIR = DATA_DIR / "raw"
REPORT_DIR = ROOT / "reports" / "mlops"

UNIFIED_REAL_PATH = PROCESSED_DIR / "phase3_unified_real_dataset.csv"
TRAINING_PATH = PROCESSED_DIR / "phase3_training_dataset.csv"

VERSION = "v20260614-phase3-real-data"
RANDOM_SEED = 42

RUNTIME_FEATURES = [
    "domain_id",
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
]

FEATURE_DEFAULTS = {
    "domain_id": 0.0,
    "pressure_bar": 0.0,
    "flow_rate_lpm": 0.0,
    "water_level_m": 0.0,
    "pipe_temp_c": 0.0,
    "leak_detected": 0.0,
    "vibration_hz": 0.0,
    "tilt_angle_deg": 0.0,
    "load_weight_ton": 0.0,
    "crack_index": 0.0,
    "temp_c": 0.0,
    "humidity_pct": 0.0,
    "co2_ppm": 0.0,
    "power_kwh": 0.0,
    "occupancy_count": 0.0,
    "smoke_level": 0.0,
    "soil_moisture_pct": 0.0,
    "soil_temp_c": 0.0,
    "air_temp_c": 0.0,
    "air_humidity_pct": 0.0,
    "irrigation_active": 0.0,
    "ndvi_index": 0.0,
    "battery_pct": 85.0,
    "rssi_dbm": -72.0,
    "snr_db": 8.0,
}

DOMAIN_IDS = {
    "water": 0.0,
    "bridge": 1.0,
    "building": 2.0,
    "gateway": 3.0,
}

BASE_COLUMNS = [
    "timestamp",
    "node_id",
    "domain",
    "infrastructure_domain",
    "source_dataset",
    "source_type",
    "source_file",
    "is_real",
    "is_weak_label",
    "weak_label_rule",
    "sample_weight",
    "is_anomaly",
    "anomaly_type",
    *RUNTIME_FEATURES,
]


def iso_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT)).replace("\\", "/")


def ensure_dirs() -> None:
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)


def count_csv_rows(path: Path) -> int:
    try:
        with path.open("r", encoding="utf-8", errors="ignore") as handle:
            return max(0, sum(1 for _ in handle) - 1)
    except Exception:
        return 0


def schema_for(path: Path) -> Tuple[int, List[str]]:
    if path.suffix.lower() != ".csv":
        return 0, []
    try:
        df = pd.read_csv(path, nrows=5)
        return count_csv_rows(path), [str(column) for column in df.columns]
    except Exception:
        return count_csv_rows(path), []


def inventory_files() -> List[Dict[str, Any]]:
    rows = []
    for base in (RAW_DIR, PROCESSED_DIR, EXTERNAL_DIR):
        if not base.exists():
            continue
        for path in sorted(base.rglob("*")):
            if not path.is_file():
                continue
            row_count, columns = schema_for(path)
            rows.append(
                {
                    "path": rel(path),
                    "folder": rel(base),
                    "size_bytes": path.stat().st_size,
                    "rows": row_count if path.suffix.lower() == ".csv" else None,
                    "columns": columns,
                }
            )
    return rows


def write_inventory_report(inventory: List[Dict[str, Any]]) -> Path:
    lines = [
        "# Phase 3 Data Inventory",
        "",
        f"- Generated at: `{iso_now()}`",
        f"- Files inspected: `{len(inventory)}`",
        "",
        "| Path | Size bytes | Rows | Column count |",
        "| --- | ---: | ---: | ---: |",
    ]
    for item in inventory:
        lines.append(
            f"| `{item['path']}` | {item['size_bytes']} | "
            f"{item['rows'] if item['rows'] is not None else ''} | {len(item['columns'])} |"
        )
    lines.extend(["", "## Schemas", ""])
    for item in inventory:
        if not item["columns"]:
            continue
        columns = ", ".join(f"`{column}`" for column in item["columns"])
        lines.extend([f"### `{item['path']}`", "", columns, ""])
    path = REPORT_DIR / "phase3_data_inventory.md"
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def clean_numeric(series: pd.Series) -> pd.Series:
    values = pd.to_numeric(series, errors="coerce")
    values = values.replace([-200, -999, 999999, -999999], np.nan)
    return values.replace([np.inf, -np.inf], np.nan)


def relative_humidity_from_dewpoint(temp_c: pd.Series, dewp_c: pd.Series) -> pd.Series:
    temp = clean_numeric(temp_c)
    dew = clean_numeric(dewp_c)
    alpha_dew = (17.625 * dew) / (243.04 + dew)
    alpha_temp = (17.625 * temp) / (243.04 + temp)
    rh = 100.0 * np.exp(alpha_dew - alpha_temp)
    return pd.Series(rh, index=temp.index).clip(0, 100)


def runtime_frame(n: int) -> pd.DataFrame:
    return pd.DataFrame({feature: FEATURE_DEFAULTS[feature] for feature in RUNTIME_FEATURES}, index=range(n))


def finalize_rows(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    for feature in RUNTIME_FEATURES:
        if feature not in out.columns:
            out[feature] = FEATURE_DEFAULTS[feature]
        out[feature] = clean_numeric(out[feature]).fillna(FEATURE_DEFAULTS[feature])
    out["domain"] = out["domain"].astype(str).str.lower()
    out["domain_id"] = out["domain"].map(DOMAIN_IDS).fillna(0).astype("float32")
    out["is_anomaly"] = pd.to_numeric(out["is_anomaly"], errors="coerce").fillna(0).astype("int32")
    out["sample_weight"] = pd.to_numeric(out["sample_weight"], errors="coerce").fillna(1.0).astype("float32")
    out["timestamp"] = pd.to_datetime(out["timestamp"], utc=True, errors="coerce")
    out = out.dropna(subset=["timestamp"]).copy()
    out["timestamp"] = out["timestamp"].dt.strftime("%Y-%m-%dT%H:%M:%SZ")
    return out[BASE_COLUMNS]


def pollutant_proxy(*series: pd.Series) -> pd.Series:
    values = None
    for item in series:
        current = clean_numeric(item).fillna(0)
        values = current if values is None else values + current
    if values is None:
        return pd.Series(dtype=float)
    return values.clip(lower=0)


def load_uci_air_quality() -> pd.DataFrame:
    path = EXTERNAL_DIR / "uci_air_quality_gas_multisensor" / "data.csv"
    if not path.exists():
        return pd.DataFrame(columns=BASE_COLUMNS)
    raw = pd.read_csv(path)
    n = len(raw)
    frame = runtime_frame(n)
    timestamp = pd.to_datetime(
        raw["Date"].astype(str) + " " + raw["Time"].astype(str),
        errors="coerce",
        utc=True,
    )
    co = clean_numeric(raw.get("CO(GT)", pd.Series(index=raw.index, dtype=float)))
    c6h6 = clean_numeric(raw.get("C6H6(GT)", pd.Series(index=raw.index, dtype=float)))
    nox = clean_numeric(raw.get("NOx(GT)", pd.Series(index=raw.index, dtype=float)))
    no2 = clean_numeric(raw.get("NO2(GT)", pd.Series(index=raw.index, dtype=float)))
    smoke = clean_numeric(raw.get("PT08.S1(CO)", pd.Series(index=raw.index, dtype=float)))
    ozone = clean_numeric(raw.get("PT08.S5(O3)", pd.Series(index=raw.index, dtype=float)))
    temp = clean_numeric(raw.get("T", pd.Series(index=raw.index, dtype=float)))
    humidity = clean_numeric(raw.get("RH", pd.Series(index=raw.index, dtype=float)))

    frame["temp_c"] = temp
    frame["humidity_pct"] = humidity
    frame["air_temp_c"] = temp
    frame["air_humidity_pct"] = humidity
    frame["smoke_level"] = smoke
    frame["co2_ppm"] = (400 + co.fillna(0) * 120 + no2.fillna(0) * 1.5 + c6h6.fillna(0) * 5).clip(0, 5000)

    weak_anomaly = (
        (co >= 7.0)
        | (c6h6 >= 30.0)
        | (nox >= 500.0)
        | (no2 >= 200.0)
        | (smoke >= 1700.0)
        | (ozone >= 1800.0)
    )
    sensor_fault = (temp < -30) | (temp > 60) | (humidity < 0) | (humidity > 100)
    meta = pd.DataFrame(
        {
            "timestamp": timestamp,
            "node_id": "uci_air_quality_gas_multisensor",
            "domain": "building",
            "infrastructure_domain": "building_environment",
            "source_dataset": "UCI Air Quality Gas Multisensor",
            "source_type": "real_external",
            "source_file": rel(path),
            "is_real": True,
            "is_weak_label": True,
            "weak_label_rule": "CO>=7 or C6H6>=30 or NOx>=500 or NO2>=200 or gas sensor proxy threshold",
            "sample_weight": 1.0,
            "is_anomaly": (weak_anomaly | sensor_fault).fillna(False).astype(int),
            "anomaly_type": np.where(sensor_fault.fillna(False), "sensor_fault", np.where(weak_anomaly.fillna(False), "environmental_air_quality", "normal")),
        }
    )
    return finalize_rows(pd.concat([meta, frame], axis=1))


def load_beijing_pm25() -> pd.DataFrame:
    path = EXTERNAL_DIR / "uci_beijing_pm25" / "data.csv"
    if not path.exists():
        return pd.DataFrame(columns=BASE_COLUMNS)
    raw = pd.read_csv(path)
    n = len(raw)
    frame = runtime_frame(n)
    timestamp = pd.to_datetime(
        raw[["year", "month", "day", "hour"]],
        errors="coerce",
        utc=True,
    )
    pm25 = clean_numeric(raw.get("pm2.5", pd.Series(index=raw.index, dtype=float)))
    temp = clean_numeric(raw.get("TEMP", pd.Series(index=raw.index, dtype=float)))
    pressure = clean_numeric(raw.get("PRES", pd.Series(index=raw.index, dtype=float)))
    dew = clean_numeric(raw.get("DEWP", pd.Series(index=raw.index, dtype=float)))
    rain = clean_numeric(raw.get("Ir", pd.Series(index=raw.index, dtype=float))).fillna(0)
    humidity = relative_humidity_from_dewpoint(temp, dew)

    frame["temp_c"] = temp
    frame["humidity_pct"] = humidity
    frame["air_temp_c"] = temp
    frame["air_humidity_pct"] = humidity
    frame["pressure_bar"] = (pressure / 1000.0).clip(0, 2)
    frame["smoke_level"] = pm25
    frame["co2_ppm"] = (400 + pm25.fillna(0) * 2.0).clip(0, 5000)
    frame["leak_detected"] = (rain > 0).astype(float)

    weak_anomaly = pm25 >= 150.0
    sensor_fault = (temp < -40) | (temp > 60) | (pressure < 850) | (pressure > 1100)
    meta = pd.DataFrame(
        {
            "timestamp": timestamp,
            "node_id": "uci_beijing_pm25_gateway_environment",
            "domain": "gateway",
            "infrastructure_domain": "gateway_environment",
            "source_dataset": "UCI Beijing PM2.5",
            "source_type": "real_external",
            "source_file": rel(path),
            "is_real": True,
            "is_weak_label": True,
            "weak_label_rule": "PM2.5>=150 ug/m3; sensor fault if temperature/pressure outside plausible range",
            "sample_weight": 1.0,
            "is_anomaly": (weak_anomaly | sensor_fault).fillna(False).astype(int),
            "anomaly_type": np.where(sensor_fault.fillna(False), "sensor_fault", np.where(weak_anomaly.fillna(False), "environmental_air_quality", "normal")),
        }
    )
    return finalize_rows(pd.concat([meta, frame], axis=1))


def load_beijing_multisite() -> pd.DataFrame:
    base = (
        EXTERNAL_DIR
        / "uci_beijing_multisite_air_quality"
        / "extracted"
        / "PRSA2017_Data_20130301-20170228"
        / "PRSA_Data_20130301-20170228"
    )
    files = sorted(base.glob("PRSA_Data_*.csv"))
    frames = []
    for path in files:
        raw = pd.read_csv(path)
        n = len(raw)
        frame = runtime_frame(n)
        timestamp = pd.to_datetime(
            raw[["year", "month", "day", "hour"]],
            errors="coerce",
            utc=True,
        )
        pm25 = clean_numeric(raw.get("PM2.5", pd.Series(index=raw.index, dtype=float)))
        pm10 = clean_numeric(raw.get("PM10", pd.Series(index=raw.index, dtype=float)))
        so2 = clean_numeric(raw.get("SO2", pd.Series(index=raw.index, dtype=float)))
        no2 = clean_numeric(raw.get("NO2", pd.Series(index=raw.index, dtype=float)))
        co = clean_numeric(raw.get("CO", pd.Series(index=raw.index, dtype=float)))
        ozone = clean_numeric(raw.get("O3", pd.Series(index=raw.index, dtype=float)))
        temp = clean_numeric(raw.get("TEMP", pd.Series(index=raw.index, dtype=float)))
        pressure = clean_numeric(raw.get("PRES", pd.Series(index=raw.index, dtype=float)))
        dew = clean_numeric(raw.get("DEWP", pd.Series(index=raw.index, dtype=float)))
        rain = clean_numeric(raw.get("RAIN", pd.Series(index=raw.index, dtype=float))).fillna(0)
        humidity = relative_humidity_from_dewpoint(temp, dew)
        station = raw.get("station", pd.Series("unknown", index=raw.index)).astype(str)

        frame["temp_c"] = temp
        frame["humidity_pct"] = humidity
        frame["air_temp_c"] = temp
        frame["air_humidity_pct"] = humidity
        frame["pressure_bar"] = (pressure / 1000.0).clip(0, 2)
        frame["smoke_level"] = pm25.fillna(pm10)
        frame["co2_ppm"] = (400 + pm25.fillna(0) * 2.0 + no2.fillna(0) + so2.fillna(0) * 0.5).clip(0, 5000)
        frame["leak_detected"] = (rain > 0).astype(float)

        weak_anomaly = (
            (pm25 >= 150.0)
            | (pm10 >= 250.0)
            | (co >= 3000.0)
            | (no2 >= 200.0)
            | (ozone >= 200.0)
        )
        sensor_fault = (temp < -40) | (temp > 60) | (pressure < 850) | (pressure > 1100)
        meta = pd.DataFrame(
            {
                "timestamp": timestamp,
                "node_id": "uci_beijing_multisite_" + station.str.lower(),
                "domain": "gateway",
                "infrastructure_domain": "gateway_environment",
                "source_dataset": "UCI Beijing Multi-Site Air Quality",
                "source_type": "real_external",
                "source_file": rel(path),
                "is_real": True,
                "is_weak_label": True,
                "weak_label_rule": "PM2.5>=150 or PM10>=250 or CO>=3000 or NO2>=200 or O3>=200",
                "sample_weight": 1.0,
                "is_anomaly": (weak_anomaly | sensor_fault).fillna(False).astype(int),
                "anomaly_type": np.where(sensor_fault.fillna(False), "sensor_fault", np.where(weak_anomaly.fillna(False), "environmental_air_quality", "normal")),
            }
        )
        frames.append(finalize_rows(pd.concat([meta, frame], axis=1)))
    if not frames:
        return pd.DataFrame(columns=BASE_COLUMNS)
    return pd.concat(frames, ignore_index=True)


def write_unified_report(real_df: pd.DataFrame, source_counts: pd.DataFrame) -> Path:
    lines = [
        "# Phase 3 Unified Real Dataset Report",
        "",
        f"- Generated at: `{iso_now()}`",
        f"- Output: `{rel(UNIFIED_REAL_PATH)}`",
        f"- Real rows: `{len(real_df)}`",
        f"- Weak-labeled rows: `{int(real_df['is_weak_label'].sum())}`",
        f"- Anomaly rows: `{int(real_df['is_anomaly'].sum())}`",
        "",
        "## Rows By Source",
        "",
        "| Source dataset | Rows | Anomalies | Domains |",
        "| --- | ---: | ---: | --- |",
    ]
    for _, row in source_counts.iterrows():
        lines.append(
            f"| {row['source_dataset']} | {int(row['rows'])} | {int(row['anomalies'])} | {row['domains']} |"
        )
    lines.extend(
        [
            "",
            "## Label Policy",
            "",
            "- No external dataset includes the project's exact target label.",
            "- Labels are weak labels generated only from documented environmental thresholds.",
            "- These labels are not treated as field-confirmed incidents.",
            "- Kaggle water leak and bridge SHM datasets were not used because credentials/data files are absent.",
            "",
            "## Domain Mapping",
            "",
            "- UCI gas multisensor data maps to `building` because its gas, temperature, and humidity sensors align with the building node's MQ/DHT telemetry.",
            "- Beijing air-quality datasets map to `gateway` / `gateway_environment` because they represent city-level environmental telemetry rather than a specific deployed node.",
        ]
    )
    path = REPORT_DIR / "phase3_unified_dataset_report.md"
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def load_real_external_dataset() -> pd.DataFrame:
    frames = [
        load_uci_air_quality(),
        load_beijing_pm25(),
        load_beijing_multisite(),
    ]
    frames = [frame for frame in frames if not frame.empty]
    if not frames:
        return pd.DataFrame(columns=BASE_COLUMNS)
    real = pd.concat(frames, ignore_index=True)
    real = real.drop_duplicates(
        subset=["timestamp", "node_id", "source_dataset"], keep="first"
    )
    real = finalize_rows(real)
    real.to_csv(UNIFIED_REAL_PATH, index=False)
    source_counts = (
        real.groupby("source_dataset")
        .agg(
            rows=("source_dataset", "size"),
            anomalies=("is_anomaly", "sum"),
            domains=("domain", lambda values: ", ".join(sorted(set(values)))),
        )
        .reset_index()
    )
    write_unified_report(real, source_counts)
    return real


def load_synthetic_sample(real_rows: int) -> pd.DataFrame:
    path = PROCESSED_DIR / "clean_telemetry_all.csv"
    if not path.exists() or real_rows <= 0:
        return pd.DataFrame(columns=BASE_COLUMNS)
    synthetic = pd.read_csv(path)
    synthetic = synthetic[synthetic["domain"].isin(["water", "bridge", "building"])].copy()
    if synthetic.empty:
        return pd.DataFrame(columns=BASE_COLUMNS)
    max_synthetic = int(real_rows * 0.35)
    domain_targets = {
        "water": min(50000, max_synthetic // 3),
        "bridge": min(50000, max_synthetic // 3),
        "building": min(35000, max_synthetic // 4),
    }
    sampled = []
    for domain, target in domain_targets.items():
        domain_rows = synthetic[synthetic["domain"] == domain]
        if domain_rows.empty or target <= 0:
            continue
        sampled.append(
            domain_rows.sample(
                n=min(target, len(domain_rows)),
                random_state=RANDOM_SEED,
                replace=False,
            )
        )
    if not sampled:
        return pd.DataFrame(columns=BASE_COLUMNS)
    sampled_df = pd.concat(sampled, ignore_index=True)
    meta = pd.DataFrame(
        {
            "timestamp": sampled_df["timestamp"],
            "node_id": sampled_df["node_id"],
            "domain": sampled_df["domain"],
            "infrastructure_domain": sampled_df["domain"],
            "source_dataset": "Phase 1 synthetic telemetry",
            "source_type": "synthetic_phase1_capped",
            "source_file": rel(path),
            "is_real": False,
            "is_weak_label": False,
            "weak_label_rule": "synthetic generator label; capped so synthetic does not dominate Phase 3",
            "sample_weight": 0.35,
            "is_anomaly": sampled_df["is_anomaly"],
            "anomaly_type": sampled_df["anomaly_type"],
        }
    )
    runtime = sampled_df[[feature for feature in RUNTIME_FEATURES if feature != "domain_id"]].copy()
    return finalize_rows(pd.concat([meta, runtime], axis=1))


def write_merge_strategy(training: pd.DataFrame, real_rows: int, synthetic_rows: int) -> Path:
    ratio = real_rows / max(1, len(training))
    lines = [
        "# Phase 3 Merge Strategy",
        "",
        f"- Generated at: `{iso_now()}`",
        f"- Output: `{rel(TRAINING_PATH)}`",
        f"- Final rows: `{len(training)}`",
        f"- Real rows: `{real_rows}`",
        f"- Synthetic rows: `{synthetic_rows}`",
        f"- Real ratio: `{ratio:.3f}`",
        "",
        "## Strategy",
        "",
        "- Keep all available real external rows.",
        "- Add synthetic rows only for deployed hardware domains that lack real external coverage.",
        "- Cap synthetic rows to at most 35% of the real row count.",
        "- Assign synthetic rows `sample_weight=0.35` and real rows `sample_weight=1.0`.",
        "- Exclude legacy agriculture synthetic rows from Phase 3 because the current hardware app domains are building, bridge, water, and gateway.",
        "",
        "## Rows By Source Type",
        "",
        "| Source type | Rows | Anomalies |",
        "| --- | ---: | ---: |",
    ]
    grouped = training.groupby("source_type").agg(rows=("source_type", "size"), anomalies=("is_anomaly", "sum"))
    for source_type, row in grouped.iterrows():
        lines.append(f"| {source_type} | {int(row['rows'])} | {int(row['anomalies'])} |")
    path = REPORT_DIR / "phase3_merge_strategy.md"
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def write_feature_alignment(training: pd.DataFrame) -> Path:
    missing_counts = {}
    default_notes = {
        "domain_id": "Derived from domain using the Phase 3 domain map.",
        "battery_pct": "Neutral 85% default for external datasets with no battery telemetry.",
        "rssi_dbm": "Neutral -72 dBm default for external datasets with no LoRa RSSI.",
        "snr_db": "Neutral 8 dB default for external datasets with no LoRa SNR.",
    }
    real = training[training["is_real"] == True]  # noqa: E712
    for feature in RUNTIME_FEATURES:
        value = FEATURE_DEFAULTS[feature]
        count = int((real[feature] == value).sum()) if feature in real.columns else len(real)
        missing_counts[feature] = count

    lines = [
        "# Phase 3 Feature Alignment",
        "",
        f"- Generated at: `{iso_now()}`",
        f"- Runtime feature count: `{len(RUNTIME_FEATURES)}`",
        "- Flutter feature vector remains unchanged.",
        "",
        "## Runtime Feature Order",
        "",
    ]
    lines.extend([f"{index + 1}. `{feature}`" for index, feature in enumerate(RUNTIME_FEATURES)])
    lines.extend(
        [
            "",
            "## Defaults And Imputation",
            "",
            "| Feature | Default | Real rows using default | Justification |",
            "| --- | ---: | ---: | --- |",
        ]
    )
    for feature in RUNTIME_FEATURES:
        note = default_notes.get(
            feature,
            "0 means not applicable or absent for this infrastructure domain; no target leakage is used.",
        )
        lines.append(
            f"| `{feature}` | {FEATURE_DEFAULTS[feature]} | {missing_counts[feature]} | {note} |"
        )
    path = REPORT_DIR / "phase3_feature_alignment.md"
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def build() -> Dict[str, Any]:
    ensure_dirs()
    inventory = inventory_files()
    inventory_report = write_inventory_report(inventory)
    real = load_real_external_dataset()
    synthetic = load_synthetic_sample(len(real))
    training = pd.concat([real, synthetic], ignore_index=True)
    training = finalize_rows(training)
    training = training.sort_values(["timestamp", "source_type", "node_id"]).reset_index(drop=True)
    training.to_csv(TRAINING_PATH, index=False)
    merge_report = write_merge_strategy(training, len(real), len(synthetic))
    feature_report = write_feature_alignment(training)

    payload = {
        "version": VERSION,
        "generated_at": iso_now(),
        "inventory_report": rel(inventory_report),
        "unified_real_dataset": rel(UNIFIED_REAL_PATH),
        "training_dataset": rel(TRAINING_PATH),
        "merge_report": rel(merge_report),
        "feature_alignment_report": rel(feature_report),
        "real_rows": int(len(real)),
        "synthetic_rows": int(len(synthetic)),
        "training_rows": int(len(training)),
        "real_ratio": round(float(len(real) / max(1, len(training))), 6),
        "domains": training["domain"].value_counts().to_dict(),
        "source_datasets": training["source_dataset"].value_counts().to_dict(),
        "anomaly_rows": int(training["is_anomaly"].sum()),
    }
    (REPORT_DIR / "phase3_dataset_summary.json").write_text(
        json.dumps(payload, indent=2), encoding="utf-8"
    )
    print(json.dumps(payload, indent=2))
    return payload


if __name__ == "__main__":
    build()
