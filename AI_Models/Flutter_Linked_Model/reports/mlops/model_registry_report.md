# Model Registry

- Active version: `v20260614-phase2`
- Registry file: `models/registry.json`

| Version | Registered | Dataset rows | F1 | Path |
| --- | --- | ---: | ---: | --- |
| v20260614-phase2 | 2026-06-14T06:17:52.945290Z | 418243 | 1.0 | `models/v20260614-phase2` |

## Rollback

- Run `python scripts/mlops/03_model_registry.py rollback --version <version>` to restore a previous registered release into `models/latest`.
- Flutter consumes bundled assets under `assets/ml_models`; after rollback, copy the desired TFLite/config assets from `models/latest` and rebuild the app.