import '../core/utils/sc1_helpers.dart';
import '../models/alert_model.dart';
import '../models/bridge_model.dart';
import '../models/building_model.dart';
import '../models/gateway_model.dart';
import '../models/water_model.dart';

class AlertRulesEngine {
  static List<AlertModel> analyzeBuilding(BuildingModel? model) {
    if (model == null) return const [];
    final now = _now;
    final alerts = <AlertModel>[];
    void add({
      required String id,
      required String severity,
      required String title,
      required String message,
      int? flags,
    }) {
      alerts.add(AlertModel(
        id: 'rule_building_$id',
        domain: 'building',
        nodeId: model.status.nodeId,
        severity: severity,
        title: title,
        message: message,
        timestamp: now,
        resolved: false,
        flags: flags ?? model.flags,
      ));
    }

    if (!model.online) {
      add(
        id: 'offline',
        severity: 'critical',
        title: 'Building Node Lost',
        message: 'No fresh packets from the building and irrigation node.',
      );
    }
    if (model.smoke >= 400) {
      add(
        id: 'smoke',
        severity: 'critical',
        title: 'Smoke Detected',
        message: 'MQ2 smoke reading is ${model.smoke.toStringAsFixed(0)} ppm.',
        flags: model.flags | flagAlert,
      );
    }
    if ((model.gas ?? 0) >= 450) {
      add(
        id: 'gas',
        severity: 'critical',
        title: 'Gas Detected',
        message: 'MQ5 gas reading is ${model.gas!.toStringAsFixed(0)} ppm.',
        flags: model.flags | flagAlert,
      );
    }
    if (model.airQuality >= 1000) {
      add(
        id: 'air',
        severity: 'warning',
        title: 'Poor Air Quality',
        message: 'MQ135 air quality is ${model.airQuality.toStringAsFixed(0)}.',
      );
    }
    if (model.soilMoisture < 20) {
      add(
        id: 'dry_soil',
        severity: 'warning',
        title: 'Dry Soil',
        message: 'Soil moisture is ${model.soilMoisture.toStringAsFixed(0)}%.',
      );
    }
    if (model.rain) {
      add(
        id: 'rain',
        severity: 'info',
        title: 'Rain Detected',
        message: 'Rain sensor reports wet conditions around the node.',
      );
    }
    _flagAlerts(model.flags, 'building', model.status.nodeId, now, alerts);
    return alerts;
  }

  static List<AlertModel> analyzeBridge(BridgeModel? model) {
    if (model == null) return const [];
    final now = _now;
    final alerts = <AlertModel>[];
    void add({
      required String id,
      required String severity,
      required String title,
      required String message,
      int? flags,
    }) {
      alerts.add(AlertModel(
        id: 'rule_bridge_$id',
        domain: 'bridge',
        nodeId: model.status.nodeId,
        severity: severity,
        title: title,
        message: message,
        timestamp: now,
        resolved: false,
        flags: flags ?? model.flags,
      ));
    }

    if (!model.online) {
      add(
        id: 'offline',
        severity: 'critical',
        title: 'Bridge Node Lost',
        message: 'No fresh LoRa packets from the bridge / road node.',
      );
    }
    if (model.anyDangerSwitch) {
      add(
        id: 'danger_switch',
        severity: 'critical',
        title: 'Danger Switch Activated',
        message: 'One or more of the four bridge danger switches is active.',
        flags: model.flags | flagAlert | flagActuatorOn,
      );
    }
    if (model.overloadAlert) {
      add(
        id: 'overload',
        severity: 'warning',
        title: 'Bridge Overload',
        message:
            '${model.carsInside}/${model.capacityLimit} cars are inside the controlled road section.',
      );
    }
    if (model.roadStatus != 'ROAD OPEN') {
      add(
        id: 'road_closed',
        severity:
            model.roadStatus == 'DANGER DETECTED' ? 'critical' : 'warning',
        title: model.roadStatus,
        message:
            'Gate in ${model.gateIn ? 'open' : 'closed'}, gate out ${model.gateOut ? 'open' : 'closed'}, buzzer ${model.buzzer ? 'active' : 'silent'}.',
      );
    }
    _flagAlerts(model.flags, 'bridge', model.status.nodeId, now, alerts);
    return alerts;
  }

  static List<AlertModel> analyzeWater(WaterModel? model) {
    if (model == null) return const [];
    final now = _now;
    final alerts = <AlertModel>[];
    void add({
      required String id,
      required String severity,
      required String title,
      required String message,
      int? flags,
    }) {
      alerts.add(AlertModel(
        id: 'rule_water_$id',
        domain: 'water',
        nodeId: model.status.nodeId,
        severity: severity,
        title: title,
        message: message,
        timestamp: now,
        resolved: false,
        flags: flags ?? model.flags,
      ));
    }

    if (!model.online) {
      add(
        id: 'offline',
        severity: 'critical',
        title: 'Water Node Lost',
        message: 'No fresh packets from the water network node.',
      );
    }
    if (model.hasLeak || model.leakProbability >= 70) {
      add(
        id: 'leak',
        severity: model.leakProbability >= 80 ? 'critical' : 'warning',
        title: 'Water Leak Detected',
        message:
            'Leak probability ${model.leakProbability.toStringAsFixed(0)}%, tank difference ${model.difference.toStringAsFixed(1)}%, pipe soil ${model.pipeSoil.toStringAsFixed(0)}%.',
        flags: model.flags | flagAlert,
      );
    }
    if (model.difference > 20) {
      add(
        id: 'difference',
        severity: 'warning',
        title: 'Tank Difference High',
        message:
            'Tank 1 and tank 2 differ by ${model.difference.toStringAsFixed(1)}%.',
      );
    }
    if (model.pipeSoil > 70 && !model.rain) {
      add(
        id: 'wet_pipe_no_rain',
        severity: 'warning',
        title: 'Pipe Soil Wet Without Rain',
        message: 'Pipe soil is wet while rain sensor reports dry conditions.',
      );
    }
    _flagAlerts(model.flags, 'water', model.status.nodeId, now, alerts);
    return alerts;
  }

  static List<AlertModel> analyzeGateway(GatewayModel? model) {
    if (model == null) return const [];
    final now = _now;
    final alerts = <AlertModel>[];
    void add({
      required String id,
      required String severity,
      required String title,
      required String message,
    }) {
      alerts.add(AlertModel(
        id: 'rule_gateway_$id',
        domain: 'gateway',
        nodeId: 4,
        severity: severity,
        title: title,
        message: message,
        timestamp: now,
        resolved: false,
        flags: severity == 'critical' ? flagAlert : 0,
      ));
    }

    if (!model.online) {
      add(
        id: 'offline',
        severity: 'critical',
        title: 'Gateway Offline',
        message: 'ESP32 gateway health timestamp is stale or offline.',
      );
    }
    if (!model.wifiStatus.toLowerCase().contains('connect')) {
      add(
        id: 'wifi',
        severity: 'critical',
        title: 'WiFi Disconnected',
        message: 'Gateway WiFi status is ${model.wifiStatus}.',
      );
    }
    if (!model.firebaseStatus.toLowerCase().contains('sync') &&
        !model.firebaseStatus.toLowerCase().contains('connected')) {
      add(
        id: 'firebase',
        severity: 'warning',
        title: 'Firebase Upload Issue',
        message: 'Firebase status is ${model.firebaseStatus}.',
      );
    }
    for (final node in model.nodeHealth) {
      if (!node.online) {
        add(
          id: 'node_${node.key}_lost',
          severity: 'critical',
          title: '${node.name} Node Lost',
          message: 'Gateway has not received fresh ${node.name} packets.',
        );
      }
      if (node.pdr > 0 && node.pdr < 90) {
        add(
          id: 'node_${node.key}_pdr',
          severity: 'warning',
          title: '${node.name} Low PDR',
          message: 'Packet delivery ratio is ${node.pdr.toStringAsFixed(1)}%.',
        );
      }
    }
    if (model.totalPackets <= 0) {
      add(
        id: 'no_packets',
        severity: 'critical',
        title: 'No Packets Received',
        message: 'Gateway total packet counter is still zero.',
      );
    }
    return alerts;
  }

  static List<AlertModel> analyzeAll({
    required BuildingModel? building,
    required BridgeModel? bridge,
    required WaterModel? water,
    required GatewayModel? gateway,
  }) {
    final alerts = [
      ...analyzeBuilding(building),
      ...analyzeBridge(bridge),
      ...analyzeWater(water),
      ...analyzeGateway(gateway),
    ];
    return _dedupe(alerts);
  }

  static int get _now => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  static void _flagAlerts(
    int flags,
    String domain,
    int nodeId,
    int now,
    List<AlertModel> output,
  ) {
    if (hasLowBattery(flags)) {
      output.add(AlertModel(
        id: 'rule_${domain}_low_battery',
        domain: domain,
        nodeId: nodeId,
        severity: 'warning',
        title: 'Low Battery',
        message: 'SC1 flag reports low battery voltage.',
        timestamp: now,
        resolved: false,
        flags: flags,
      ));
    }
    if (hasSensorError(flags)) {
      output.add(AlertModel(
        id: 'rule_${domain}_sensor_error',
        domain: domain,
        nodeId: nodeId,
        severity: 'critical',
        title: 'Sensor Error',
        message: 'SC1 flag reports a sensor error.',
        timestamp: now,
        resolved: false,
        flags: flags,
      ));
    }
  }

  static List<AlertModel> _dedupe(List<AlertModel> alerts) {
    final seen = <String>{};
    final result = <AlertModel>[];
    for (final alert in alerts) {
      if (seen.add(alert.id)) result.add(alert);
    }
    return result;
  }
}
