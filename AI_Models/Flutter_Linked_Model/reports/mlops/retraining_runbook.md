# Production Retraining Runbook

- Generated at: `2026-06-14T06:17:31.105032Z`
- Mode: `dry_run`
- Target version: `v20260614-phase2`

## Pipeline Steps

| Step | Status | Purpose |
| --- | --- | --- |
| catalog_external_datasets | planned | Search/catalog public SmartCity, IoT, LPWAN, environmental, water, and SHM datasets. |
| generate_or_refresh_raw_telemetry | planned | Export Firebase telemetry or generate fallback synthetic telemetry. |
| clean_and_engineer_features | planned | Clean merged data and rebuild runtime/offline features. |
| train_models | planned | Train RF, XGBoost, LightGBM, CatBoost when available, and compact neural models. |
| convert_to_tflite | planned | Regenerate production Flutter TFLite assets. |
| validate_tflite | planned | Validate TFLite parity, latency, and threshold behavior. |
| monitoring_and_explainability | planned | Regenerate drift, monitoring, explainability, and Flutter MLOps summary artifacts. |

## Promotion Gates

- TFLite validation status must be `passed`.
- Live-window F1/recall must not regress from the active registry version.
- Drift status should be `low` or have an accepted investigation note.
- Flutter must load `assets/ml_models/model_config.json`, `production_model.tflite`, and `mlops_summary.json`.

## Rollback

- Use `python scripts/mlops/03_model_registry.py rollback --version <previous>`.
- Rebuild Flutter after restoring older TFLite/config assets if the mobile bundle was changed.