# SmartCity Phase 2 MLOps Report

- Generated at: `2026-06-14T06:18:03.806343Z`
- Model version: `2026.06.13-prod`
- Overall status: `attention`
- Monitoring backend: `keras`

## Production Metrics

- Inference count: `62736`
- Average anomaly score: `0.058879`
- Per-sample latency: `0.066382` ms
- Precision: `1.0`
- Recall: `1.0`
- F1: `1.0`
- Calibration ECE: `0.001056`

## Drift Detection

- Overall drift: `high`
- Drifted features: `3`

| Feature | PSI | KS | Status |
| --- | ---: | ---: | --- |
| humidity_pct | 1.239472 | 0.143597 | high |
| battery_pct | 0.377907 | 0.177977 | high |
| temp_c | 0.112649 | 0.081611 | medium |
| air_humidity_pct | 0.04491 | 0.051327 | low |
| water_level_m | 0.034734 | 0.048279 | low |
| pipe_temp_c | 0.024129 | 0.036173 | low |
| air_temp_c | 0.018331 | 0.031062 | low |
| soil_temp_c | 0.017786 | 0.032051 | low |

## Explainability

- Method: `drift-aware proxy feature contribution`
- SHAP status: `not_run_by_default; install shap and run offline for exact SHAP values`

| Feature | Importance | Direction |
| --- | ---: | --- |
| air_humidity_pct | 1.360488 | higher risk when elevated |
| air_temp_c | 1.354088 | higher risk when elevated |
| soil_temp_c | 1.344408 | higher risk when elevated |
| ndvi_index | 1.325751 | higher risk when elevated |
| soil_moisture_pct | 1.299253 | higher risk when elevated |
| humidity_pct | 0.765054 | higher risk when reduced |
| temp_c | 0.738494 | higher risk when reduced |
| battery_pct | 0.668703 | higher risk when reduced |

## Model Registry And A/B Testing

- Active version: `v20260614-phase2`
- Registry path: `models/registry.json`
- A/B status: `baseline_only`
- Decision: Keep active model until a retrained candidate is registered.

## Recommendations

- Trigger retraining review because high feature drift is present.

## Flutter Asset

- Mobile UI reads `assets/ml_models/mlops_summary.json` to show production health, drift, metrics, and explanations.