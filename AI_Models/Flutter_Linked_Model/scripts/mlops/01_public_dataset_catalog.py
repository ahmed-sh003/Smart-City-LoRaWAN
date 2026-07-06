#!/usr/bin/env python3
"""Catalog and optionally acquire public SmartCity/IoT datasets.

This script is intentionally conservative: it records the largest useful open
datasets for the project domains, validates local external files, and only
downloads sources that are openly accessible from Python without credentials.
Authenticated portals such as Kaggle are included in the catalog with explicit
instructions so retraining runs are reproducible once credentials are provided.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List


ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT / "data" / "external"
REPORT_DIR = ROOT / "reports" / "mlops"


DATASETS: List[Dict[str, Any]] = [
    {
        "id": "uci_beijing_multisite_air_quality",
        "name": "Beijing Multi-Site Air Quality",
        "source": "UCI Machine Learning Repository",
        "url": "https://archive.ics.uci.edu/dataset/501/beijing%2Bmulti%2Bsite%2Bair%2Bquality%2Bdata",
        "license": "CC BY 4.0",
        "uci_id": 501,
        "direct_download_url": "https://archive.ics.uci.edu/static/public/501/beijing+multi+site+air+quality+data.zip",
        "domain_fit": ["building", "environment"],
        "row_estimate": 420768,
        "hardware_alignment": [
            "temperature",
            "humidity",
            "pressure",
            "rain",
            "airQuality",
        ],
        "status": "cataloged",
        "download_mode": "open_ucimlrepo",
    },
    {
        "id": "uci_air_quality_gas_multisensor",
        "name": "Air Quality Gas Multisensor",
        "source": "UCI Machine Learning Repository",
        "url": "https://archive.ics.uci.edu/dataset/360/air%2Bquality",
        "license": "research only on UCI page",
        "uci_id": 360,
        "direct_download_url": "https://archive.ics.uci.edu/static/public/360/air+quality.zip",
        "domain_fit": ["building"],
        "row_estimate": 9358,
        "hardware_alignment": [
            "MQ135 air quality",
            "MQ2/MQ5 gas proxy",
            "temperature",
            "humidity",
        ],
        "status": "cataloged",
        "download_mode": "open_ucimlrepo",
    },
    {
        "id": "uci_beijing_pm25",
        "name": "Beijing PM2.5",
        "source": "UCI Machine Learning Repository",
        "url": "https://archive.ics.uci.edu/dataset/381/beijing%2Bpm2%2B5%2Bdata",
        "license": "UCI listed dataset",
        "uci_id": 381,
        "direct_download_url": "https://archive.ics.uci.edu/static/public/381/beijing+pm2+5+data.zip",
        "domain_fit": ["building", "environment"],
        "row_estimate": 43824,
        "hardware_alignment": [
            "airQuality",
            "temperature",
            "humidity",
            "pressure",
        ],
        "status": "cataloged",
        "download_mode": "open_ucimlrepo",
    },
    {
        "id": "mendeley_bridge_vibration",
        "name": "Bridge Vibration Monitoring Dataset",
        "source": "Mendeley Data",
        "url": "https://data.mendeley.com/datasets/d3by55pjh7/2",
        "license": "CC BY 4.0",
        "doi": "10.17632/d3by55pjh7.2",
        "domain_fit": ["bridge"],
        "row_estimate": None,
        "hardware_alignment": [
            "vibration",
            "traffic/load proxy",
            "structural health monitoring",
        ],
        "status": "cataloged",
        "download_mode": "manual_or_api",
    },
    {
        "id": "kaggle_water_leak_dataset",
        "name": "Water Leak Dataset",
        "source": "Kaggle",
        "url": "https://www.kaggle.com/datasets/ziya07/water-leak-dataset",
        "license": "check Kaggle dataset page before use",
        "kaggle_slug": "ziya07/water-leak-dataset",
        "domain_fit": ["water"],
        "row_estimate": None,
        "hardware_alignment": [
            "leakStatus",
            "leakProbability",
            "soil moisture/leak proxy",
            "tank level proxy",
        ],
        "status": "requires_kaggle_credentials",
        "download_mode": "kaggle_api",
    },
    {
        "id": "kaggle_aging_bridge_shm",
        "name": "Aging Bridge SHM Time-Series Dataset",
        "source": "Kaggle",
        "url": "https://www.kaggle.com/datasets/programmer3/aging-bridge-shm-time-series-dataset",
        "license": "check Kaggle dataset page before use",
        "kaggle_slug": "programmer3/aging-bridge-shm-time-series-dataset",
        "domain_fit": ["bridge"],
        "row_estimate": 1340,
        "hardware_alignment": [
            "danger switches proxy",
            "bridge vibration/load proxy",
            "roadStatus/danger labels",
        ],
        "status": "requires_kaggle_credentials",
        "download_mode": "kaggle_api",
    },
]


def iso_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT)).replace("\\", "/")


def ensure_dirs() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)


def file_sha256(path: Path, chunk_size: int = 1024 * 1024) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(chunk_size), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_external_files() -> List[Dict[str, Any]]:
    files = []
    for path in sorted(DATA_DIR.rglob("*")):
        if not path.is_file():
            continue
        files.append(
            {
                "path": rel(path),
                "size_bytes": path.stat().st_size,
                "sha256": file_sha256(path),
            }
        )
    return files


def fetch_uci_dataset(dataset: Dict[str, Any]) -> Dict[str, Any]:
    try:
        from ucimlrepo import fetch_ucirepo
    except Exception as exc:
        return {
            "id": dataset["id"],
            "status": "skipped",
            "reason": f"ucimlrepo is not installed: {exc}",
        }

    import pandas as pd

    output_dir = DATA_DIR / dataset["id"]
    output_dir.mkdir(parents=True, exist_ok=True)
    try:
        bundle = fetch_ucirepo(id=int(dataset["uci_id"]))
        frames = []
        if getattr(bundle.data, "features", None) is not None:
            frames.append(bundle.data.features)
        if getattr(bundle.data, "targets", None) is not None:
            frames.append(bundle.data.targets)
        if not frames:
            return {
                "id": dataset["id"],
                "status": "failed",
                "reason": "ucimlrepo returned no feature or target frames",
            }
        frame = pd.concat(frames, axis=1)
        output_path = output_dir / "data.csv"
        frame.to_csv(output_path, index=False)
        metadata_path = output_dir / "metadata.json"
        metadata = {
            "id": dataset["id"],
            "source_url": dataset["url"],
            "downloaded_at": iso_now(),
            "rows": int(len(frame)),
            "columns": [str(col) for col in frame.columns],
        }
        metadata_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
        return {
            "id": dataset["id"],
            "status": "downloaded",
            "path": rel(output_path),
            "metadata": rel(metadata_path),
            "rows": int(len(frame)),
            "columns": int(len(frame.columns)),
        }
    except Exception as exc:
        return fetch_direct_archive(dataset, previous_error=str(exc))


def fetch_direct_archive(dataset: Dict[str, Any], previous_error: str) -> Dict[str, Any]:
    url = dataset.get("direct_download_url")
    if not url:
        return {
            "id": dataset["id"],
            "status": "failed",
            "reason": previous_error,
        }
    output_dir = DATA_DIR / dataset["id"]
    extracted_dir = output_dir / "extracted"
    output_dir.mkdir(parents=True, exist_ok=True)
    extracted_dir.mkdir(parents=True, exist_ok=True)
    archive_path = output_dir / "source.zip"
    try:
        urllib.request.urlretrieve(str(url), archive_path)
        if zipfile.is_zipfile(archive_path):
            extract_zip_recursive(archive_path, extracted_dir)
        extracted_files = [
            path for path in sorted(extracted_dir.rglob("*")) if path.is_file()
        ]
        csv_rows = 0
        for path in extracted_files:
            if path.suffix.lower() == ".csv":
                with path.open("r", encoding="utf-8", errors="ignore") as handle:
                    csv_rows += max(0, sum(1 for _ in handle) - 1)
        metadata_path = output_dir / "metadata.json"
        metadata = {
            "id": dataset["id"],
            "source_url": dataset["url"],
            "direct_download_url": url,
            "downloaded_at": iso_now(),
            "previous_import_error": previous_error,
            "archive": rel(archive_path),
            "files": [rel(path) for path in extracted_files],
            "csv_rows": csv_rows,
        }
        metadata_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
        return {
            "id": dataset["id"],
            "status": "downloaded_direct_archive",
            "path": rel(archive_path),
            "metadata": rel(metadata_path),
            "rows": csv_rows,
            "files": len(extracted_files),
            "import_fallback_reason": previous_error,
        }
    except Exception as exc:
        return {
            "id": dataset["id"],
            "status": "failed",
            "reason": f"{previous_error}; direct archive failed: {exc}",
        }


def extract_zip_recursive(archive_path: Path, extracted_dir: Path) -> None:
    pending = [(archive_path, extracted_dir)]
    seen = set()
    while pending:
        current_archive, target_dir = pending.pop()
        resolved = current_archive.resolve()
        if resolved in seen:
            continue
        seen.add(resolved)
        target_dir.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(current_archive) as archive:
            archive.extractall(target_dir)
        for nested in sorted(target_dir.rglob("*.zip")):
            nested_target = nested.with_suffix("")
            if nested.resolve() not in seen:
                pending.append((nested, nested_target))


def fetch_kaggle_dataset(dataset: Dict[str, Any]) -> Dict[str, Any]:
    venv_kaggle = Path(sys.executable).with_name("kaggle.exe")
    kaggle_cli = shutil.which("kaggle") or (str(venv_kaggle) if venv_kaggle.exists() else None)
    if not kaggle_cli:
        return {
            "id": dataset["id"],
            "status": "skipped",
            "reason": "Kaggle CLI not found. Install kaggle and configure kaggle.json.",
        }
    if not os.getenv("KAGGLE_USERNAME") and not (Path.home() / ".kaggle" / "kaggle.json").exists():
        return {
            "id": dataset["id"],
            "status": "skipped",
            "reason": "Kaggle credentials are not configured.",
        }
    return {
        "id": dataset["id"],
        "status": "manual",
        "reason": (
            "Credentials are available, but this script leaves large Kaggle downloads "
            "to the operator. Run: kaggle datasets download -d "
            f"{dataset['kaggle_slug']} -p {rel(DATA_DIR / dataset['id'])} --unzip"
        ),
    }


def acquire_datasets(download_open: bool, check_kaggle: bool) -> List[Dict[str, Any]]:
    results = []
    for dataset in DATASETS:
        mode = dataset["download_mode"]
        if mode == "open_ucimlrepo" and download_open:
            results.append(fetch_uci_dataset(dataset))
        elif mode == "kaggle_api" and check_kaggle:
            results.append(fetch_kaggle_dataset(dataset))
        else:
            results.append(
                {
                    "id": dataset["id"],
                    "status": "cataloged",
                    "reason": "download not requested for this source",
                }
            )
    return results


def write_catalog_report(
    generated_at: str,
    catalog_path: Path,
    acquisition_results: Iterable[Dict[str, Any]],
    external_files: Iterable[Dict[str, Any]],
) -> Path:
    lines = [
        "# Public Dataset Acquisition Report",
        "",
        f"- Generated at: `{generated_at}`",
        f"- Catalog: `{rel(catalog_path)}`",
        "",
        "## Catalog",
        "",
        "| Dataset | Source | Domains | Rows | Download mode | Status |",
        "| --- | --- | --- | ---: | --- | --- |",
    ]
    for dataset in DATASETS:
        domains = ", ".join(dataset["domain_fit"])
        rows = dataset["row_estimate"] if dataset["row_estimate"] is not None else "unknown"
        lines.append(
            f"| {dataset['name']} | {dataset['source']} | {domains} | {rows} | "
            f"{dataset['download_mode']} | {dataset['status']} |"
        )
    lines.extend(["", "## Acquisition Results", ""])
    for result in acquisition_results:
        detail = result.get("path") or result.get("reason") or result.get("status")
        lines.append(f"- `{result['id']}`: `{result['status']}` - {detail}")
    lines.extend(
        [
            "",
            "## Local External Data Validation",
            "",
        ]
    )
    local_files = list(external_files)
    if local_files:
        for item in local_files:
            lines.append(
                f"- `{item['path']}`: {item['size_bytes']} bytes, sha256 `{item['sha256'][:16]}...`"
            )
    else:
        lines.append("- No external dataset files are present yet.")
    lines.extend(
        [
            "",
            "## Merge Strategy",
            "",
            "- Map environmental datasets into building features: temperature, humidity, pressure, airQuality, smoke/gas proxies, rain.",
            "- Map bridge vibration/SHM datasets into bridge features: vibration/load proxies, danger labels, roadStatus risk labels.",
            "- Map water/leak datasets into water features: leakStatus, leakProbability, tank/pipe/moisture proxies.",
            "- Keep the SC1 packet feature order stable for Flutter/TFLite inference; external datasets only enrich offline training rows.",
        ]
    )
    path = REPORT_DIR / "dataset_acquisition_report.md"
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def run(args: argparse.Namespace) -> Dict[str, Any]:
    ensure_dirs()
    generated_at = iso_now()
    acquisition_results = acquire_datasets(
        download_open=args.download_open,
        check_kaggle=args.check_kaggle,
    )
    external_files = validate_external_files()
    payload = {
        "generated_at": generated_at,
        "datasets": DATASETS,
        "acquisition_results": acquisition_results,
        "external_files": external_files,
        "next_steps": [
            "Run with --download-open after installing ucimlrepo to fetch UCI datasets.",
            "Configure Kaggle credentials and run the listed Kaggle commands for authenticated datasets.",
            "Run scripts/data_pipeline/02_clean_and_engineer.py after placing external CSV files.",
        ],
    }
    catalog_path = DATA_DIR / "dataset_catalog.json"
    catalog_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    report_path = write_catalog_report(
        generated_at,
        catalog_path,
        acquisition_results,
        external_files,
    )
    payload["report"] = rel(report_path)
    catalog_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(json.dumps({"catalog": rel(catalog_path), "report": rel(report_path)}, indent=2))
    return payload


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--download-open",
        action="store_true",
        help="Download open UCI datasets using ucimlrepo when the dependency is installed.",
    )
    parser.add_argument(
        "--check-kaggle",
        action="store_true",
        help="Check whether Kaggle credentials are configured and print exact download commands.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    run(parse_args())
