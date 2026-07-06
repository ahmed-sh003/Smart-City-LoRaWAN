# Phase 3 Final Report

- Generated at: `2026-06-14T06:58:00Z`
- Model version: `v20260614-phase3-real-data`
- Status: complete

## Datasets Used

| Dataset | Rows used | Type | Domain mapping |
| --- | ---: | --- | --- |
| UCI Beijing Multi-Site Air Quality | 420,768 | real external, weak-labeled | gateway / gateway_environment |
| UCI Beijing PM2.5 | 43,824 | real external, weak-labeled | gateway / gateway_environment |
| UCI Air Quality Gas Multisensor | 9,357 | real external, weak-labeled | building / building_environment |
| Phase 1 synthetic telemetry | 135,000 | capped synthetic | bridge, water, building |

Kaggle water leak and bridge SHM datasets were not used because credentials/data files are not available. Mendeley bridge vibration data was cataloged only and was not used because it has not been downloaded into the project.

## Real Vs Synthetic Mix

- Unified real dataset: `data/processed/phase3_unified_real_dataset.csv`
- Training dataset: `data/processed/phase3_training_dataset.csv`
- Training rows: `608,949`
- Real rows: `473,949`
- Synthetic rows: `135,000`
- Real-data ratio: `77.83%`
- Weak-labeled real rows: `473,949`

Synthetic telemetry was added only to preserve bridge and water coverage because no real bridge/water datasets are present locally. Synthetic rows were capped and assigned lower sample weight during training.

## Feature Alignment

The Flutter/TFLite runtime vector remains exactly 25 features:

`domain_id`, `pressure_bar`, `flow_rate_lpm`, `water_level_m`, `pipe_temp_c`, `leak_detected`, `vibration_hz`, `tilt_angle_deg`, `load_weight_ton`, `crack_index`, `temp_c`, `humidity_pct`, `co2_ppm`, `power_kwh`, `occupancy_count`, `smoke_level`, `soil_moisture_pct`, `soil_temp_c`, `air_temp_c`, `air_humidity_pct`, `irrigation_active`, `ndvi_index`, `battery_pct`, `rssi_dbm`, `snr_db`.

External datasets do not contain LoRa battery/RSSI/SNR, bridge, or water sensors. Missing domain-specific features are set to neutral/not-applicable defaults and documented in `reports/mlops/phase3_feature_alignment.md`. The Keras normalization layer is embedded in `models/production_anomaly_model.keras`.

## Benchmark Table

| Model | F1 | Precision | Recall | ROC-AUC | Latency ms | Size estimate |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Logistic Regression | 0.750865 | 0.659186 | 0.872164 | 0.961135 | 0.000383 | 1,797 |
| Random Forest | 0.862571 | 0.798294 | 0.938107 | 0.989267 | 0.021855 | 32,427,327 |
| Gradient Boosting | 0.724009 | 0.576304 | 0.973520 | 0.985668 | 0.002104 | 396,813 |
| Extra Trees | 0.837998 | 0.762857 | 0.929558 | 0.984184 | 0.028266 | 46,156,182 |
| Small Neural Network | 0.891862 | 0.948302 | 0.841764 | 0.983882 | 0.079514 | 91,603 |

Real-only test metrics for the selected neural model:

- F1: `0.882301`
- Precision: `0.943414`
- Recall: `0.828623`
- ROC-AUC: `0.976776`

## Selected Model

The small neural network was selected for production because it is directly convertible to TensorFlow Lite, keeps the mobile asset compact, embeds preprocessing/normalization, and achieved the best production-ready balance among validation F1, real-data holdout behavior, latency, and mobile deployability.

Tree models performed well as offline baselines, but they are not shipped to Flutter because the app already uses a TFLite runtime path.

## TFLite Validation

- Report: `reports/mlops/phase3_tflite_validation_report.md`
- Status: `passed`
- Max absolute deviation: `0.00000095`
- Mean absolute deviation: `0.00000002`
- Accepted max deviation: `0.01`
- Production TFLite size: `21,380` bytes
- Alert scorer TFLite size: `13,680` bytes
- Per-sample TFLite latency in validation: `0.000152 ms`

Float32 TFLite was used for Phase 3 because float16 quantization missed the parity gate on the first run.

## Registry And Flutter Assets

Registered active version: `v20260614-phase3-real-data`

Updated assets:

- `assets/ml_models/production_model.tflite`
- `assets/ml_models/alert_scorer.tflite`
- `assets/ml_models/model_config.json`
- `assets/ml_models/mlops_summary.json`

Versioned model directory:

- `models/v20260614-phase3-real-data/`

The Flutter reports tab now reads the Phase 3 training object from `mlops_summary.json` and displays training rows, real rows, synthetic rows, feature count, and real-data mix.

## Flutter Verification

All requested Flutter commands passed:

- `flutter pub get`
- `flutter analyze --no-fatal-infos --no-fatal-warnings`
- `flutter test`
- `flutter build web`

The analyzer still prints existing project-wide info-level style/deprecation messages, but the requested non-fatal analyzer command exits successfully.

## Limitations

- Real external data currently covers environmental and air-quality telemetry only.
- Real bridge, road, water leak, tank, and pipe datasets were not available locally.
- All real labels are weak labels from documented thresholds, not field-confirmed incidents.
- UCI pollutant fields are mapped into the existing 25-feature mobile schema as environmental proxies; they are not exact hardware sensor duplicates.
- More Firebase field telemetry should be collected to replace synthetic bridge/water coverage.

## Next Steps

- Add authenticated Kaggle or manually downloaded Mendeley bridge/water datasets when credentials/data are available.
- Export confirmed Firebase incidents from the deployed hardware to replace weak labels.
- Add per-domain calibration checks before tightening production thresholds.
- Re-run `scripts/mlops/phase3_build_unified_dataset.py` and `scripts/mlops/phase3_train_deploy.py` after new real datasets are added.
