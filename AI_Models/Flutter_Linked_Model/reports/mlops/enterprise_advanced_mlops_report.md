# Advanced MLOps Report

- Generated at: `2026-06-14T07:22:17.585717Z`
- Feature drift status: `high`
- Concept drift status: `medium`
- Retraining triggered now: `True`

| Feature | PSI | KS | Jensen-Shannon | Status |
| --- | ---: | ---: | ---: | --- |
| packet_loss_rate | 0.103208 | 0.014175 | 0.004876 | medium |
| battery_pct | 0.082567 | 0.874171 | 0.152543 | high |
| rssi_dbm | 6.085586 | 0.490489 | 0.299505 | high |
| snr_db | 4.392122 | 0.526892 | 0.28172 | high |
| air_quality_score | 1.437849 | 0.501918 | 0.235354 | high |
| leak_probability_feature | 4.410294 | 0.827498 | 0.468057 | high |
| structural_stress_score | 2.558592 | 0.328433 | 0.130064 | high |
| global_risk_score | 0.979645 | 0.321837 | 0.154214 | high |

## Automatic Retraining Rules

- PSI > 0.25
- KS > 0.25
- Jensen-Shannon > 0.10
- F1 below threshold
- concept drift high