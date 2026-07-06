# LPWAN / LoRaWAN Model Training Report

- Generated at: `2026-06-14T13:17:40.625948Z`
- Rows available: `620000`
- Rows used for training: `150000`
- Real/enriched rows: `620000`
- Synthetic rows: `0`
- Real/enriched ratio: `1.0`
- Feature count: `17`

## Task Summary

| Task | Best Model | F1 Macro | Accuracy | TFLite Asset | SHAP |
| --- | --- | ---: | ---: | --- | --- |
| Packet Loss Predictor | XGBoost | 0.999966 | 0.99997 | `assets/ml_models/lpwan_packet_loss.tflite` | computed |
| Link Quality Classifier | XGBoost | 1.0 | 1.0 | `assets/ml_models/lpwan_link_quality.tflite` | computed |
| Gateway Health Classifier | Random Forest | 1.0 | 1.0 | `assets/ml_models/lpwan_gateway_health.tflite` | computed |
| Energy Risk Predictor | Random Forest | 0.999876 | 0.99997 | `assets/ml_models/lpwan_energy_risk.tflite` | computed |
| Optimal Spreading Factor Classifier | Gradient Boosting | 0.999922 | 0.999939 | `assets/ml_models/lpwan_optimal_sf.tflite` | computed |

## Benchmarks

### Packet Loss Predictor

| Model | Status | F1 Macro | Accuracy | ROC-AUC | Runtime |
| --- | --- | ---: | ---: | ---: | ---: |
| Random Forest | trained | 0.999933 | 0.999939 | 1.0 | 0.975 |
| Gradient Boosting | trained | 0.999933 | 0.999939 | 1.0 | 1.784 |
| Extra Trees | trained | 0.990481 | 0.991424 | 0.999655 | 0.837 |
| XGBoost | trained | 0.999966 | 0.99997 | 1.0 | 2.003 |
| LightGBM | trained | 0.999899 | 0.999909 | 0.999997 | 0.431 |
| CatBoost | trained | 0.999966 | 0.99997 | 1.0 | 1.039 |
| Neural Network/TFLite | trained | 0.993054 | 0.993758 | 0.999714 | 3.055 |

- Confusion matrix: `reports/lpwan/packet_loss_confusion_matrix.png`
- rocCurve: `reports/lpwan/packet_loss_roc_curve.png`
- precisionRecallCurve: `reports/lpwan/packet_loss_precision_recall_curve.png`
- SHAP/top drivers: snr_db (3.117013), packet_loss_rate (1.118215), crc_ok (0.826189), delivery_ratio (0.471076), rssi_dbm (0.455055)

### Link Quality Classifier

| Model | Status | F1 Macro | Accuracy | ROC-AUC | Runtime |
| --- | --- | ---: | ---: | ---: | ---: |
| Random Forest | trained | 0.999819 | 0.999909 | 1.0 | 1.018 |
| Gradient Boosting | trained | 0.997809 | 0.998576 | 0.999993 | 1.321 |
| Extra Trees | trained | 0.961814 | 0.968091 | 0.998714 | 1.24 |
| XGBoost | trained | 1.0 | 1.0 | 1.0 | 1.991 |
| LightGBM | trained | 0.99994 | 0.99997 | 0.999941 | 1.474 |
| CatBoost | trained | 0.99994 | 0.99997 | 1.0 | 2.643 |
| Neural Network/TFLite | trained | 0.959448 | 0.967879 | 0.998129 | 3.015 |

- Confusion matrix: `reports/lpwan/link_quality_confusion_matrix.png`
- rocCurve: `reports/lpwan/link_quality_roc_curve.png`
- precisionRecallCurve: `reports/lpwan/link_quality_precision_recall_curve.png`
- SHAP/top drivers: snr_db (2.266004), rssi_dbm (0.878068), distance_m (0.135893), crc_ok (0.052204), packet_received (0.016989)

### Gateway Health Classifier

| Model | Status | F1 Macro | Accuracy | ROC-AUC | Runtime |
| --- | --- | ---: | ---: | ---: | ---: |
| Random Forest | trained | 1.0 | 1.0 | 1.0 | 1.044 |
| Gradient Boosting | trained | 1.0 | 1.0 | 1.0 | 1.424 |
| Extra Trees | trained | 1.0 | 1.0 | 1.0 | 0.798 |
| Neural Network/TFLite | trained | 1.0 | 1.0 | 1.0 | 3.308 |

- Confusion matrix: `reports/lpwan/gateway_health_confusion_matrix.png`
- rocCurve: `reports/lpwan/gateway_health_roc_curve.png`
- precisionRecallCurve: `reports/lpwan/gateway_health_precision_recall_curve.png`
- SHAP/top drivers: obstacle_level (0.138968), delivery_ratio (0.092923), environment_code (0.084707), packet_loss_rate (0.081532), distance_m (0.039512)

### Energy Risk Predictor

| Model | Status | F1 Macro | Accuracy | ROC-AUC | Runtime |
| --- | --- | ---: | ---: | ---: | ---: |
| Random Forest | trained | 0.999876 | 0.99997 | 1.0 | 0.845 |
| Gradient Boosting | trained | 0.999381 | 0.999848 | 0.999995 | 0.413 |
| Extra Trees | trained | 0.950365 | 0.986758 | 0.999827 | 0.803 |
| XGBoost | trained | 0.998758 | 0.999697 | 0.999987 | 0.541 |
| LightGBM | trained | 0.989699 | 0.997455 | 0.999965 | 0.409 |
| CatBoost | trained | 0.998386 | 0.999606 | 0.999991 | 0.837 |
| Neural Network/TFLite | trained | 0.972853 | 0.993545 | 0.999464 | 3.129 |

- Confusion matrix: `reports/lpwan/energy_risk_confusion_matrix.png`
- rocCurve: `reports/lpwan/energy_risk_roc_curve.png`
- precisionRecallCurve: `reports/lpwan/energy_risk_precision_recall_curve.png`
- SHAP/top drivers: current_ma (0.246325), spreading_factor (0.131671), tx_power_dbm (0.063541), distance_m (0.017231), environment_code (0.014791)

### Optimal Spreading Factor Classifier

| Model | Status | F1 Macro | Accuracy | ROC-AUC | Runtime |
| --- | --- | ---: | ---: | ---: | ---: |
| Random Forest | trained | 0.999639 | 0.999667 | 1.0 | 1.201 |
| Gradient Boosting | trained | 0.999922 | 0.999939 | 1.0 | 2.75 |
| Extra Trees | trained | 0.972548 | 0.968515 | 0.998739 | 1.299 |
| Neural Network/TFLite | trained | 0.950643 | 0.957121 | 0.997738 | 3.319 |

- Confusion matrix: `reports/lpwan/optimal_sf_confusion_matrix.png`
- rocCurve: `reports/lpwan/optimal_sf_roc_curve.png`
- precisionRecallCurve: `reports/lpwan/optimal_sf_precision_recall_curve.png`
- SHAP/top drivers: snr_db (5.456415), rssi_dbm (1.289143), distance_m (0.001629), battery_pct (0.001191), spreading_factor (0.001123)

## Notes

- Neural Network/TFLite models are exported for Flutter/mobile deployment even when a tree model wins the offline benchmark.
- XGBoost, LightGBM, and CatBoost are benchmarked for selected tasks when installed; Random Forest, Gradient Boosting, Extra Trees, and Neural Network are always attempted.
- Labels are generated from documented LPWAN engineering rules, not manually annotated field incidents.