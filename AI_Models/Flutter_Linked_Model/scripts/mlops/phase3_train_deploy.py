#!/usr/bin/env python3
"""Train, benchmark, convert, validate, and register the Phase 3 model."""

from __future__ import annotations

import json
import os
import pickle
import shutil
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Tuple

import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.ensemble import ExtraTreesClassifier, GradientBoostingClassifier, RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split


ROOT = Path(__file__).resolve().parents[2]
PROCESSED_DIR = ROOT / "data" / "processed"
MODEL_DIR = ROOT / "models"
DEPLOY_MODEL_DIR = ROOT / "model"
ASSET_MODEL_DIR = ROOT / "assets" / "ml_models"
REPORT_DIR = ROOT / "reports" / "mlops"

VERSION = "v20260614-phase3-real-data"
TRAINING_DATASET = PROCESSED_DIR / "phase3_training_dataset.csv"
UNIFIED_REAL_DATASET = PROCESSED_DIR / "phase3_unified_real_dataset.csv"

PRODUCTION_KERAS = MODEL_DIR / "production_anomaly_model.keras"
ALERT_KERAS = MODEL_DIR / "alert_scorer.keras"
METADATA_PATH = MODEL_DIR / "model_metadata.json"
VALIDATION_SAMPLE = MODEL_DIR / "validation_sample.npz"
REGISTRY_PATH = MODEL_DIR / "registry.json"

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

DOMAIN_IDS = {
    "water": 0,
    "bridge": 1,
    "building": 2,
    "gateway": 3,
}

LABEL_TYPE_NAMES = {
    0: "Normal",
    1: "Sensor Fault",
    2: "Infrastructure / Environment Issue",
    3: "Communication Issue",
    4: "Battery Critical",
}


def iso_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT)).replace("\\", "/")


def ensure_dirs() -> None:
    for directory in (MODEL_DIR, DEPLOY_MODEL_DIR, ASSET_MODEL_DIR, REPORT_DIR):
        directory.mkdir(parents=True, exist_ok=True)


def load_training_dataset() -> pd.DataFrame:
    if not TRAINING_DATASET.exists():
        raise FileNotFoundError(
            f"Missing {rel(TRAINING_DATASET)}. Run scripts/mlops/phase3_build_unified_dataset.py first."
        )
    df = pd.read_csv(TRAINING_DATASET)
    df["domain"] = df["domain"].astype(str).str.lower()
    df = df[df["domain"].isin(DOMAIN_IDS)].copy()
    df["domain_id"] = df["domain"].map(DOMAIN_IDS).astype("float32")
    for feature in RUNTIME_FEATURES:
        if feature not in df.columns:
            df[feature] = 0.0
        df[feature] = (
            pd.to_numeric(df[feature], errors="coerce")
            .replace([np.inf, -np.inf], np.nan)
            .fillna(0.0)
            .astype("float32")
        )
    df["is_anomaly"] = pd.to_numeric(df["is_anomaly"], errors="coerce").fillna(0).astype("int32")
    df["sample_weight"] = pd.to_numeric(df.get("sample_weight", 1.0), errors="coerce").fillna(1.0).astype("float32")
    df["is_real"] = df["is_real"].astype(str).str.lower().isin(["true", "1", "yes"])
    df["source_type"] = df["source_type"].fillna("unknown").astype(str)
    df["source_dataset"] = df["source_dataset"].fillna("unknown").astype(str)
    df["anomaly_type"] = df["anomaly_type"].fillna("normal").astype(str)
    return df.reset_index(drop=True)


def split_indices(df: pd.DataFrame) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    indices = np.arange(len(df))
    y = df["is_anomaly"].to_numpy(dtype=np.int32)
    train_valid_idx, test_idx = train_test_split(
        indices,
        test_size=0.15,
        random_state=42,
        stratify=y,
    )
    y_train_valid = y[train_valid_idx]
    train_idx, valid_idx = train_test_split(
        train_valid_idx,
        test_size=0.17647,
        random_state=42,
        stratify=y_train_valid,
    )
    return train_idx, valid_idx, test_idx


def class_weight_vector(y: np.ndarray, sample_weight: np.ndarray) -> np.ndarray:
    classes, counts = np.unique(y, return_counts=True)
    total = float(len(y))
    weights = {int(cls): total / (len(classes) * float(count)) for cls, count in zip(classes, counts)}
    return sample_weight * np.array([weights[int(value)] for value in y], dtype=np.float32)


def balanced_sample_indices(y: np.ndarray, max_rows: int) -> np.ndarray:
    if len(y) <= max_rows:
        return np.arange(len(y))
    rng = np.random.default_rng(42)
    positive = np.flatnonzero(y == 1)
    negative = np.flatnonzero(y == 0)
    pos_take = min(len(positive), max_rows // 2)
    neg_take = min(len(negative), max_rows - pos_take)
    if pos_take + neg_take < max_rows:
        extra_pool = positive if pos_take < len(positive) else negative
        extra_take = min(len(extra_pool), max_rows - pos_take - neg_take)
        extra = rng.choice(extra_pool, size=extra_take, replace=False) if extra_take else np.array([], dtype=int)
    else:
        extra = np.array([], dtype=int)
    selected = np.concatenate(
        [
            rng.choice(positive, size=pos_take, replace=False),
            rng.choice(negative, size=neg_take, replace=False),
            extra,
        ]
    )
    rng.shuffle(selected)
    return selected


def metric_dict(y_true: np.ndarray, y_pred: np.ndarray, y_score: np.ndarray) -> Dict[str, Any]:
    metrics = {
        "accuracy": round(float(accuracy_score(y_true, y_pred)), 6),
        "precision": round(float(precision_score(y_true, y_pred, zero_division=0)), 6),
        "recall": round(float(recall_score(y_true, y_pred, zero_division=0)), 6),
        "f1": round(float(f1_score(y_true, y_pred, zero_division=0)), 6),
        "confusion_matrix": confusion_matrix(y_true, y_pred).astype(int).tolist(),
    }
    try:
        metrics["roc_auc"] = round(float(roc_auc_score(y_true, y_score)), 6)
    except Exception:
        metrics["roc_auc"] = None
    return metrics


def choose_threshold(y_true: np.ndarray, scores: np.ndarray) -> float:
    thresholds = np.linspace(0.08, 0.92, 85)
    best = 0.5
    best_f1 = -1.0
    for threshold in thresholds:
        preds = (scores >= threshold).astype("int32")
        score = float(f1_score(y_true, preds, zero_division=0))
        if score > best_f1:
            best_f1 = score
            best = float(threshold)
    return best


def score_model(model: Any, x: np.ndarray) -> np.ndarray:
    if hasattr(model, "predict_proba"):
        return model.predict_proba(x)[:, 1]
    output = model.predict(x, verbose=0)
    return np.asarray(output).reshape(-1)


def latency_ms(model: Any, x: np.ndarray) -> float:
    sample = x[: min(2048, len(x))]
    start = time.perf_counter()
    score_model(model, sample)
    return round(float((time.perf_counter() - start) * 1000 / max(1, len(sample))), 6)


def model_size_estimate(model: Any) -> int:
    try:
        return len(pickle.dumps(model))
    except Exception:
        return 0


def benchmark_sklearn_models(
    x_train: np.ndarray,
    y_train: np.ndarray,
    weights_train: np.ndarray,
    x_valid: np.ndarray,
    y_valid: np.ndarray,
    max_rows: int = 150000,
) -> Dict[str, Any]:
    sample_idx = balanced_sample_indices(y_train, max_rows)
    sx = x_train[sample_idx]
    sy = y_train[sample_idx]
    sw = weights_train[sample_idx]
    candidates = {
        "Logistic Regression": make_pipeline(
            StandardScaler(),
            LogisticRegression(max_iter=500, class_weight="balanced", n_jobs=-1),
        ),
        "Random Forest": RandomForestClassifier(
            n_estimators=120,
            max_depth=16,
            min_samples_leaf=3,
            class_weight="balanced_subsample",
            n_jobs=-1,
            random_state=42,
        ),
        "Gradient Boosting": GradientBoostingClassifier(
            n_estimators=160,
            learning_rate=0.06,
            max_depth=4,
            random_state=42,
        ),
        "Extra Trees": ExtraTreesClassifier(
            n_estimators=160,
            max_depth=18,
            min_samples_leaf=3,
            class_weight="balanced",
            n_jobs=-1,
            random_state=42,
        ),
    }
    results: Dict[str, Any] = {}
    for name, model in candidates.items():
        started = time.time()
        try:
            if name == "Logistic Regression":
                model.fit(sx, sy, logisticregression__sample_weight=sw)
            else:
                model.fit(sx, sy, sample_weight=sw)
            scores = score_model(model, x_valid)
            preds = (scores >= 0.5).astype("int32")
            results[name] = {
                "status": "trained",
                "metrics": metric_dict(y_valid, preds, scores),
                "latency_ms": latency_ms(model, x_valid),
                "model_size_estimate_bytes": model_size_estimate(model),
                "training_rows_used": int(len(sx)),
                "runtime_seconds": round(time.time() - started, 3),
                "mobile_suitability": "server/offline benchmark; not selected for direct Flutter TFLite deployment",
            }
            if name == "Extra Trees" and hasattr(model, "feature_importances_"):
                results[name]["feature_importance"] = dict(
                    zip(RUNTIME_FEATURES, [float(v) for v in model.feature_importances_])
                )
        except Exception as exc:
            results[name] = {
                "status": "failed",
                "reason": str(exc),
                "runtime_seconds": round(time.time() - started, 3),
            }
    return results


def build_neural_model(feature_count: int) -> Tuple[tf.keras.Model, tf.keras.layers.Normalization]:
    normalizer = tf.keras.layers.Normalization(axis=-1, name="phase3_runtime_normalization")
    inputs = tf.keras.Input(shape=(feature_count,), name="runtime_features")
    x = normalizer(inputs)
    x = tf.keras.layers.Dense(64, activation="relu", name="dense_64")(x)
    x = tf.keras.layers.Dropout(0.06, name="dropout_006")(x)
    x = tf.keras.layers.Dense(32, activation="relu", name="dense_32")(x)
    x = tf.keras.layers.Dense(16, activation="relu", name="dense_16")(x)
    outputs = tf.keras.layers.Dense(1, activation="sigmoid", name="anomaly_score")(x)
    model = tf.keras.Model(inputs=inputs, outputs=outputs, name="smartcity_phase3_anomaly_classifier")
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss="binary_crossentropy",
        metrics=[
            tf.keras.metrics.BinaryAccuracy(name="accuracy"),
            tf.keras.metrics.Precision(name="precision"),
            tf.keras.metrics.Recall(name="recall"),
            tf.keras.metrics.AUC(name="roc_auc"),
        ],
    )
    return model, normalizer


def train_neural_model(
    x_train: np.ndarray,
    y_train: np.ndarray,
    weights_train: np.ndarray,
    x_valid: np.ndarray,
    y_valid: np.ndarray,
    x_test: np.ndarray,
    y_test: np.ndarray,
) -> Dict[str, Any]:
    model, normalizer = build_neural_model(x_train.shape[1])
    normalizer.adapt(x_train)
    started = time.time()
    history = model.fit(
        x_train,
        y_train,
        validation_data=(x_valid, y_valid),
        sample_weight=weights_train,
        epochs=10,
        batch_size=2048,
        callbacks=[
            tf.keras.callbacks.EarlyStopping(
                monitor="val_roc_auc",
                mode="max",
                patience=3,
                restore_best_weights=True,
            )
        ],
        verbose=2,
    )
    valid_scores = model.predict(x_valid, batch_size=4096, verbose=0).reshape(-1)
    threshold = choose_threshold(y_valid, valid_scores)
    test_scores = model.predict(x_test, batch_size=4096, verbose=0).reshape(-1)
    test_preds = (test_scores >= threshold).astype("int32")
    model.save(PRODUCTION_KERAS)
    sample_count = min(4096, len(x_test))
    np.savez_compressed(
        VALIDATION_SAMPLE,
        x=x_test[:sample_count].astype("float32"),
        y=y_test[:sample_count].astype("int32"),
        keras_scores=test_scores[:sample_count].astype("float32"),
    )
    return {
        "model": model,
        "status": "trained",
        "threshold": float(threshold),
        "metrics": metric_dict(y_test, test_preds, test_scores),
        "validation_metrics": metric_dict(y_valid, (valid_scores >= threshold).astype("int32"), valid_scores),
        "latency_ms": latency_ms(model, x_test),
        "model_path": rel(PRODUCTION_KERAS),
        "model_size_estimate_bytes": PRODUCTION_KERAS.stat().st_size,
        "runtime_seconds": round(time.time() - started, 3),
        "mobile_suitability": "selected candidate: compact Keras network with embedded normalization and TFLite conversion path",
        "history": {key: [float(v) for v in values] for key, values in history.history.items()},
    }


def severity_labels(anomaly_types: pd.Series) -> np.ndarray:
    values = []
    for item in anomaly_types.fillna("normal").astype(str):
        text = item.lower()
        if text == "normal":
            values.append(0)
        elif "sensor" in text:
            values.append(2)
        elif "battery" in text:
            values.append(4)
        elif "communication" in text:
            values.append(2)
        elif "environment" in text or "infrastructure" in text:
            values.append(3)
        else:
            values.append(1)
    return np.array(values, dtype=np.int32)


def train_alert_scorer(x_train: np.ndarray, severity_train: np.ndarray, x_test: np.ndarray, severity_test: np.ndarray) -> Dict[str, Any]:
    normalizer = tf.keras.layers.Normalization(axis=-1, name="phase3_alert_normalization")
    inputs = tf.keras.Input(shape=(x_train.shape[1],), name="runtime_features")
    x = normalizer(inputs)
    x = tf.keras.layers.Dense(48, activation="relu")(x)
    x = tf.keras.layers.Dense(24, activation="relu")(x)
    outputs = tf.keras.layers.Dense(5, activation="softmax", name="severity")(x)
    model = tf.keras.Model(inputs=inputs, outputs=outputs, name="smartcity_phase3_alert_scorer")
    normalizer.adapt(x_train)
    model.compile(optimizer="adam", loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    started = time.time()
    model.fit(x_train, severity_train, epochs=5, batch_size=2048, verbose=0)
    pred = model.predict(x_test, batch_size=4096, verbose=0).argmax(axis=1)
    model.save(ALERT_KERAS)
    return {
        "status": "trained",
        "model_path": rel(ALERT_KERAS),
        "metrics": {
            "accuracy": round(float(accuracy_score(severity_test, pred)), 6),
            "f1_macro": round(float(f1_score(severity_test, pred, average="macro", zero_division=0)), 6),
            "confusion_matrix": confusion_matrix(severity_test, pred).astype(int).tolist(),
        },
        "classes": {str(key): value for key, value in LABEL_TYPE_NAMES.items()},
        "runtime_seconds": round(time.time() - started, 3),
    }


def convert_one(
    name: str,
    keras_path: Path,
    outputs: List[Path],
    sample_input: np.ndarray,
    *,
    quantize_float16: bool,
) -> Dict[str, Any]:
    model = tf.keras.models.load_model(keras_path, compile=False)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    if quantize_float16:
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
    started = time.time()
    data = converter.convert()
    written = []
    for path in outputs:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        written.append({"path": rel(path), "size_bytes": path.stat().st_size})
    interpreter = tf.lite.Interpreter(model_path=str(outputs[0]))
    input_details = interpreter.get_input_details()
    input_index = input_details[0]["index"]
    interpreter.resize_tensor_input(input_index, sample_input.shape, strict=False)
    interpreter.allocate_tensors()
    interpreter.set_tensor(interpreter.get_input_details()[0]["index"], sample_input)
    start = time.perf_counter()
    interpreter.invoke()
    latency = (time.perf_counter() - start) * 1000
    output = interpreter.get_tensor(interpreter.get_output_details()[0]["index"])
    return {
        "status": "converted",
        "name": name,
        "keras_model": rel(keras_path),
        "outputs": written,
        "quantization": "float16_weights_float32_io" if quantize_float16 else "float32",
        "conversion_seconds": round(time.time() - started, 3),
        "interpreter_test": {
            "input_shape": [int(v) for v in interpreter.get_input_details()[0]["shape"]],
            "output_shape": [int(v) for v in interpreter.get_output_details()[0]["shape"]],
            "single_inference_ms": round(float(latency), 6),
            "sample_output": output.reshape(-1)[:8].astype(float).round(6).tolist(),
        },
    }


def convert_to_tflite(sample_input: np.ndarray) -> Dict[str, Any]:
    return {
        "production_anomaly": convert_one(
            "production_anomaly",
            PRODUCTION_KERAS,
            [DEPLOY_MODEL_DIR / "production_model.tflite", ASSET_MODEL_DIR / "production_model.tflite"],
            sample_input,
            quantize_float16=False,
        ),
        "alert_scorer": convert_one(
            "alert_scorer",
            ALERT_KERAS,
            [DEPLOY_MODEL_DIR / "alert_scorer.tflite", ASSET_MODEL_DIR / "alert_scorer.tflite"],
            sample_input,
            quantize_float16=False,
        ),
    }


def run_tflite(x: np.ndarray) -> Tuple[np.ndarray, Dict[str, Any]]:
    model_path = ASSET_MODEL_DIR / "production_model.tflite"
    interpreter = tf.lite.Interpreter(model_path=str(model_path))
    input_index = interpreter.get_input_details()[0]["index"]
    try:
        interpreter.resize_tensor_input(input_index, x.shape, strict=False)
        interpreter.allocate_tensors()
        interpreter.set_tensor(interpreter.get_input_details()[0]["index"], x)
        started = time.perf_counter()
        interpreter.invoke()
        latency = (time.perf_counter() - started) * 1000
        scores = interpreter.get_tensor(interpreter.get_output_details()[0]["index"]).reshape(-1)
        batch_mode = True
    except Exception:
        interpreter = tf.lite.Interpreter(model_path=str(model_path))
        interpreter.resize_tensor_input(input_index, (1, x.shape[1]), strict=False)
        interpreter.allocate_tensors()
        scores_out = []
        started = time.perf_counter()
        for row in x:
            interpreter.set_tensor(interpreter.get_input_details()[0]["index"], row.reshape(1, -1))
            interpreter.invoke()
            scores_out.append(float(interpreter.get_tensor(interpreter.get_output_details()[0]["index"]).reshape(-1)[0]))
        latency = (time.perf_counter() - started) * 1000
        scores = np.array(scores_out, dtype=np.float32)
        batch_mode = False
    return scores.astype(np.float32), {
        "batch_mode": batch_mode,
        "sample_count": int(len(x)),
        "batch_latency_ms": round(float(latency), 6),
        "per_sample_latency_ms": round(float(latency / max(1, len(x))), 6),
    }


def validate_tflite(threshold: float) -> Dict[str, Any]:
    payload = np.load(VALIDATION_SAMPLE)
    x = payload["x"].astype("float32")
    y = payload["y"].astype("int32")
    stored_scores = payload["keras_scores"].astype("float32")
    model = tf.keras.models.load_model(PRODUCTION_KERAS, compile=False)
    live_scores = model.predict(x, batch_size=4096, verbose=0).reshape(-1).astype("float32")
    tflite_scores, latency = run_tflite(x)
    deviation = np.abs(live_scores - tflite_scores)
    stored_deviation = np.abs(stored_scores - live_scores)
    max_abs = float(deviation.max())
    status = "passed" if max_abs <= 0.01 else "failed"
    report = {
        "generated_at": iso_now(),
        "status": status,
        "model_version": VERSION,
        "threshold": round(float(threshold), 6),
        "sample_count": int(len(x)),
        "model_size_bytes": (ASSET_MODEL_DIR / "production_model.tflite").stat().st_size,
        "deviation": {
            "max_abs": round(max_abs, 8),
            "mean_abs": round(float(deviation.mean()), 8),
            "p95_abs": round(float(np.percentile(deviation, 95)), 8),
            "accepted_max_abs": 0.01,
            "stored_vs_live_keras_max_abs": round(float(stored_deviation.max()), 8),
        },
        "latency": latency,
        "keras_metrics": metric_dict(y, (live_scores >= threshold).astype("int32"), live_scores),
        "tflite_metrics": metric_dict(y, (tflite_scores >= threshold).astype("int32"), tflite_scores),
        "sample_predictions": [
            {
                "keras": round(float(k), 6),
                "tflite": round(float(t), 6),
                "label": int(label),
            }
            for k, t, label in zip(live_scores[:10], tflite_scores[:10], y[:10])
        ],
    }
    (REPORT_DIR / "phase3_tflite_validation_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    lines = [
        "# Phase 3 TFLite Validation Report",
        "",
        f"- Generated at: `{report['generated_at']}`",
        f"- Status: `{status}`",
        f"- Model version: `{VERSION}`",
        f"- Max absolute deviation: `{report['deviation']['max_abs']}`",
        f"- Mean absolute deviation: `{report['deviation']['mean_abs']}`",
        f"- Accepted max absolute deviation: `0.01`",
        f"- Per-sample latency: `{latency['per_sample_latency_ms']}` ms",
        f"- TFLite F1: `{report['tflite_metrics']['f1']}`",
        "",
        "## Sample Predictions",
        "",
        "| Row | Keras | TFLite | Label |",
        "| ---: | ---: | ---: | ---: |",
    ]
    for index, item in enumerate(report["sample_predictions"], start=1):
        lines.append(f"| {index} | {item['keras']} | {item['tflite']} | {item['label']} |")
    (REPORT_DIR / "phase3_tflite_validation_report.md").write_text("\n".join(lines), encoding="utf-8")
    if status != "passed":
        raise SystemExit(f"Phase 3 TFLite validation failed: max deviation {max_abs}")
    return report


def psi(reference: np.ndarray, current: np.ndarray, bins: int = 10) -> float:
    ref = reference[np.isfinite(reference)]
    cur = current[np.isfinite(current)]
    if len(ref) == 0 or len(cur) == 0:
        return 0.0
    edges = np.unique(np.quantile(ref, np.linspace(0, 1, bins + 1)))
    if len(edges) < 3:
        lo = min(float(ref.min()), float(cur.min()))
        hi = max(float(ref.max()), float(cur.max()))
        if np.isclose(lo, hi):
            return 0.0
        edges = np.linspace(lo, hi, bins + 1)
    edges[0] = min(float(ref.min()), float(cur.min())) - 1e-9
    edges[-1] = max(float(ref.max()), float(cur.max())) + 1e-9
    ref_hist, _ = np.histogram(ref, bins=edges)
    cur_hist, _ = np.histogram(cur, bins=edges)
    ref_pct = np.maximum(ref_hist / max(1, ref_hist.sum()), 1e-6)
    cur_pct = np.maximum(cur_hist / max(1, cur_hist.sum()), 1e-6)
    return float(np.sum((cur_pct - ref_pct) * np.log(cur_pct / ref_pct)))


def feature_drift(df: pd.DataFrame, train_idx: np.ndarray, test_idx: np.ndarray) -> Dict[str, Any]:
    ref = df.iloc[train_idx]
    cur = df.iloc[test_idx]
    rows = []
    for feature in RUNTIME_FEATURES:
        if feature == "domain_id":
            continue
        score = psi(ref[feature].to_numpy(dtype=float), cur[feature].to_numpy(dtype=float))
        status = "high" if score >= 0.25 else "medium" if score >= 0.10 else "low"
        rows.append(
            {
                "feature": feature,
                "psi": round(score, 6),
                "referenceMean": round(float(ref[feature].mean()), 6),
                "liveMean": round(float(cur[feature].mean()), 6),
                "status": status,
            }
        )
    rows.sort(key=lambda item: item["psi"], reverse=True)
    high = sum(1 for item in rows if item["status"] == "high")
    medium = sum(1 for item in rows if item["status"] == "medium")
    return {
        "overallStatus": "high" if high else "medium" if medium else "low",
        "featuresDrifted": high + medium,
        "highDriftFeatures": high,
        "mediumDriftFeatures": medium,
        "topFeatureDrift": rows[:8],
    }


def proxy_feature_importance(df: pd.DataFrame) -> List[Dict[str, Any]]:
    rows = []
    y = df["is_anomaly"].to_numpy(dtype=int)
    for feature in RUNTIME_FEATURES:
        if feature == "domain_id":
            continue
        values = df[feature].to_numpy(dtype=float)
        normal = values[y == 0]
        anomaly = values[y == 1]
        if len(normal) == 0 or len(anomaly) == 0:
            importance = 0.0
            direction = "not enough class variation"
        else:
            importance = abs(float(anomaly.mean() - normal.mean())) / (float(values.std()) + 1e-6)
            direction = "higher risk when elevated" if anomaly.mean() >= normal.mean() else "higher risk when reduced"
        rows.append({"feature": feature, "importance": round(float(importance), 6), "direction": direction})
    rows.sort(key=lambda item: item["importance"], reverse=True)
    return rows[:10]


def write_model_config(metadata: Dict[str, Any], conversions: Dict[str, Any]) -> Dict[str, Any]:
    config = {
        "model_version": VERSION,
        "generated_at": iso_now(),
        "feature_order": RUNTIME_FEATURES,
        "runtime_feature_order": RUNTIME_FEATURES,
        "feature_count": len(RUNTIME_FEATURES),
        "input_shape": [1, len(RUNTIME_FEATURES)],
        "domain_ids": DOMAIN_IDS,
        "thresholds": {
            "anomaly": metadata["thresholds"]["anomaly"],
            "fallback_heuristic": 0.58,
        },
        "models": {
            "production_anomaly": "assets/ml_models/production_model.tflite",
            "alert_scorer": "assets/ml_models/alert_scorer.tflite",
        },
        "performance": metadata["performance"],
        "conversion": conversions,
        "phase3": metadata["phase3"],
        "runtime_behavior": {
            "native_flutter": "uses production_anomaly TFLite for anomaly scores",
            "web_flutter": "uses deterministic fallback because tflite_flutter does not provide a web interpreter",
        },
    }
    (ASSET_MODEL_DIR / "model_config.json").write_text(json.dumps(config, indent=2), encoding="utf-8")
    return config


def write_benchmark_report(metadata: Dict[str, Any]) -> Path:
    benchmark = metadata["performance"]["candidate_models"]
    selected = metadata["performance"]["selected_model"]
    lines = [
        "# Phase 3 Model Benchmark",
        "",
        f"- Generated at: `{metadata['generated_at']}`",
        f"- Training rows: `{metadata['phase3']['training_rows']}`",
        f"- Real rows: `{metadata['phase3']['real_rows']}`",
        f"- Synthetic rows: `{metadata['phase3']['synthetic_rows']}`",
        "",
        "| Model | Status | F1 | Precision | Recall | ROC-AUC | Latency ms | Size bytes | Notes |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for name, item in benchmark.items():
        if item.get("status") != "trained":
            lines.append(f"| {name} | {item.get('status')} |  |  |  |  |  |  | {item.get('reason', '')} |")
            continue
        metrics = item["metrics"]
        lines.append(
            f"| {name} | trained | {metrics['f1']} | {metrics['precision']} | {metrics['recall']} | "
            f"{metrics.get('roc_auc')} | {item['latency_ms']} | {item['model_size_estimate_bytes']} | {item['mobile_suitability']} |"
        )
    metrics = selected["metrics"]
    lines.append(
        f"| Small Neural Network | trained | {metrics['f1']} | {metrics['precision']} | {metrics['recall']} | "
        f"{metrics.get('roc_auc')} | {selected['latency_ms']} | {selected['model_size_estimate_bytes']} | selected for TFLite |"
    )
    lines.extend(
        [
            "",
            "## Selection",
            "",
            metadata["selection_rationale"],
            "",
            "## Real-Only Test Metrics",
            "",
            f"- F1: `{metadata['performance']['real_test_metrics']['f1']}`",
            f"- Precision: `{metadata['performance']['real_test_metrics']['precision']}`",
            f"- Recall: `{metadata['performance']['real_test_metrics']['recall']}`",
            f"- ROC-AUC: `{metadata['performance']['real_test_metrics']['roc_auc']}`",
        ]
    )
    path = REPORT_DIR / "phase3_model_benchmark.md"
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def write_mlops_summary(
    metadata: Dict[str, Any],
    tflite_report: Dict[str, Any],
    drift: Dict[str, Any],
    feature_importance: List[Dict[str, Any]],
    test_scores: np.ndarray,
) -> Dict[str, Any]:
    threshold = metadata["thresholds"]["anomaly"]
    distribution = {
        "normal": int((test_scores < threshold * 0.75).sum()),
        "watch": int(((test_scores >= threshold * 0.75) & (test_scores < threshold)).sum()),
        "anomaly": int((test_scores >= threshold).sum()),
    }
    status = "healthy"
    if tflite_report["status"] != "passed" or metadata["performance"]["selected_model"]["metrics"]["recall"] < 0.85:
        status = "attention"
    elif drift["overallStatus"] != "low":
        status = "watch"
    summary = {
        "generatedAt": iso_now(),
        "modelVersion": VERSION,
        "status": status,
        "monitoring": {
            "backend": "keras+tflite_validated",
            "backendError": None,
            "inferenceCount": int(metadata["splits"]["test"]),
            "referenceRows": int(metadata["splits"]["train"]),
            "liveRows": int(metadata["splits"]["test"]),
            "averageScore": round(float(test_scores.mean()), 6),
            "p95Score": round(float(np.percentile(test_scores, 95)), 6),
            "threshold": round(float(threshold), 6),
            "latencyMs": tflite_report["latency"]["per_sample_latency_ms"],
            "errorRate": 0,
            "predictionDistribution": distribution,
        },
        "drift": drift,
        "metrics": {
            **metadata["performance"]["selected_model"]["metrics"],
            "brier": metadata["performance"]["selected_model"]["calibration"]["brier"],
            "ece": metadata["performance"]["selected_model"]["calibration"]["ece"],
            "confidenceMean": metadata["performance"]["selected_model"]["calibration"]["confidence_mean"],
        },
        "explainability": {
            "method": "Phase 3 real-data class-separation proxy",
            "shapStatus": "not_run_by_default; feature drivers are calculated from held-out Phase 3 data",
            "topFeatures": feature_importance,
            "topContributingFactors": feature_importance[:8],
        },
        "registry": {
            "activeVersion": VERSION,
            "path": "models/registry.json",
            "latestPath": "models/latest",
        },
        "abTesting": {
            "status": "baseline_only",
            "activeVersion": VERSION,
            "candidateVersion": "",
            "trafficSplit": {"active": 100, "candidate": 0},
            "decision": "Phase 3 model is active after TFLite validation; collect field telemetry before introducing a candidate split.",
        },
        "training": {
            "phase": "Phase 3 Real Data Training Pass",
            "trainingRows": metadata["phase3"]["training_rows"],
            "realRows": metadata["phase3"]["real_rows"],
            "syntheticRows": metadata["phase3"]["synthetic_rows"],
            "realRatio": metadata["phase3"]["real_ratio"],
            "featureCount": len(RUNTIME_FEATURES),
            "datasetsUsed": metadata["phase3"]["source_datasets"],
        },
        "recommendations": [
            "Collect real bridge and water datasets or export more Firebase field telemetry to reduce synthetic dependence.",
            "Treat real environmental labels as weak labels until incidents are field-confirmed.",
            "Monitor false positives on gateway/environment telemetry before tightening thresholds.",
        ],
    }
    (ROOT / "reports" / "mlops_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    (ASSET_MODEL_DIR / "mlops_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return summary


def update_registry(metadata: Dict[str, Any], summary: Dict[str, Any]) -> Dict[str, Any]:
    registry = {
        "schema": "smartcity-model-registry-v1",
        "created_at": iso_now(),
        "active_version": None,
        "versions": [],
    }
    if REGISTRY_PATH.exists():
        registry = json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))
    version_dir = MODEL_DIR / VERSION
    latest_dir = MODEL_DIR / "latest"
    if version_dir.exists():
        shutil.rmtree(version_dir)
    version_dir.mkdir(parents=True, exist_ok=True)
    artifacts = [
        METADATA_PATH,
        PRODUCTION_KERAS,
        ALERT_KERAS,
        VALIDATION_SAMPLE,
        DEPLOY_MODEL_DIR / "production_model.tflite",
        DEPLOY_MODEL_DIR / "alert_scorer.tflite",
        ASSET_MODEL_DIR / "production_model.tflite",
        ASSET_MODEL_DIR / "alert_scorer.tflite",
        ASSET_MODEL_DIR / "model_config.json",
        ASSET_MODEL_DIR / "mlops_summary.json",
    ]
    copied = []
    for source in artifacts:
        if not source.exists():
            continue
        destination = version_dir / source.name
        shutil.copy2(source, destination)
        copied.append({"source": rel(source), "path": rel(destination), "size_bytes": destination.stat().st_size})
    if latest_dir.exists():
        shutil.rmtree(latest_dir)
    shutil.copytree(version_dir, latest_dir)
    (latest_dir / "ACTIVE_VERSION").write_text(VERSION, encoding="utf-8")

    versions = [item for item in registry.get("versions", []) if item.get("version") != VERSION]
    record = {
        "version": VERSION,
        "registered_at": iso_now(),
        "path": rel(version_dir),
        "latest_path": rel(latest_dir),
        "notes": "Phase 3 real-data training pass with weak-labeled UCI environmental data and capped synthetic domain coverage.",
        "artifacts": copied,
        "metrics": {
            "training_rows": metadata["phase3"]["training_rows"],
            "real_rows": metadata["phase3"]["real_rows"],
            "synthetic_rows": metadata["phase3"]["synthetic_rows"],
            "feature_count": len(RUNTIME_FEATURES),
            "selected_model": metadata["performance"]["selected_model"]["metrics"],
            "real_test_metrics": metadata["performance"]["real_test_metrics"],
            "drift_baseline": summary["drift"],
            "active_model_path": rel(ASSET_MODEL_DIR / "production_model.tflite"),
        },
    }
    versions.append(record)
    registry["versions"] = versions
    registry["active_version"] = VERSION
    registry["updated_at"] = iso_now()
    REGISTRY_PATH.write_text(json.dumps(registry, indent=2), encoding="utf-8")
    return record


def calibration(y_true: np.ndarray, scores: np.ndarray, bins: int = 10) -> Dict[str, float]:
    brier = float(np.mean((scores - y_true) ** 2))
    boundaries = np.linspace(0, 1, bins + 1)
    ece = 0.0
    for low, high in zip(boundaries[:-1], boundaries[1:]):
        mask = (scores >= low) & (scores < high if high < 1 else scores <= high)
        if not mask.any():
            continue
        ece += float(mask.mean()) * abs(float(scores[mask].mean()) - float(y_true[mask].mean()))
    confidence = float(np.mean(np.abs(scores - 0.5) * 2))
    return {
        "brier": round(brier, 6),
        "ece": round(ece, 6),
        "confidence_mean": round(confidence, 6),
    }


def train_and_deploy() -> Dict[str, Any]:
    ensure_dirs()
    started = time.time()
    df = load_training_dataset()
    train_idx, valid_idx, test_idx = split_indices(df)
    x = df[RUNTIME_FEATURES].to_numpy(dtype="float32")
    y = df["is_anomaly"].to_numpy(dtype="int32")
    base_weights = df["sample_weight"].to_numpy(dtype="float32")
    weights = class_weight_vector(y[train_idx], base_weights[train_idx])

    x_train, y_train = x[train_idx], y[train_idx]
    x_valid, y_valid = x[valid_idx], y[valid_idx]
    x_test, y_test = x[test_idx], y[test_idx]

    benchmark = benchmark_sklearn_models(x_train, y_train, weights, x_valid, y_valid)
    neural = train_neural_model(x_train, y_train, weights, x_valid, y_valid, x_test, y_test)
    threshold = float(neural["threshold"])
    test_scores = neural["model"].predict(x_test, batch_size=4096, verbose=0).reshape(-1)

    real_mask_test = df.iloc[test_idx]["is_real"].to_numpy(dtype=bool)
    real_test_metrics = metric_dict(
        y_test[real_mask_test],
        (test_scores[real_mask_test] >= threshold).astype("int32"),
        test_scores[real_mask_test],
    )
    neural["calibration"] = calibration(y_test, test_scores)
    alert = train_alert_scorer(
        x_train,
        severity_labels(df.iloc[train_idx]["anomaly_type"]),
        x_test,
        severity_labels(df.iloc[test_idx]["anomaly_type"]),
    )

    phase3 = {
        "training_dataset": rel(TRAINING_DATASET),
        "unified_real_dataset": rel(UNIFIED_REAL_DATASET),
        "training_rows": int(len(df)),
        "real_rows": int(df["is_real"].sum()),
        "synthetic_rows": int((~df["is_real"]).sum()),
        "real_ratio": round(float(df["is_real"].sum() / len(df)), 6),
        "source_datasets": df["source_dataset"].value_counts().to_dict(),
        "source_types": df["source_type"].value_counts().to_dict(),
        "domains": df["domain"].value_counts().to_dict(),
        "weak_labeled_real_rows": int(((df["is_real"]) & (df["is_weak_label"].astype(str).str.lower().isin(["true", "1"]))).sum()),
    }
    metadata = {
        "model_version": VERSION,
        "generated_at": iso_now(),
        "status": "trained",
        "feature_count": len(RUNTIME_FEATURES),
        "feature_names": RUNTIME_FEATURES,
        "runtime_feature_order": RUNTIME_FEATURES,
        "domain_ids": DOMAIN_IDS,
        "thresholds": {"anomaly": threshold},
        "label_types": LABEL_TYPE_NAMES,
        "splits": {
            "train": int(len(train_idx)),
            "validation": int(len(valid_idx)),
            "test": int(len(test_idx)),
            "real_test": int(real_mask_test.sum()),
        },
        "phase3": phase3,
        "production_model": rel(PRODUCTION_KERAS),
        "validation_sample": rel(VALIDATION_SAMPLE),
        "performance": {
            "candidate_models": benchmark,
            "selected_model": {
                "model_type": "Small Neural Network",
                "model_path": rel(PRODUCTION_KERAS),
                "threshold": round(threshold, 6),
                "metrics": neural["metrics"],
                "validation_metrics": neural["validation_metrics"],
                "calibration": neural["calibration"],
                "latency_ms": neural["latency_ms"],
                "model_size_estimate_bytes": neural["model_size_estimate_bytes"],
                "runtime_seconds": neural["runtime_seconds"],
                "mobile_suitability": neural["mobile_suitability"],
            },
            "real_test_metrics": real_test_metrics,
            "alert_scorer": alert,
        },
        "selection_rationale": (
            "The small neural network is selected for production because it is the only benchmarked "
            "model with a direct TensorFlow Lite deployment path, compact asset size, embedded "
            "normalization, strong validation F1, and acceptable real-data holdout behavior. Tree "
            "models remain useful offline comparisons but are not shipped to Flutter."
        ),
        "library_versions": {
            "python": os.sys.version,
            "pandas": pd.__version__,
            "numpy": np.__version__,
            "sklearn": __import__("sklearn").__version__,
            "tensorflow": tf.__version__,
        },
        "runtime_seconds": round(time.time() - started, 3),
    }
    METADATA_PATH.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    benchmark_path = write_benchmark_report(metadata)
    conversions = convert_to_tflite(x_test[:1])
    config = write_model_config(metadata, conversions)
    tflite_report = validate_tflite(threshold)
    drift = feature_drift(df, train_idx, test_idx)
    importance = proxy_feature_importance(df.iloc[test_idx])
    summary = write_mlops_summary(metadata, tflite_report, drift, importance, test_scores)
    registry_record = update_registry(metadata, summary)
    metadata["conversion"] = conversions
    metadata["model_config"] = config
    metadata["tflite_validation"] = tflite_report
    metadata["mlops_summary"] = rel(ASSET_MODEL_DIR / "mlops_summary.json")
    metadata["registry_record"] = registry_record
    metadata["reports"] = {
        "benchmark": rel(benchmark_path),
        "tflite_validation": rel(REPORT_DIR / "phase3_tflite_validation_report.md"),
    }
    METADATA_PATH.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    (REPORT_DIR / "phase3_training_result.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    print(
        json.dumps(
            {
                "model_version": VERSION,
                "benchmark_report": rel(benchmark_path),
                "tflite_validation": tflite_report["status"],
                "registry_version": registry_record["version"],
                "mlops_summary": rel(ASSET_MODEL_DIR / "mlops_summary.json"),
            },
            indent=2,
        )
    )
    return metadata


if __name__ == "__main__":
    train_and_deploy()
