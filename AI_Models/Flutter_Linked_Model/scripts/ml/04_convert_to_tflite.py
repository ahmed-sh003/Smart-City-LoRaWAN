#!/usr/bin/env python3
"""Convert trained Keras models to TensorFlow Lite and write Flutter config."""

from __future__ import annotations

import argparse
import json
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List

import numpy as np
import tensorflow as tf


ROOT = Path(__file__).resolve().parents[2]
MODEL_DIR = ROOT / "models"
DEPLOY_MODEL_DIR = ROOT / "model"
ASSET_MODEL_DIR = ROOT / "assets" / "ml_models"
REPORT_DIR = ROOT / "reports"

PRODUCTION_KERAS = MODEL_DIR / "production_anomaly_model.keras"
ALERT_KERAS = MODEL_DIR / "alert_scorer.keras"
VALIDATION_SAMPLE = MODEL_DIR / "validation_sample.npz"

PRODUCTION_OUTPUTS = [
    DEPLOY_MODEL_DIR / "production_model.tflite",
    ASSET_MODEL_DIR / "production_model.tflite",
]
ALERT_OUTPUTS = [
    DEPLOY_MODEL_DIR / "alert_scorer.tflite",
    ASSET_MODEL_DIR / "alert_scorer.tflite",
]
LEGACY_PLACEHOLDER_ASSETS = [
    ASSET_MODEL_DIR / "anomaly_water.tflite",
    ASSET_MODEL_DIR / "anomaly_bridge.tflite",
    ASSET_MODEL_DIR / "anomaly_building.tflite",
    ASSET_MODEL_DIR / "anomaly_agriculture.tflite",
    ASSET_MODEL_DIR / "maintenance_predictor.tflite",
]


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


def iso_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def ensure_dirs() -> None:
    for directory in (DEPLOY_MODEL_DIR, ASSET_MODEL_DIR, REPORT_DIR):
        directory.mkdir(parents=True, exist_ok=True)


def load_metadata() -> Dict[str, Any]:
    path = MODEL_DIR / "model_metadata.json"
    if not path.exists():
        raise FileNotFoundError(f"Missing trained model metadata: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def load_sample_input(feature_count: int) -> np.ndarray:
    if VALIDATION_SAMPLE.exists():
        payload = np.load(VALIDATION_SAMPLE)
        x = payload["x"].astype(np.float32)
        if x.ndim == 2 and x.shape[1] == feature_count:
            return x[:1]
    return np.zeros((1, feature_count), dtype=np.float32)


def write_all(paths: Iterable[Path], data: bytes) -> List[Dict[str, Any]]:
    written = []
    for path in paths:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        written.append(
            {
                "path": str(path.relative_to(ROOT)),
                "size_bytes": path.stat().st_size,
            }
        )
    return written


def remove_legacy_placeholders() -> Dict[str, Any]:
    removed = []
    kept = []
    for path in LEGACY_PLACEHOLDER_ASSETS:
        if not path.exists():
            continue
        data = path.read_bytes()
        if data.startswith(b"placeholder-"):
            path.unlink()
            removed.append(str(path.relative_to(ROOT)))
        else:
            kept.append(str(path.relative_to(ROOT)))
    return {"removed": removed, "kept_non_placeholder": kept}


def tflite_tensor_summary(path: Path, sample_input: np.ndarray) -> Dict[str, Any]:
    interpreter = tf.lite.Interpreter(model_path=str(path))
    input_details = interpreter.get_input_details()
    input_index = input_details[0]["index"]
    requested_shape = sample_input.shape
    if list(input_details[0]["shape"]) != list(requested_shape):
        interpreter.resize_tensor_input(input_index, requested_shape, strict=False)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    interpreter.set_tensor(input_details[0]["index"], sample_input)
    start = time.perf_counter()
    interpreter.invoke()
    latency_ms = (time.perf_counter() - start) * 1000
    output = interpreter.get_tensor(output_details[0]["index"])

    return {
        "ok": True,
        "input_shape": [int(value) for value in input_details[0]["shape"]],
        "input_dtype": str(input_details[0]["dtype"]),
        "output_shape": [int(value) for value in output_details[0]["shape"]],
        "output_dtype": str(output_details[0]["dtype"]),
        "sample_output": output.astype(float).reshape(-1)[:8].round(6).tolist(),
        "single_inference_ms": round(float(latency_ms), 4),
    }


def convert_keras_to_tflite(
    *,
    name: str,
    keras_path: Path,
    output_paths: List[Path],
    sample_input: np.ndarray,
) -> Dict[str, Any]:
    if not keras_path.exists():
        return {
            "status": "skipped",
            "reason": f"Missing {keras_path.relative_to(ROOT)}",
        }

    log(f"[cyan]Converting {keras_path.relative_to(ROOT)}[/cyan]")
    model = tf.keras.models.load_model(keras_path, compile=False)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]

    start = time.perf_counter()
    tflite_model = converter.convert()
    conversion_seconds = time.perf_counter() - start
    written = write_all(output_paths, tflite_model)
    tensor_test = tflite_tensor_summary(output_paths[0], sample_input)

    return {
        "status": "converted",
        "name": name,
        "keras_model": str(keras_path.relative_to(ROOT)),
        "outputs": written,
        "quantization": "float16_weights_float32_io",
        "conversion_seconds": round(conversion_seconds, 3),
        "interpreter_test": tensor_test,
    }


def write_model_config(metadata: Dict[str, Any], conversions: Dict[str, Any]) -> Dict[str, Any]:
    feature_order = metadata.get("runtime_feature_order") or metadata.get("feature_names") or []
    threshold = metadata.get("thresholds", {}).get("anomaly", 0.35)
    config = {
        "model_version": metadata.get("model_version", "unknown"),
        "generated_at": iso_now(),
        "feature_order": feature_order,
        "runtime_feature_order": feature_order,
        "feature_count": len(feature_order),
        "input_shape": [1, len(feature_order)],
        "domain_ids": metadata.get(
            "domain_ids",
            {"water": 0, "bridge": 1, "building": 2, "agriculture": 3},
        ),
        "thresholds": {
            "anomaly": threshold,
            "fallback_heuristic": 0.58,
        },
        "models": {
            "production_anomaly": "assets/ml_models/production_model.tflite",
            "alert_scorer": "assets/ml_models/alert_scorer.tflite",
        },
        "performance": metadata.get("performance", {}),
        "conversion": conversions,
        "runtime_behavior": {
            "native_flutter": "uses production_anomaly TFLite for anomaly scores",
            "web_flutter": "uses deterministic fallback because tflite_flutter does not provide a web interpreter",
        },
    }
    (ASSET_MODEL_DIR / "model_config.json").write_text(
        json.dumps(config, indent=2), encoding="utf-8"
    )
    return config


def convert(_: argparse.Namespace) -> Dict[str, Any]:
    ensure_dirs()
    metadata = load_metadata()
    feature_order = metadata.get("runtime_feature_order") or metadata.get("feature_names") or []
    feature_count = len(feature_order)
    if feature_count <= 0:
        raise ValueError("Model metadata does not contain a runtime feature order")

    sample_input = load_sample_input(feature_count)
    conversions = {
        "production_anomaly": convert_keras_to_tflite(
            name="production_anomaly",
            keras_path=PRODUCTION_KERAS,
            output_paths=PRODUCTION_OUTPUTS,
            sample_input=sample_input,
        ),
        "alert_scorer": convert_keras_to_tflite(
            name="alert_scorer",
            keras_path=ALERT_KERAS,
            output_paths=ALERT_OUTPUTS,
            sample_input=sample_input,
        ),
    }
    legacy_cleanup = remove_legacy_placeholders()
    config = write_model_config(metadata, conversions)
    report = {
        "step": 4,
        "status": "complete",
        "generated_at": iso_now(),
        "tensorflow_version": tf.__version__,
        "numpy_version": np.__version__,
        "conversions": conversions,
        "config_path": "assets/ml_models/model_config.json",
        "deployment_paths": {
            "production_model": [str(path.relative_to(ROOT)) for path in PRODUCTION_OUTPUTS],
            "alert_scorer": [str(path.relative_to(ROOT)) for path in ALERT_OUTPUTS],
        },
        "legacy_placeholder_cleanup": legacy_cleanup,
        "config": config,
    }
    (REPORT_DIR / "step_4_report.json").write_text(
        json.dumps(report, indent=2), encoding="utf-8"
    )
    log("[green]TFLite conversion complete[/green]")
    return report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    return parser.parse_args()


if __name__ == "__main__":
    convert(parse_args())
