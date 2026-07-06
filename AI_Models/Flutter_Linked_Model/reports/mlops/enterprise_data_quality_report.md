# Enterprise Data Quality And Feature Store Report

- Generated at: `2026-06-14T07:22:17.585717Z`
- Rows: `608949`
- Columns: `38`
- Feature store: `data/processed/enterprise_feature_store.parquet`
- Duplicate timestamp/node/domain rows: `0`

## Impossible Value Checks

- `battery_pct_outside_0_100`: `0`
- `humidity_pct_outside_0_100`: `0`
- `snr_db_extreme`: `0`
- `rssi_dbm_extreme`: `0`
- `negative_pressure`: `0`
- `negative_flow`: `80`
- `negative_water_level`: `0`

## Outlier Method Comparison

| Method | Rows | Outliers | Rate | Notes |
| --- | ---: | ---: | ---: | --- |
| IQR | 608949 | 72034 | 0.118292 | Fast univariate method; useful for impossible sensor spikes. |
| Isolation Forest | 30000 | 5602 | 0.186733 | Multivariate method; selected for scalable production screening. |
| DBSCAN | 6000 | 163 | 0.027167 | Density method; useful offline but less stable across mixed domains. |

- Selected method: `Isolation Forest`