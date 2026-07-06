import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../models/ai_models.dart';
import 'ai_tflite_backend_stub.dart'
    if (dart.library.io) 'ai_tflite_backend_native.dart';

class AiInferenceService {
  final AiTfliteBackend _backend;
  Map<String, dynamic> _config = const {};
  bool _configLoaded = false;

  AiInferenceService({AiTfliteBackend? backend})
      : _backend = backend ?? AiTfliteBackend();

  bool get isModelLoaded => _configLoaded || _backend.hasLoadedModels;

  Future<void> loadModels() async {
    if (_configLoaded || _backend.hasLoadedModels) return;
    try {
      final raw =
          await rootBundle.loadString('assets/ml_models/model_config.json');
      _config = jsonDecode(raw) as Map<String, dynamic>;
      _configLoaded = true;
    } catch (_) {
      _config = const {};
      _configLoaded = false;
    }
    await _backend.load(_config);
  }

  Future<AnomalyResult> detectAnomaly({
    required String domain,
    required Map<String, double> sensorReadings,
    required List<Map<String, double>> recentHistory,
  }) async {
    await loadModels();
    final heuristic = _heuristicScore(domain, sensorReadings);
    final sequence = _buildSequence(domain, sensorReadings, recentHistory);
    final modelScore = await _backend.runAnomalyModel(
      domain: domain,
      sequence: sequence,
    );
    final score = (modelScore ?? heuristic.score).clamp(0.0, 1.0).toDouble();
    final threshold =
        modelScore == null ? _fallbackThreshold : _anomalyThreshold;
    final anomalyType =
        _anomalyType(heuristic.affectedFeatures, sensorReadings);
    final isAnomaly = score >= threshold;
    return AnomalyResult(
      isAnomaly: isAnomaly,
      anomalyScore: _round(score),
      anomalyType: isAnomaly ? anomalyType : 'normal',
      confidence: _round(
        (modelScore == null
                ? 0.62 + (score - 0.5).abs() * 0.68
                : 0.76 + (score - threshold).abs() * 0.58)
            .clamp(0.55, 0.97)
            .toDouble(),
      ),
      explanation: _explanation(
        domain: domain,
        isAnomaly: isAnomaly,
        anomalyType: anomalyType,
        affectedFeatures: heuristic.affectedFeatures,
      ),
      affectedFeatures: heuristic.affectedFeatures,
      analyzedAt: DateTime.now(),
    );
  }

  Future<MaintenancePrediction> predictMaintenance({
    required String nodeId,
    required String domain,
    required List<Map<String, double>> telemetryWindow,
  }) async {
    await loadModels();
    if (telemetryWindow.isEmpty) return MaintenancePrediction.lowRisk();
    final latest = telemetryWindow.last;
    final anomaly = await detectAnomaly(
      domain: domain,
      sensorReadings: latest,
      recentHistory: telemetryWindow,
    );
    final riskFactors = <String>[];
    var probability = anomaly.anomalyScore * 0.55;

    final batteries = telemetryWindow
        .map((row) => row['battery_pct'])
        .whereType<double>()
        .toList(growable: false);
    if (batteries.isNotEmpty) {
      final avgBattery = batteries.reduce((a, b) => a + b) / batteries.length;
      final batteryDrop = batteries.first - batteries.last;
      if (avgBattery < 25 || batteryDrop > 8) {
        probability += 0.18;
        riskFactors.add('Battery degradation');
      }
    }

    final rssiValues = telemetryWindow
        .map((row) => row['rssi_dbm'])
        .whereType<double>()
        .toList(growable: false);
    if (rssiValues.isNotEmpty && rssiValues.reduce(math.min) < -105) {
      probability += 0.12;
      riskFactors.add('Weak LoRa signal');
    }

    if (anomaly.isAnomaly) {
      riskFactors.addAll(anomaly.affectedFeatures);
    }
    probability = probability.clamp(0.02, 0.98).toDouble();
    final urgency = probability >= 0.82
        ? 'critical'
        : probability >= 0.65
            ? 'high'
            : probability >= 0.38
                ? 'medium'
                : 'low';
    return MaintenancePrediction(
      willFailIn24h: probability >= 0.72,
      willFailIn48h: probability >= 0.52,
      failureProbability: _round(probability),
      recommendedAction: _maintenanceAction(urgency, domain),
      urgencyLevel: urgency,
      riskFactors: riskFactors.toSet().toList(growable: false),
      analyzedAt: DateTime.now(),
    );
  }

  Future<AlertScore> scoreAlert({
    required Map<String, dynamic> alertData,
    required String domain,
  }) async {
    await loadModels();
    final severity = (alertData['severity'] ?? 'info').toString().toLowerCase();
    final title = (alertData['title'] ?? '').toString().toLowerCase();
    final message = (alertData['message'] ?? '').toString().toLowerCase();
    final resolved = alertData['resolved'] == true;
    final text = '$title $message';

    if (resolved || text.contains('healthy') || text.contains('recovered')) {
      return const AlertScore(
        severityLevel: 0,
        severityLabel: 'false_alarm',
        confidenceScore: 0.78,
        requiresImmediateAction: false,
        suggestedResponse:
            'The condition appears recovered or resolved; keep it as an audit record.',
      );
    }

    var level = 1;
    if (severity == 'critical') level = 3;
    if (severity == 'warning') level = 2;
    if (text.contains('emergency') ||
        text.contains('danger') ||
        text.contains('leak')) {
      level = math.max(level, 4);
    }
    if (text.contains('battery') ||
        text.contains('rssi') ||
        text.contains('snr')) {
      level = math.max(level, 2);
    }
    final label =
        ['false_alarm', 'info', 'warning', 'critical', 'emergency'][level];
    return AlertScore(
      severityLevel: level,
      severityLabel: label,
      confidenceScore: _round(0.68 + level * 0.065),
      requiresImmediateAction: level >= 3,
      suggestedResponse: _alertResponse(label, domain),
    );
  }

  Future<SignalPrediction> predictSignalQuality({
    required String gatewayId,
    required List<double> recentRssi,
  }) async {
    await loadModels();
    if (recentRssi.isEmpty) {
      return SignalPrediction(
        predictedRssi: -85,
        predictedSnr: 5,
        signalQuality: 'fair',
        recommendation:
            'Not enough readings yet; wait for more LoRa packets before judging link quality.',
        analyzedAt: DateTime.now(),
      );
    }
    final values = recentRssi.take(12).toList(growable: false);
    final avg = values.reduce((a, b) => a + b) / values.length;
    final trend =
        values.length < 2 ? 0.0 : (values.last - values.first) / values.length;
    final predictedRssi = avg + trend * 12;
    final predictedSnr =
        ((predictedRssi + 120) / 10).clamp(-5.0, 14.0).toDouble();
    final quality = _signalQuality(predictedRssi, predictedSnr);
    return SignalPrediction(
      predictedRssi: _round(predictedRssi),
      predictedSnr: _round(predictedSnr),
      signalQuality: quality,
      recommendation: _signalRecommendation(quality),
      analyzedAt: DateTime.now(),
    );
  }

  List<List<double>> _buildSequence(
    String domain,
    Map<String, double> sensorReadings,
    List<Map<String, double>> recentHistory,
  ) {
    final order = _featureOrder();
    final allRows = [...recentHistory, sensorReadings];
    final start = math.max(0, allRows.length - 24);
    final rows = allRows.sublist(start);
    return rows
        .map((row) => _buildFeatureVector(domain, row, order))
        .toList(growable: false);
  }

  List<String> _featureOrder() {
    final configured =
        _config['runtime_feature_order'] ?? _config['feature_order'];
    if (configured is List && configured.isNotEmpty) {
      return configured.map((item) => item.toString()).toList(growable: false);
    }
    return _defaultRuntimeFeatures.toList(growable: false);
  }

  List<double> _buildFeatureVector(
    String domain,
    Map<String, double> row,
    List<String> order,
  ) {
    return order
        .map((feature) =>
            feature == 'domain_id' ? _domainId(domain) : (row[feature] ?? 0.0))
        .map((value) => value.isFinite ? value : 0.0)
        .toList(growable: false);
  }

  double get _anomalyThreshold {
    final thresholds = _config['thresholds'];
    final configured = thresholds is Map ? thresholds['anomaly'] : null;
    if (configured is num) return configured.toDouble();
    return double.tryParse(configured?.toString() ?? '') ?? 0.35;
  }

  double get _fallbackThreshold {
    final thresholds = _config['thresholds'];
    final configured =
        thresholds is Map ? thresholds['fallback_heuristic'] : null;
    if (configured is num) return configured.toDouble();
    return double.tryParse(configured?.toString() ?? '') ?? 0.58;
  }

  double _domainId(String domain) {
    final configured = _config['domain_ids'];
    if (configured is Map) {
      final value = configured[domain];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    switch (domain) {
      case 'water':
        return 0;
      case 'bridge':
        return 1;
      case 'building':
        return 2;
      case 'gateway':
        return 3;
      case 'agriculture':
        return 4;
      default:
        return 0;
    }
  }

  _HeuristicScore _heuristicScore(String domain, Map<String, double> readings) {
    final affected = <String>[];
    var score = 0.08;

    void bump(String feature, double amount) {
      affected.add(feature);
      score += amount;
    }

    final battery = readings['battery_pct'];
    if (battery != null && battery < 18) bump('battery_pct', 0.28);
    final rssi = readings['rssi_dbm'];
    final snr = readings['snr_db'];
    if (rssi != null && rssi < -105) bump('rssi_dbm', 0.20);
    if (snr != null && snr < -6) bump('snr_db', 0.16);

    switch (domain) {
      case 'water':
        if ((readings['pressure_bar'] ?? 4) < 2.5) bump('pressure_bar', 0.24);
        if ((readings['flow_rate_lpm'] ?? 0) > 210) bump('flow_rate_lpm', 0.18);
        if ((readings['leak_detected'] ?? 0) >= 1) bump('leak_detected', 0.35);
        break;
      case 'bridge':
        if ((readings['vibration_hz'] ?? 0) > 42) bump('vibration_hz', 0.24);
        if ((readings['tilt_angle_deg'] ?? 0).abs() > 3.2) {
          bump('tilt_angle_deg', 0.24);
        }
        if ((readings['load_weight_ton'] ?? 0) > 25) {
          bump('load_weight_ton', 0.18);
        }
        if ((readings['crack_index'] ?? 0) > 0.38) bump('crack_index', 0.22);
        break;
      case 'building':
        if ((readings['temp_c'] ?? 22) > 38) bump('temp_c', 0.16);
        if ((readings['co2_ppm'] ?? 400) > 1000) bump('co2_ppm', 0.22);
        if ((readings['smoke_level'] ?? 0) > 380) bump('smoke_level', 0.35);
        if ((readings['power_kwh'] ?? 0) > 9) bump('power_kwh', 0.12);
        break;
      case 'agriculture':
        if ((readings['soil_moisture_pct'] ?? 45) < 20) {
          bump('soil_moisture_pct', 0.26);
        }
        if ((readings['air_temp_c'] ?? 25) > 39) bump('air_temp_c', 0.14);
        if ((readings['ndvi_index'] ?? 0.6) < 0.34) bump('ndvi_index', 0.20);
        if ((readings['irrigation_active'] ?? 0) < 1 &&
            (readings['soil_moisture_pct'] ?? 45) < 25) {
          bump('irrigation_active', 0.12);
        }
        break;
    }
    return _HeuristicScore(
      score.clamp(0.0, 1.0).toDouble(),
      affected.toSet().toList(),
    );
  }

  String _anomalyType(List<String> affected, Map<String, double> readings) {
    if (affected.contains('battery_pct')) return 'battery_critical';
    if (affected.contains('rssi_dbm') || affected.contains('snr_db')) {
      return 'communication';
    }
    final impossible = readings.entries.any((entry) =>
        entry.key.contains('temp') && (entry.value < -10 || entry.value > 80) ||
        entry.key.contains('pressure') &&
            (entry.value < 0 || entry.value > 20));
    if (impossible) return 'sensor_fault';
    return 'infrastructure';
  }

  String _explanation({
    required String domain,
    required bool isAnomaly,
    required String anomalyType,
    required List<String> affectedFeatures,
  }) {
    if (!isAnomaly) {
      return 'The model sees the current $domain readings inside the normal production pattern.';
    }
    final features = affectedFeatures.isEmpty
        ? 'multiple signals'
        : affectedFeatures.join(', ');
    switch (anomalyType) {
      case 'battery_critical':
        return 'Battery risk is high enough to affect node availability; inspect the power source soon.';
      case 'communication':
        return 'Link quality is weak in $features, so LoRa packet loss or delayed telemetry is more likely.';
      case 'sensor_fault':
        return 'A sensor reading is outside the plausible range; check wiring and calibration before field action.';
      default:
        return 'The model found an unusual pattern in $features that may indicate a real $domain issue.';
    }
  }

  String _maintenanceAction(String urgency, String domain) {
    switch (urgency) {
      case 'critical':
        return 'Dispatch maintenance immediately and isolate the affected area if it is safe.';
      case 'high':
        return 'Schedule maintenance within 24 hours and review the latest $domain telemetry.';
      case 'medium':
        return 'Watch this node during the next day and prepare a preventive inspection if the trend continues.';
      default:
        return 'Continue routine monitoring; no urgent maintenance action is needed.';
    }
  }

  String _alertResponse(String label, String domain) {
    switch (label) {
      case 'emergency':
        return 'Escalate now and run the emergency response procedure for $domain.';
      case 'critical':
        return 'Open an urgent intervention ticket and review the last hour of telemetry.';
      case 'warning':
        return 'Monitor the alert and compare it with nearby readings before escalation.';
      case 'false_alarm':
        return 'Keep it as a record; no field action is needed now.';
      default:
        return 'Review this alert during normal operations.';
    }
  }

  String _signalQuality(double rssi, double snr) {
    if (rssi > -70 && snr > 8) return 'excellent';
    if (rssi > -85 && snr > 5) return 'good';
    if (rssi > -100 && snr > 1) return 'fair';
    return 'poor';
  }

  String _signalRecommendation(String quality) {
    switch (quality) {
      case 'excellent':
        return 'Signal is excellent; keep the current transmission schedule.';
      case 'good':
        return 'Signal is good; keep monitoring during heavier network traffic.';
      case 'fair':
        return 'Signal is fair; raise the antenna or reduce obstacles if packet loss increases.';
      default:
        return 'Signal is weak; inspect antenna placement, gateway location, and transmission timing.';
    }
  }

  double _round(double value) => double.parse(value.toStringAsFixed(4));

  void dispose() {
    _backend.dispose();
  }
}

class _HeuristicScore {
  final double score;
  final List<String> affectedFeatures;

  const _HeuristicScore(this.score, this.affectedFeatures);
}

const _defaultRuntimeFeatures = [
  'domain_id',
  'pressure_bar',
  'flow_rate_lpm',
  'water_level_m',
  'pipe_temp_c',
  'leak_detected',
  'vibration_hz',
  'tilt_angle_deg',
  'load_weight_ton',
  'crack_index',
  'temp_c',
  'humidity_pct',
  'co2_ppm',
  'power_kwh',
  'occupancy_count',
  'smoke_level',
  'soil_moisture_pct',
  'soil_temp_c',
  'air_temp_c',
  'air_humidity_pct',
  'irrigation_active',
  'ndvi_index',
  'battery_pct',
  'rssi_dbm',
  'snr_db',
];
