# Phase 3 Merge Strategy

- Generated at: `2026-06-14T06:44:17.086850Z`
- Output: `data/processed/phase3_training_dataset.csv`
- Final rows: `608949`
- Real rows: `473949`
- Synthetic rows: `135000`
- Real ratio: `0.778`

## Strategy

- Keep all available real external rows.
- Add synthetic rows only for deployed hardware domains that lack real external coverage.
- Cap synthetic rows to at most 35% of the real row count.
- Assign synthetic rows `sample_weight=0.35` and real rows `sample_weight=1.0`.
- Exclude legacy agriculture synthetic rows from Phase 3 because the current hardware app domains are building, bridge, water, and gateway.

## Rows By Source Type

| Source type | Rows | Anomalies |
| --- | ---: | ---: |
| real_external | 473949 | 95812 |
| synthetic_phase1_capped | 135000 | 7915 |