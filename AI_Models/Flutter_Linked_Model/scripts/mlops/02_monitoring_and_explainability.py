#!/usr/bin/env python3
"""Generate production monitoring, drift, explainability, and A/B reports."""

from __future__ import annotations

import argparse
import json
import math
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Tuple


ROOT = Path(__file__).resolve().parents[2]
PROCESSED_DIR = ROOT / "data" / "processed"
MODEL_DIR = ROOT / "models"
REPORT_DIR = ROOT / "reports"
MLOPS_DIR = REPORT_DIR / "mlops"
ASSET_DIR = ROOT / "assets" / "ml_models"


DEFAULT_FEATURES = [
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


DOMAIN_IDS = {
    "water": 0.0,
    "bridge": 1.0,
    "building": 2.0,
    "agriculture": 3.0,
}


def iso_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT)).replace("\\", "/")


def ensure_dirs() -> None:
    MLOPS_DIR.mkdir(parents=True, exist_ok=True)
    ASSET_DIR.mkdir(parents=True, exist_ok=True)


def load_json(path: Path, default: Dict[str, Any] | None = None) -> Dict[str, Any]:
    if not path.exists():
        return default or {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default or {}


def load_dataset(feature_order: List[str]):
    import numpy as np
    import pandas as pd

    path = PROCESSED_DIR / "clean_telemetry_all.csv"
    if not path.exists():
        raise FileNotFoundError(
            f"Missing {rel(path)}. Run scripts/data_pipeline/02_clean_and_engineer.py first."
        )
    df = pd.read_csv(path)
    if "timestamp" in df.columns:
        df["timestamp"] = pd.to_datetime(df["timestamp"], utc=True, errors="coerce")
        df = df.dropna(subset=["timestamp"]).sort_values("timestamp").reset_index(drop=True)
    if "domain" not in df.columns:
        df["domain"] = "unknown"
    df["domain"] = df["domain"].astype(str).str.lower()
    df["domain_id"] = df["domain"].map(DOMAIN_IDS).fillna(0.0).astype("float32")
    for feature in feature_order:
        if feature not in df.columns:
            df[feature] = 0.0
        df[feature] = (
            pd.to_numeric(df[feature], errors="coerce")
            .replace([np.inf, -np.inf], np.nan)
            .fillna(0.0)
            .astype("float32")
        )
    if "is_anomaly" not in df.columns:
        df["is_anomaly"] = 0
    df["is_anomaly"] = pd.to_numeric(df["is_anomaly"], errors="coerce").fillna(0).astype("int32")
    return df


def split_reference_live(df, live_fraction: float):
    if len(df) < 20:
        raise ValueError("Need at least 20 telemetry rows to compute production monitoring windows.")
    live_count = max(10, int(len(df) * live_fraction))
    live_count = min(live_count, max(10, len(df) // 2))
    reference = df.iloc[: len(df) - live_count].copy()
    live = df.iloc[len(df) - live_count :].copy()
    return reference, live


def psi(reference, current, bins: int = 10) -> float:
    import numpy as np

    ref = np.asarray(reference, dtype=float)
    cur = np.asarray(current, dtype=float)
    ref = ref[np.isfinite(ref)]
    cur = cur[np.isfinite(cur)]
    if len(ref) == 0 or len(cur) == 0:
        return 0.0
    quantiles = np.unique(np.quantile(ref, np.linspace(0, 1, bins + 1)))
    if len(quantiles) < 3:
        lo = min(float(ref.min()), float(cur.min()))
        hi = max(float(ref.max()), float(cur.max()))
        if math.isclose(lo, hi):
            return 0.0
        quantiles = np.linspace(lo, hi, bins + 1)
    quantiles[0] = min(float(ref.min()), float(cur.min())) - 1e-9
    quantiles[-1] = max(float(ref.max()), float(cur.max())) + 1e-9
    ref_hist, _ = np.histogram(ref, bins=quantiles)
    cur_hist, _ = np.histogram(cur, bins=quantiles)
    ref_pct = np.maximum(ref_hist / max(1, ref_hist.sum()), 1e-6)
    cur_pct = np.maximum(cur_hist / max(1, cur_hist.sum()), 1e-6)
    return float(np.sum((cur_pct - ref_pct) * np.log(cur_pct / ref_pct)))


def ks_statistic(reference, current) -> float:
    import numpy as np

    ref = np.sort(np.asarray(reference, dtype=float))
    cur = np.sort(np.asarray(current, dtype=float))
    ref = ref[np.isfinite(ref)]
    cur = cur[np.isfinite(cur)]
    if len(ref) == 0 or len(cur) == 0:
        return 0.0
    values = np.sort(np.unique(np.concatenate([ref, cur])))
    ref_cdf = np.searchsorted(ref, values, side="right") / len(ref)
    cur_cdf = np.searchsorted(cur, values, side="right") / len(cur)
    return float(np.max(np.abs(ref_cdf - cur_cdf)))


def drift_status(psi_value: float, ks_value: float) -> str:
    if psi_value >= 0.25 or ks_value >= 0.25:
        return "high"
    if psi_value >= 0.10 or ks_value >= 0.12:
        return "medium"
    return "low"


def compute_drift(reference, live, feature_order: List[str]) -> Dict[str, Any]:
    feature_drift = []
    for feature in feature_order:
        if feature == "domain_id":
            continue
        psi_value = psi(reference[feature].to_numpy(), live[feature].to_numpy())
        ks_value = ks_statistic(reference[feature].to_numpy(), live[feature].to_numpy())
        feature_drift.append(
            {
                "feature": feature,
                "psi": round(psi_value, 6),
                "ks": round(ks_value, 6),
                "referenceMean": round(float(reference[feature].mean()), 6),
                "liveMean": round(float(live[feature].mean()), 6),
                "status": drift_status(psi_value, ks_value),
            }
        )
    feature_drift.sort(key=lambda item: (item["status"] != "high", -item["psi"], -item["ks"]))
    high = sum(1 for item in feature_drift if item["status"] == "high")
    medium = sum(1 for item in feature_drift if item["status"] == "medium")
    if high:
        overall = "high"
    elif medium:
        overall = "medium"
    else:
        overall = "low"
    return {
        "overallStatus": overall,
        "featuresDrifted": high + medium,
        "highDriftFeatures": high,
        "mediumDriftFeatures": medium,
        "topFeatureDrift": feature_drift[:8],
        "allFeatures": feature_drift,
    }


def feature_matrix(df, feature_order: List[str]):
    return df[feature_order].to_numpy(dtype="float32")


def heuristic_scores(live, feature_order: List[str]):
    import numpy as np

    scores = np.full(len(live), 0.08, dtype="float32")
    if "is_anomaly" in live.columns:
        scores += live["is_anomaly"].to_numpy(dtype="float32") * 0.58
    def add_if(feature: str, condition, amount: float) -> None:
        if feature in live.columns:
            scores[:] += np.where(condition(live[feature].to_numpy(dtype="float32")), amount, 0.0)

    add_if("battery_pct", lambda values: values < 18, 0.20)
    add_if("rssi_dbm", lambda values: values < -105, 0.14)
    add_if("snr_db", lambda values: values < -6, 0.10)
    add_if("leak_detected", lambda values: values >= 1, 0.22)
    add_if("smoke_level", lambda values: values > 380, 0.20)
    add_if("load_weight_ton", lambda values: values > 25, 0.12)
    return np.clip(scores, 0.0, 1.0)


def score_live_window(live, feature_order: List[str], metadata: Dict[str, Any]):
    import numpy as np

    model_path_value = metadata.get("production_model", "models/production_anomaly_model.keras")
    model_path = ROOT / str(model_path_value)
    threshold = float(metadata.get("thresholds", {}).get("anomaly", 0.35))
    x_live = feature_matrix(live, feature_order)
    started = time.time()
    backend = "heuristic"
    error = None
    try:
        import tensorflow as tf

        model = tf.keras.models.load_model(model_path, compile=False)
        scores = model.predict(x_live, batch_size=4096, verbose=0).reshape(-1)
        backend = "keras"
    except Exception as exc:
        scores = heuristic_scores(live, feature_order)
        error = str(exc)
    latency_ms = (time.time() - started) * 1000 / max(1, len(live))
    scores = np.asarray(scores, dtype=float)
    predictions = (scores >= threshold).astype("int32")
    return {
        "backend": backend,
        "backendError": error,
        "threshold": threshold,
        "scores": scores,
        "predictions": predictions,
        "latencyMs": round(float(latency_ms), 6),
    }


def binary_metrics(y_true, y_pred, y_score) -> Dict[str, Any]:
    import numpy as np

    y_true = np.asarray(y_true, dtype=int)
    y_pred = np.asarray(y_pred, dtype=int)
    tp = int(((y_true == 1) & (y_pred == 1)).sum())
    tn = int(((y_true == 0) & (y_pred == 0)).sum())
    fp = int(((y_true == 0) & (y_pred == 1)).sum())
    fn = int(((y_true == 1) & (y_pred == 0)).sum())
    precision = tp / max(1, tp + fp)
    recall = tp / max(1, tp + fn)
    f1 = 2 * precision * recall / max(1e-9, precision + recall)
    accuracy = (tp + tn) / max(1, len(y_true))
    brier = float(np.mean((np.asarray(y_score, dtype=float) - y_true) ** 2))
    return {
        "accuracy": round(accuracy, 6),
        "precision": round(precision, 6),
        "recall": round(recall, 6),
        "f1": round(f1, 6),
        "brier": round(brier, 6),
        "confusionMatrix": [[tn, fp], [fn, tp]],
    }


def expected_calibration_error(y_true, y_score, bins: int = 10) -> float:
    import numpy as np

    y_true = np.asarray(y_true, dtype=int)
    y_score = np.asarray(y_score, dtype=float)
    boundaries = np.linspace(0, 1, bins + 1)
    ece = 0.0
    for low, high in zip(boundaries[:-1], boundaries[1:]):
        mask = (y_score >= low) & (y_score < high if high < 1 else y_score <= high)
        if not mask.any():
            continue
        confidence = float(y_score[mask].mean())
        accuracy = float(y_true[mask].mean())
        ece += float(mask.mean()) * abs(confidence - accuracy)
    return round(ece, 6)


def prediction_distribution(scores, threshold: float) -> Dict[str, int]:
    import numpy as np

    scores = np.asarray(scores, dtype=float)
    return {
        "normal": int((scores < threshold * 0.75).sum()),
        "watch": int(((scores >= threshold * 0.75) & (scores < threshold)).sum()),
        "anomaly": int((scores >= threshold).sum()),
    }


def explainability(reference, live, feature_order: List[str], scores) -> Dict[str, Any]:
    import numpy as np

    scores = np.asarray(scores, dtype=float)
    labels = (scores >= np.quantile(scores, 0.80)).astype(int)
    top_features = []
    for feature in feature_order:
        if feature == "domain_id":
            continue
        values = live[feature].to_numpy(dtype=float)
        normal = values[labels == 0]
        high = values[labels == 1]
        if len(high) == 0 or len(normal) == 0:
            importance = abs(float(np.corrcoef(values, scores)[0, 1])) if len(values) > 1 else 0.0
        else:
            importance = abs(float(high.mean() - normal.mean())) / (float(values.std()) + 1e-6)
        if not math.isfinite(importance):
            importance = 0.0
        top_features.append(
            {
                "feature": feature,
                "importance": round(float(importance), 6),
                "direction": "higher risk when elevated"
                if float(high.mean() if len(high) else values.mean()) >= float(normal.mean() if len(normal) else values.mean())
                else "higher risk when reduced",
            }
        )
    top_features.sort(key=lambda item: item["importance"], reverse=True)

    if len(live) == 0:
        contributors = []
    else:
        latest_index = int(np.argmax(scores))
        latest = live.iloc[latest_index]
        contributors = []
        for feature in feature_order:
            if feature == "domain_id":
                continue
            ref_values = reference[feature].to_numpy(dtype=float)
            median = float(np.median(ref_values))
            iqr = float(np.percentile(ref_values, 75) - np.percentile(ref_values, 25))
            value = float(latest[feature])
            deviation = abs(value - median) / (iqr + 1e-6)
            contributors.append(
                {
                    "feature": feature,
                    "value": round(value, 6),
                    "referenceMedian": round(median, 6),
                    "deviation": round(float(deviation), 6),
                }
            )
        contributors.sort(key=lambda item: item["deviation"], reverse=True)

    return {
        "method": "drift-aware proxy feature contribution",
        "shapStatus": "not_run_by_default; install shap and run offline for exact SHAP values",
        "topFeatures": top_features[:10],
        "topContributingFactors": contributors[:8],
        "operatorExplanation": (
            "The explanation ranks features by how strongly they separate recent high-risk "
            "telemetry from normal telemetry, then shows which latest readings deviate most "
            "from the reference production baseline."
        ),
    }


def ab_testing_report(metrics: Dict[str, Any], metadata: Dict[str, Any]) -> Dict[str, Any]:
    registry = load_json(MODEL_DIR / "registry.json", default={})
    versions = registry.get("versions", [])
    active = registry.get("active_version") or metadata.get("model_version", "current")
    if len(versions) < 2:
        return {
            "status": "baseline_only",
            "activeVersion": active,
            "candidateVersion": None,
            "trafficSplit": {"active": 100, "candidate": 0},
            "decision": "Keep active model until a retrained candidate is registered.",
            "activeMetrics": metrics,
        }
    candidate = versions[-1]["version"] if versions[-1].get("version") != active else versions[-2]["version"]
    return {
        "status": "ready",
        "activeVersion": active,
        "candidateVersion": candidate,
        "trafficSplit": {"active": 90, "candidate": 10},
        "decision": "Promote candidate only if live F1 is not lower and drift/anomaly false positives remain stable.",
        "activeMetrics": metrics,
    }


def recommendations(drift: Dict[str, Any], metrics: Dict[str, Any], monitoring: Dict[str, Any]) -> List[str]:
    items = []
    if drift["overallStatus"] == "high":
        items.append("Trigger retraining review because high feature drift is present.")
    elif drift["overallStatus"] == "medium":
        items.append("Schedule retraining evaluation; recent telemetry has moderate drift.")
    else:
        items.append("No immediate retraining required from drift checks.")
    if metrics.get("recall", 1) < 0.90:
        items.append("Increase anomaly sensitivity or retrain with recent alert cases; recall is below target.")
    if monitoring.get("errorRate", 0) > 0:
        items.append("Investigate inference backend errors and confirm Flutter can load bundled TFLite assets.")
    if monitoring.get("averageScore", 0) > 0.45:
        items.append("Review recent high-risk nodes; average production anomaly score is elevated.")
    return items


def write_reports(payload: Dict[str, Any]) -> None:
    (MLOPS_DIR / "production_monitoring.json").write_text(
        json.dumps(payload["monitoring"], indent=2),
        encoding="utf-8",
    )
    (MLOPS_DIR / "drift_report.json").write_text(
        json.dumps(payload["drift"], indent=2),
        encoding="utf-8",
    )
    (MLOPS_DIR / "explainability_report.json").write_text(
        json.dumps(payload["explainability"], indent=2),
        encoding="utf-8",
    )
    (MLOPS_DIR / "ab_test_report.json").write_text(
        json.dumps(payload["abTesting"], indent=2),
        encoding="utf-8",
    )
    summary = {
        key: payload[key]
        for key in [
            "generatedAt",
            "modelVersion",
            "status",
            "monitoring",
            "drift",
            "metrics",
            "explainability",
            "registry",
            "abTesting",
            "recommendations",
        ]
    }
    (REPORT_DIR / "mlops_summary.json").write_text(
        json.dumps(summary, indent=2),
        encoding="utf-8",
    )
    (ASSET_DIR / "mlops_summary.json").write_text(
        json.dumps(summary, indent=2),
        encoding="utf-8",
    )

    lines = [
        "# SmartCity Phase 2 MLOps Report",
        "",
        f"- Generated at: `{payload['generatedAt']}`",
        f"- Model version: `{payload['modelVersion']}`",
        f"- Overall status: `{payload['status']}`",
        f"- Monitoring backend: `{payload['monitoring']['backend']}`",
        "",
        "## Production Metrics",
        "",
        f"- Inference count: `{payload['monitoring']['inferenceCount']}`",
        f"- Average anomaly score: `{payload['monitoring']['averageScore']}`",
        f"- Per-sample latency: `{payload['monitoring']['latencyMs']}` ms",
        f"- Precision: `{payload['metrics']['precision']}`",
        f"- Recall: `{payload['metrics']['recall']}`",
        f"- F1: `{payload['metrics']['f1']}`",
        f"- Calibration ECE: `{payload['metrics']['ece']}`",
        "",
        "## Drift Detection",
        "",
        f"- Overall drift: `{payload['drift']['overallStatus']}`",
        f"- Drifted features: `{payload['drift']['featuresDrifted']}`",
        "",
        "| Feature | PSI | KS | Status |",
        "| --- | ---: | ---: | --- |",
    ]
    for item in payload["drift"]["topFeatureDrift"]:
        lines.append(f"| {item['feature']} | {item['psi']} | {item['ks']} | {item['status']} |")
    lines.extend(
        [
            "",
            "## Explainability",
            "",
            f"- Method: `{payload['explainability']['method']}`",
            f"- SHAP status: `{payload['explainability']['shapStatus']}`",
            "",
            "| Feature | Importance | Direction |",
            "| --- | ---: | --- |",
        ]
    )
    for item in payload["explainability"]["topFeatures"][:8]:
        lines.append(f"| {item['feature']} | {item['importance']} | {item['direction']} |")
    lines.extend(
        [
            "",
            "## Model Registry And A/B Testing",
            "",
            f"- Active version: `{payload['registry']['activeVersion']}`",
            f"- Registry path: `{payload['registry']['path']}`",
            f"- A/B status: `{payload['abTesting']['status']}`",
            f"- Decision: {payload['abTesting']['decision']}",
            "",
            "## Recommendations",
            "",
        ]
    )
    for item in payload["recommendations"]:
        lines.append(f"- {item}")
    lines.extend(
        [
            "",
            "## Flutter Asset",
            "",
            "- Mobile UI reads `assets/ml_models/mlops_summary.json` to show production health, drift, metrics, and explanations.",
        ]
    )
    (REPORT_DIR / "mlops_report.md").write_text("\n".join(lines), encoding="utf-8")


def run(args: argparse.Namespace) -> Dict[str, Any]:
    ensure_dirs()
    metadata = load_json(MODEL_DIR / "model_metadata.json", default={})
    feature_order = metadata.get("runtime_feature_order") or metadata.get("feature_names") or DEFAULT_FEATURES
    feature_order = [str(feature) for feature in feature_order]
    df = load_dataset(feature_order)
    reference, live = split_reference_live(df, args.live_fraction)
    drift = compute_drift(reference, live, feature_order)
    scored = score_live_window(live, feature_order, metadata)
    y_true = live["is_anomaly"].to_numpy(dtype="int32")
    metrics = binary_metrics(y_true, scored["predictions"], scored["scores"])
    metrics["ece"] = expected_calibration_error(y_true, scored["scores"])
    metrics["confidenceMean"] = round(float(abs(scored["scores"] - 0.5).mean() * 2), 6)
    monitoring = {
        "backend": scored["backend"],
        "backendError": scored["backendError"],
        "inferenceCount": int(len(live)),
        "referenceRows": int(len(reference)),
        "liveRows": int(len(live)),
        "averageScore": round(float(scored["scores"].mean()), 6),
        "p95Score": round(float(__import__("numpy").percentile(scored["scores"], 95)), 6),
        "threshold": round(float(scored["threshold"]), 6),
        "latencyMs": scored["latencyMs"],
        "errorRate": 0 if scored["backendError"] is None else 1,
        "predictionDistribution": prediction_distribution(scored["scores"], scored["threshold"]),
    }
    explanations = explainability(reference, live, feature_order, scored["scores"])
    registry = load_json(MODEL_DIR / "registry.json", default={})
    active_version = registry.get("active_version") or metadata.get("model_version", "unregistered")
    status = "healthy"
    if drift["overallStatus"] == "high" or metrics["recall"] < 0.90:
        status = "attention"
    elif drift["overallStatus"] == "medium" or monitoring["averageScore"] > 0.45:
        status = "watch"
    payload = {
        "generatedAt": iso_now(),
        "modelVersion": metadata.get("model_version", "unknown"),
        "status": status,
        "monitoring": monitoring,
        "drift": drift,
        "metrics": metrics,
        "explainability": explanations,
        "registry": {
            "activeVersion": active_version,
            "path": rel(MODEL_DIR / "registry.json") if (MODEL_DIR / "registry.json").exists() else "not initialized",
            "latestPath": rel(MODEL_DIR / "latest") if (MODEL_DIR / "latest").exists() else "not initialized",
        },
        "abTesting": ab_testing_report(metrics, metadata),
        "recommendations": recommendations(drift, metrics, monitoring),
    }
    write_reports(payload)
    print(
        json.dumps(
            {
                "status": payload["status"],
                "report": rel(REPORT_DIR / "mlops_report.md"),
                "flutter_asset": rel(ASSET_DIR / "mlops_summary.json"),
            },
            indent=2,
        )
    )
    return payload


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--live-fraction",
        type=float,
        default=0.15,
        help="Fraction of newest processed telemetry treated as live production data.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    run(parse_args())
