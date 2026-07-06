#!/usr/bin/env python3
"""Orchestrate the SmartCity production retraining pipeline."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List


ROOT = Path(__file__).resolve().parents[2]
REPORT_DIR = ROOT / "reports" / "mlops"


def iso_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT)).replace("\\", "/")


def pipeline_steps(version: str, download_open: bool, check_kaggle: bool, promote: bool) -> List[Dict[str, Any]]:
    python = sys.executable
    catalog_cmd = [
        python,
        "scripts/mlops/01_public_dataset_catalog.py",
    ]
    if download_open:
        catalog_cmd.append("--download-open")
    if check_kaggle:
        catalog_cmd.append("--check-kaggle")

    steps = [
        {
            "name": "catalog_external_datasets",
            "command": catalog_cmd,
            "purpose": "Search/catalog public SmartCity, IoT, LPWAN, environmental, water, and SHM datasets.",
        },
        {
            "name": "generate_or_refresh_raw_telemetry",
            "command": [python, "scripts/data_pipeline/01_generate_and_export.py"],
            "purpose": "Export Firebase telemetry or generate fallback synthetic telemetry.",
        },
        {
            "name": "clean_and_engineer_features",
            "command": [python, "scripts/data_pipeline/02_clean_and_engineer.py"],
            "purpose": "Clean merged data and rebuild runtime/offline features.",
        },
        {
            "name": "train_models",
            "command": [python, "scripts/ml/03_train_models.py"],
            "purpose": "Train RF, XGBoost, LightGBM, CatBoost when available, and compact neural models.",
        },
        {
            "name": "convert_to_tflite",
            "command": [python, "scripts/ml/04_convert_to_tflite.py"],
            "purpose": "Regenerate production Flutter TFLite assets.",
        },
        {
            "name": "validate_tflite",
            "command": [python, "scripts/ml/05_validate_tflite.py"],
            "purpose": "Validate TFLite parity, latency, and threshold behavior.",
        },
        {
            "name": "monitoring_and_explainability",
            "command": [python, "scripts/mlops/02_monitoring_and_explainability.py"],
            "purpose": "Regenerate drift, monitoring, explainability, and Flutter MLOps summary artifacts.",
        },
    ]
    if promote:
        steps.append(
            {
                "name": "promote_to_registry",
                "command": [
                    python,
                    "scripts/mlops/03_model_registry.py",
                    "promote",
                    "--version",
                    version,
                    "--notes",
                    "Promoted by retraining pipeline.",
                ],
                "purpose": "Version the retrained artifacts and update models/latest.",
            }
        )
    return steps


def run_step(step: Dict[str, Any], execute: bool) -> Dict[str, Any]:
    started = time.time()
    if not execute:
        return {
            **step,
            "status": "planned",
            "runtime_seconds": 0,
        }
    try:
        completed = subprocess.run(
            step["command"],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        return {
            **step,
            "status": "passed" if completed.returncode == 0 else "failed",
            "returncode": completed.returncode,
            "stdout_tail": completed.stdout[-4000:],
            "stderr_tail": completed.stderr[-4000:],
            "runtime_seconds": round(time.time() - started, 3),
        }
    except Exception as exc:
        return {
            **step,
            "status": "failed",
            "reason": str(exc),
            "runtime_seconds": round(time.time() - started, 3),
        }


def write_runbook(report: Dict[str, Any]) -> Path:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Production Retraining Runbook",
        "",
        f"- Generated at: `{report['generated_at']}`",
        f"- Mode: `{report['mode']}`",
        f"- Target version: `{report['target_version']}`",
        "",
        "## Pipeline Steps",
        "",
        "| Step | Status | Purpose |",
        "| --- | --- | --- |",
    ]
    for step in report["steps"]:
        lines.append(f"| {step['name']} | {step['status']} | {step['purpose']} |")
    lines.extend(
        [
            "",
            "## Promotion Gates",
            "",
            "- TFLite validation status must be `passed`.",
            "- Live-window F1/recall must not regress from the active registry version.",
            "- Drift status should be `low` or have an accepted investigation note.",
            "- Flutter must load `assets/ml_models/model_config.json`, `production_model.tflite`, and `mlops_summary.json`.",
            "",
            "## Rollback",
            "",
            "- Use `python scripts/mlops/03_model_registry.py rollback --version <previous>`.",
            "- Rebuild Flutter after restoring older TFLite/config assets if the mobile bundle was changed.",
        ]
    )
    path = REPORT_DIR / "retraining_runbook.md"
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def run(args: argparse.Namespace) -> Dict[str, Any]:
    steps = pipeline_steps(
        version=args.version,
        download_open=args.download_open,
        check_kaggle=args.check_kaggle,
        promote=args.promote,
    )
    executed = []
    for step in steps:
        result = run_step(step, execute=args.execute)
        executed.append(result)
        if result["status"] == "failed" and args.stop_on_failure:
            break
    report = {
        "generated_at": iso_now(),
        "mode": "execute" if args.execute else "dry_run",
        "target_version": args.version,
        "steps": executed,
    }
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    json_path = REPORT_DIR / "retraining_pipeline.json"
    json_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    runbook_path = write_runbook(report)
    print(json.dumps({"report": rel(json_path), "runbook": rel(runbook_path)}, indent=2))
    return report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", default=datetime.now().strftime("v%Y%m%d%H%M"))
    parser.add_argument("--execute", action="store_true", help="Run the pipeline. Default is a dry run.")
    parser.add_argument("--promote", action="store_true", help="Promote artifacts after successful monitoring.")
    parser.add_argument("--download-open", action="store_true", help="Download open UCI datasets during catalog step.")
    parser.add_argument("--check-kaggle", action="store_true", help="Check Kaggle credential state during catalog step.")
    parser.add_argument("--stop-on-failure", action="store_true", default=True)
    return parser.parse_args()


if __name__ == "__main__":
    run(parse_args())
