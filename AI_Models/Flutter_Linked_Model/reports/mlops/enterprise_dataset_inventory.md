# Enterprise Dataset Inventory

- Generated at: `2026-06-14T07:22:17.585717Z`
- Training rows inspected: `608949`
- Real rows: `473949`
- Synthetic rows: `135000`
- Real ratio: `0.778307`

## Dataset Catalog

| Dataset | Source | Domain | Access | Current Use |
| --- | --- | --- | --- | --- |
| UCI Air Quality Gas Multisensor | UCI Machine Learning Repository | building | open | used_local |
| UCI Beijing PM2.5 | UCI Machine Learning Repository | environment | open | used_local |
| UCI Beijing Multi-Site Air Quality | UCI Machine Learning Repository | environment | open | used_local |
| OpenAQ v3 Measurements / Latest | OpenAQ | environment | public_api | cataloged_not_used_no_api_snapshot |
| NASA POWER Hourly Meteorology | NASA POWER | environment | public_api | cataloged_not_used_no_api_snapshot |
| NOAA Climate Data Online | NOAA NCEI | environment | token_required | cataloged_not_used_token_required |
| WNTR / EPANET Example Networks | USEPA / Open Water Analytics | water | open_code_models | cataloged_not_used_no_local_hydraulic_scenarios |
| DiTEC-WDN Hydraulic Scenarios | Scientific Data / Nature | water | publication_dataset | cataloged_not_downloaded |
| Hell Bridge Test Arena Benchmark | Zenodo | bridge | open_repository | cataloged_not_downloaded |
| Vänersborg Bridge SHM Dataset | Zenodo | bridge | open_repository | cataloged_not_downloaded |
| Railway Bridge KW51 Monitoring Data | Zenodo | bridge | open_repository | cataloged_not_downloaded |
| Water Leak Dataset | Kaggle | water | kaggle_credentials_required | cataloged_not_used_credentials_required |
| Aging Bridge SHM Time-Series Dataset | Kaggle | bridge | kaggle_credentials_required | cataloged_not_used_credentials_required |

## Datasets Actually Used In Training

- `UCI Beijing Multi-Site Air Quality`: `420768` rows
- `Phase 1 synthetic telemetry`: `135000` rows
- `UCI Beijing PM2.5`: `43824` rows
- `UCI Air Quality Gas Multisensor`: `9357` rows

## Honesty Notes

- Kaggle, Mendeley, IEEE Dataport, NOAA, OpenAQ, NASA POWER, and Zenodo rows are not counted as used unless files exist locally or an API snapshot is downloaded.
- Current real rows come from locally present UCI environmental datasets.
- Bridge and water still need real field exports or downloaded benchmark datasets for fully real supervised training.