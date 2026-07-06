# Root Cause And Explainability Report

- Generated at: `2026-06-14T07:22:17.585717Z`
- Status: `generated`
- Method: `SHAP when available, ExtraTrees feature contribution fallback otherwise`
- SHAP status: `computed`

## Global Feature Importance

| Feature | Importance | Direction |
| --- | ---: | --- |
| pollution_score | 0.311305 | higher risk when elevated |
| air_quality_score | 0.24114 | higher risk when elevated |
| global_risk_score | 0.204927 | higher risk when elevated |
| leak_probability_feature | 0.061695 | higher risk when reduced |
| domain_id | 0.055325 | higher risk when elevated |
| battery_pct | 0.030279 | higher risk when elevated |
| structural_stress_score | 0.029281 | higher risk when elevated |
| drought_score | 0.026789 | higher risk when elevated |
| packet_loss_rate | 0.015497 | higher risk when elevated |
| rssi_dbm | 0.012266 | higher risk when elevated |

## Example RCA Output

- Risk Score: `0.93`
- Primary Cause: `Pollution Score`
- Secondary Cause: `AIR Quality Score`
- Contributing Factors: `Global Risk Score, Leak Probability Feature, Domain ID`
- Recommended Action: Inspect building air-quality, smoke/gas sensors, and ventilation state.