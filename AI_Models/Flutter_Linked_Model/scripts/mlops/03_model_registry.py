#!/usr/bin/env python3
"""Maintain a lightweight on-disk model registry for SmartCity AI artifacts."""

from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List


ROOT = Path(__file__).resolve().parents[2]
MODEL_DIR = ROOT / "models"
ASSET_DIR = ROOT / "assets" / "ml_models"
REPORT_DIR = ROOT / "reports" / "mlops"
REGISTRY_PATH = MODEL_DIR / "registry.json"


ARTIFACTS = [
    MODEL_DIR / "model_metadata.json",
    MODEL_DIR / "production_anomaly_model.keras",
    MODEL_DIR / "alert_scorer.keras",
    MODEL_DIR / "signal_predictor.pkl",
    MODEL_DIR / "validation_sample.npz",
    ASSET_DIR / "production_model.tflite",
    ASSET_DIR / "alert_scorer.tflite",
    ASSET_DIR / "model_config.json",
    ASSET_DIR / "mlops_summary.json",
]


def iso_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT)).replace("\\", "/")


def load_registry() -> Dict[str, Any]:
    if not REGISTRY_PATH.exists():
        return {
            "schema": "smartcity-model-registry-v1",
            "created_at": iso_now(),
            "active_version": None,
            "versions": [],
        }
    return json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))


def save_registry(registry: Dict[str, Any]) -> None:
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    REGISTRY_PATH.write_text(json.dumps(registry, indent=2), encoding="utf-8")


def copy_artifacts(target: Path) -> List[Dict[str, Any]]:
    target.mkdir(parents=True, exist_ok=True)
    copied = []
    for source in ARTIFACTS:
        if not source.exists():
            copied.append({"source": rel(source), "status": "missing"})
            continue
        destination = target / source.name
        if source.is_dir():
            if destination.exists():
                shutil.rmtree(destination)
            shutil.copytree(source, destination)
        else:
            shutil.copy2(source, destination)
        copied.append(
            {
                "source": rel(source),
                "path": rel(destination),
                "size_bytes": destination.stat().st_size if destination.is_file() else None,
                "status": "copied",
            }
        )
    return copied


def read_metrics() -> Dict[str, Any]:
    metadata_path = MODEL_DIR / "model_metadata.json"
    if not metadata_path.exists():
        return {}
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    selected = metadata.get("performance", {}).get("selected_model", {})
    return {
        "model_version": metadata.get("model_version"),
        "dataset_size": metadata.get("dataset_size"),
        "threshold": selected.get("threshold"),
        "metrics": selected.get("metrics", {}),
    }


def promote(version: str, notes: str) -> Dict[str, Any]:
    registry = load_registry()
    target = MODEL_DIR / version
    copied = copy_artifacts(target)
    latest = MODEL_DIR / "latest"
    if latest.exists():
        shutil.rmtree(latest)
    shutil.copytree(target, latest)
    (latest / "ACTIVE_VERSION").write_text(version, encoding="utf-8")

    versions = [item for item in registry.get("versions", []) if item.get("version") != version]
    record = {
        "version": version,
        "registered_at": iso_now(),
        "path": rel(target),
        "latest_path": rel(latest),
        "notes": notes,
        "artifacts": copied,
        "metrics": read_metrics(),
    }
    versions.append(record)
    registry["versions"] = versions
    registry["active_version"] = version
    registry["updated_at"] = iso_now()
    save_registry(registry)
    write_registry_report(registry)
    return record


def rollback(version: str) -> Dict[str, Any]:
    registry = load_registry()
    target = MODEL_DIR / version
    if not target.exists():
        raise FileNotFoundError(f"Version {version} does not exist in {rel(MODEL_DIR)}")
    latest = MODEL_DIR / "latest"
    if latest.exists():
        shutil.rmtree(latest)
    shutil.copytree(target, latest)
    (latest / "ACTIVE_VERSION").write_text(version, encoding="utf-8")
    registry["active_version"] = version
    registry["updated_at"] = iso_now()
    save_registry(registry)
    write_registry_report(registry)
    return {"version": version, "latest_path": rel(latest), "status": "rolled_back"}


def write_registry_report(registry: Dict[str, Any]) -> Path:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Model Registry",
        "",
        f"- Active version: `{registry.get('active_version')}`",
        f"- Registry file: `{rel(REGISTRY_PATH)}`",
        "",
        "| Version | Registered | Dataset rows | F1 | Path |",
        "| --- | --- | ---: | ---: | --- |",
    ]
    for item in registry.get("versions", []):
        metrics = item.get("metrics", {})
        model_metrics = metrics.get("metrics", {})
        lines.append(
            f"| {item.get('version')} | {item.get('registered_at')} | "
            f"{metrics.get('dataset_size', 'unknown')} | {model_metrics.get('f1', 'unknown')} | "
            f"`{item.get('path')}` |"
        )
    lines.extend(
        [
            "",
            "## Rollback",
            "",
            "- Run `python scripts/mlops/03_model_registry.py rollback --version <version>` to restore a previous registered release into `models/latest`.",
            "- Flutter consumes bundled assets under `assets/ml_models`; after rollback, copy the desired TFLite/config assets from `models/latest` and rebuild the app.",
        ]
    )
    path = REPORT_DIR / "model_registry_report.md"
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    promote_parser = subparsers.add_parser("promote", help="Register and promote current artifacts.")
    promote_parser.add_argument("--version", required=True)
    promote_parser.add_argument("--notes", default="Promoted from current training artifacts.")

    rollback_parser = subparsers.add_parser("rollback", help="Restore a registered version into models/latest.")
    rollback_parser.add_argument("--version", required=True)

    subparsers.add_parser("list", help="Print registry JSON.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.command == "promote":
        result = promote(args.version, args.notes)
    elif args.command == "rollback":
        result = rollback(args.version)
    else:
        result = load_registry()
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
