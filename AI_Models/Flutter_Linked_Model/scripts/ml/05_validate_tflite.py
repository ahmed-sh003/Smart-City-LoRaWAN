#!/usr/bin/env python3
"""Validate TensorFlow Lite output against the original Keras model."""

from __future__ import annotations

import argparse
import json
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Tuple

import numpy as np
import tensorflow as tf
from sklearn.metrics import accuracy_score, f1_score, precision_score, recall_score


ROOT = Path(__file__).resolve().parents[2]
MODEL_DIR = ROOT / "models"
ASSET_MODEL_DIR = ROOT / "assets" / "ml_models"
REPORT_DIR = ROOT / "reports"

KERAS_MODEL = MODEL_DIR / "production_anomaly_model.keras"
TFLITE_MODEL = ASSET_MODEL_DIR / "production_model.tflite"
VALIDATION_SAMPLE = MODEL_DIR / "validation_sample.npz"
METADATA_PATH = MODEL_DIR / "model_metadata.json"


def iso_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def load_metadata() -> Dict[str, Any]:
    return json.loads(METADATA_PATH.read_text(encoding="utf-8"))


def load_validation_sample() -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    if not VALIDATION_SAMPLE.exists():
        raise FileNotFoundError(f"Missing validation sample: {VALIDATION_SAMPLE}")
    payload = np.load(VALIDATION_SAMPLE)
    return (
        payload["x"].astype(np.float32),
        payload["y"].astype(np.int32),
        payload["keras_scores"].astype(np.float32),
    )


def run_tflite_scores(model_path: Path, x: np.ndarray) -> Tuple[np.ndarray, Dict[str, Any]]:
    interpreter = tf.lite.Interpreter(model_path=str(model_path))
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    input_index = input_details[0]["index"]
    output_index = output_details[0]["index"]

    try:
        interpreter.resize_tensor_input(input_index, x.shape, strict=False)
        interpreter.allocate_tensors()
        interpreter.set_tensor(input_index, x)
        start = time.perf_counter()
        interpreter.invoke()
        batch_latency_ms = (time.perf_counter() - start) * 1000
        scores = interpreter.get_tensor(output_index).reshape(-1).astype(np.float32)
        batch_mode = True
    except Exception:
        interpreter = tf.lite.Interpreter(model_path=str(model_path))
        interpreter.resize_tensor_input(input_index, (1, x.shape[1]), strict=False)
        interpreter.allocate_tensors()
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        scores_out = []
        start = time.perf_counter()
        for row in x:
            interpreter.set_tensor(input_details[0]["index"], row.reshape(1, -1))
            interpreter.invoke()
            scores_out.append(float(interpreter.get_tensor(output_details[0]["index"]).reshape(-1)[0]))
        batch_latency_ms = (time.perf_counter() - start) * 1000
        scores = np.array(scores_out, dtype=np.float32)
        batch_mode = False

    latency_interpreter = tf.lite.Interpreter(model_path=str(model_path))
    latency_input_details = latency_interpreter.get_input_details()
    latency_interpreter.resize_tensor_input(
        latency_input_details[0]["index"], (1, x.shape[1]), strict=False
    )
    latency_interpreter.allocate_tensors()
    latency_input_details = latency_interpreter.get_input_details()

    warmup = min(16, len(x))
    for row in x[:warmup]:
        latency_interpreter.set_tensor(
            latency_input_details[0]["index"], row.reshape(1, -1)
        )
        latency_interpreter.invoke()

    timed_rows = x[: min(512, len(x))]
    start = time.perf_counter()
    for row in timed_rows:
        latency_interpreter.set_tensor(
            latency_input_details[0]["index"], row.reshape(1, -1)
        )
        latency_interpreter.invoke()
    per_sample_latency_ms = ((time.perf_counter() - start) * 1000) / len(timed_rows)

    details = {
        "batch_mode": batch_mode,
        "sample_count": int(len(x)),
        "batch_latency_ms": round(float(batch_latency_ms), 4),
        "per_sample_latency_ms": round(float(per_sample_latency_ms), 4),
        "input_shape": [int(v) for v in interpreter.get_input_details()[0]["shape"]],
        "latency_input_shape": [
            int(v) for v in latency_interpreter.get_input_details()[0]["shape"]
        ],
        "output_shape": [int(v) for v in interpreter.get_output_details()[0]["shape"]],
    }
    return scores, details


def classification_metrics(y_true: np.ndarray, scores: np.ndarray, threshold: float) -> Dict[str, Any]:
    preds = (scores >= threshold).astype(np.int32)
    return {
        "accuracy": round(float(accuracy_score(y_true, preds)), 6),
        "precision": round(float(precision_score(y_true, preds, zero_division=0)), 6),
        "recall": round(float(recall_score(y_true, preds, zero_division=0)), 6),
        "f1": round(float(f1_score(y_true, preds, zero_division=0)), 6),
    }


def write_markdown(report: Dict[str, Any]) -> None:
    md = f"""# TFLite Validation Report

Generated: {report["generated_at"]}

## Result

- Status: {report["status"]}
- Max absolute deviation: {report["deviation"]["max_abs"]}
- Mean absolute deviation: {report["deviation"]["mean_abs"]}
- Acceptance threshold: {report["deviation"]["accepted_max_abs"]}
- TFLite model size: {report["model_size_bytes"]} bytes
- Per-sample latency: {report["latency"]["per_sample_latency_ms"]} ms

## Metrics

- Keras F1: {report["keras_metrics"]["f1"]}
- TFLite F1: {report["tflite_metrics"]["f1"]}
- TFLite accuracy: {report["tflite_metrics"]["accuracy"]}
- TFLite precision: {report["tflite_metrics"]["precision"]}
- TFLite recall: {report["tflite_metrics"]["recall"]}
"""
    (REPORT_DIR / "tflite_validation_report.md").write_text(md, encoding="utf-8")


def validate(args: argparse.Namespace) -> Dict[str, Any]:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    metadata = load_metadata()
    threshold = float(metadata.get("thresholds", {}).get("anomaly", 0.35))
    x, y, stored_keras_scores = load_validation_sample()

    keras_model = tf.keras.models.load_model(KERAS_MODEL, compile=False)
    live_keras_scores = keras_model.predict(x, verbose=0).reshape(-1).astype(np.float32)
    tflite_scores, latency = run_tflite_scores(TFLITE_MODEL, x)

    stored_deviation = np.abs(stored_keras_scores - live_keras_scores)
    tflite_deviation = np.abs(live_keras_scores - tflite_scores)
    max_abs = float(tflite_deviation.max())
    mean_abs = float(tflite_deviation.mean())
    status = "passed" if max_abs <= args.max_abs_deviation else "failed"

    report = {
        "generated_at": iso_now(),
        "status": status,
        "model_version": metadata.get("model_version"),
        "sample_count": int(len(x)),
        "threshold": threshold,
        "model_size_bytes": TFLITE_MODEL.stat().st_size,
        "deviation": {
            "max_abs": round(max_abs, 8),
            "mean_abs": round(mean_abs, 8),
            "p95_abs": round(float(np.percentile(tflite_deviation, 95)), 8),
            "accepted_max_abs": args.max_abs_deviation,
            "stored_vs_live_keras_max_abs": round(float(stored_deviation.max()), 8),
        },
        "latency": latency,
        "keras_metrics": classification_metrics(y, live_keras_scores, threshold),
        "tflite_metrics": classification_metrics(y, tflite_scores, threshold),
        "environment": {
            "tensorflow": tf.__version__,
            "numpy": np.__version__,
        },
    }
    (REPORT_DIR / "tflite_validation_report.json").write_text(
        json.dumps(report, indent=2), encoding="utf-8"
    )
    write_markdown(report)

    if status != "passed":
        raise SystemExit(
            f"TFLite validation failed: max deviation {max_abs:.8f} exceeds {args.max_abs_deviation}"
        )
    print(json.dumps(report, indent=2))
    return report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--max-abs-deviation", type=float, default=0.01)
    return parser.parse_args()


if __name__ == "__main__":
    validate(parse_args())
