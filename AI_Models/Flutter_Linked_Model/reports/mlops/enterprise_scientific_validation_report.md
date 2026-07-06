# Scientific Validation And Publication Artifacts

- Generated at: `2026-06-14T07:22:17.585717Z`
- Publication readiness: `strong_demo_ready_needs_more_real_bridge_water_for_publication_claims`

## Generated Artifacts

- `reports/enterprise_model_comparison_table.csv`
- `reports/enterprise_confusion_matrix.json`
- `reports/enterprise_roc_pr_curve_points.json`
- `reports/enterprise_shap_summary.json`
- `reports/mlops/enterprise_forecasting_report.md`
- `reports/mlops/enterprise_predictive_maintenance_report.md`
- `reports/mlops/enterprise_explainability_report.md`

## Model Comparison

| Model | F1 | Precision | Recall | ROC-AUC | Latency |
| --- | ---: | ---: | ---: | ---: | ---: |
| Logistic Regression | 0.750865 | 0.659186 | 0.872164 | 0.961135 | 0.000383 |
| Random Forest | 0.862571 | 0.798294 | 0.938107 | 0.989267 | 0.021855 |
| Gradient Boosting | 0.724009 | 0.576304 | 0.97352 | 0.985668 | 0.002104 |
| Extra Trees | 0.837998 | 0.762857 | 0.929558 | 0.984184 | 0.028266 |
| Small Neural Network | 0.891862 | 0.948302 | 0.841764 | 0.983882 | 0.079514 |