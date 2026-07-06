#!/usr/bin/env python3
"""Train production-ready AI models for SmartCity LPWAN.

The production anomaly model intentionally uses only the raw telemetry fields
that Flutter can provide at inference time. Engineered features remain useful
for offline analysis, but mobile inference must receive a stable, small feature
vector with no hidden server-side dependencies.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple


ROOT = Path(__file__).resolve().parents[2]
PROCESSED_DIR = ROOT / "data" / "processed"
MODEL_DIR = ROOT / "models"
REPORT_DIR = ROOT / "reports"

MODEL_VERSION = os.getenv("MODEL_VERSION", "2026.06.13-prod")
DOMAINS = ["water", "bridge", "building", "agriculture"]
DOMAIN_IDS = {domain: index for index, domain in enumerate(DOMAINS)}

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

LABEL_TYPE_NAMES = {
    0: "Normal",
    1: "Sensor Fault",
    2: "Infrastructure Issue",
    3: "Communication Issue",
    4: "Battery Critical",
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


def ensure_dirs() -> None:
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)


def iso_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT)).replace("\\", "/")


def load_dataset():
    import numpy as np
    import pandas as pd

    clean_path = PROCESSED_DIR / "clean_telemetry_all.csv"
    if not clean_path.exists():
        raise FileNotFoundError(
            f"Missing {rel(clean_path)}. Run scripts/data_pipeline/02_clean_and_engineer.py first."
        )
    usecols = [
        "timestamp",
        "node_id",
        "domain",
        *[feature for feature in RUNTIME_FEATURES if feature != "domain_id"],
        "is_anomaly",
        "anomaly_type",
    ]
    log(f"[cyan]Loading training data from {rel(clean_path)}[/cyan]")
    df = pd.read_csv(clean_path, usecols=lambda col: col in usecols)
    df["domain"] = df["domain"].astype(str).str.lower()
    df = df[df["domain"].isin(DOMAINS)].copy()
    df["domain_id"] = df["domain"].map(DOMAIN_IDS).astype("float32")
    df["timestamp"] = pd.to_datetime(df["timestamp"], utc=True, errors="coerce")
    df = df.dropna(subset=["timestamp"]).sort_values("timestamp").reset_index(drop=True)
    for feature in RUNTIME_FEATURES:
        if feature not in df.columns:
            df[feature] = 0.0
        df[feature] = pd.to_numeric(df[feature], errors="coerce").fillna(0.0).astype("float32")
    df["target_anomaly"] = pd.to_numeric(df["is_anomaly"], errors="coerce").fillna(0).astype("int32")
    anomaly_type = df["anomaly_type"].fillna("normal").astype(str)
    label_map = {
        "normal": 0,
        "sensor_fault": 1,
        "infrastructure_issue": 2,
        "communication_issue": 3,
        "battery_critical": 4,
    }
    df["label_type"] = anomaly_type.map(label_map).fillna(df["target_anomaly"] * 2).astype("int32")
    x = df[RUNTIME_FEATURES].to_numpy(dtype=np.float32)
    y = df["target_anomaly"].to_numpy(dtype=np.int32)
    labels = df["label_type"].to_numpy(dtype=np.int32)
    return df, x, y, labels


def split_indices(n: int) -> Tuple[slice, slice, slice]:
    train_end = int(n * 0.70)
    valid_end = int(n * 0.85)
    return slice(0, train_end), slice(train_end, valid_end), slice(valid_end, n)


def class_weights(y_train) -> Dict[int, float]:
    import numpy as np

    values, counts = np.unique(y_train, return_counts=True)
    total = float(len(y_train))
    weights = {}
    for value, count in zip(values, counts):
        weights[int(value)] = total / (len(values) * float(count))
    return weights


def classification_metrics(y_true, y_pred, y_score) -> Dict[str, Any]:
    from sklearn.metrics import (
        accuracy_score,
        confusion_matrix,
        f1_score,
        precision_score,
        recall_score,
        roc_auc_score,
    )

    metrics = {
        "accuracy": round(float(accuracy_score(y_true, y_pred)), 6),
        "precision": round(float(precision_score(y_true, y_pred, zero_division=0)), 6),
        "recall": round(float(recall_score(y_true, y_pred, zero_division=0)), 6),
        "f1": round(float(f1_score(y_true, y_pred, zero_division=0)), 6),
        "confusion_matrix": confusion_matrix(y_true, y_pred).astype(int).tolist(),
    }
    try:
        metrics["auc_roc"] = round(float(roc_auc_score(y_true, y_score)), 6)
    except Exception:
        metrics["auc_roc"] = 0.0
    return metrics


def regression_metrics(y_true, y_pred) -> Dict[str, float]:
    import numpy as np
    from sklearn.metrics import mean_absolute_error, mean_squared_error

    return {
        "mae": round(float(mean_absolute_error(y_true, y_pred)), 6),
        "rmse": round(float(math.sqrt(mean_squared_error(y_true, y_pred))), 6),
        "max_abs_error": round(float(np.max(np.abs(y_true - y_pred))), 6),
    }


def sample_for_candidates(x_train, y_train, max_rows: int):
    import numpy as np

    if len(y_train) <= max_rows:
        return x_train, y_train
    rng = np.random.default_rng(42)
    positive_idx = np.flatnonzero(y_train == 1)
    negative_idx = np.flatnonzero(y_train == 0)
    pos_take = min(len(positive_idx), max_rows // 2)
    neg_take = max_rows - pos_take
    selected = np.concatenate(
        [
            rng.choice(positive_idx, size=pos_take, replace=False),
            rng.choice(negative_idx, size=neg_take, replace=False),
        ]
    )
    rng.shuffle(selected)
    return x_train[selected], y_train[selected]


def evaluate_candidate_models(x_train, y_train, x_valid, y_valid, args) -> Dict[str, Any]:
    from sklearn.ensemble import GradientBoostingClassifier, RandomForestClassifier
    from sklearn.pipeline import make_pipeline
    from sklearn.preprocessing import StandardScaler

    candidate_x, candidate_y = sample_for_candidates(
        x_train, y_train, int(args.max_candidate_rows)
    )
    weight = class_weights(candidate_y)
    candidates: Dict[str, Any] = {
        "Random Forest": RandomForestClassifier(
            n_estimators=120,
            max_depth=14,
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
    }
    try:
        from xgboost import XGBClassifier

        scale_pos_weight = max(1.0, float((candidate_y == 0).sum()) / max(1, int((candidate_y == 1).sum())))
        candidates["XGBoost"] = XGBClassifier(
            n_estimators=180,
            max_depth=5,
            learning_rate=0.05,
            subsample=0.9,
            colsample_bytree=0.9,
            eval_metric="logloss",
            scale_pos_weight=scale_pos_weight,
            random_state=42,
        )
    except Exception as exc:
        log(f"[yellow]XGBoost comparison skipped: {exc}[/yellow]")
    try:
        from lightgbm import LGBMClassifier

        candidates["LightGBM"] = LGBMClassifier(
            n_estimators=220,
            learning_rate=0.04,
            num_leaves=31,
            class_weight="balanced",
            random_state=42,
            verbose=-1,
        )
    except Exception as exc:
        log(f"[yellow]LightGBM comparison skipped: {exc}[/yellow]")
    try:
        from catboost import CatBoostClassifier

        scale_pos_weight = max(
            1.0,
            float((candidate_y == 0).sum()) / max(1, int((candidate_y == 1).sum())),
        )
        candidates["CatBoost"] = CatBoostClassifier(
            iterations=220,
            depth=6,
            learning_rate=0.05,
            loss_function="Logloss",
            eval_metric="F1",
            random_seed=42,
            verbose=False,
            scale_pos_weight=scale_pos_weight,
            allow_writing_files=False,
        )
    except Exception as exc:
        log(f"[yellow]CatBoost comparison skipped: {exc}[/yellow]")

    results: Dict[str, Any] = {}
    for name, model in candidates.items():
        started = time.time()
        log(f"[cyan]Evaluating {name}[/cyan]")
        try:
            if name == "Gradient Boosting":
                sample_weight = [weight[int(v)] for v in candidate_y]
                model.fit(candidate_x, candidate_y, sample_weight=sample_weight)
            else:
                model.fit(candidate_x, candidate_y)
            scores = model.predict_proba(x_valid)[:, 1]
            pred = (scores >= 0.5).astype("int32")
            results[name] = {
                "status": "trained",
                "metrics": classification_metrics(y_valid, pred, scores),
                "runtime_seconds": round(time.time() - started, 3),
                "mobile_suitability": "server-side/offline artifact; not directly TFLite deployable",
            }
        except Exception as exc:
            results[name] = {
                "status": "failed",
                "reason": str(exc),
                "runtime_seconds": round(time.time() - started, 3),
            }
    return results


def build_anomaly_model(feature_count: int):
    import tensorflow as tf

    normalizer = tf.keras.layers.Normalization(axis=-1, name="runtime_normalization")
    inputs = tf.keras.Input(shape=(feature_count,), name="runtime_features")
    x = normalizer(inputs)
    x = tf.keras.layers.Dense(48, activation="relu", name="dense_48")(x)
    x = tf.keras.layers.Dropout(0.05, name="dropout_005")(x)
    x = tf.keras.layers.Dense(24, activation="relu", name="dense_24")(x)
    outputs = tf.keras.layers.Dense(1, activation="sigmoid", name="anomaly_score")(x)
    model = tf.keras.Model(inputs=inputs, outputs=outputs, name="smartcity_anomaly_classifier")
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss="binary_crossentropy",
        metrics=[
            tf.keras.metrics.BinaryAccuracy(name="accuracy"),
            tf.keras.metrics.Precision(name="precision"),
            tf.keras.metrics.Recall(name="recall"),
            tf.keras.metrics.AUC(name="auc_roc"),
        ],
    )
    return model, normalizer


def train_neural_model(x_train, y_train, x_valid, y_valid, x_test, y_test, args):
    import numpy as np
    import tensorflow as tf

    model, normalizer = build_anomaly_model(x_train.shape[1])
    normalizer.adapt(x_train)
    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor="val_auc_roc",
            mode="max",
            patience=3,
            restore_best_weights=True,
        )
    ]
    started = time.time()
    history = model.fit(
        x_train,
        y_train,
        validation_data=(x_valid, y_valid),
        epochs=int(args.epochs),
        batch_size=int(args.batch_size),
        class_weight=class_weights(y_train),
        callbacks=callbacks,
        verbose=2,
    )
    valid_scores = model.predict(x_valid, batch_size=4096, verbose=0).reshape(-1)
    threshold = choose_threshold(y_valid, valid_scores)
    test_scores = model.predict(x_test, batch_size=4096, verbose=0).reshape(-1)
    test_pred = (test_scores >= threshold).astype("int32")
    model_path = MODEL_DIR / "production_anomaly_model.keras"
    model.save(model_path)
    validation_path = MODEL_DIR / "validation_sample.npz"
    sample_count = min(2048, len(x_test))
    np.savez_compressed(
        validation_path,
        x=x_test[:sample_count].astype("float32"),
        y=y_test[:sample_count].astype("int32"),
        keras_scores=test_scores[:sample_count].astype("float32"),
    )
    return {
        "model": model,
        "model_path": model_path,
        "validation_sample_path": validation_path,
        "threshold": float(threshold),
        "metrics": classification_metrics(y_test, test_pred, test_scores),
        "history": {
            key: [float(v) for v in values]
            for key, values in history.history.items()
        },
        "runtime_seconds": round(time.time() - started, 3),
        "mobile_suitability": "selected: compact dense Keras model with embedded normalization; directly convertible to TFLite",
    }


def choose_threshold(y_true, scores) -> float:
    import numpy as np
    from sklearn.metrics import f1_score

    thresholds = np.linspace(0.10, 0.90, 81)
    best_threshold = 0.5
    best_f1 = -1.0
    for threshold in thresholds:
        pred = (scores >= threshold).astype("int32")
        f1 = float(f1_score(y_true, pred, zero_division=0))
        if f1 > best_f1:
            best_f1 = f1
            best_threshold = float(threshold)
    return best_threshold


def train_signal_regressor(df, x, train_slice, valid_slice, test_slice) -> Dict[str, Any]:
    from sklearn.ensemble import RandomForestRegressor
    from sklearn.multioutput import MultiOutputRegressor

    signal_df = df[["node_id", "timestamp", "rssi_dbm", "snr_db"]].copy()
    signal_df["row_index"] = range(len(signal_df))
    signal_df = signal_df.sort_values(["node_id", "timestamp"])
    signal_df["rssi_next_hour"] = signal_df.groupby("node_id")["rssi_dbm"].shift(-12)
    signal_df["snr_next_hour"] = signal_df.groupby("node_id")["snr_db"].shift(-12)
    signal_df = signal_df.dropna(subset=["rssi_next_hour", "snr_next_hour"])
    if len(signal_df) < 500:
        return {"status": "skipped", "reason": "not enough signal rows"}
    idx = signal_df["row_index"].to_numpy()
    y = signal_df[["rssi_next_hour", "snr_next_hour"]].to_numpy(dtype="float32")
    train_mask = idx < train_slice.stop
    test_mask = idx >= test_slice.start
    model = MultiOutputRegressor(
        RandomForestRegressor(
            n_estimators=120,
            max_depth=12,
            min_samples_leaf=3,
            n_jobs=-1,
            random_state=42,
        )
    )
    started = time.time()
    model.fit(x[idx[train_mask]], y[train_mask])
    pred = model.predict(x[idx[test_mask]])
    import joblib

    path = MODEL_DIR / "signal_predictor.pkl"
    joblib.dump({"model": model, "features": RUNTIME_FEATURES}, path)
    return {
        "status": "trained",
        "algorithm": "RandomForestRegressor",
        "metrics": regression_metrics(y[test_mask], pred),
        "model_path": rel(path),
        "runtime_seconds": round(time.time() - started, 3),
    }


def severity_target(label_type: int) -> int:
    if label_type == 0:
        return 0
    if label_type == 1:
        return 2
    if label_type == 2:
        return 3
    if label_type == 3:
        return 2
    if label_type == 4:
        return 4
    return 1


def train_alert_scorer(x_train, labels_train, x_test, labels_test) -> Dict[str, Any]:
    import numpy as np
    import tensorflow as tf

    y_train = np.array([severity_target(int(v)) for v in labels_train], dtype="int32")
    y_test = np.array([severity_target(int(v)) for v in labels_test], dtype="int32")
    normalizer = tf.keras.layers.Normalization(axis=-1, name="alert_normalization")
    inputs = tf.keras.Input(shape=(x_train.shape[1],), name="runtime_features")
    x = normalizer(inputs)
    x = tf.keras.layers.Dense(40, activation="relu")(x)
    x = tf.keras.layers.Dense(20, activation="relu")(x)
    outputs = tf.keras.layers.Dense(5, activation="softmax", name="severity")(x)
    model = tf.keras.Model(inputs=inputs, outputs=outputs, name="smartcity_alert_scorer")
    normalizer.adapt(x_train)
    model.compile(
        optimizer="adam",
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    started = time.time()
    model.fit(x_train, y_train, epochs=5, batch_size=2048, verbose=0)
    pred = model.predict(x_test, batch_size=4096, verbose=0).argmax(axis=1)
    from sklearn.metrics import accuracy_score, confusion_matrix, f1_score

    path = MODEL_DIR / "alert_scorer.keras"
    model.save(path)
    return {
        "status": "trained",
        "model_path": rel(path),
        "metrics": {
            "accuracy": round(float(accuracy_score(y_test, pred)), 6),
            "f1_macro": round(float(f1_score(y_test, pred, average="macro", zero_division=0)), 6),
            "confusion_matrix": confusion_matrix(y_test, pred).astype(int).tolist(),
        },
        "classes": {
            "0": "False Alarm",
            "1": "Info",
            "2": "Warning",
            "3": "Critical",
            "4": "Emergency",
        },
        "runtime_seconds": round(time.time() - started, 3),
    }


def write_training_report(report: Dict[str, Any]) -> Path:
    path = REPORT_DIR / "model_training_report.md"
    perf = report["performance"]
    selected = perf["selected_model"]
    cm = selected["metrics"].get("confusion_matrix", [])
    lines = [
        "# SmartCity AI Model Training Report",
        "",
        f"- Generated at: `{report['generated_at']}`",
        f"- Model version: `{report['model_version']}`",
        f"- Dataset size: `{report['dataset_size']}` rows",
        f"- Train size: `{report['splits']['train']}` rows",
        f"- Validation size: `{report['splits']['validation']}` rows",
        f"- Test size: `{report['splits']['test']}` rows",
        f"- Feature count: `{report['feature_count']}`",
        f"- Selected model type: `{selected['model_type']}`",
        f"- Training duration: `{report['runtime_seconds']}` seconds",
        "",
        "## Selected Model Metrics",
        "",
        f"- Accuracy: `{selected['metrics']['accuracy']}`",
        f"- Precision: `{selected['metrics']['precision']}`",
        f"- Recall: `{selected['metrics']['recall']}`",
        f"- F1: `{selected['metrics']['f1']}`",
        f"- AUC-ROC: `{selected['metrics']['auc_roc']}`",
        f"- Threshold: `{selected['threshold']}`",
        "",
        "## Confusion Matrix",
        "",
        "| Actual / Predicted | Normal | Anomaly |",
        "| --- | ---: | ---: |",
    ]
    if len(cm) == 2:
        lines.extend(
            [
                f"| Normal | {cm[0][0]} | {cm[0][1]} |",
                f"| Anomaly | {cm[1][0]} | {cm[1][1]} |",
            ]
        )
    lines.extend(["", "## Model Comparison", ""])
    lines.append("| Model | Accuracy | F1 | AUC-ROC | Runtime (s) | Mobile Suitability |")
    lines.append("| --- | ---: | ---: | ---: | ---: | --- |")
    for name, item in perf["candidate_models"].items():
        if item.get("status") != "trained":
            lines.append(f"| {name} | skipped | skipped | skipped | {item.get('runtime_seconds', 0)} | {item.get('reason', '')} |")
            continue
        metrics = item["metrics"]
        lines.append(
            f"| {name} | {metrics['accuracy']} | {metrics['f1']} | {metrics['auc_roc']} | {item['runtime_seconds']} | {item['mobile_suitability']} |"
        )
    lines.extend(
        [
            f"| Neural Network (selected) | {selected['metrics']['accuracy']} | {selected['metrics']['f1']} | {selected['metrics']['auc_roc']} | {selected['runtime_seconds']} | {selected['mobile_suitability']} |",
            "",
            "## Regression Metrics",
            "",
        ]
    )
    signal = perf.get("signal_predictor", {})
    if signal.get("status") == "trained":
        sm = signal["metrics"]
        lines.extend(
            [
                f"- Signal predictor MAE: `{sm['mae']}`",
                f"- Signal predictor RMSE: `{sm['rmse']}`",
                f"- Signal predictor max absolute error: `{sm['max_abs_error']}`",
            ]
        )
    else:
        lines.append(f"- Signal predictor: `{signal.get('status', 'unknown')}`")
    lines.extend(
        [
            "",
            "## Architecture Choice",
            "",
            "A compact dense neural network was selected for production deployment because it is directly convertible to TensorFlow Lite, has embedded normalization, has a small memory footprint, and avoids shipping tree-ensemble runtimes inside the Flutter app.",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def train(args: argparse.Namespace) -> Dict[str, Any]:
    ensure_dirs()
    started = time.time()
    import numpy as np
    import pandas as pd
    import sklearn
    import tensorflow as tf

    df, x, y, labels = load_dataset()
    train_slice, valid_slice, test_slice = split_indices(len(df))
    x_train, y_train = x[train_slice], y[train_slice]
    x_valid, y_valid = x[valid_slice], y[valid_slice]
    x_test, y_test = x[test_slice], y[test_slice]
    labels_train, labels_test = labels[train_slice], labels[test_slice]

    log(f"[cyan]Training data: {len(df)} rows, {len(RUNTIME_FEATURES)} runtime features[/cyan]")
    candidate_results = evaluate_candidate_models(
        x_train, y_train, x_valid, y_valid, args
    )
    neural = train_neural_model(x_train, y_train, x_valid, y_valid, x_test, y_test, args)
    signal = train_signal_regressor(df, x, train_slice, valid_slice, test_slice)
    alert = train_alert_scorer(x_train, labels_train, x_test, labels_test)

    metadata = {
        "model_version": MODEL_VERSION,
        "generated_at": iso_now(),
        "status": "trained",
        "dataset_size": int(len(df)),
        "splits": {
            "train": int(len(x_train)),
            "validation": int(len(x_valid)),
            "test": int(len(x_test)),
        },
        "feature_count": len(RUNTIME_FEATURES),
        "feature_names": RUNTIME_FEATURES,
        "runtime_feature_order": RUNTIME_FEATURES,
        "domain_ids": DOMAIN_IDS,
        "thresholds": {"anomaly": neural["threshold"]},
        "label_types": LABEL_TYPE_NAMES,
        "production_model": rel(neural["model_path"]),
        "validation_sample": rel(neural["validation_sample_path"]),
        "performance": {
            "candidate_models": candidate_results,
            "selected_model": {
                "model_type": "Dense Neural Network",
                "model_path": rel(neural["model_path"]),
                "threshold": round(float(neural["threshold"]), 6),
                "metrics": neural["metrics"],
                "runtime_seconds": neural["runtime_seconds"],
                "mobile_suitability": neural["mobile_suitability"],
            },
            "signal_predictor": signal,
            "alert_scorer": alert,
        },
        "library_versions": {
            "python": os.sys.version,
            "pandas": pd.__version__,
            "numpy": np.__version__,
            "sklearn": sklearn.__version__,
            "tensorflow": tf.__version__,
        },
        "runtime_seconds": round(time.time() - started, 3),
    }
    metadata_path = MODEL_DIR / "model_metadata.json"
    metadata_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    report_json_path = REPORT_DIR / "step_3_report.json"
    report_json_path.write_text(json.dumps({"step": 3, **metadata}, indent=2), encoding="utf-8")
    report_md_path = write_training_report(metadata)
    log(f"[green]All models trained and saved[/green]")
    log(f"[green]Training report saved to {rel(report_md_path)}[/green]")
    return metadata


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--epochs", type=int, default=int(os.getenv("PRODUCTION_EPOCHS", "12")))
    parser.add_argument("--batch-size", type=int, default=int(os.getenv("PRODUCTION_BATCH_SIZE", "1024")))
    parser.add_argument(
        "--max-candidate-rows",
        type=int,
        default=int(os.getenv("MAX_CANDIDATE_ROWS", "120000")),
        help="Balanced sample size used for non-TFLite candidate comparisons.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    train(parse_args())
