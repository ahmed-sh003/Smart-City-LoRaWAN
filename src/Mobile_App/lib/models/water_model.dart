import '../core/utils/sc1_helpers.dart';
import 'node_status.dart';

class WaterModel {
  final NodeStatus status;
  final bool rain;
  final double pipeSoil;
  final double tank1;
  final double tank2;
  final double difference;
  final int leakStatus;
  final double leakProbabilityOverride;
  final bool pumpOn;
  final double reserved;

  const WaterModel({
    required this.status,
    required this.rain,
    required this.pipeSoil,
    required this.tank1,
    required this.tank2,
    required this.difference,
    required this.leakStatus,
    required this.leakProbabilityOverride,
    required this.pumpOn,
    required this.reserved,
  });

  String get leakLabel {
    switch (leakStatus) {
      case 0:
        return 'No Leak';
      case 1:
        return 'Leak Suspected';
      case 2:
        return 'Critical Leak';
      default:
        return 'Unknown';
    }
  }

  int get batteryMv => status.batteryMv;
  double get batteryPercent => status.batteryPercent;
  double get rssi => status.rssi;
  double get snr => status.snr;
  int get seq => status.seq;
  int get uptimeSec => status.uptimeSec;
  int get flags => status.flags;
  bool get online => status.online;
  bool get alert => status.alert;
  int get lastUpdate => status.lastUpdate;
  String get lastRawPacket => status.lastRawPacket;

  bool get hasLeak => leakStatus > 0;

  bool get hasAlert =>
      status.effectiveAlert || hasLeak || leakProbability >= 70;

  double get leakProbability {
    if (leakProbabilityOverride >= 0) return leakProbabilityOverride;
    if (leakStatus >= 2) return 95;
    if (leakStatus == 1) return 76;
    if (difference > 20) return 90;
    if (difference > 10) return 65;
    if (pipeSoil > 75) return 45;
    if (pipeSoil > 55 && rain) return 28;
    return 5;
  }

  factory WaterModel.fromMap(Map<dynamic, dynamic> map) {
    final values = asMap(map['values']);
    final raw = rawValuesFrom(values);
    final hasExplicitTank =
        values.containsKey('tank1') || values.containsKey('tank2');
    final promptRawMapping =
        !hasExplicitTank && raw.length >= 6 && raw[0] >= 0 && raw[0] <= 1;

    final explicitLeak = values['leakStatus'];
    int leakStatusFrom(dynamic value) {
      if (value is bool) return value ? 1 : 0;
      final parsed = parseInt(value);
      return parsed.clamp(0, 2);
    }

    return WaterModel(
      status: NodeStatus.fromMap(
        map,
        defaultNodeId: 3,
        defaultDomain: 3,
      ),
      rain: values.containsKey('rain')
          ? parseRain(values['rain'])
          : (promptRawMapping ? parseRain(raw[0]) : false),
      pipeSoil: mapDouble(values, ['pipeSoil', 'soil', 'soilWet'],
              raw: raw, rawIndex: promptRawMapping ? 1 : 4) ??
          0,
      tank1: mapDouble(values, ['tank1', 'tank1Level'],
              raw: raw, rawIndex: promptRawMapping ? 2 : 0) ??
          0,
      tank2: mapDouble(values, ['tank2', 'tank2Level'],
              raw: raw, rawIndex: promptRawMapping ? 3 : 1) ??
          0,
      difference: mapDouble(values, ['difference', 'missing', 'delta'],
              raw: raw, rawIndex: promptRawMapping ? 4 : 3) ??
          0,
      leakStatus: explicitLeak != null
          ? leakStatusFrom(explicitLeak)
          : leakStatusFrom(raw.length > 5 ? raw[5] : 0),
      leakProbabilityOverride:
          mapDouble(values, ['leakProbability', 'leakProbabilityPercent']) ??
              -1,
      pumpOn: mapBool(values, ['pumpOn', 'actuatorOn'],
          raw: raw, rawIndex: promptRawMapping ? 6 : 6),
      reserved: mapDouble(values, ['reserved'],
              raw: raw, rawIndex: promptRawMapping ? 6 : 6) ??
          0,
    );
  }

  factory WaterModel.mock({
    bool alertMode = false,
    bool lowBattery = false,
    bool sensorError = false,
    bool waterLeak = false,
    int seq = 45,
  }) {
    var flags = 0;
    if (alertMode || waterLeak) flags |= flagAlert;
    if (lowBattery) flags |= flagBatteryLow;
    if (sensorError) flags |= flagSensorError;
    if (alertMode || waterLeak || sensorError) flags |= flagEvent;
    if (waterLeak) flags |= flagActuatorOn;
    final tank1 = waterLeak ? 78.0 : 80.0;
    final tank2 = waterLeak ? 50.0 : 78.0;
    final diff = (tank1 - tank2).abs();
    return WaterModel(
      status: NodeStatus.mock(
        alert: alertMode || waterLeak || sensorError || lowBattery,
        nodeId: 3,
        domain: 3,
        seq: seq,
        uptimeSec: 16410,
        batteryMv: lowBattery ? 3170 : 3820,
        flags: flags,
        rssi: -68,
        snr: 9.4,
        lastRawPacket:
            'SC1|A|3|3|$seq|16410|${flags.toRadixString(16).padLeft(2, '0').toUpperCase()}|0|${waterLeak ? 86 : 34}|${tank1.toStringAsFixed(0)}|${tank2.toStringAsFixed(0)}|${diff.toStringAsFixed(0)}|${waterLeak ? 1 : 0}|0|D2',
      ),
      rain: alertMode,
      pipeSoil: waterLeak ? 86 : 34,
      tank1: tank1,
      tank2: tank2,
      difference: diff,
      leakStatus: waterLeak ? 2 : 0,
      leakProbabilityOverride: waterLeak ? 94 : -1,
      pumpOn: waterLeak,
      reserved: 0,
    );
  }
}
