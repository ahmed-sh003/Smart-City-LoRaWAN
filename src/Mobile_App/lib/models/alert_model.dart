import '../core/utils/sc1_helpers.dart';

class AlertModel {
  final String id;
  final String domain;
  final int nodeId;
  final String severity;
  final String title;
  final String message;
  final int timestamp;
  final bool resolved;
  final int flags;

  const AlertModel({
    required this.id,
    required this.domain,
    required this.nodeId,
    required this.severity,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.resolved,
    required this.flags,
  });

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

  List<String> get decodedFlags => decodeFlags(flags);

  String get domainLabel {
    switch (domain) {
      case 'building':
      case '1':
        return 'Building & Irrigation';
      case 'bridge':
      case '2':
        return 'Bridge / Road';
      case 'water':
      case '3':
        return 'Water Network';
      case 'gateway':
      case '4':
        return 'Gateway';
      default:
        return domain.isEmpty ? 'System' : domain;
    }
  }

  factory AlertModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return AlertModel(
      id: id,
      domain: (map['domain'] ?? '').toString(),
      nodeId: parseInt(map['nodeId']),
      severity: (map['severity'] ?? 'info').toString(),
      title: (map['title'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      timestamp: parseTimestamp(map['timestamp']),
      resolved: parseBool(map['resolved']),
      flags: parseFlags(map['flags']),
    );
  }

  AlertModel copyWith({bool? resolved}) {
    return AlertModel(
      id: id,
      domain: domain,
      nodeId: nodeId,
      severity: severity,
      title: title,
      message: message,
      timestamp: timestamp,
      resolved: resolved ?? this.resolved,
      flags: flags,
    );
  }

  static List<AlertModel> mockAlerts({
    bool buildingAlert = false,
    bool bridgeDanger = false,
    bool waterLeak = false,
    bool lowBattery = false,
    bool sensorError = false,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return [
      if (buildingAlert)
        AlertModel(
          id: 'mock_building_smoke',
          domain: 'building',
          nodeId: 1,
          severity: 'critical',
          title: 'Gas and Smoke Alert',
          message:
              'MQ2 smoke and MQ5 gas readings exceeded the configured safety range.',
          timestamp: now - 120,
          resolved: false,
          flags: flagAlert | flagEvent,
        ),
      if (bridgeDanger)
        AlertModel(
          id: 'mock_bridge_danger',
          domain: 'bridge',
          nodeId: 2,
          severity: 'critical',
          title: 'Bridge Danger Switch',
          message:
              'Danger switch telemetry closed the road and activated the buzzer.',
          timestamp: now - 240,
          resolved: false,
          flags: flagAlert | flagEvent | flagActuatorOn,
        ),
      if (waterLeak)
        AlertModel(
          id: 'mock_water_leak',
          domain: 'water',
          nodeId: 3,
          severity: 'critical',
          title: 'Water Leak Detected',
          message:
              'Tank level difference and pipe soil moisture indicate a probable leak.',
          timestamp: now - 360,
          resolved: false,
          flags: flagAlert | flagEvent | flagActuatorOn,
        ),
      if (lowBattery)
        AlertModel(
          id: 'mock_low_battery',
          domain: 'building',
          nodeId: 1,
          severity: 'warning',
          title: 'Low Battery',
          message:
              'Battery voltage dropped below the safe operating threshold.',
          timestamp: now - 540,
          resolved: false,
          flags: flagBatteryLow,
        ),
      if (sensorError)
        AlertModel(
          id: 'mock_sensor_error',
          domain: 'building',
          nodeId: 1,
          severity: 'warning',
          title: 'Sensor Error',
          message:
              'One or more environmental sensors reported invalid values in the SC1 packet.',
          timestamp: now - 720,
          resolved: false,
          flags: flagSensorError | flagEvent,
        ),
      AlertModel(
        id: 'mock_gateway_sync',
        domain: 'gateway',
        nodeId: 4,
        severity: 'info',
        title: 'Gateway Sync Healthy',
        message: 'ESP32 gateway is uploading node telemetry to Firebase.',
        timestamp: now - 1020,
        resolved: true,
        flags: 0,
      ),
      AlertModel(
        id: 'mock_air_history',
        domain: 'building',
        nodeId: 1,
        severity: 'warning',
        title: 'Air Quality Watch',
        message: 'MQ135 crossed the watch threshold earlier and recovered.',
        timestamp: now - 3200,
        resolved: true,
        flags: flagAlert,
      ),
    ];
  }
}
