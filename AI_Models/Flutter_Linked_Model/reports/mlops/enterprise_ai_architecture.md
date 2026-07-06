# Multi-Model AI Architecture

- Generated at: `2026-06-14T07:22:17.585717Z`
- Fusion strategy: weighted risk fusion with domain-specific guardrails and TFLite anomaly score

```mermaid
flowchart TD
  A["LoRa / Firebase Telemetry"] --> B["Feature Store"]
  B --> network_health_predictor["AI Engine 1 - Network Health Predictor"]
  network_health_predictor --> G["Global Smart City Risk Engine"]
  B --> battery_rul_predictor["AI Engine 2 - Battery RUL Predictor"]
  battery_rul_predictor --> G["Global Smart City Risk Engine"]
  B --> water_leak_predictor["AI Engine 3 - Water Leak Predictor"]
  water_leak_predictor --> G["Global Smart City Risk Engine"]
  B --> bridge_health_predictor["AI Engine 4 - Bridge Health Predictor"]
  bridge_health_predictor --> G["Global Smart City Risk Engine"]
  B --> environment_forecasting["AI Engine 5 - Environmental Forecasting"]
  environment_forecasting --> G["Global Smart City Risk Engine"]
  B --> global_smart_city_risk["AI Engine 6 - Global Smart City Risk Engine"]
  global_smart_city_risk --> G["Global Smart City Risk Engine"]
  G --> H["Flutter AI Command Center"]
```

## Engines

### AI Engine 1 - Network Health Predictor
- Inputs: RSSI, SNR, packet loss, node uptime
- Outputs: RSSI next hour, SNR next hour, communication failure probability

### AI Engine 2 - Battery RUL Predictor
- Inputs: battery percentage, battery decay rate, RSSI, domain
- Outputs: remaining battery %, days to battery failure

### AI Engine 3 - Water Leak Predictor
- Inputs: pipe soil, tank levels, difference, rain, leak status
- Outputs: leak probability 6h, leak probability 24h

### AI Engine 4 - Bridge Health Predictor
- Inputs: cars inside, danger switches, vibration, tilt, gate state
- Outputs: structural stress score, failure risk, maintenance priority

### AI Engine 5 - Environmental Forecasting
- Inputs: temperature, humidity, pressure, air quality, smoke/gas
- Outputs: air quality tomorrow, pollution score, drought probability

### AI Engine 6 - Global Smart City Risk Engine
- Inputs: all engine outputs, TFLite anomaly score, alerts, gateway health
- Outputs: global risk score, root cause, recommended action
