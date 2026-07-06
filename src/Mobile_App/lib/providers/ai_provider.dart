import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/ai_models.dart';
import '../models/alert_model.dart';
import '../services/ai_inference_service.dart';
import '../services/notification_service.dart';
import 'dashboard_provider.dart';

class AiNodeRisk {
  final String nodeId;
  final String domain;
  final String title;
  final double score;
  final String explanation;

  const AiNodeRisk({
    required this.nodeId,
    required this.domain,
    required this.title,
    required this.score,
    required this.explanation,
  });
}

class AiProvider extends ChangeNotifier {
  final AiInferenceService _aiService;
  NotificationService? _notifications;

  final Map<String, AnomalyResult> _nodeAnomalies = {};
  final Map<String, MaintenancePrediction> _maintenancePredictions = {};
  final Map<String, AlertScore> _alertScores = {};
  final Map<String, SignalPrediction> _signalPredictions = {};
  final Map<String, List<Map<String, double>>> _telemetryHistory = {};
  final List<AnomalyHistoryPoint> _anomalyHistory = [];

  bool _isModelLoaded = false;
  bool _isAnalyzing = false;
  String _lastDashboardSignature = '';
  DateTime? _lastAnalysisAt;

  AiProvider({AiInferenceService? aiService})
      : _aiService = aiService ?? AiInferenceService();

  bool get isModelLoaded => _isModelLoaded;
  bool get isAnalyzing => _isAnalyzing;
  DateTime? get lastAnalysisAt => _lastAnalysisAt;
  Map<String, AlertScore> get alertScores => Map.unmodifiable(_alertScores);
  List<AnomalyHistoryPoint> get anomalyHistory =>
      List.unmodifiable(_anomalyHistory);

  int get totalActiveAnomalies =>
      _nodeAnomalies.values.where((result) => result.isAnomaly).length;

  List<AiNodeRisk> get topRiskNodes {
    final risks = _nodeAnomalies.entries.map((entry) {
      final result = entry.value;
      return AiNodeRisk(
        nodeId: entry.key,
        domain: _domainForNode(entry.key),
        title: _titleForNode(entry.key),
        score: result.anomalyScore,
        explanation: result.explanation,
      );
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return risks.take(5).toList(growable: false);
  }

  void attachNotifications(NotificationService service) {
    _notifications = service;
  }

  Future<void> initializeAI() async {
    if (_isModelLoaded) return;
    await _aiService.loadModels();
    _isModelLoaded = _aiService.isModelLoaded;
    notifyListeners();
  }

  void syncFromDashboard(DashboardProvider dashboard) {
    final signature = [
      dashboard.building?.seq,
      dashboard.bridge?.seq,
      dashboard.water?.seq,
      dashboard.gateway?.totalPackets,
      dashboard.effectiveAlerts
          .map((alert) => '${alert.id}:${alert.resolved}')
          .join(','),
    ].join('|');
    if (signature == _lastDashboardSignature) return;
    _lastDashboardSignature = signature;
    scheduleMicrotask(() => unawaited(runFullAnalysis(dashboard)));
  }

  Future<void> runFullAnalysis(DashboardProvider dashboard) async {
    if (_isAnalyzing) return;
    _isAnalyzing = true;
    notifyListeners();
    await initializeAI();
    try {
      final readings = _dashboardReadings(dashboard);
      for (final entry in readings.entries) {
        await analyzeNewTelemetry(
          entry.key,
          _domainForNode(entry.key),
          entry.value,
        );
      }
      for (final entry in readings.entries) {
        await loadMaintenancePrediction(entry.key, _domainForNode(entry.key));
      }
      await _scoreAlerts(dashboard.effectiveAlerts);
      await _predictGatewaySignals(dashboard);
      _lastAnalysisAt = DateTime.now();
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  Future<void> analyzeNewTelemetry(
    String nodeId,
    String domain,
    Map<String, dynamic> data,
  ) async {
    await initializeAI();
    final numeric = _numericMap(data);
    final history = _telemetryHistory.putIfAbsent(nodeId, () => []);
    history.add(numeric);
    if (history.length > 576) {
      history.removeRange(0, history.length - 576);
    }
    final result = await _aiService.detectAnomaly(
      domain: domain,
      sensorReadings: numeric,
      recentHistory: history,
    );
    _nodeAnomalies[nodeId] = result;
    _anomalyHistory.add(
      AnomalyHistoryPoint(
        timestamp: result.analyzedAt,
        nodeId: nodeId,
        domain: domain,
        score: result.anomalyScore,
      ),
    );
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    _anomalyHistory.removeWhere((point) => point.timestamp.isBefore(cutoff));
    _notifyCritical(nodeId, domain, result);
  }

  Future<void> loadMaintenancePrediction(String nodeId, String domain) async {
    final history = _telemetryHistory[nodeId] ?? const <Map<String, double>>[];
    final prediction = await _aiService.predictMaintenance(
      nodeId: nodeId,
      domain: domain,
      telemetryWindow: history,
    );
    _maintenancePredictions[nodeId] = prediction;
  }

  AnomalyResult? getNodeAnomaly(String nodeId) => _nodeAnomalies[nodeId];

  MaintenancePrediction? getMaintenancePrediction(String nodeId) =>
      _maintenancePredictions[nodeId];

  AlertScore? getAlertScore(String alertId) => _alertScores[alertId];

  SignalPrediction? getSignalPrediction(String gatewayId) =>
      _signalPredictions[gatewayId];

  Future<void> _scoreAlerts(List<AlertModel> alerts) async {
    for (final alert in alerts) {
      _alertScores[alert.id] = await _aiService.scoreAlert(
        alertData: {
          'severity': alert.severity,
          'title': alert.title,
          'message': alert.message,
          'resolved': alert.resolved,
          'nodeId': alert.nodeId,
        },
        domain: _normalizeDomain(alert.domain),
      );
    }
  }

  Future<void> _predictGatewaySignals(DashboardProvider dashboard) async {
    final gateway = dashboard.gateway;
    if (gateway == null) return;
    final values = [
      gateway.averageRssi,
      gateway.buildingNode.rssi,
      gateway.bridgeNode.rssi,
      gateway.waterNode.rssi,
    ].where((value) => value != 0).map((value) => value.toDouble()).toList();
    if (values.isEmpty) return;
    _signalPredictions['gateway'] = await _aiService.predictSignalQuality(
      gatewayId: 'gateway',
      recentRssi: values,
    );
  }

  Map<String, Map<String, dynamic>> _dashboardReadings(
    DashboardProvider dashboard,
  ) {
    final readings = <String, Map<String, dynamic>>{};
    final building = dashboard.building;
    if (building != null) {
      readings['building'] = {
        'temp_c': building.temperature,
        'humidity_pct': building.humidity,
        'co2_ppm': building.airQuality,
        'power_kwh': math.max(0, building.pressure / 240.0),
        'occupancy_count': building.airQuality / 28.0,
        'smoke_level': building.smoke,
        'soil_moisture_pct': building.soilMoisture,
        'battery_pct': building.batteryPercent,
        'rssi_dbm': building.rssi,
        'snr_db': building.snr,
      };
    }
    final bridge = dashboard.bridge;
    if (bridge != null) {
      readings['bridge'] = {
        'vibration_hz': bridge.carsInside * 3.0 + bridge.riskState * 12.0,
        'tilt_angle_deg': bridge.anyDangerSwitch ? 4.2 : 0.35,
        'load_weight_ton': bridge.loadKg / 1000.0,
        'crack_index': (bridge.riskState / 3.0).clamp(0.0, 1.0),
        'temp_c': 28.0,
        'humidity_pct': 45.0,
        'battery_pct': bridge.batteryPercent,
        'rssi_dbm': bridge.rssi,
        'snr_db': bridge.snr,
      };
    }
    final water = dashboard.water;
    if (water != null) {
      readings['water'] = {
        'pressure_bar': (5.7 - water.difference / 8.5).clamp(0.2, 7.0),
        'flow_rate_lpm': 90.0 + water.difference * 4.6,
        'water_level_m':
            ((water.tank1 + water.tank2) / 2.0 / 25.0).clamp(0.0, 5.0),
        'pipe_temp_c': 24.0 + water.pipeSoil / 18.0,
        'leak_detected': water.hasLeak ? 1.0 : 0.0,
        'battery_pct': water.batteryPercent,
        'rssi_dbm': water.rssi,
        'snr_db': water.snr,
      };
    }
    return readings;
  }

  Map<String, double> _numericMap(Map<String, dynamic> data) {
    final output = <String, double>{};
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is num) {
        output[entry.key] = value.toDouble();
      } else if (value is bool) {
        output[entry.key] = value ? 1 : 0;
      } else {
        final parsed = double.tryParse(value?.toString() ?? '');
        if (parsed != null) output[entry.key] = parsed;
      }
    }
    return output;
  }

  void _notifyCritical(String nodeId, String domain, AnomalyResult result) {
    final notifications = _notifications;
    if (notifications == null ||
        !result.isAnomaly ||
        result.anomalyScore < 0.84) {
      return;
    }
    notifications.showCriticalAlert(
      AlertModel(
        id: 'ai_${nodeId}_${result.anomalyType}',
        domain: domain,
        nodeId: _nodeNumber(nodeId),
        severity: 'critical',
        title: 'AI Anomaly Detected',
        message: result.explanation,
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        resolved: false,
        flags: 0,
      ),
    );
  }

  String _domainForNode(String nodeId) {
    if (nodeId.contains('bridge')) return 'bridge';
    if (nodeId.contains('water')) return 'water';
    if (nodeId.contains('agriculture')) return 'agriculture';
    return 'building';
  }

  String _normalizeDomain(String domain) {
    switch (domain) {
      case '1':
        return 'building';
      case '2':
        return 'bridge';
      case '3':
        return 'water';
      case '4':
        return 'gateway';
      default:
        return domain.isEmpty ? 'system' : domain;
    }
  }

  String _titleForNode(String nodeId) {
    switch (_domainForNode(nodeId)) {
      case 'bridge':
        return 'Bridge Node';
      case 'water':
        return 'Water Node';
      case 'agriculture':
        return 'Agriculture Node';
      default:
        return 'Building Node';
    }
  }

  int _nodeNumber(String nodeId) {
    switch (_domainForNode(nodeId)) {
      case 'bridge':
        return 2;
      case 'water':
        return 3;
      case 'gateway':
        return 4;
      default:
        return 1;
    }
  }

  @override
  void dispose() {
    _aiService.dispose();
    super.dispose();
  }
}
