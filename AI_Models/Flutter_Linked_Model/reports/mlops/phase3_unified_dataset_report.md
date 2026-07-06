# Phase 3 Unified Real Dataset Report

- Generated at: `2026-06-14T06:43:21.534716Z`
- Output: `data/processed/phase3_unified_real_dataset.csv`
- Real rows: `473949`
- Weak-labeled rows: `473949`
- Anomaly rows: `95812`

## Rows By Source

| Source dataset | Rows | Anomalies | Domains |
| --- | ---: | ---: | --- |
| UCI Air Quality Gas Multisensor | 9357 | 1188 | building |
| UCI Beijing Multi-Site Air Quality | 420768 | 85531 | gateway |
| UCI Beijing PM2.5 | 43824 | 9093 | gateway |

## Label Policy

- No external dataset includes the project's exact target label.
- Labels are weak labels generated only from documented environmental thresholds.
- These labels are not treated as field-confirmed incidents.
- Kaggle water leak and bridge SHM datasets were not used because credentials/data files are absent.

## Domain Mapping

- UCI gas multisensor data maps to `building` because its gas, temperature, and humidity sensors align with the building node's MQ/DHT telemetry.
- Beijing air-quality datasets map to `gateway` / `gateway_environment` because they represent city-level environmental telemetry rather than a specific deployed node.