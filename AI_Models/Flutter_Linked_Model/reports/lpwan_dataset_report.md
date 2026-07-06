# LPWAN / LoRaWAN Training Dataset Report

- Generated at: `2026-06-14T13:10:43.536272Z`
- Rows: `620000`
- Real/enriched rows: `620000`
- Synthetic LPWAN rows: `0`
- Real/enriched ratio: `1.0`
- CSV: `data/lpwan/processed/lpwan_training_dataset.csv`
- Parquet: `data/lpwan/processed/lpwan_training_dataset.parquet`

## Source Datasets

- `LoED: The LoRaWAN at the Edge Dataset`: `520000` rows
- `Existing SmartCity project telemetry`: `100000` rows

## LoED Acquisition

- Zenodo DOI: `10.5281/zenodo.4121430`
- License: `cc-by-4.0`
- Archive: `data/lpwan/raw/LoED_LoRaWAN_at_edge_dataset.zip`
- CSV files used: `9` of `188`

## Missing Fields Filled

- `tx_power_dbm`
- `distance_m`
- `environment_type`
- `obstacle_level`
- `battery_voltage`
- `battery_pct`
- `current_ma`
- `delivery_ratio`
- `packet_loss_rate`
- `labels`

## Label Generation Rules

- `label_link_quality`: excellent/good/fair/poor thresholds from RSSI and SNR.
- `label_packet_loss`: 1 when rolling loss >= 18%, CRC failed, RSSI < -115 dBm, or SNR < -10 dB.
- `label_gateway_health`: healthy/degraded/critical from gateway-level delivery ratio, median RSSI, and median SNR.
- `label_energy_risk`: 1 when battery < 20%, high current with SF>=11, or high TX power with high packet loss.
- `label_optimal_sf`: SF7-SF12 rule recommendation from link margin, distance, and obstacle level.

## Assumptions

- LoED provides real gateway packet reception metadata; battery, current draw, distance, obstacle level, and deployment environment are not packet columns and are deterministically enriched.
- Observed LoED gateway rows are received gateway events. CRC failures are treated as packet reception failures for packet-loss labels.
- Synthetic LPWAN rows are generated only when real/enriched rows do not reach the configured row target.
- Optimal spreading factor labels are rule labels based on RSSI, SNR, inferred distance, and obstacle level.