# Final AI Deployment Report

Generated: 2026-06-13

## Deployment Status

The production AI pipeline is trained, converted, validated, and wired into Flutter. Native Flutter builds load `assets/ml_models/production_model.tflite` when the TensorFlow Lite runtime is available. Flutter web uses the deterministic fallback path because `tflite_flutter` does not provide a web interpreter.

## Model Architecture

- Production anomaly model: compact Keras dense neural network with embedded normalization.
- Input contract: flat runtime tensor `[1, 25]`.
- Output: sigmoid anomaly score `[1, 1]`.
- Quantization: float16 weights with float32 input/output.
- Alert scorer: Keras multiclass dense classifier converted to TFLite, output `[1, 5]`.
- Signal predictor: RandomForestRegressor artifact retained at `models/signal_predictor.pkl` for offline/server use.

## Dataset And Features

- Raw generated telemetry: 420,480 rows.
- Clean training dataset: 418,243 rows.
- Splits: 292,770 train, 62,736 validation, 62,737 test.
- Runtime feature count: 25.
- Domains: water, bridge, building, agriculture.
- Domain IDs: water=0, bridge=1, building=2, agriculture=3.

## Training Metrics

- Selected production model: Dense Neural Network.
- Threshold: 0.35.
- Test accuracy: 1.000000.
- Test precision: 1.000000.
- Test recall: 1.000000.
- Test F1: 1.000000.
- Test AUC ROC: 1.000000.
- Alert scorer accuracy: 0.997896.
- Alert scorer macro F1: 0.988972.
- Signal predictor MAE: 2.701394.
- Signal predictor RMSE: 4.514340.

## TFLite Validation

- Validation sample size: 2,048 rows.
- Keras vs TFLite max absolute deviation: 0.00096935.
- Mean absolute deviation: 0.00000437.
- Accepted max absolute deviation: 0.01000000.
- TFLite accuracy: 1.000000.
- TFLite precision: 1.000000.
- TFLite recall: 1.000000.
- TFLite F1: 1.000000.
- Production model size: 9,668 bytes.
- Alert scorer size: 8,452 bytes.
- Measured per-sample CPU latency: 0.0019 ms.

## Flutter Integration

- `AiInferenceService` now builds the same 25-feature runtime vector used during training.
- `domain_id` is injected from `model_config.json`.
- Native `AiTfliteBackend` loads the production anomaly model and returns the model sigmoid score directly.
- Heuristic scoring remains only as graceful degradation for web or missing desktop runtime, and for explanations/risk factors.
- Placeholder anomaly and maintenance `.tflite` assets were removed from the bundled asset list and deleted from `assets/ml_models`.
- Windows/Linux CMake hooks are ready to bundle desktop TFLite C runtimes from `blobs/`.

## Assets Generated

- `model/production_model.tflite`
- `model/alert_scorer.tflite`
- `assets/ml_models/production_model.tflite`
- `assets/ml_models/alert_scorer.tflite`
- `assets/ml_models/model_config.json`
- `models/production_anomaly_model.keras`
- `models/alert_scorer.keras`
- `models/signal_predictor.pkl`
- `models/validation_sample.npz`

## Reports Generated

- `reports/model_training_report.md`
- `reports/step_3_report.json`
- `reports/step_4_report.json`
- `reports/tflite_validation_report.md`
- `reports/tflite_validation_report.json`
- `reports/final_ai_deployment_report.md`

## Verification

- Python imports and ML environment validated in `.venv_ai_win`.
- `python -m py_compile scripts/ml/04_convert_to_tflite.py scripts/ml/05_validate_tflite.py`: passed.
- `python scripts/ml/04_convert_to_tflite.py`: passed.
- `python scripts/ml/05_validate_tflite.py`: passed.
- `flutter pub get`: passed.
- `flutter analyze --no-fatal-infos --no-fatal-warnings`: passed.
- `flutter test`: passed.
- `flutter build web`: passed.
- Browser smoke test on `http://127.0.0.1:5200/`: passed, demo dashboard and AI Insights action rendered with no browser console errors.

## Remaining Limitations

- The current dataset is synthetic. Real field telemetry should be used for recalibration before operational deployment.
- Flutter web cannot execute `tflite_flutter`; it intentionally uses fallback scoring.
- Desktop native builds require the TensorFlow Lite C runtime in `blobs/`, matching the `tflite_flutter` desktop setup guidance: https://github.com/tensorflow/flutter-tflite#important-initial-setup--add-dynamic-libraries-to-your-app
- The desktop runtime DLL/SO was not present locally, so I added guarded load behavior and CMake bundling hooks instead of pulling an unsigned third-party binary.

## Future Improvements

- Train a compact TFLite-native maintenance predictor instead of keeping the RandomForest regressor server-side.
- Add a native alert-scorer inference path in Flutter using `alert_scorer.tflite`.
- Add field-data drift monitoring and threshold recalibration.
- Add an integration test on Android or iOS hardware to confirm device-side interpreter loading.
