# SmartCity LPWAN AI Gap Analysis

Generated: 2026-06-14

## Current Capabilities

- Flutter app already models Building, Bridge, Water, Gateway, Alerts, AI predictions, and MLOps summaries.
- Firebase integration supports the SC1 node and gateway structure through `DashboardProvider` and `FirebaseService`.
- Mock data covers normal, alert, low battery, sensor error, water leak, bridge danger, and gas/smoke scenarios.
- AI inference service provides anomaly checks, alert scoring, maintenance-style predictions, gateway signal quality, and graceful fallback scoring when desktop TFLite is unavailable.
- Existing MLOps assets include production TFLite models, LPWAN model summaries, edge AI variants, reports, SHAP-style feature drivers, and generated LPWAN dataset/model artifacts.
- Reports screen retained technical MLOps, enterprise AI, LPWAN research, trend, node-health, and alert-breakdown sections.

## Missing Capabilities

- Forecasting-specific models for packet loss next 10 minutes, next 30 minutes, and next hour are not yet separately trained as production assets.
- Battery remaining useful life is currently presented as a conservative UI estimate from battery percentage, not a dedicated trained RUL model.
- Gateway recommendation logic is currently UI-level guidance from gateway health and signal data, not a trained best-gateway selector.
- Root-cause explanations are available from current feature drivers and anomaly factors, but the Flutter app does not yet run a dedicated root-cause TFLite model on device.
- The app does not yet expose FP32, FP16, and INT8 benchmark comparisons for all requested new model families.

## Research Gaps

- Labels in the LPWAN pipeline are deterministic engineering labels, not manually annotated field incident labels.
- LoED provides real gateway packet metadata, while deployment fields such as distance, obstacle level, current draw, and battery state are enriched assumptions.
- Bridge and water domain incident labels need more real project telemetry to reduce reliance on rules and mock scenarios.
- Forecasting validation should use time-based splits and field replay scenarios before claiming operational accuracy.

## Deployment Gaps

- Desktop test runs use fallback AI scoring because the desktop TFLite runtime is not bundled.
- The app bundles TFLite assets, but there is no unified on-device router for every LPWAN model family yet.
- Model registry data is visible in reports, but model rollback and remote model rollout are not implemented in Flutter.

## UI Gaps Addressed

- The previous Reports screen opened directly into dense technical MLOps content.
- Home AI insights used technical phrases such as anomaly, score, and full analysis.
- Technical report details were visible before the user had a simple answer to what happened, why, and what to do.
- The redesigned UI now prioritizes status, risk by domain, top reasons, recommended action, forecast, model health, and an optional technical section.

## LPWAN Intelligence Gaps

- Adaptive spreading factor recommendations are summarized from available LPWAN outputs, but closed-loop actuation is not implemented in Flutter.
- Packet loss risk is visualized from current gateway PDR, alerts, and AI trend history; dedicated forecast model inference still needs a production integration pass.
- Battery life is displayed as an estimated remaining-life indicator until a trained RUL model is generated and wired into the inference service.

## Prioritized Roadmap

1. Collect more real bridge and water telemetry with incident labels.
2. Train and export dedicated packet-loss forecasting models with time-based validation.
3. Train and export a battery RUL model using battery, current, SF, TX power, packet rate, RSSI, and SNR.
4. Add a gateway recommendation model and expose expected RSSI/PDR improvement.
5. Add a unified Flutter inference router for LPWAN packet loss, battery life, gateway health, optimal SF, and root-cause models.
6. Add FP32, FP16, and INT8 benchmark cards to the Technical tab.
7. Continue keeping the default AI experience simple for non-technical reviewers, with advanced metrics hidden by default.
