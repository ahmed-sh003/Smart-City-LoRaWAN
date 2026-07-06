# Edge AI Optimization Report

- Generated at: `2026-06-14T07:22:17.585717Z`
- Selected deployment: float32 production_model.tflite retained after Phase 3 parity validation; FP16/INT8 variants available for edge trials.

| Variant | Status | Size | Path |
| --- | --- | ---: | --- |
| float32 | active | 21380 | `assets/ml_models/production_model.tflite` |
| fp16 | generated | 14544 | `assets/ml_models/production_model_fp16.tflite` |
| int8 | generated | 12304 | `assets/ml_models/production_model_int8.tflite` |