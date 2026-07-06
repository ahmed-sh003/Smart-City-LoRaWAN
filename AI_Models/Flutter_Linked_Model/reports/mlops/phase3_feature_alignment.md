# Phase 3 Feature Alignment

- Generated at: `2026-06-14T06:44:17.432323Z`
- Runtime feature count: `25`
- Flutter feature vector remains unchanged.

## Runtime Feature Order

1. `domain_id`
2. `pressure_bar`
3. `flow_rate_lpm`
4. `water_level_m`
5. `pipe_temp_c`
6. `leak_detected`
7. `vibration_hz`
8. `tilt_angle_deg`
9. `load_weight_ton`
10. `crack_index`
11. `temp_c`
12. `humidity_pct`
13. `co2_ppm`
14. `power_kwh`
15. `occupancy_count`
16. `smoke_level`
17. `soil_moisture_pct`
18. `soil_temp_c`
19. `air_temp_c`
20. `air_humidity_pct`
21. `irrigation_active`
22. `ndvi_index`
23. `battery_pct`
24. `rssi_dbm`
25. `snr_db`

## Defaults And Imputation

| Feature | Default | Real rows using default | Justification |
| --- | ---: | ---: | --- |
| `domain_id` | 0.0 | 0 | Derived from domain using the Phase 3 domain map. |
| `pressure_bar` | 0.0 | 9750 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `flow_rate_lpm` | 0.0 | 473949 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `water_level_m` | 0.0 | 473949 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `pipe_temp_c` | 0.0 | 473949 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `leak_detected` | 0.0 | 455621 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `vibration_hz` | 0.0 | 473949 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `tilt_angle_deg` | 0.0 | 473949 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `load_weight_ton` | 0.0 | 473949 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `crack_index` | 0.0 | 473949 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `temp_c` | 0.0 | 4637 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `humidity_pct` | 0.0 | 769 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `co2_ppm` | 0.0 | 0 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `power_kwh` | 0.0 | 473949 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `occupancy_count` | 0.0 | 473949 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `smoke_level` | 0.0 | 8668 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `soil_moisture_pct` | 0.0 | 473949 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `soil_temp_c` | 0.0 | 473949 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `air_temp_c` | 0.0 | 4637 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `air_humidity_pct` | 0.0 | 769 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `irrigation_active` | 0.0 | 473949 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `ndvi_index` | 0.0 | 473949 | 0 means not applicable or absent for this infrastructure domain; no target leakage is used. |
| `battery_pct` | 85.0 | 473949 | Neutral 85% default for external datasets with no battery telemetry. |
| `rssi_dbm` | -72.0 | 473949 | Neutral -72 dBm default for external datasets with no LoRa RSSI. |
| `snr_db` | 8.0 | 473949 | Neutral 8 dB default for external datasets with no LoRa SNR. |