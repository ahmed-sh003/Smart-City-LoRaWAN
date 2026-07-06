#!/usr/bin/env python3
"""Build a publication-ready LPWAN/LoRaWAN training dataset.

The builder prioritizes real LoRaWAN data from LoED:
https://zenodo.org/records/4121430 / DOI 10.5281/zenodo.4121430

Rows from LoED are tagged as `real_enriched`: gateway packet metadata is real,
while missing deployment fields such as battery, distance, and current draw are
filled with documented deterministic rules. Additional `synthetic_lpwan` rows
are generated only when needed to reach the target row count.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import random
import shutil
import sys
import urllib.request
import zipfile
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, Iterator, List, Tuple

import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parents[2]
LPWAN_DIR = ROOT / "data" / "lpwan"
RAW_DIR = LPWAN_DIR / "raw"
PROCESSED_DIR = LPWAN_DIR / "processed"
REPORT_DIR = ROOT / "reports"

ZENODO_API = "https://zenodo.org/api/records/4121430"
LOED_FULL = "LoED_LoRaWAN_at_edge_dataset.zip"
LOED_SAMPLE = "LoED_LoRaWAN_at_edge_dataset-SAMPLE.zip"

REQUIRED_COLUMNS = [
    "timestamp",
    "node_id",
    "gateway_id",
    "packet_id",
    "rssi_dbm",
    "snr_db",
    "spreading_factor",
    "bandwidth_khz",
    "coding_rate",
    "tx_power_dbm",
    "frequency_mhz",
    "crc_ok",
    "packet_received",
    "distance_m",
    "environment_type",
    "obstacle_level",
    "battery_voltage",
    "battery_pct",
    "current_ma",
    "delivery_ratio",
    "packet_loss_rate",
    "label_link_quality",
    "label_packet_loss",
    "label_gateway_health",
    "label_energy_risk",
    "label_optimal_sf",
    "source_type",
    "source_dataset",
    "source_file",
    "fields_filled",
]


GATEWAY_METADATA: Dict[str, Dict[str, Any]] = {
    "00000f0c210281c4": {
        "environment_type": "dense_urban_outdoor",
        "obstacle_level": 4,
        "base_distance_m": 1250,
    },
    "00000f0c22433141": {
        "environment_type": "urban_open_rooftop",
        "obstacle_level": 2,
        "base_distance_m": 1550,
    },
    "00000f0c210721f2": {
        "environment_type": "dense_urban_open_space",
        "obstacle_level": 3,
        "base_distance_m": 1350,
    },
    "00000f0c224331c4": {
        "environment_type": "indoor_ground_floor",
        "obstacle_level": 5,
        "base_distance_m": 220,
    },
    "00800000a0001914": {
        "environment_type": "indoor_university",
        "obstacle_level": 4,
        "base_distance_m": 180,
    },
    "00800000a0001793": {
        "environment_type": "indoor_university",
        "obstacle_level": 4,
        "base_distance_m": 180,
    },
    "00800000a0001794": {
        "environment_type": "indoor_university",
        "obstacle_level": 4,
        "base_distance_m": 180,
    },
    "7276ff002e062804": {
        "environment_type": "open_rooftop_university",
        "obstacle_level": 2,
        "base_distance_m": 1800,
    },
    "0000024b0b031c97": {
        "environment_type": "dense_urban_rooftop",
        "obstacle_level": 4,
        "base_distance_m": 1150,
    },
}


def iso_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT)).replace("\\", "/")


def ensure_dirs() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)


def load_zenodo_metadata() -> Dict[str, Any]:
    with urllib.request.urlopen(ZENODO_API, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def zenodo_file_url(metadata: Dict[str, Any], filename: str) -> str:
    for item in metadata.get("files", []):
        if item.get("key") == filename:
            return str(item["links"]["self"])
    raise KeyError(f"{filename} not found in Zenodo record")


def download_file(url: str, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".part")
    with urllib.request.urlopen(url, timeout=120) as response, temp.open("wb") as handle:
        shutil.copyfileobj(response, handle, length=1024 * 1024)
    temp.replace(path)


def ensure_loed_archives(prefer_full: bool) -> Tuple[Path, Dict[str, Any], List[str]]:
    metadata = load_zenodo_metadata()
    notes: List[str] = []
    selected_name = LOED_FULL if prefer_full else LOED_SAMPLE
    selected_path = RAW_DIR / selected_name
    if not selected_path.exists():
        try:
            notes.append(f"Downloading {selected_name} from Zenodo.")
            download_file(zenodo_file_url(metadata, selected_name), selected_path)
        except Exception as exc:
            notes.append(f"Could not download {selected_name}: {exc}")
    if selected_path.exists():
        return selected_path, metadata, notes

    sample_path = RAW_DIR / LOED_SAMPLE
    if not sample_path.exists():
        notes.append(f"Downloading fallback {LOED_SAMPLE} from Zenodo.")
        download_file(zenodo_file_url(metadata, LOED_SAMPLE), sample_path)
    return sample_path, metadata, notes


def csv_members(archive_path: Path) -> List[str]:
    with zipfile.ZipFile(archive_path) as archive:
        return sorted(
            name
            for name in archive.namelist()
            if name.lower().endswith(".csv") and "__macosx" not in name.lower()
        )


def normalize_loed_archive(
    archive_path: Path,
    target_real_rows: int,
    chunksize: int,
    seed: int,
) -> Tuple[pd.DataFrame, Dict[str, Any]]:
    rows: List[pd.DataFrame] = []
    total = 0
    files_used = []
    rng = np.random.default_rng(seed)
    members = csv_members(archive_path)
    with zipfile.ZipFile(archive_path) as archive:
        for member in members:
            if total >= target_real_rows:
                break
            with archive.open(member) as handle:
                for chunk in pd.read_csv(handle, chunksize=chunksize):
                    if total >= target_real_rows:
                        break
                    remaining = target_real_rows - total
                    if len(chunk) > remaining:
                        chunk = chunk.head(remaining)
                    normalized = normalize_loed_chunk(
                        chunk,
                        source_file=f"{archive_path.name}:{member}",
                        rng=rng,
                    )
                    rows.append(normalized)
                    total += len(normalized)
                    files_used.append(member)
    if rows:
        frame = pd.concat(rows, ignore_index=True)
    else:
        frame = pd.DataFrame(columns=REQUIRED_COLUMNS)
    report = {
        "archive": rel(archive_path),
        "csvFilesAvailable": len(members),
        "csvFilesUsed": len(set(files_used)),
        "rows": int(len(frame)),
    }
    return frame, report


def normalize_loed_chunk(chunk: pd.DataFrame, source_file: str, rng: np.random.Generator) -> pd.DataFrame:
    out = pd.DataFrame()
    out["timestamp"] = pd.to_datetime(chunk.get("time"), utc=True, errors="coerce")
    out["node_id"] = chunk.get("device_address", "unknown_node").astype(str)
    out["gateway_id"] = chunk.get("gateway", "unknown_gateway").astype(str)
    fcnt = pd.to_numeric(chunk.get("fcnt", 0), errors="coerce").fillna(0).astype(int)
    out["packet_id"] = [
        stable_packet_id(ts, node, gw, count, i)
        for i, (ts, node, gw, count) in enumerate(
            zip(out["timestamp"], out["node_id"], out["gateway_id"], fcnt)
        )
    ]
    out["rssi_dbm"] = pd.to_numeric(chunk.get("rssi"), errors="coerce").fillna(-120)
    out["snr_db"] = pd.to_numeric(chunk.get("snr"), errors="coerce").fillna(-20)
    out["spreading_factor"] = (
        pd.to_numeric(chunk.get("spreading_factor"), errors="coerce")
        .fillna(7)
        .clip(7, 12)
        .astype(int)
    )
    out["bandwidth_khz"] = pd.to_numeric(chunk.get("bandwidth"), errors="coerce").fillna(125)
    out["coding_rate"] = chunk.get("code_rate", "4/5").astype(str)
    frequency = pd.to_numeric(chunk.get("frequency"), errors="coerce").fillna(868100000).astype(float)
    out["frequency_mhz"] = np.where(frequency > 10000, frequency / 1_000_000, frequency)
    crc = pd.to_numeric(chunk.get("crc_status", 1), errors="coerce").fillna(1).astype(int)
    out["crc_ok"] = (crc == 1).astype(int)
    out["packet_received"] = out["crc_ok"]

    gateway_meta = out["gateway_id"].map(lambda gateway: GATEWAY_METADATA.get(str(gateway), {}))
    out["environment_type"] = gateway_meta.map(lambda meta: meta.get("environment_type", "urban_unknown"))
    out["obstacle_level"] = gateway_meta.map(lambda meta: meta.get("obstacle_level", 3)).astype(float)
    base_distance = gateway_meta.map(lambda meta: meta.get("base_distance_m", 900)).astype(float)
    signal_penalty = ((-80 - out["rssi_dbm"]).clip(lower=0) * 18) + ((0 - out["snr_db"]).clip(lower=0) * 22)
    sf_bonus = (out["spreading_factor"] - 7) * 85
    noise = rng.normal(0, 80, len(out))
    out["distance_m"] = (base_distance + signal_penalty + sf_bonus + noise).clip(20, 8000).round(2)

    out["tx_power_dbm"] = infer_tx_power(out["spreading_factor"], out["rssi_dbm"], rng)
    battery = infer_battery(out["node_id"], out["timestamp"], out["spreading_factor"], rng)
    out["battery_pct"] = battery["battery_pct"]
    out["battery_voltage"] = battery["battery_voltage"]
    out["current_ma"] = infer_current(out["spreading_factor"], out["tx_power_dbm"], out["crc_ok"], rng)
    out["delivery_ratio"] = rolling_delivery_ratio(out)
    out["packet_loss_rate"] = (1 - out["delivery_ratio"]).clip(0, 1)
    out["label_link_quality"] = [
        link_quality(rssi, snr)
        for rssi, snr in zip(out["rssi_dbm"].to_numpy(), out["snr_db"].to_numpy())
    ]
    out["label_packet_loss"] = (
        (out["packet_loss_rate"] >= 0.18)
        | (out["crc_ok"] == 0)
        | (out["rssi_dbm"] < -115)
        | (out["snr_db"] < -10)
    ).astype(int)
    out["label_gateway_health"] = gateway_health_labels(out)
    out["label_energy_risk"] = (
        (out["battery_pct"] < 20)
        | ((out["current_ma"] > 92) & (out["spreading_factor"] >= 11))
        | ((out["tx_power_dbm"] >= 18) & (out["packet_loss_rate"] > 0.25))
    ).astype(int)
    out["label_optimal_sf"] = [
        optimal_sf(rssi, snr, distance, obstacle)
        for rssi, snr, distance, obstacle in zip(
            out["rssi_dbm"], out["snr_db"], out["distance_m"], out["obstacle_level"]
        )
    ]
    out["source_type"] = "real_enriched"
    out["source_dataset"] = "LoED: The LoRaWAN at the Edge Dataset"
    out["source_file"] = source_file
    out["fields_filled"] = "tx_power_dbm,distance_m,environment_type,obstacle_level,battery_voltage,battery_pct,current_ma,delivery_ratio,packet_loss_rate,labels"
    return finalize_columns(out)


def stable_packet_id(ts: Any, node: str, gateway: str, fcnt: int, index: int) -> str:
    raw = f"{ts}|{node}|{gateway}|{fcnt}|{index}".encode("utf-8", errors="ignore")
    return hashlib.sha1(raw).hexdigest()[:20]


def infer_tx_power(sf: pd.Series, rssi: pd.Series, rng: np.random.Generator) -> np.ndarray:
    values = 12 + (sf.to_numpy(dtype=float) - 7) * 0.9 + np.where(rssi.to_numpy(dtype=float) < -112, 2, 0)
    values += rng.normal(0, 1.1, len(sf))
    return np.clip(np.round(values), 2, 20).astype(int)


def infer_battery(
    nodes: pd.Series,
    timestamps: pd.Series,
    sf: pd.Series,
    rng: np.random.Generator,
) -> Dict[str, np.ndarray]:
    node_factor = nodes.map(lambda node: int(hashlib.md5(str(node).encode()).hexdigest()[:4], 16) % 35)
    ts = pd.to_datetime(timestamps, utc=True, errors="coerce")
    min_ts = ts.min()
    days = (ts - min_ts).dt.total_seconds().fillna(0) / 86400 if pd.notna(min_ts) else 0
    pct = 92 - node_factor.to_numpy(dtype=float) * 0.35 - np.asarray(days, dtype=float) * 0.015
    pct -= (sf.to_numpy(dtype=float) - 7) * 0.85
    pct += rng.normal(0, 2.2, len(nodes))
    pct = np.clip(pct, 5, 100)
    voltage = 3.05 + (pct / 100) * 1.12 + rng.normal(0, 0.025, len(nodes))
    return {
        "battery_pct": np.round(pct, 2),
        "battery_voltage": np.round(np.clip(voltage, 3.0, 4.22), 3),
    }


def infer_current(sf: pd.Series, tx_power: pd.Series, crc_ok: pd.Series, rng: np.random.Generator) -> np.ndarray:
    current = 28 + (sf.to_numpy(dtype=float) - 7) * 7.5 + np.asarray(tx_power, dtype=float) * 1.7
    current += np.where(np.asarray(crc_ok, dtype=int) == 0, 8, 0)
    current += rng.normal(0, 4.5, len(sf))
    return np.round(np.clip(current, 18, 140), 2)


def rolling_delivery_ratio(frame: pd.DataFrame) -> pd.Series:
    ordered = frame[["node_id", "gateway_id", "timestamp", "crc_ok"]].copy()
    ordered["_idx"] = np.arange(len(ordered))
    ordered = ordered.sort_values(["node_id", "gateway_id", "timestamp", "_idx"])
    ratios = (
        ordered.groupby(["node_id", "gateway_id"], sort=False)["crc_ok"]
        .transform(lambda s: s.rolling(50, min_periods=1).mean())
        .clip(0, 1)
    )
    ordered["_ratio"] = ratios
    return ordered.sort_values("_idx")["_ratio"].reset_index(drop=True)


def link_quality(rssi: float, snr: float) -> str:
    if rssi >= -90 and snr >= 8:
        return "excellent"
    if rssi >= -103 and snr >= 2:
        return "good"
    if rssi >= -115 and snr >= -8:
        return "fair"
    return "poor"


def gateway_health_labels(frame: pd.DataFrame) -> pd.Series:
    grouped = frame.groupby("gateway_id", sort=False)
    delivery = grouped["delivery_ratio"].transform("mean")
    rssi = grouped["rssi_dbm"].transform("median")
    snr = grouped["snr_db"].transform("median")
    labels = np.where(
        (delivery < 0.82) | (rssi < -112) | (snr < -8),
        "critical",
        np.where((delivery < 0.93) | (rssi < -103) | (snr < 0), "degraded", "healthy"),
    )
    return pd.Series(labels, index=frame.index)


def optimal_sf(rssi: float, snr: float, distance: float, obstacle: float) -> int:
    if rssi > -92 and snr > 7 and distance < 900 and obstacle <= 2:
        return 7
    if rssi > -100 and snr > 3 and distance < 1700 and obstacle <= 3:
        return 8
    if rssi > -106 and snr > 0 and distance < 2600:
        return 9
    if rssi > -112 and snr > -5 and distance < 4200:
        return 10
    if rssi > -118 and snr > -10:
        return 11
    return 12


def normalize_project_telemetry(max_rows: int, seed: int) -> pd.DataFrame:
    path = ROOT / "data" / "raw" / "nodes_telemetry.csv"
    if not path.exists() or max_rows <= 0:
        return pd.DataFrame(columns=REQUIRED_COLUMNS)
    df = pd.read_csv(path, nrows=max_rows)
    if df.empty or "rssi_dbm" not in df.columns or "snr_db" not in df.columns:
        return pd.DataFrame(columns=REQUIRED_COLUMNS)
    rng = np.random.default_rng(seed + 7)
    out = pd.DataFrame()
    out["timestamp"] = pd.to_datetime(df["timestamp"], utc=True, errors="coerce")
    out["node_id"] = df.get("node_id", "project_node").astype(str)
    out["gateway_id"] = "smartcity_gateway_001"
    out["packet_id"] = [
        stable_packet_id(ts, node, "smartcity_gateway_001", i, i)
        for i, (ts, node) in enumerate(zip(out["timestamp"], out["node_id"]))
    ]
    out["rssi_dbm"] = pd.to_numeric(df["rssi_dbm"], errors="coerce").fillna(-95)
    out["snr_db"] = pd.to_numeric(df["snr_db"], errors="coerce").fillna(4)
    out["spreading_factor"] = [
        optimal_sf(rssi, snr, 800, 2)
        for rssi, snr in zip(out["rssi_dbm"], out["snr_db"])
    ]
    out["bandwidth_khz"] = 125
    out["coding_rate"] = "4/5"
    out["tx_power_dbm"] = infer_tx_power(out["spreading_factor"], out["rssi_dbm"], rng)
    out["frequency_mhz"] = rng.choice([867.1, 867.3, 867.5, 867.7, 868.1, 868.3], len(out))
    out["crc_ok"] = (rng.random(len(out)) > 0.015).astype(int)
    out["packet_received"] = out["crc_ok"]
    out["distance_m"] = np.round(np.clip(650 + (-80 - out["rssi_dbm"]).clip(lower=0) * 12 + rng.normal(0, 45, len(out)), 20, 5000), 2)
    out["environment_type"] = "smartcity_field"
    out["obstacle_level"] = 2
    out["battery_pct"] = pd.to_numeric(df.get("battery_pct", 80), errors="coerce").fillna(80).clip(0, 100)
    out["battery_voltage"] = np.round(3.05 + (out["battery_pct"] / 100) * 1.12, 3)
    out["current_ma"] = infer_current(out["spreading_factor"], out["tx_power_dbm"], out["crc_ok"], rng)
    out["delivery_ratio"] = rolling_delivery_ratio(out)
    out["packet_loss_rate"] = (1 - out["delivery_ratio"]).clip(0, 1)
    out["label_link_quality"] = [link_quality(r, s) for r, s in zip(out["rssi_dbm"], out["snr_db"])]
    out["label_packet_loss"] = ((out["packet_loss_rate"] >= 0.18) | (out["rssi_dbm"] < -115) | (out["snr_db"] < -10)).astype(int)
    out["label_gateway_health"] = gateway_health_labels(out)
    out["label_energy_risk"] = ((out["battery_pct"] < 20) | ((out["current_ma"] > 92) & (out["spreading_factor"] >= 11))).astype(int)
    out["label_optimal_sf"] = [
        optimal_sf(rssi, snr, distance, obstacle)
        for rssi, snr, distance, obstacle in zip(out["rssi_dbm"], out["snr_db"], out["distance_m"], out["obstacle_level"])
    ]
    out["source_type"] = "project_telemetry_enriched"
    out["source_dataset"] = "Existing SmartCity project telemetry"
    out["source_file"] = rel(path)
    out["fields_filled"] = "gateway_id,packet_id,spreading_factor,bandwidth_khz,coding_rate,tx_power_dbm,frequency_mhz,crc_ok,packet_received,distance_m,environment_type,obstacle_level,battery_voltage,current_ma,delivery_ratio,packet_loss_rate,labels"
    return finalize_columns(out)


def synthesize_lpwan_rows(count: int, seed: int) -> pd.DataFrame:
    if count <= 0:
        return pd.DataFrame(columns=REQUIRED_COLUMNS)
    rng = np.random.default_rng(seed + 17)
    start = datetime(2026, 1, 1, tzinfo=timezone.utc)
    envs = np.array(["dense_urban_outdoor", "urban_open_rooftop", "indoor_university", "smartcity_field", "industrial_edge"])
    obstacles = {"dense_urban_outdoor": 4, "urban_open_rooftop": 2, "indoor_university": 4, "smartcity_field": 2, "industrial_edge": 3}
    out = pd.DataFrame()
    out["timestamp"] = [start + timedelta(seconds=int(i * 45)) for i in range(count)]
    out["node_id"] = [f"synthetic_lpwan_node_{i % 1200:04d}" for i in range(count)]
    out["gateway_id"] = [f"synthetic_gateway_{i % 18:03d}" for i in range(count)]
    out["packet_id"] = [stable_packet_id(ts, node, gw, i, i) for i, (ts, node, gw) in enumerate(zip(out["timestamp"], out["node_id"], out["gateway_id"]))]
    out["environment_type"] = rng.choice(envs, size=count, p=[0.34, 0.20, 0.20, 0.18, 0.08])
    out["obstacle_level"] = [obstacles[str(env)] for env in out["environment_type"]]
    out["distance_m"] = np.round(np.clip(rng.gamma(2.3, 620, count) + np.asarray(out["obstacle_level"]) * 120, 20, 8000), 2)
    out["spreading_factor"] = [
        7 if distance < 800 and obs <= 2 else
        8 if distance < 1500 and obs <= 3 else
        9 if distance < 2500 else
        10 if distance < 3800 else
        11 if distance < 5600 else 12
        for distance, obs in zip(out["distance_m"], out["obstacle_level"])
    ]
    out["bandwidth_khz"] = rng.choice([125, 250], size=count, p=[0.96, 0.04])
    out["coding_rate"] = rng.choice(["4/5", "4/6", "4/7", "4/8"], size=count, p=[0.83, 0.10, 0.05, 0.02])
    out["tx_power_dbm"] = np.round(np.clip(10 + (np.asarray(out["spreading_factor"]) - 7) * 1.2 + rng.normal(0, 1.8, count), 2, 20)).astype(int)
    out["frequency_mhz"] = rng.choice([867.1, 867.3, 867.5, 867.7, 868.1, 868.3, 868.5], size=count)
    path_loss = 35 + 18 * np.log10(np.maximum(out["distance_m"], 20)) + np.asarray(out["obstacle_level"]) * 4
    out["rssi_dbm"] = np.round(np.clip(out["tx_power_dbm"] - path_loss + rng.normal(0, 5.0, count), -130, -45), 2)
    out["snr_db"] = np.round(np.clip(13 - (np.asarray(out["spreading_factor"]) - 7) * 2.2 - np.asarray(out["obstacle_level"]) * 1.1 + rng.normal(0, 3.5, count), -20, 15), 2)
    loss_prob = sigmoid((out["distance_m"] - 3200) / 1200 + (-112 - out["rssi_dbm"]) / 9 + (-7 - out["snr_db"]) / 4)
    out["crc_ok"] = (rng.random(count) > np.clip(loss_prob * 0.45, 0.005, 0.55)).astype(int)
    out["packet_received"] = out["crc_ok"]
    out["battery_pct"] = np.round(np.clip(rng.normal(72, 18, count) - (np.asarray(out["spreading_factor"]) - 7) * 2.2, 4, 100), 2)
    out["battery_voltage"] = np.round(np.clip(3.05 + (out["battery_pct"] / 100) * 1.12 + rng.normal(0, 0.03, count), 3.0, 4.22), 3)
    out["current_ma"] = infer_current(out["spreading_factor"], out["tx_power_dbm"], out["crc_ok"], rng)
    out["delivery_ratio"] = np.round(np.clip(1 - loss_prob + rng.normal(0, 0.04, count), 0, 1), 4)
    out["packet_loss_rate"] = (1 - out["delivery_ratio"]).clip(0, 1)
    out["label_link_quality"] = [link_quality(r, s) for r, s in zip(out["rssi_dbm"], out["snr_db"])]
    out["label_packet_loss"] = ((out["packet_loss_rate"] >= 0.18) | (out["crc_ok"] == 0) | (out["rssi_dbm"] < -115) | (out["snr_db"] < -10)).astype(int)
    out["label_gateway_health"] = gateway_health_labels(out)
    out["label_energy_risk"] = ((out["battery_pct"] < 20) | ((out["current_ma"] > 92) & (np.asarray(out["spreading_factor"]) >= 11))).astype(int)
    out["label_optimal_sf"] = [
        optimal_sf(rssi, snr, distance, obstacle)
        for rssi, snr, distance, obstacle in zip(out["rssi_dbm"], out["snr_db"], out["distance_m"], out["obstacle_level"])
    ]
    out["source_type"] = "synthetic_lpwan"
    out["source_dataset"] = "Rule-based LPWAN expansion"
    out["source_file"] = "generated_by_scripts/mlops/build_lpwan_dataset.py"
    out["fields_filled"] = "all_fields_synthetic"
    return finalize_columns(out)


def sigmoid(values: Any) -> np.ndarray:
    arr = np.asarray(values, dtype=float)
    return 1 / (1 + np.exp(-arr))


def finalize_columns(frame: pd.DataFrame) -> pd.DataFrame:
    for column in REQUIRED_COLUMNS:
        if column not in frame.columns:
            frame[column] = "" if column in {"timestamp", "node_id", "gateway_id", "packet_id", "environment_type", "coding_rate", "label_link_quality", "label_gateway_health", "source_type", "source_dataset", "source_file", "fields_filled"} else 0
    frame = frame[REQUIRED_COLUMNS].copy()
    frame["timestamp"] = pd.to_datetime(frame["timestamp"], utc=True, errors="coerce").dt.strftime("%Y-%m-%dT%H:%M:%SZ")
    numeric_cols = [
        "rssi_dbm",
        "snr_db",
        "spreading_factor",
        "bandwidth_khz",
        "tx_power_dbm",
        "frequency_mhz",
        "crc_ok",
        "packet_received",
        "distance_m",
        "obstacle_level",
        "battery_voltage",
        "battery_pct",
        "current_ma",
        "delivery_ratio",
        "packet_loss_rate",
        "label_packet_loss",
        "label_energy_risk",
        "label_optimal_sf",
    ]
    for column in numeric_cols:
        frame[column] = pd.to_numeric(frame[column], errors="coerce").fillna(0)
    frame["spreading_factor"] = frame["spreading_factor"].astype(int)
    frame["tx_power_dbm"] = frame["tx_power_dbm"].astype(int)
    frame["crc_ok"] = frame["crc_ok"].astype(int)
    frame["packet_received"] = frame["packet_received"].astype(int)
    frame["obstacle_level"] = frame["obstacle_level"].astype(int)
    frame["label_packet_loss"] = frame["label_packet_loss"].astype(int)
    frame["label_energy_risk"] = frame["label_energy_risk"].astype(int)
    frame["label_optimal_sf"] = frame["label_optimal_sf"].astype(int)
    return frame


def write_outputs(dataset: pd.DataFrame) -> Tuple[Path, Path]:
    csv_path = PROCESSED_DIR / "lpwan_training_dataset.csv"
    parquet_path = PROCESSED_DIR / "lpwan_training_dataset.parquet"
    dataset.to_csv(csv_path, index=False)
    dataset.to_parquet(parquet_path, index=False)
    return csv_path, parquet_path


def write_report(
    dataset: pd.DataFrame,
    generated_at: str,
    zenodo_metadata: Dict[str, Any],
    loed_report: Dict[str, Any],
    notes: List[str],
    csv_path: Path,
    parquet_path: Path,
) -> Dict[str, Any]:
    source_counts = dataset["source_type"].value_counts().to_dict()
    dataset_counts = dataset["source_dataset"].value_counts().to_dict()
    real_rows = int(dataset["source_type"].isin(["real_enriched", "project_telemetry_enriched"]).sum())
    synthetic_rows = int((dataset["source_type"] == "synthetic_lpwan").sum())
    payload = {
        "generatedAt": generated_at,
        "rows": int(len(dataset)),
        "realRows": real_rows,
        "syntheticRows": synthetic_rows,
        "realRatio": round(real_rows / max(1, len(dataset)), 6),
        "sourceTypes": {str(k): int(v) for k, v in source_counts.items()},
        "sourceDatasets": {str(k): int(v) for k, v in dataset_counts.items()},
        "outputs": {
            "csv": rel(csv_path),
            "parquet": rel(parquet_path),
        },
        "loed": loed_report,
        "zenodo": {
            "record": ZENODO_API,
            "doi": zenodo_metadata.get("doi"),
            "title": zenodo_metadata.get("title"),
            "license": zenodo_metadata.get("metadata", {}).get("license", {}).get("id"),
        },
        "missingFieldsFilled": [
            "tx_power_dbm",
            "distance_m",
            "environment_type",
            "obstacle_level",
            "battery_voltage",
            "battery_pct",
            "current_ma",
            "delivery_ratio",
            "packet_loss_rate",
            "labels",
        ],
        "assumptions": [
            "LoED provides real gateway packet reception metadata; battery, current draw, distance, obstacle level, and deployment environment are not packet columns and are deterministically enriched.",
            "Observed LoED gateway rows are received gateway events. CRC failures are treated as packet reception failures for packet-loss labels.",
            "Synthetic LPWAN rows are generated only when real/enriched rows do not reach the configured row target.",
            "Optimal spreading factor labels are rule labels based on RSSI, SNR, inferred distance, and obstacle level.",
        ],
        "labelRules": {
            "label_link_quality": "excellent/good/fair/poor thresholds from RSSI and SNR.",
            "label_packet_loss": "1 when rolling loss >= 18%, CRC failed, RSSI < -115 dBm, or SNR < -10 dB.",
            "label_gateway_health": "healthy/degraded/critical from gateway-level delivery ratio, median RSSI, and median SNR.",
            "label_energy_risk": "1 when battery < 20%, high current with SF>=11, or high TX power with high packet loss.",
            "label_optimal_sf": "SF7-SF12 rule recommendation from link margin, distance, and obstacle level.",
        },
        "notes": notes,
    }
    json_path = REPORT_DIR / "lpwan_dataset_report.json"
    json_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    lines = [
        "# LPWAN / LoRaWAN Training Dataset Report",
        "",
        f"- Generated at: `{generated_at}`",
        f"- Rows: `{payload['rows']}`",
        f"- Real/enriched rows: `{real_rows}`",
        f"- Synthetic LPWAN rows: `{synthetic_rows}`",
        f"- Real/enriched ratio: `{payload['realRatio']}`",
        f"- CSV: `{rel(csv_path)}`",
        f"- Parquet: `{rel(parquet_path)}`",
        "",
        "## Source Datasets",
        "",
    ]
    for name, count in payload["sourceDatasets"].items():
        lines.append(f"- `{name}`: `{count}` rows")
    lines.extend(
        [
            "",
            "## LoED Acquisition",
            "",
            f"- Zenodo DOI: `{payload['zenodo']['doi']}`",
            f"- License: `{payload['zenodo']['license']}`",
            f"- Archive: `{loed_report.get('archive')}`",
            f"- CSV files used: `{loed_report.get('csvFilesUsed')}` of `{loed_report.get('csvFilesAvailable')}`",
            "",
            "## Missing Fields Filled",
            "",
        ]
    )
    for field in payload["missingFieldsFilled"]:
        lines.append(f"- `{field}`")
    lines.extend(["", "## Label Generation Rules", ""])
    for label, rule in payload["labelRules"].items():
        lines.append(f"- `{label}`: {rule}")
    lines.extend(["", "## Assumptions", ""])
    for item in payload["assumptions"]:
        lines.append(f"- {item}")
    if notes:
        lines.extend(["", "## Run Notes", ""])
        for note in notes:
            lines.append(f"- {note}")
    (REPORT_DIR / "lpwan_dataset_report.md").write_text("\n".join(lines), encoding="utf-8")
    return payload


def build(args: argparse.Namespace) -> Dict[str, Any]:
    ensure_dirs()
    generated_at = iso_now()
    archive_path, metadata, notes = ensure_loed_archives(prefer_full=not args.sample_only)
    loed_rows_target = max(args.target_rows, args.max_real_rows)
    loed_df, loed_report = normalize_loed_archive(
        archive_path,
        target_real_rows=loed_rows_target,
        chunksize=args.chunksize,
        seed=args.seed,
    )
    project_df = normalize_project_telemetry(
        max_rows=max(0, args.max_project_rows),
        seed=args.seed,
    )
    combined = pd.concat([loed_df, project_df], ignore_index=True)
    synthetic_needed = max(0, args.target_rows - len(combined))
    synthetic_df = synthesize_lpwan_rows(synthetic_needed, args.seed)
    dataset = pd.concat([combined, synthetic_df], ignore_index=True)
    dataset = dataset.drop_duplicates(subset=["packet_id"]).reset_index(drop=True)
    if len(dataset) < args.target_rows:
        extra = synthesize_lpwan_rows(args.target_rows - len(dataset), args.seed + 99)
        dataset = pd.concat([dataset, extra], ignore_index=True)
    csv_path, parquet_path = write_outputs(dataset)
    report = write_report(dataset, generated_at, metadata, loed_report, notes, csv_path, parquet_path)
    print(json.dumps({"rows": report["rows"], "csv": report["outputs"]["csv"], "parquet": report["outputs"]["parquet"]}, indent=2))
    return report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target-rows", type=int, default=500_000)
    parser.add_argument("--max-real-rows", type=int, default=520_000)
    parser.add_argument("--max-project-rows", type=int, default=100_000)
    parser.add_argument("--chunksize", type=int, default=100_000)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--sample-only", action="store_true", help="Use the smaller LoED sample archive instead of the full archive.")
    return parser.parse_args()


if __name__ == "__main__":
    build(parse_args())
