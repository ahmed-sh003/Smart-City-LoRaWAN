import '../models/alert_model.dart';
import '../models/bridge_model.dart';
import '../models/building_model.dart';
import '../models/gateway_model.dart';
import '../models/water_model.dart';

enum MockScenario {
  normal,
  alertState,
  lowBattery,
  sensorError,
  waterLeak,
  bridgeDanger,
  gasSmokeAlert,
  gatewayNodeLost,
}

extension MockScenarioLabel on MockScenario {
  String get label {
    switch (this) {
      case MockScenario.normal:
        return 'Normal';
      case MockScenario.alertState:
        return 'General Alert';
      case MockScenario.lowBattery:
        return 'Low Battery';
      case MockScenario.sensorError:
        return 'Sensor Error';
      case MockScenario.waterLeak:
        return 'Water Leak';
      case MockScenario.bridgeDanger:
        return 'Bridge Danger';
      case MockScenario.gasSmokeAlert:
        return 'Gas/Smoke Alert';
      case MockScenario.gatewayNodeLost:
        return 'Gateway Node Lost';
    }
  }
}

class MockDashboardSnapshot {
  final BuildingModel building;
  final BridgeModel bridge;
  final WaterModel water;
  final GatewayModel gateway;
  final List<AlertModel> alerts;

  const MockDashboardSnapshot({
    required this.building,
    required this.bridge,
    required this.water,
    required this.gateway,
    required this.alerts,
  });
}

class MockDataService {
  MockDashboardSnapshot snapshot({
    required MockScenario scenario,
    required int tick,
  }) {
    final alertState = scenario == MockScenario.alertState;
    final lowBattery = scenario == MockScenario.lowBattery;
    final sensorError = scenario == MockScenario.sensorError;
    final waterLeak = scenario == MockScenario.waterLeak;
    final bridgeDanger = scenario == MockScenario.bridgeDanger;
    final gasSmokeAlert = scenario == MockScenario.gasSmokeAlert;
    final gatewayNodeLost = scenario == MockScenario.gatewayNodeLost;

    final building = BuildingModel.mock(
      alertMode: alertState,
      lowBattery: lowBattery,
      sensorError: sensorError,
      gasSmokeAlert: gasSmokeAlert,
      seq: 42 + tick,
    );
    final bridge = BridgeModel.mock(
      alertMode: alertState,
      lowBattery: lowBattery,
      sensorError: sensorError,
      bridgeDanger: bridgeDanger,
      seq: 38 + tick,
    );
    final water = WaterModel.mock(
      alertMode: alertState,
      lowBattery: lowBattery,
      sensorError: sensorError,
      waterLeak: waterLeak,
      seq: 45 + tick,
    );
    final gateway = GatewayModel.mock(
      offline: gatewayNodeLost,
      bridgeDanger: bridgeDanger,
      waterLeak: waterLeak,
      tick: tick,
    );
    final alerts = AlertModel.mockAlerts(
      buildingAlert: gasSmokeAlert || alertState,
      bridgeDanger: bridgeDanger,
      waterLeak: waterLeak,
      lowBattery: lowBattery,
      sensorError: sensorError,
    );

    return MockDashboardSnapshot(
      building: building,
      bridge: bridge,
      water: water,
      gateway: gateway,
      alerts: alerts,
    );
  }

  List<double> last24hPackets({int points = 24, int seed = 0}) {
    return List.generate(points, (index) {
      final base = 18 + ((index + seed) % 6) * 2;
      final peak = index > 8 && index < 18 ? 8 : 0;
      return (base + peak + (index % 3)).toDouble();
    });
  }

  List<double> last24hAlerts({int points = 24, int seed = 0}) {
    return List.generate(points, (index) {
      if ((index + seed) % 9 == 0) return 3;
      if ((index + seed) % 5 == 0) return 1;
      return 0;
    });
  }
}
