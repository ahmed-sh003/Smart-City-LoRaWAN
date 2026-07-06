# Phase 3 Data Inventory

- Generated at: `2026-06-14T06:42:35.660500Z`
- Files inspected: `33`

| Path | Size bytes | Rows | Column count |
| --- | ---: | ---: | ---: |
| `data/raw/alerts_history.csv` | 4984235 | 27318 | 9 |
| `data/raw/domains.csv` | 581 | 5 | 5 |
| `data/raw/gateways.csv` | 8621362 | 105120 | 10 |
| `data/raw/labeled_anomalies.csv` | 25124774 | 420480 | 6 |
| `data/raw/nodes_status.csv` | 461 | 4 | 9 |
| `data/raw/nodes_telemetry.csv` | 53105997 | 420480 | 29 |
| `data/processed/class_distribution.json` | 76 |  | 0 |
| `data/processed/clean_telemetry_all.csv` | 53450194 | 418243 | 29 |
| `data/processed/feature_metadata.json` | 33692 |  | 0 |
| `data/processed/features_engineered.csv` | 364563991 | 418243 | 294 |
| `data/external/dataset_catalog.json` | 12037 |  | 0 |
| `data/external/uci_air_quality_gas_multisensor/data.csv` | 756065 | 9357 | 15 |
| `data/external/uci_air_quality_gas_multisensor/metadata.json` | 453 |  | 0 |
| `data/external/uci_beijing_multisite_air_quality/extracted/2A2478DC-8517-4490-9FA7-36F9A7A542BE.JPG` | 158758 |  | 0 |
| `data/external/uci_beijing_multisite_air_quality/extracted/data.csv` | 37769 | 503 | 7 |
| `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Aotizhongxin_20130301-20170228.csv` | 2835916 | 35064 | 18 |
| `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Changping_20130301-20170228.csv` | 2722295 | 35064 | 18 |
| `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Dingling_20130301-20170228.csv` | 2675856 | 35064 | 18 |
| `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Dongsi_20130301-20170228.csv` | 2636684 | 35064 | 18 |
| `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Guanyuan_20130301-20170228.csv` | 2695860 | 35064 | 18 |
| `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Gucheng_20130301-20170228.csv` | 2654625 | 35064 | 18 |
| `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Huairou_20130301-20170228.csv` | 2641027 | 35064 | 18 |
| `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Nongzhanguan_20130301-20170228.csv` | 2839705 | 35064 | 18 |
| `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Shunyi_20130301-20170228.csv` | 2620654 | 35064 | 18 |
| `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Tiantan_20130301-20170228.csv` | 2655061 | 35064 | 18 |
| `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Wanliu_20130301-20170228.csv` | 2659544 | 35064 | 18 |
| `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Wanshouxigong_20130301-20170228.csv` | 2871076 | 35064 | 18 |
| `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228.zip` | 7959991 |  | 0 |
| `data/external/uci_beijing_multisite_air_quality/extracted/test.csv` | 35186 | 503 | 7 |
| `data/external/uci_beijing_multisite_air_quality/metadata.json` | 3087 |  | 0 |
| `data/external/uci_beijing_multisite_air_quality/source.zip` | 8192212 |  | 0 |
| `data/external/uci_beijing_pm25/data.csv` | 2013605 | 43824 | 12 |
| `data/external/uci_beijing_pm25/metadata.json` | 359 |  | 0 |

## Schemas

### `data/raw/alerts_history.csv`

`alert_id`, `timestamp`, `domain`, `node_id`, `severity`, `title`, `message`, `resolved`, `source`

### `data/raw/domains.csv`

`domain`, `display_name`, `node_count`, `primary_sensor`, `description`

### `data/raw/gateways.csv`

`timestamp`, `gateway_id`, `connected_nodes`, `packet_loss_pct`, `uptime_hrs`, `avg_rssi`, `avg_snr`, `data_volume_mb`, `is_anomaly`, `anomaly_type`

### `data/raw/labeled_anomalies.csv`

`timestamp`, `node_id`, `domain`, `is_anomaly`, `anomaly_type`, `label_type`

### `data/raw/nodes_status.csv`

`node_id`, `domain`, `online`, `battery_pct`, `rssi_dbm`, `snr_db`, `last_seen`, `firmware_version`, `health_state`

### `data/raw/nodes_telemetry.csv`

`timestamp`, `node_id`, `domain`, `pressure_bar`, `flow_rate_lpm`, `water_level_m`, `pipe_temp_c`, `leak_detected`, `vibration_hz`, `tilt_angle_deg`, `load_weight_ton`, `crack_index`, `temp_c`, `humidity_pct`, `co2_ppm`, `power_kwh`, `occupancy_count`, `smoke_level`, `soil_moisture_pct`, `soil_temp_c`, `air_temp_c`, `air_humidity_pct`, `irrigation_active`, `ndvi_index`, `battery_pct`, `rssi_dbm`, `snr_db`, `is_anomaly`, `anomaly_type`

### `data/processed/clean_telemetry_all.csv`

`timestamp`, `node_id`, `domain`, `pressure_bar`, `flow_rate_lpm`, `water_level_m`, `pipe_temp_c`, `leak_detected`, `vibration_hz`, `tilt_angle_deg`, `load_weight_ton`, `crack_index`, `temp_c`, `humidity_pct`, `co2_ppm`, `power_kwh`, `occupancy_count`, `smoke_level`, `soil_moisture_pct`, `soil_temp_c`, `air_temp_c`, `air_humidity_pct`, `irrigation_active`, `ndvi_index`, `battery_pct`, `rssi_dbm`, `snr_db`, `is_anomaly`, `anomaly_type`

### `data/processed/features_engineered.csv`

`timestamp`, `node_id`, `domain`, `pressure_bar`, `flow_rate_lpm`, `water_level_m`, `pipe_temp_c`, `leak_detected`, `vibration_hz`, `tilt_angle_deg`, `load_weight_ton`, `crack_index`, `temp_c`, `humidity_pct`, `co2_ppm`, `power_kwh`, `occupancy_count`, `smoke_level`, `soil_moisture_pct`, `soil_temp_c`, `air_temp_c`, `air_humidity_pct`, `irrigation_active`, `ndvi_index`, `battery_pct`, `rssi_dbm`, `snr_db`, `is_anomaly`, `anomaly_type`, `timestamp_unix`, `hour`, `day_of_week`, `month`, `is_weekend`, `is_ramadan`, `time_since_last_reading_min`, `is_peak_hour`, `soil_moisture_pct_lag_1`, `soil_moisture_pct_lag_6`, `soil_moisture_pct_lag_12`, `soil_moisture_pct_lag_24`, `soil_moisture_pct_rolling_60m_mean`, `soil_moisture_pct_rolling_60m_std`, `soil_moisture_pct_rolling_60m_min`, `soil_moisture_pct_rolling_60m_max`, `soil_moisture_pct_rolling_60m_trend`, `soil_moisture_pct_rolling_360m_mean`, `soil_moisture_pct_rolling_360m_std`, `soil_moisture_pct_rolling_360m_min`, `soil_moisture_pct_rolling_360m_max`, `soil_moisture_pct_rolling_360m_trend`, `soil_moisture_pct_rolling_1440m_mean`, `soil_moisture_pct_rolling_1440m_std`, `soil_moisture_pct_rolling_1440m_min`, `soil_moisture_pct_rolling_1440m_max`, `soil_moisture_pct_rolling_1440m_trend`, `air_temp_c_lag_1`, `air_temp_c_lag_6`, `air_temp_c_lag_12`, `air_temp_c_lag_24`, `air_temp_c_rolling_60m_mean`, `air_temp_c_rolling_60m_std`, `air_temp_c_rolling_60m_min`, `air_temp_c_rolling_60m_max`, `air_temp_c_rolling_60m_trend`, `air_temp_c_rolling_360m_mean`, `air_temp_c_rolling_360m_std`, `air_temp_c_rolling_360m_min`, `air_temp_c_rolling_360m_max`, `air_temp_c_rolling_360m_trend`, `air_temp_c_rolling_1440m_mean`, `air_temp_c_rolling_1440m_std`, `air_temp_c_rolling_1440m_min`, `air_temp_c_rolling_1440m_max`, `air_temp_c_rolling_1440m_trend`, `air_humidity_pct_lag_1`, `air_humidity_pct_lag_6`, `air_humidity_pct_lag_12`, `air_humidity_pct_lag_24`, `air_humidity_pct_rolling_60m_mean`, `air_humidity_pct_rolling_60m_std`, `air_humidity_pct_rolling_60m_min`, `air_humidity_pct_rolling_60m_max`, `air_humidity_pct_rolling_60m_trend`, `air_humidity_pct_rolling_360m_mean`, `air_humidity_pct_rolling_360m_std`, `air_humidity_pct_rolling_360m_min`, `air_humidity_pct_rolling_360m_max`, `air_humidity_pct_rolling_360m_trend`, `air_humidity_pct_rolling_1440m_mean`, `air_humidity_pct_rolling_1440m_std`, `air_humidity_pct_rolling_1440m_min`, `air_humidity_pct_rolling_1440m_max`, `air_humidity_pct_rolling_1440m_trend`, `evapotranspiration_index`, `irrigation_efficiency`, `link_quality_score`, `signal_stability`, `label_type`, `vibration_hz_lag_1`, `vibration_hz_lag_6`, `vibration_hz_lag_12`, `vibration_hz_lag_24`, `vibration_hz_rolling_60m_mean`, `vibration_hz_rolling_60m_std`, `vibration_hz_rolling_60m_min`, `vibration_hz_rolling_60m_max`, `vibration_hz_rolling_60m_trend`, `vibration_hz_rolling_360m_mean`, `vibration_hz_rolling_360m_std`, `vibration_hz_rolling_360m_min`, `vibration_hz_rolling_360m_max`, `vibration_hz_rolling_360m_trend`, `vibration_hz_rolling_1440m_mean`, `vibration_hz_rolling_1440m_std`, `vibration_hz_rolling_1440m_min`, `vibration_hz_rolling_1440m_max`, `vibration_hz_rolling_1440m_trend`, `tilt_angle_deg_lag_1`, `tilt_angle_deg_lag_6`, `tilt_angle_deg_lag_12`, `tilt_angle_deg_lag_24`, `tilt_angle_deg_rolling_60m_mean`, `tilt_angle_deg_rolling_60m_std`, `tilt_angle_deg_rolling_60m_min`, `tilt_angle_deg_rolling_60m_max`, `tilt_angle_deg_rolling_60m_trend`, `tilt_angle_deg_rolling_360m_mean`, `tilt_angle_deg_rolling_360m_std`, `tilt_angle_deg_rolling_360m_min`, `tilt_angle_deg_rolling_360m_max`, `tilt_angle_deg_rolling_360m_trend`, `tilt_angle_deg_rolling_1440m_mean`, `tilt_angle_deg_rolling_1440m_std`, `tilt_angle_deg_rolling_1440m_min`, `tilt_angle_deg_rolling_1440m_max`, `tilt_angle_deg_rolling_1440m_trend`, `load_weight_ton_lag_1`, `load_weight_ton_lag_6`, `load_weight_ton_lag_12`, `load_weight_ton_lag_24`, `load_weight_ton_rolling_60m_mean`, `load_weight_ton_rolling_60m_std`, `load_weight_ton_rolling_60m_min`, `load_weight_ton_rolling_60m_max`, `load_weight_ton_rolling_60m_trend`, `load_weight_ton_rolling_360m_mean`, `load_weight_ton_rolling_360m_std`, `load_weight_ton_rolling_360m_min`, `load_weight_ton_rolling_360m_max`, `load_weight_ton_rolling_360m_trend`, `load_weight_ton_rolling_1440m_mean`, `load_weight_ton_rolling_1440m_std`, `load_weight_ton_rolling_1440m_min`, `load_weight_ton_rolling_1440m_max`, `load_weight_ton_rolling_1440m_trend`, `vibration_energy`, `structural_stress_index`, `temp_c_lag_1`, `temp_c_lag_6`, `temp_c_lag_12`, `temp_c_lag_24`, `temp_c_rolling_60m_mean`, `temp_c_rolling_60m_std`, `temp_c_rolling_60m_min`, `temp_c_rolling_60m_max`, `temp_c_rolling_60m_trend`, `temp_c_rolling_360m_mean`, `temp_c_rolling_360m_std`, `temp_c_rolling_360m_min`, `temp_c_rolling_360m_max`, `temp_c_rolling_360m_trend`, `temp_c_rolling_1440m_mean`, `temp_c_rolling_1440m_std`, `temp_c_rolling_1440m_min`, `temp_c_rolling_1440m_max`, `temp_c_rolling_1440m_trend`, `humidity_pct_lag_1`, `humidity_pct_lag_6`, `humidity_pct_lag_12`, `humidity_pct_lag_24`, `humidity_pct_rolling_60m_mean`, `humidity_pct_rolling_60m_std`, `humidity_pct_rolling_60m_min`, `humidity_pct_rolling_60m_max`, `humidity_pct_rolling_60m_trend`, `humidity_pct_rolling_360m_mean`, `humidity_pct_rolling_360m_std`, `humidity_pct_rolling_360m_min`, `humidity_pct_rolling_360m_max`, `humidity_pct_rolling_360m_trend`, `humidity_pct_rolling_1440m_mean`, `humidity_pct_rolling_1440m_std`, `humidity_pct_rolling_1440m_min`, `humidity_pct_rolling_1440m_max`, `humidity_pct_rolling_1440m_trend`, `co2_ppm_lag_1`, `co2_ppm_lag_6`, `co2_ppm_lag_12`, `co2_ppm_lag_24`, `co2_ppm_rolling_60m_mean`, `co2_ppm_rolling_60m_std`, `co2_ppm_rolling_60m_min`, `co2_ppm_rolling_60m_max`, `co2_ppm_rolling_60m_trend`, `co2_ppm_rolling_360m_mean`, `co2_ppm_rolling_360m_std`, `co2_ppm_rolling_360m_min`, `co2_ppm_rolling_360m_max`, `co2_ppm_rolling_360m_trend`, `co2_ppm_rolling_1440m_mean`, `co2_ppm_rolling_1440m_std`, `co2_ppm_rolling_1440m_min`, `co2_ppm_rolling_1440m_max`, `co2_ppm_rolling_1440m_trend`, `power_kwh_lag_1`, `power_kwh_lag_6`, `power_kwh_lag_12`, `power_kwh_lag_24`, `power_kwh_rolling_60m_mean`, `power_kwh_rolling_60m_std`, `power_kwh_rolling_60m_min`, `power_kwh_rolling_60m_max`, `power_kwh_rolling_60m_trend`, `power_kwh_rolling_360m_mean`, `power_kwh_rolling_360m_std`, `power_kwh_rolling_360m_min`, `power_kwh_rolling_360m_max`, `power_kwh_rolling_360m_trend`, `power_kwh_rolling_1440m_mean`, `power_kwh_rolling_1440m_std`, `power_kwh_rolling_1440m_min`, `power_kwh_rolling_1440m_max`, `power_kwh_rolling_1440m_trend`, `comfort_index`, `pressure_bar_lag_1`, `pressure_bar_lag_6`, `pressure_bar_lag_12`, `pressure_bar_lag_24`, `pressure_bar_rolling_60m_mean`, `pressure_bar_rolling_60m_std`, `pressure_bar_rolling_60m_min`, `pressure_bar_rolling_60m_max`, `pressure_bar_rolling_60m_trend`, `pressure_bar_rolling_360m_mean`, `pressure_bar_rolling_360m_std`, `pressure_bar_rolling_360m_min`, `pressure_bar_rolling_360m_max`, `pressure_bar_rolling_360m_trend`, `pressure_bar_rolling_1440m_mean`, `pressure_bar_rolling_1440m_std`, `pressure_bar_rolling_1440m_min`, `pressure_bar_rolling_1440m_max`, `pressure_bar_rolling_1440m_trend`, `flow_rate_lpm_lag_1`, `flow_rate_lpm_lag_6`, `flow_rate_lpm_lag_12`, `flow_rate_lpm_lag_24`, `flow_rate_lpm_rolling_60m_mean`, `flow_rate_lpm_rolling_60m_std`, `flow_rate_lpm_rolling_60m_min`, `flow_rate_lpm_rolling_60m_max`, `flow_rate_lpm_rolling_60m_trend`, `flow_rate_lpm_rolling_360m_mean`, `flow_rate_lpm_rolling_360m_std`, `flow_rate_lpm_rolling_360m_min`, `flow_rate_lpm_rolling_360m_max`, `flow_rate_lpm_rolling_360m_trend`, `flow_rate_lpm_rolling_1440m_mean`, `flow_rate_lpm_rolling_1440m_std`, `flow_rate_lpm_rolling_1440m_min`, `flow_rate_lpm_rolling_1440m_max`, `flow_rate_lpm_rolling_1440m_trend`, `water_level_m_lag_1`, `water_level_m_lag_6`, `water_level_m_lag_12`, `water_level_m_lag_24`, `water_level_m_rolling_60m_mean`, `water_level_m_rolling_60m_std`, `water_level_m_rolling_60m_min`, `water_level_m_rolling_60m_max`, `water_level_m_rolling_60m_trend`, `water_level_m_rolling_360m_mean`, `water_level_m_rolling_360m_std`, `water_level_m_rolling_360m_min`, `water_level_m_rolling_360m_max`, `water_level_m_rolling_360m_trend`, `water_level_m_rolling_1440m_mean`, `water_level_m_rolling_1440m_std`, `water_level_m_rolling_1440m_min`, `water_level_m_rolling_1440m_max`, `water_level_m_rolling_1440m_trend`, `pressure_drop_rate`, `flow_efficiency`

### `data/external/uci_air_quality_gas_multisensor/data.csv`

`Date`, `Time`, `CO(GT)`, `PT08.S1(CO)`, `NMHC(GT)`, `C6H6(GT)`, `PT08.S2(NMHC)`, `NOx(GT)`, `PT08.S3(NOx)`, `NO2(GT)`, `PT08.S4(NO2)`, `PT08.S5(O3)`, `T`, `RH`, `AH`

### `data/external/uci_beijing_multisite_air_quality/extracted/data.csv`

`Date`, `Open`, `High`, `Low`, `Close`, `Adj Close`, `Volume`

### `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Aotizhongxin_20130301-20170228.csv`

`No`, `year`, `month`, `day`, `hour`, `PM2.5`, `PM10`, `SO2`, `NO2`, `CO`, `O3`, `TEMP`, `PRES`, `DEWP`, `RAIN`, `wd`, `WSPM`, `station`

### `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Changping_20130301-20170228.csv`

`No`, `year`, `month`, `day`, `hour`, `PM2.5`, `PM10`, `SO2`, `NO2`, `CO`, `O3`, `TEMP`, `PRES`, `DEWP`, `RAIN`, `wd`, `WSPM`, `station`

### `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Dingling_20130301-20170228.csv`

`No`, `year`, `month`, `day`, `hour`, `PM2.5`, `PM10`, `SO2`, `NO2`, `CO`, `O3`, `TEMP`, `PRES`, `DEWP`, `RAIN`, `wd`, `WSPM`, `station`

### `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Dongsi_20130301-20170228.csv`

`No`, `year`, `month`, `day`, `hour`, `PM2.5`, `PM10`, `SO2`, `NO2`, `CO`, `O3`, `TEMP`, `PRES`, `DEWP`, `RAIN`, `wd`, `WSPM`, `station`

### `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Guanyuan_20130301-20170228.csv`

`No`, `year`, `month`, `day`, `hour`, `PM2.5`, `PM10`, `SO2`, `NO2`, `CO`, `O3`, `TEMP`, `PRES`, `DEWP`, `RAIN`, `wd`, `WSPM`, `station`

### `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Gucheng_20130301-20170228.csv`

`No`, `year`, `month`, `day`, `hour`, `PM2.5`, `PM10`, `SO2`, `NO2`, `CO`, `O3`, `TEMP`, `PRES`, `DEWP`, `RAIN`, `wd`, `WSPM`, `station`

### `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Huairou_20130301-20170228.csv`

`No`, `year`, `month`, `day`, `hour`, `PM2.5`, `PM10`, `SO2`, `NO2`, `CO`, `O3`, `TEMP`, `PRES`, `DEWP`, `RAIN`, `wd`, `WSPM`, `station`

### `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Nongzhanguan_20130301-20170228.csv`

`No`, `year`, `month`, `day`, `hour`, `PM2.5`, `PM10`, `SO2`, `NO2`, `CO`, `O3`, `TEMP`, `PRES`, `DEWP`, `RAIN`, `wd`, `WSPM`, `station`

### `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Shunyi_20130301-20170228.csv`

`No`, `year`, `month`, `day`, `hour`, `PM2.5`, `PM10`, `SO2`, `NO2`, `CO`, `O3`, `TEMP`, `PRES`, `DEWP`, `RAIN`, `wd`, `WSPM`, `station`

### `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Tiantan_20130301-20170228.csv`

`No`, `year`, `month`, `day`, `hour`, `PM2.5`, `PM10`, `SO2`, `NO2`, `CO`, `O3`, `TEMP`, `PRES`, `DEWP`, `RAIN`, `wd`, `WSPM`, `station`

### `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Wanliu_20130301-20170228.csv`

`No`, `year`, `month`, `day`, `hour`, `PM2.5`, `PM10`, `SO2`, `NO2`, `CO`, `O3`, `TEMP`, `PRES`, `DEWP`, `RAIN`, `wd`, `WSPM`, `station`

### `data/external/uci_beijing_multisite_air_quality/extracted/PRSA2017_Data_20130301-20170228/PRSA_Data_20130301-20170228/PRSA_Data_Wanshouxigong_20130301-20170228.csv`

`No`, `year`, `month`, `day`, `hour`, `PM2.5`, `PM10`, `SO2`, `NO2`, `CO`, `O3`, `TEMP`, `PRES`, `DEWP`, `RAIN`, `wd`, `WSPM`, `station`

### `data/external/uci_beijing_multisite_air_quality/extracted/test.csv`

`Date`, `Open`, `High`, `Low`, `Close`, `Adj Close`, `Volume`

### `data/external/uci_beijing_pm25/data.csv`

`year`, `month`, `day`, `hour`, `DEWP`, `TEMP`, `PRES`, `cbwd`, `Iws`, `Is`, `Ir`, `pm2.5`
