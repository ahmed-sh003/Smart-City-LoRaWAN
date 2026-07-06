# Phase 3 Model Benchmark

- Generated at: `2026-06-14T06:53:12.820580Z`
- Training rows: `608949`
- Real rows: `473949`
- Synthetic rows: `135000`

| Model | Status | F1 | Precision | Recall | ROC-AUC | Latency ms | Size bytes | Notes |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Logistic Regression | trained | 0.750865 | 0.659186 | 0.872164 | 0.961135 | 0.000383 | 1797 | server/offline benchmark; not selected for direct Flutter TFLite deployment |
| Random Forest | trained | 0.862571 | 0.798294 | 0.938107 | 0.989267 | 0.021855 | 32427327 | server/offline benchmark; not selected for direct Flutter TFLite deployment |
| Gradient Boosting | trained | 0.724009 | 0.576304 | 0.97352 | 0.985668 | 0.002104 | 396813 | server/offline benchmark; not selected for direct Flutter TFLite deployment |
| Extra Trees | trained | 0.837998 | 0.762857 | 0.929558 | 0.984184 | 0.028266 | 46156182 | server/offline benchmark; not selected for direct Flutter TFLite deployment |
| Small Neural Network | trained | 0.891862 | 0.948302 | 0.841764 | 0.983882 | 0.079514 | 91603 | selected for TFLite |

## Selection

The small neural network is selected for production because it is the only benchmarked model with a direct TensorFlow Lite deployment path, compact asset size, embedded normalization, strong validation F1, and acceptable real-data holdout behavior. Tree models remain useful offline comparisons but are not shipped to Flutter.

## Real-Only Test Metrics

- F1: `0.882301`
- Precision: `0.943414`
- Recall: `0.828623`
- ROC-AUC: `0.976776`