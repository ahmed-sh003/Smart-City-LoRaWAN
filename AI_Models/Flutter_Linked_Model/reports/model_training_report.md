# SmartCity AI Model Training Report

- Generated at: `2026-06-13T16:42:57.286934Z`
- Model version: `2026.06.13-prod`
- Dataset size: `418243` rows
- Train size: `292770` rows
- Validation size: `62736` rows
- Test size: `62737` rows
- Feature count: `25`
- Selected model type: `Dense Neural Network`
- Training duration: `158.014` seconds

## Selected Model Metrics

- Accuracy: `1.0`
- Precision: `1.0`
- Recall: `1.0`
- F1: `1.0`
- AUC-ROC: `1.0`
- Threshold: `0.35`

## Confusion Matrix

| Actual / Predicted | Normal | Anomaly |
| --- | ---: | ---: |
| Normal | 59101 | 0 |
| Anomaly | 0 | 3636 |

## Model Comparison

| Model | Accuracy | F1 | AUC-ROC | Runtime (s) | Mobile Suitability |
| --- | ---: | ---: | ---: | ---: | --- |
| Random Forest | 0.999984 | 0.999869 | 1.0 | 2.354 | server-side/offline artifact; not directly TFLite deployable |
| Gradient Boosting | 0.999904 | 0.999214 | 1.0 | 99.79 | server-side/offline artifact; not directly TFLite deployable |
| XGBoost | 0.999936 | 0.999476 | 1.0 | 0.892 | server-side/offline artifact; not directly TFLite deployable |
| LightGBM | 0.999936 | 0.999476 | 1.0 | 2.194 | server-side/offline artifact; not directly TFLite deployable |
| Neural Network (selected) | 1.0 | 1.0 | 1.0 | 6.282 | selected: compact dense Keras model with embedded normalization; directly convertible to TFLite |

## Regression Metrics

- Signal predictor MAE: `2.701394`
- Signal predictor RMSE: `4.51434`
- Signal predictor max absolute error: `47.432622`

## Architecture Choice

A compact dense neural network was selected for production deployment because it is directly convertible to TensorFlow Lite, has embedded normalization, has a small memory footprint, and avoids shipping tree-ensemble runtimes inside the Flutter app.