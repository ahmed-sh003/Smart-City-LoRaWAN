# Enterprise Forecasting Report

- Generated at: `2026-06-14T07:22:17.585717Z`
- Rows sampled for forecasting: `50000`
- Feature count: `14`

| Task | Best Model | Metric | Status |
| --- | --- | --- | --- |
| network_rssi_next_hour | Ridge | RMSE `6.072169` | trained |
| network_rssi_next_day | Ridge | RMSE `6.189286` | trained |
| network_snr_next_hour | Ridge | RMSE `2.016573` | trained |
| network_packet_loss_next_hour | Ridge | RMSE `0.05294` | trained |
| battery_remaining_pct | Gradient Boosting | RMSE `7.897043` | trained |
| days_to_battery_failure | LightGBM | RMSE `1.959364` | trained |
| water_leak_probability_6h | CatBoost | RMSE `0.060935` | trained |
| water_leak_probability_24h | Gradient Boosting | RMSE `0.060229` | trained |
| bridge_crack_growth | Gradient Boosting | RMSE `0.037242` | trained |
| bridge_vibration_increase | Gradient Boosting | RMSE `16.196596` | trained |
| bridge_structural_failure_risk | Gradient Boosting | RMSE `0.077615` | trained |
| environment_air_quality_tomorrow | XGBoost | RMSE `0.086933` | trained |
| environment_pollution_tomorrow | XGBoost | RMSE `0.063846` | trained |
| environment_drought_probability | Persistence | RMSE `0.0` | trained |
| global_risk_lstm_sequence | Compact LSTM | {'mae': 0.050402, 'rmse': 0.070329, 'r2': -0.139689} | trained |
| temporal_fusion_transformer | Temporal Fusion Transformer | blueprint registered | blueprint_registered |

## Model Coverage

- XGBoost and LightGBM are trained when the installed Python environment provides them.
- Compact LSTM is trained for global sequential risk when TensorFlow is available.
- Temporal Fusion Transformer is registered as a server/GPU training blueprint because the required TFT dependency is not installed in this project environment.