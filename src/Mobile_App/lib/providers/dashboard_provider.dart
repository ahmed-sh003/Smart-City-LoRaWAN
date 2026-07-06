import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/alert_model.dart';
import '../models/bridge_model.dart';
import '../models/building_model.dart';
import '../models/gateway_model.dart';
import '../models/water_model.dart';
import '../services/alert_rules_engine.dart';
import '../services/firebase_service.dart';
import '../services/mock_data_service.dart';

export '../services/mock_data_service.dart'
    show MockScenario, MockScenarioLabel;

class DashboardProvider extends ChangeNotifier {
  bool useMockData = true;
  bool rotateMockScenarios = true;
  MockScenario mockScenario = MockScenario.normal;
  String firebaseStatus = 'Mock data mode';
  DateTime lastSync = DateTime.now();

  FirebaseService? _firebaseService;
  final MockDataService _mockDataService = MockDataService();

  BuildingModel? building;
  BridgeModel? bridge;
  WaterModel? water;
  GatewayModel? gateway;
  List<AlertModel> alerts = [];

  bool _loading = true;
  bool get loading => _loading;

  final List<StreamSubscription> _subscriptions = [];
  Timer? _mockTimer;
  Timer? _freshnessTimer;
  int _mockTick = 0;

  bool get firebaseLiveMode => !useMockData;

  void initialize() {
    _cleanup();
    _loading = true;
    if (useMockData) {
      firebaseStatus = 'Mock data mode';
      _loadMockData();
      _mockTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (rotateMockScenarios) _advanceScenario();
        _loadMockData();
      });
    } else {
      _listenToFirebase();
      _freshnessTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => notifyListeners(),
      );
    }
  }

  void _advanceScenario() {
    _mockTick++;
    mockScenario = MockScenario.values[_mockTick % MockScenario.values.length];
  }

  void _loadMockData() {
    final snapshot = _mockDataService.snapshot(
      scenario: mockScenario,
      tick: _mockTick,
    );
    building = snapshot.building;
    bridge = snapshot.bridge;
    water = snapshot.water;
    gateway = snapshot.gateway;
    alerts = snapshot.alerts;
    lastSync = DateTime.now();
    _loading = false;
    notifyListeners();
  }

  void _listenToFirebase() {
    try {
      firebaseStatus = 'Firebase Realtime Database live';
      _firebaseService ??= FirebaseService();
      _subscriptions.add(_firebaseService!.buildingStream().listen((data) {
        building = data;
        _markSynced();
      }, onError: _fallbackToMock));

      _subscriptions.add(_firebaseService!.bridgeStream().listen((data) {
        bridge = data;
        _markSynced();
      }, onError: _fallbackToMock));

      _subscriptions.add(_firebaseService!.waterStream().listen((data) {
        water = data;
        _markSynced();
      }, onError: _fallbackToMock));

      _subscriptions.add(_firebaseService!.gatewayStream().listen((data) {
        gateway = data;
        _markSynced();
      }, onError: _fallbackToMock));

      _subscriptions.add(_firebaseService!.alertsStream().listen((data) {
        alerts = data;
        _markSynced();
      }, onError: _fallbackToMock));
    } catch (error) {
      _fallbackToMock(error);
    }
  }

  void _markSynced() {
    lastSync = DateTime.now();
    _loading = false;
    notifyListeners();
  }

  int get totalOnlineNodes {
    return [
      building?.status.online == true,
      bridge?.status.online == true,
      water?.status.online == true,
    ].where((online) => online).length;
  }

  int get nodeAlertCount {
    return [
      building?.hasAlert == true,
      bridge?.hasAlert == true,
      water?.hasAlert == true,
    ].where((alert) => alert).length;
  }

  List<AlertModel> get effectiveAlerts {
    final merged = [
      ...alerts,
      ...AlertRulesEngine.analyzeAll(
        building: building,
        bridge: bridge,
        water: water,
        gateway: gateway,
      ),
    ];
    final seen = <String>{};
    merged.removeWhere((alert) => !seen.add(alert.id));
    merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return merged;
  }

  int get activeAlertCount =>
      effectiveAlerts.where((alert) => !alert.resolved).length;

  String get cityStatus {
    if (gateway?.online == false || totalOnlineNodes < 2) return 'CRITICAL';
    if (effectiveAlerts.any((alert) => !alert.resolved)) {
      return 'WARNING';
    }
    return 'SAFE';
  }

  void toggleMockData(bool value) {
    useMockData = value;
    _cleanup();
    _loading = true;
    notifyListeners();
    initialize();
  }

  void toggleFirebaseMode(bool value) => toggleMockData(!value);

  void setMockScenario(MockScenario scenario) {
    mockScenario = scenario;
    rotateMockScenarios = false;
    _loadMockData();
  }

  void toggleMockRotation(bool value) {
    rotateMockScenarios = value;
    notifyListeners();
  }

  Future<void> resolveAlert(String alertId) async {
    if (useMockData) {
      alerts = alerts
          .map((alert) =>
              alert.id == alertId ? alert.copyWith(resolved: true) : alert)
          .toList();
      notifyListeners();
      return;
    }
    await _firebaseService?.resolveAlert(alertId);
  }

  Future<bool> signInWithFirebase(String email, String password) async {
    if (useMockData) return true;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      firebaseStatus = 'Firebase Auth signed in';
      notifyListeners();
      return true;
    } catch (error) {
      firebaseStatus = 'Firebase Auth unavailable, using local session';
      notifyListeners();
      debugPrint('Firebase auth sign-in failed: $error');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      debugPrint('Firebase sign-out skipped: $error');
    }
  }

  void _fallbackToMock(Object error) {
    if (useMockData) return;
    debugPrint('Firebase stream failed, falling back to mock data: $error');
    useMockData = true;
    firebaseStatus = 'Firebase unavailable, mock data active';
    _cleanup();
    _loadMockData();
  }

  void _cleanup() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _mockTimer?.cancel();
    _freshnessTimer?.cancel();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
