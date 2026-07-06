#!/usr/bin/env python3
"""Train LPWAN/LoRaWAN models and export lightweight TFLite assets."""

from __future__ import annotations

import argparse
import json
import math
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Tuple

import numpy as np
import pandas as pd

try:
    import matplotlib

    matplotlib.use("Agg", force=True)
except Exception:
    pass


ROOT = Path(__file__).resolve().parents[2]
LPWAN_PROCESSED = ROOT / "data" / "lpwan" / "processed"
REPORT_DIR = ROOT / "reports"
LPWAN_REPORT_DIR = REPORT_DIR / "lpwan"
ASSET_DIR = ROOT / "assets" / "ml_models"
MODEL_DIR = ROOT / "models" / "lpwan"


FEATURE_COLUMNS = [
    "rssi_dbm",
    "snr_db",
    "spreading_factor",
    "bandwidth_khz",
    "coding_rate_value",
    "tx_power_dbm",
    "frequency_mhz",
    "crc_ok",
    "packet_received",
    "distance_m",
    "environment_code",
    "obstacle_level",
    "battery_voltage",
    "battery_pct",
    "current_ma",
    "delivery_ratio",
    "packet_loss_rate",
]


TASKS = {
    "packet_loss": {
        "target": "label_packet_loss",
        "type": "binary",
        "title": "Packet Loss Predictor",
    },
    "link_quality": {
        "target": "label_link_quality",
        "type": "multiclass",
        "title": "Link Quality Classifier",
    },
    "gateway_health": {
        "target": "label_gateway_health",
        "type": "multiclass",
        "title": "Gateway Health Classifier",
    },
    "energy_risk": {
        "target": "label_energy_risk",
        "type": "binary",
        "title": "Energy Risk Predictor",
    },
    "optimal_sf": {
        "target": "label_optimal_sf",
        "type": "multiclass",
        "title": "Optimal Spreading Factor Classifier",
    },
}


def iso_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT)).replace("\\", "/")


def ensure_dirs() -> None:
    for path in [LPWAN_REPORT_DIR, ASSET_DIR, MODEL_DIR]:
        path.mkdir(parents=True, exist_ok=True)


def load_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def load_dataset(max_rows: int, seed: int) -> pd.DataFrame:
    parquet_path = LPWAN_PROCESSED / "lpwan_training_dataset.parquet"
    csv_path = LPWAN_PROCESSED / "lpwan_training_dataset.csv"
    if parquet_path.exists():
        df = pd.read_parquet(parquet_path)
    elif csv_path.exists():
        df = pd.read_csv(csv_path)
    else:
        raise FileNotFoundError(
            "Missing data/lpwan/processed/lpwan_training_dataset.csv. "
            "Run scripts/mlops/build_lpwan_dataset.py first."
        )
    if max_rows and len(df) > max_rows:
        df = df.sample(max_rows, random_state=seed).reset_index(drop=True)
    return prepare_features(df)


def prepare_features(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    out["coding_rate_value"] = out["coding_rate"].map(parse_coding_rate).fillna(0.8)
    environment_categories = sorted(out["environment_type"].astype(str).unique())
    env_map = {name: index for index, name in enumerate(environment_categories)}
    out["environment_code"] = out["environment_type"].astype(str).map(env_map).fillna(0)
    for column in FEATURE_COLUMNS:
        out[column] = pd.to_numeric(out[column], errors="coerce").fillna(0)
    for task in TASKS.values():
        target = task["target"]
        if target not in out.columns:
            raise KeyError(f"Missing target column {target}")
    out.attrs["environment_map"] = env_map
    return out


def parse_coding_rate(value: Any) -> float:
    text = str(value)
    if "/" in text:
        left, right = text.split("/", 1)
        try:
            return float(left) / float(right)
        except Exception:
            return 0.8
    return float(text) if text.replace(".", "", 1).isdigit() else 0.8


def encode_target(series: pd.Series) -> Tuple[np.ndarray, Dict[str, int]]:
    labels = sorted(series.astype(str).unique())
    mapping = {label: index for index, label in enumerate(labels)}
    encoded = series.astype(str).map(mapping).astype(int).to_numpy()
    return encoded, mapping


def split_data(df: pd.DataFrame, target: str, seed: int):
    from sklearn.model_selection import train_test_split

    x = df[FEATURE_COLUMNS].to_numpy(dtype="float32")
    y, mapping = encode_target(df[target])
    stratify = y if len(np.unique(y)) > 1 and min(np.bincount(y)) >= 2 else None
    return (*train_test_split(x, y, test_size=0.22, random_state=seed, stratify=stratify), mapping)


def classifier_metrics(y_true: np.ndarray, y_pred: np.ndarray, y_score: np.ndarray | None, labels: List[str]) -> Dict[str, Any]:
    from sklearn.metrics import accuracy_score, confusion_matrix, f1_score, precision_score, recall_score, roc_auc_score

    metrics = {
        "accuracy": round(float(accuracy_score(y_true, y_pred)), 6),
        "precision_macro": round(float(precision_score(y_true, y_pred, average="macro", zero_division=0)), 6),
        "recall_macro": round(float(recall_score(y_true, y_pred, average="macro", zero_division=0)), 6),
        "f1_macro": round(float(f1_score(y_true, y_pred, average="macro", zero_division=0)), 6),
        "confusion_matrix": confusion_matrix(y_true, y_pred).astype(int).tolist(),
        "labels": labels,
    }
    if y_score is not None:
        try:
            if y_score.ndim == 1 or y_score.shape[1] <= 2:
                positive = np.ravel(y_score if y_score.ndim == 1 else y_score[:, -1])
                metrics["roc_auc"] = round(float(roc_auc_score(y_true, positive)), 6)
            else:
                metrics["roc_auc_ovr_macro"] = round(float(roc_auc_score(y_true, y_score, multi_class="ovr", average="macro")), 6)
        except Exception:
            pass
    return metrics


def prediction_scores(model: Any, x_test: np.ndarray) -> Tuple[np.ndarray, np.ndarray | None]:
    if hasattr(model, "predict_proba"):
        score = model.predict_proba(x_test)
        pred = np.argmax(score, axis=1)
        return pred, score
    pred = model.predict(x_test)
    return np.asarray(pred, dtype=int), None


def benchmark_models(task_name: str, x_train: np.ndarray, x_test: np.ndarray, y_train: np.ndarray, y_test: np.ndarray, labels: List[str], seed: int) -> List[Dict[str, Any]]:
    from sklearn.ensemble import ExtraTreesClassifier, HistGradientBoostingClassifier, RandomForestClassifier

    factories = [
        (
            "Random Forest",
            lambda: RandomForestClassifier(
                n_estimators=90,
                max_depth=16,
                min_samples_leaf=2,
                class_weight="balanced_subsample",
                n_jobs=-1,
                random_state=seed,
            ),
        ),
        (
            "Gradient Boosting",
            lambda: HistGradientBoostingClassifier(
                max_iter=100,
                learning_rate=0.08,
                max_leaf_nodes=31,
                random_state=seed,
            ),
        ),
        (
            "Extra Trees",
            lambda: ExtraTreesClassifier(
                n_estimators=130,
                max_depth=18,
                min_samples_leaf=2,
                class_weight="balanced",
                n_jobs=-1,
                random_state=seed,
            ),
        ),
    ]
    optional = optional_model_factories(seed, len(labels))
    if task_name in {"packet_loss", "link_quality", "energy_risk"}:
        factories.extend(optional)

    results: List[Dict[str, Any]] = []
    for name, factory in factories:
        started = time.time()
        try:
            model = factory()
            model.fit(x_train, y_train)
            pred, score = prediction_scores(model, x_test)
            metrics = classifier_metrics(y_test, pred, score, labels)
            model_size = model_size_estimate(model)
            results.append(
                {
                    "model": name,
                    "status": "trained",
                    "metrics": metrics,
                    "runtimeSeconds": round(time.time() - started, 3),
                    "modelSizeEstimateBytes": model_size,
                    "isTreeModel": True,
                    "modelObject": model,
                }
            )
        except Exception as exc:
            results.append(
                {
                    "model": name,
                    "status": "failed",
                    "reason": str(exc),
                    "runtimeSeconds": round(time.time() - started, 3),
                }
            )
    return results


def optional_model_factories(seed: int, class_count: int) -> List[Tuple[str, Any]]:
    factories: List[Tuple[str, Any]] = []
    try:
        from xgboost import XGBClassifier

        factories.append(
            (
                "XGBoost",
                lambda: XGBClassifier(
                    n_estimators=70,
                    max_depth=4,
                    learning_rate=0.08,
                    subsample=0.85,
                    colsample_bytree=0.85,
                    objective="binary:logistic" if class_count <= 2 else "multi:softprob",
                    eval_metric="logloss" if class_count <= 2 else "mlogloss",
                    random_state=seed,
                    n_jobs=2,
                    verbosity=0,
                ),
            )
        )
    except Exception:
        pass
    try:
        from lightgbm import LGBMClassifier

        factories.append(
            (
                "LightGBM",
                lambda: LGBMClassifier(
                    n_estimators=90,
                    learning_rate=0.06,
                    num_leaves=31,
                    class_weight="balanced",
                    random_state=seed,
                    n_jobs=2,
                    verbose=-1,
                ),
            )
        )
    except Exception:
        pass
    try:
        from catboost import CatBoostClassifier

        factories.append(
            (
                "CatBoost",
                lambda: CatBoostClassifier(
                    iterations=80,
                    depth=5,
                    learning_rate=0.08,
                    loss_function="Logloss" if class_count <= 2 else "MultiClass",
                    random_seed=seed,
                    verbose=False,
                    thread_count=2,
                ),
            )
        )
    except Exception:
        pass
    return factories


def model_size_estimate(model: Any) -> int:
    import pickle

    try:
        return len(pickle.dumps(model))
    except Exception:
        return 0


def train_tflite_model(
    task_name: str,
    task: Dict[str, str],
    x_train: np.ndarray,
    x_test: np.ndarray,
    y_train: np.ndarray,
    y_test: np.ndarray,
    labels: List[str],
    seed: int,
) -> Dict[str, Any]:
    import tensorflow as tf

    tf.keras.utils.set_random_seed(seed)
    class_count = len(labels)
    normalizer = tf.keras.layers.Normalization(axis=-1, name="feature_normalization")
    normalizer.adapt(x_train)
    inputs = tf.keras.Input(shape=(x_train.shape[1],), dtype=tf.float32, name="lpwan_features")
    x = normalizer(inputs)
    x = tf.keras.layers.Dense(48, activation="relu")(x)
    x = tf.keras.layers.Dropout(0.08)(x)
    x = tf.keras.layers.Dense(24, activation="relu")(x)
    if class_count <= 2:
        outputs = tf.keras.layers.Dense(1, activation="sigmoid", name=task_name)(x)
        loss = "binary_crossentropy"
        y_train_fit = y_train.astype("float32")
        y_test_eval = y_test.astype("float32")
    else:
        outputs = tf.keras.layers.Dense(class_count, activation="softmax", name=task_name)(x)
        loss = "sparse_categorical_crossentropy"
        y_train_fit = y_train
        y_test_eval = y_test
    model = tf.keras.Model(inputs=inputs, outputs=outputs)
    model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=0.0015), loss=loss, metrics=["accuracy"])
    started = time.time()
    model.fit(
        x_train,
        y_train_fit,
        validation_split=0.12,
        epochs=5,
        batch_size=512,
        verbose=0,
    )
    raw = model.predict(x_test, batch_size=4096, verbose=0)
    if class_count <= 2:
        score = raw.reshape(-1)
        pred = (score >= 0.5).astype(int)
        score_for_metrics = score
    else:
        score_for_metrics = raw
        pred = np.argmax(raw, axis=1)
    metrics = classifier_metrics(y_test_eval.astype(int), pred, score_for_metrics, labels)
    keras_path = MODEL_DIR / f"lpwan_{task_name}.keras"
    model.save(keras_path)
    tflite_path = ASSET_DIR / f"lpwan_{task_name}.tflite"
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_bytes = converter.convert()
    tflite_path.write_bytes(tflite_bytes)
    return {
        "model": "Neural Network/TFLite",
        "status": "trained",
        "metrics": metrics,
        "runtimeSeconds": round(time.time() - started, 3),
        "kerasPath": rel(keras_path),
        "tflitePath": rel(tflite_path),
        "tfliteSizeBytes": tflite_path.stat().st_size,
        "isTreeModel": False,
    }


def plot_confusion_matrix(task_name: str, matrix: List[List[int]], labels: List[str]) -> str:
    import matplotlib.pyplot as plt

    path = LPWAN_REPORT_DIR / f"{task_name}_confusion_matrix.png"
    arr = np.asarray(matrix)
    fig, ax = plt.subplots(figsize=(5.2, 4.4))
    image = ax.imshow(arr, cmap="Blues")
    ax.set_title(f"{task_name.replace('_', ' ').title()} Confusion Matrix")
    ax.set_xlabel("Predicted")
    ax.set_ylabel("Actual")
    ax.set_xticks(range(len(labels)), labels=labels, rotation=35, ha="right")
    ax.set_yticks(range(len(labels)), labels=labels)
    for i in range(arr.shape[0]):
        for j in range(arr.shape[1]):
            ax.text(j, i, str(arr[i, j]), ha="center", va="center", color="black", fontsize=8)
    fig.colorbar(image, ax=ax, fraction=0.046, pad=0.04)
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)
    return rel(path)


def plot_curves(task_name: str, y_true: np.ndarray, y_score: np.ndarray, labels: List[str]) -> Dict[str, str]:
    import matplotlib.pyplot as plt
    from sklearn.metrics import auc, precision_recall_curve, roc_curve
    from sklearn.preprocessing import label_binarize

    outputs: Dict[str, str] = {}
    try:
        if y_score.ndim == 1 or len(labels) <= 2:
            scores = np.ravel(y_score if y_score.ndim == 1 else y_score[:, -1])
            fpr, tpr, _ = roc_curve(y_true, scores)
            precision, recall, _ = precision_recall_curve(y_true, scores)
        else:
            y_bin = label_binarize(y_true, classes=list(range(len(labels))))
            fpr, tpr, _ = roc_curve(y_bin.ravel(), y_score.ravel())
            precision, recall, _ = precision_recall_curve(y_bin.ravel(), y_score.ravel())

        roc_path = LPWAN_REPORT_DIR / f"{task_name}_roc_curve.png"
        fig, ax = plt.subplots(figsize=(5.0, 4.0))
        ax.plot(fpr, tpr, label=f"AUC {auc(fpr, tpr):.3f}")
        ax.plot([0, 1], [0, 1], linestyle="--", color="gray", linewidth=1)
        ax.set_xlabel("False Positive Rate")
        ax.set_ylabel("True Positive Rate")
        ax.set_title(f"{task_name.replace('_', ' ').title()} ROC")
        ax.legend()
        fig.tight_layout()
        fig.savefig(roc_path, dpi=150)
        plt.close(fig)
        outputs["rocCurve"] = rel(roc_path)

        pr_path = LPWAN_REPORT_DIR / f"{task_name}_precision_recall_curve.png"
        fig, ax = plt.subplots(figsize=(5.0, 4.0))
        ax.plot(recall, precision)
        ax.set_xlabel("Recall")
        ax.set_ylabel("Precision")
        ax.set_title(f"{task_name.replace('_', ' ').title()} Precision-Recall")
        fig.tight_layout()
        fig.savefig(pr_path, dpi=150)
        plt.close(fig)
        outputs["precisionRecallCurve"] = rel(pr_path)
    except Exception as exc:
        outputs["curveError"] = str(exc)
    return outputs


def shap_report(task_name: str, model: Any, x_sample: np.ndarray, feature_names: List[str]) -> Dict[str, Any]:
    try:
        import shap  # type: ignore

        explainer = shap.TreeExplainer(model)
        values = explainer.shap_values(x_sample)
        if isinstance(values, list):
            arr = np.asarray(values[-1])
        else:
            arr = np.asarray(values)
            if arr.ndim == 3:
                arr = arr[:, :, min(1, arr.shape[-1] - 1)]
        if arr.ndim > 2:
            arr = arr.reshape(arr.shape[0], -1)
        mean_abs = np.abs(arr).mean(axis=0).reshape(-1)
        rows = [
            {"feature": feature, "meanAbsShap": round(float(value), 6)}
            for feature, value in zip(feature_names, mean_abs)
        ]
        rows.sort(key=lambda row: row["meanAbsShap"], reverse=True)
        return {"status": "computed", "topFeatures": rows[:12]}
    except Exception as exc:
        if hasattr(model, "feature_importances_"):
            rows = [
                {"feature": feature, "meanAbsShap": round(float(value), 6)}
                for feature, value in zip(feature_names, model.feature_importances_)
            ]
            rows.sort(key=lambda row: row["meanAbsShap"], reverse=True)
            return {"status": f"fallback_feature_importance: {exc}", "topFeatures": rows[:12]}
        return {"status": f"failed: {exc}", "topFeatures": []}


def train_all(args: argparse.Namespace) -> Dict[str, Any]:
    ensure_dirs()
    generated_at = iso_now()
    dataset_report = load_json(REPORT_DIR / "lpwan_dataset_report.json", {})
    df = load_dataset(args.max_rows, args.seed)
    summary: Dict[str, Any] = {
        "generatedAt": generated_at,
        "dataset": {
            "rowsAvailable": int(dataset_report.get("rows", len(df))),
            "rowsUsedForTraining": int(len(df)),
            "realRows": int(dataset_report.get("realRows", 0)),
            "syntheticRows": int(dataset_report.get("syntheticRows", 0)),
            "realRatio": float(dataset_report.get("realRatio", 0)),
            "sourceTypes": dataset_report.get("sourceTypes", {}),
            "sourceDatasets": dataset_report.get("sourceDatasets", {}),
        },
        "featureColumns": FEATURE_COLUMNS,
        "tasks": {},
        "tfliteAssets": {},
    }

    for task_name, task in TASKS.items():
        x_train, x_test, y_train, y_test, mapping = split_data(df, task["target"], args.seed)
        inverse_labels = [label for label, _ in sorted(mapping.items(), key=lambda item: item[1])]
        results = benchmark_models(task_name, x_train, x_test, y_train, y_test, inverse_labels, args.seed)
        nn_result = train_tflite_model(task_name, task, x_train, x_test, y_train, y_test, inverse_labels, args.seed)
        results.append(nn_result)
        trained = [row for row in results if row.get("status") == "trained"]
        best = max(trained, key=lambda row: row["metrics"].get("f1_macro", 0)) if trained else {}
        tflite = nn_result
        score_source = None
        best_for_artifacts = best
        if "modelObject" in best_for_artifacts:
            pred, score_source = prediction_scores(best_for_artifacts["modelObject"], x_test)
        else:
            score_source = None
        confusion_path = plot_confusion_matrix(
            task_name,
            best.get("metrics", {}).get("confusion_matrix", []),
            inverse_labels,
        ) if best else ""
        curves = {}
        if score_source is not None:
            curves = plot_curves(task_name, y_test, score_source, inverse_labels)
        shap_payload = {}
        tree_candidates = [row for row in trained if row.get("isTreeModel") and "modelObject" in row]
        if tree_candidates:
            tree_best = max(tree_candidates, key=lambda row: row["metrics"].get("f1_macro", 0))
            shap_payload = shap_report(
                task_name,
                tree_best["modelObject"],
                x_test[: min(500, len(x_test))],
                FEATURE_COLUMNS,
            )
        clean_results = []
        for row in results:
            cleaned = {key: value for key, value in row.items() if key != "modelObject"}
            clean_results.append(cleaned)
        summary["tasks"][task_name] = {
            "title": task["title"],
            "target": task["target"],
            "type": task["type"],
            "labels": inverse_labels,
            "labelMapping": mapping,
            "bestModel": {key: value for key, value in best.items() if key != "modelObject"},
            "tfliteModel": tflite,
            "benchmarks": clean_results,
            "confusionMatrixPlot": confusion_path,
            "curves": curves,
            "shap": shap_payload,
        }
        summary["tfliteAssets"][task_name] = tflite.get("tflitePath")

    write_outputs(summary)
    print(json.dumps({"status": "trained", "summary": "assets/ml_models/lpwan_summary.json", "tasks": list(summary["tasks"].keys())}, indent=2))
    return summary


def write_outputs(summary: Dict[str, Any]) -> None:
    write_json(REPORT_DIR / "lpwan_model_summary.json", summary)
    write_json(ASSET_DIR / "lpwan_summary.json", compact_summary(summary))
    merged = load_json(ASSET_DIR / "mlops_summary.json", {})
    merged["lpwan"] = compact_summary(summary)
    write_json(ASSET_DIR / "mlops_summary.json", merged)
    report_summary = load_json(REPORT_DIR / "mlops_summary.json", {})
    report_summary["lpwan"] = compact_summary(summary)
    write_json(REPORT_DIR / "mlops_summary.json", report_summary)
    write_markdown(summary)


def compact_summary(summary: Dict[str, Any]) -> Dict[str, Any]:
    tasks = {}
    for name, task in summary["tasks"].items():
        best = task.get("bestModel", {})
        tflite = task.get("tfliteModel", {})
        tasks[name] = {
            "title": task["title"],
            "bestModel": best.get("model", "unknown"),
            "bestF1": best.get("metrics", {}).get("f1_macro", 0),
            "bestAccuracy": best.get("metrics", {}).get("accuracy", 0),
            "tflitePath": tflite.get("tflitePath", ""),
            "tfliteSizeBytes": tflite.get("tfliteSizeBytes", 0),
            "shapStatus": task.get("shap", {}).get("status", ""),
            "topFeatures": task.get("shap", {}).get("topFeatures", [])[:5],
        }
    return {
        "generatedAt": summary["generatedAt"],
        "status": "research_grade" if summary["dataset"].get("realRatio", 0) >= 0.95 else "attention",
        "dataset": summary["dataset"],
        "featureCount": len(summary["featureColumns"]),
        "tasks": tasks,
        "tfliteAssets": summary["tfliteAssets"],
        "reports": {
            "dataset": "reports/lpwan_dataset_report.md",
            "models": "reports/lpwan_model_report.md",
            "summary": "reports/lpwan_model_summary.json",
            "figures": "reports/lpwan/",
        },
    }


def write_markdown(summary: Dict[str, Any]) -> None:
    dataset = summary["dataset"]
    lines = [
        "# LPWAN / LoRaWAN Model Training Report",
        "",
        f"- Generated at: `{summary['generatedAt']}`",
        f"- Rows available: `{dataset['rowsAvailable']}`",
        f"- Rows used for training: `{dataset['rowsUsedForTraining']}`",
        f"- Real/enriched rows: `{dataset['realRows']}`",
        f"- Synthetic rows: `{dataset['syntheticRows']}`",
        f"- Real/enriched ratio: `{dataset['realRatio']}`",
        f"- Feature count: `{len(summary['featureColumns'])}`",
        "",
        "## Task Summary",
        "",
        "| Task | Best Model | F1 Macro | Accuracy | TFLite Asset | SHAP |",
        "| --- | --- | ---: | ---: | --- | --- |",
    ]
    for name, task in summary["tasks"].items():
        best = task.get("bestModel", {})
        tflite = task.get("tfliteModel", {})
        metrics = best.get("metrics", {})
        lines.append(
            f"| {task['title']} | {best.get('model', 'unknown')} | {metrics.get('f1_macro', 0)} | "
            f"{metrics.get('accuracy', 0)} | `{tflite.get('tflitePath', '')}` | {task.get('shap', {}).get('status', '')} |"
        )
    lines.extend(["", "## Benchmarks", ""])
    for name, task in summary["tasks"].items():
        lines.append(f"### {task['title']}")
        lines.append("")
        lines.append("| Model | Status | F1 Macro | Accuracy | ROC-AUC | Runtime |")
        lines.append("| --- | --- | ---: | ---: | ---: | ---: |")
        for row in task["benchmarks"]:
            metrics = row.get("metrics", {})
            auc = metrics.get("roc_auc", metrics.get("roc_auc_ovr_macro", ""))
            lines.append(
                f"| {row.get('model')} | {row.get('status')} | {metrics.get('f1_macro', '')} | "
                f"{metrics.get('accuracy', '')} | {auc} | {row.get('runtimeSeconds', '')} |"
            )
        lines.append("")
        if task.get("confusionMatrixPlot"):
            lines.append(f"- Confusion matrix: `{task['confusionMatrixPlot']}`")
        if task.get("curves"):
            for label, path in task["curves"].items():
                lines.append(f"- {label}: `{path}`")
        top_features = task.get("shap", {}).get("topFeatures", [])
        if top_features:
            lines.append("- SHAP/top drivers: " + ", ".join(f"{item['feature']} ({item['meanAbsShap']})" for item in top_features[:5]))
        lines.append("")
    lines.extend(
        [
            "## Notes",
            "",
            "- Neural Network/TFLite models are exported for Flutter/mobile deployment even when a tree model wins the offline benchmark.",
            "- XGBoost, LightGBM, and CatBoost are benchmarked for selected tasks when installed; Random Forest, Gradient Boosting, Extra Trees, and Neural Network are always attempted.",
            "- Labels are generated from documented LPWAN engineering rules, not manually annotated field incidents.",
        ]
    )
    (REPORT_DIR / "lpwan_model_report.md").write_text("\n".join(lines), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--max-rows", type=int, default=150_000)
    parser.add_argument("--seed", type=int, default=42)
    return parser.parse_args()


if __name__ == "__main__":
    train_all(parse_args())
