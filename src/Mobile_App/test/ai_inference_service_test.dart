import 'package:flutter_test/flutter_test.dart';
import 'package:smartcity_lpwan/services/ai_inference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AI inference service returns a graceful anomaly result', () async {
    final service = AiInferenceService();
    await service.loadModels();

    final result = await service.detectAnomaly(
      domain: 'water',
      sensorReadings: const {
        'pressure_bar': 1.8,
        'flow_rate_lpm': 240,
        'water_level_m': 2.1,
        'leak_detected': 1,
        'battery_pct': 82,
        'rssi_dbm': -74,
        'snr_db': 8,
      },
      recentHistory: const [],
    );

    expect(result.anomalyScore, inInclusiveRange(0, 1));
    expect(result.explanation, isNotEmpty);
  });
}
