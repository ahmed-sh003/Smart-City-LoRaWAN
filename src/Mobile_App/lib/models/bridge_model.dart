import '../core/utils/sc1_helpers.dart';
import 'node_status.dart';

class BridgeModel {
  final NodeStatus status;
  final int carsInside;
  final int carsEntered;
  final int carsExited;
  final double loadKg;
  final int riskState;
  final bool dangerSwitch1;
  final bool dangerSwitch2;
  final bool dangerSwitch3;
  final bool dangerSwitch4;
  final bool gateIn;
  final bool gateOut;
  final bool buzzer;
  final String roadStatusOverride;
  final int capacityLimit;

  const BridgeModel({
    required this.status,
    required this.carsInside,
    required this.carsEntered,
    required this.carsExited,
    required this.loadKg,
    required this.riskState,
    required this.dangerSwitch1,
    required this.dangerSwitch2,
    required this.dangerSwitch3,
    required this.dangerSwitch4,
    required this.gateIn,
    required this.gateOut,
    required this.buzzer,
    required this.roadStatusOverride,
    this.capacityLimit = 10,
  });

  int get carsIn => carsEntered;
  int get carsOut => carsExited;
  bool get switch1 => dangerSwitch1;
  bool get switch2 => dangerSwitch2;
  bool get switch3 => dangerSwitch3;
  bool get switch4 => dangerSwitch4;
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

  bool get anyDangerSwitch =>
      dangerSwitch1 || dangerSwitch2 || dangerSwitch3 || dangerSwitch4;

  bool get overloadAlert => carsInside >= capacityLimit || loadKg >= 9600;
  bool get dangerSwitchAlert => anyDangerSwitch || riskState >= 2;
  bool get hasAlert =>
      status.effectiveAlert || overloadAlert || dangerSwitchAlert || buzzer;

  String get roadStatus {
    final normalized = normalizeRoadStatus(roadStatusOverride);
    if (normalized.isNotEmpty) return normalized;
    if (dangerSwitchAlert || buzzer) return 'DANGER DETECTED';
    if (!gateIn && !gateOut) return 'ROAD CLOSED';
    return 'ROAD OPEN';
  }

  double get occupancyPercent =>
      (carsInside / capacityLimit * 100).clamp(0, 100);

  String get riskLabel {
    if (riskState >= 3) return 'Sensor Fault';
    if (riskState >= 2) return 'Danger';
    if (riskState >= 1 || overloadAlert) return 'Overload';
    return 'Normal';
  }

  factory BridgeModel.fromMap(Map<dynamic, dynamic> map) {
    final values = asMap(map['values']);
    final raw = rawValuesFrom(values);
    final v2 = raw.length > 1 ? raw[1] : 0;
    final v3 = raw.length > 2 ? raw[2] : 0;
    final v4 = raw.length > 3 ? raw[3] : 0;
    final v5 = raw.length > 4 ? raw[4] : 0;
    final v6 = raw.length > 5 ? raw[5] : null;
    final v7 = raw.length > 6 ? raw[6] : null;
    final hasExplicitCounters =
        values.containsKey('carsEntered') || values.containsKey('carsExited');
    final legacyLoadRiskTilt =
        !hasExplicitCounters && (v2 > 20 || (v3 >= 0 && v3 <= 3));
    final switchAggregate =
        mapInt(values, ['switchAggregate', 'dangerSwitchMask', 'switchMask']);
    final tiltX = mapDouble(values, ['tiltX'], raw: raw, rawIndex: 3) ?? v4;
    final tiltY = mapDouble(values, ['tiltY'], raw: raw, rawIndex: 4) ?? v5;
    final riskState =
        mapInt(values, ['riskState', 'dangerState'], raw: raw, rawIndex: 2) ??
            0;
    final gateValue = parseBool(v7);

    bool switchFromBit(int bit, bool fallback) {
      if (switchAggregate != null) return (switchAggregate & bit) != 0;
      return fallback;
    }

    return BridgeModel(
      status: NodeStatus.fromMap(
        map,
        defaultNodeId: 2,
        defaultDomain: 2,
      ),
      carsInside:
          mapInt(values, ['carsInside', 'carCount'], raw: raw, rawIndex: 0) ??
              0,
      carsEntered: mapInt(values, ['carsEntered', 'carsIn', 'entered']) ??
          (legacyLoadRiskTilt ? 0 : (v4 > 1 ? v4.round() : 0)),
      carsExited: mapInt(values, ['carsExited', 'carsOut', 'exited']) ??
          (legacyLoadRiskTilt ? 0 : (v5 > 1 ? v5.round() : 0)),
      loadKg: mapDouble(values, ['loadKg', 'load'], raw: raw, rawIndex: 1) ?? 0,
      riskState: riskState,
      dangerSwitch1: mapBool(values, ['dangerSwitch1', 'switch1']) ||
          switchFromBit(0x01, tiltX < 0),
      dangerSwitch2: mapBool(values, ['dangerSwitch2', 'switch2']) ||
          switchFromBit(0x02, tiltY < 0),
      dangerSwitch3: mapBool(values, ['dangerSwitch3', 'switch3']) ||
          switchFromBit(0x04, tiltX > 0),
      dangerSwitch4: mapBool(values, ['dangerSwitch4', 'switch4']) ||
          switchFromBit(0x08, tiltY > 0),
      gateIn: values.containsKey('gateIn')
          ? mapBool(values, ['gateIn'])
          : (legacyLoadRiskTilt ? gateValue : parseBool(v6)),
      gateOut: values.containsKey('gateOut')
          ? mapBool(values, ['gateOut'])
          : gateValue,
      buzzer: mapBool(values, ['buzzer']) || riskState > 0,
      roadStatusOverride: mapString(values, ['roadStatus']) ?? '',
      capacityLimit: mapInt(values, ['capacityLimit', 'maxCars']) ??
          parseInt(map['capacityLimit'], defaultValue: 10),
    );
  }

  factory BridgeModel.mock({
    bool alertMode = false,
    bool lowBattery = false,
    bool sensorError = false,
    bool bridgeDanger = false,
    int seq = 38,
  }) {
    var flags = 0;
    if (alertMode || bridgeDanger) flags |= flagAlert;
    if (lowBattery) flags |= flagBatteryLow;
    if (sensorError) flags |= flagSensorError;
    if (alertMode || bridgeDanger || sensorError) flags |= flagEvent;
    if (bridgeDanger || alertMode) flags |= flagActuatorOn;
    final cars = bridgeDanger ? 11 : (alertMode ? 9 : 3);
    final gatesOpen = !(bridgeDanger || alertMode);
    return BridgeModel(
      status: NodeStatus.mock(
        alert: alertMode || bridgeDanger || sensorError || lowBattery,
        nodeId: 2,
        domain: 2,
        seq: seq,
        uptimeSec: 14320,
        batteryMv: lowBattery ? 3150 : 3740,
        flags: flags,
        rssi: bridgeDanger ? -89 : -75,
        snr: bridgeDanger ? 5.6 : 7.2,
        lastRawPacket:
            'SC1|E|2|2|$seq|14320|${flags.toRadixString(16).padLeft(2, '0').toUpperCase()}|$cars|${cars * 1200}|${bridgeDanger ? 2 : 0}|${bridgeDanger ? -1 : 0}|0|0|${gatesOpen ? 1 : 0}|7C',
      ),
      carsInside: cars,
      carsEntered: bridgeDanger ? 22 : 10,
      carsExited: bridgeDanger ? 11 : 7,
      loadKg: cars * 1200,
      riskState: bridgeDanger ? 2 : (alertMode ? 1 : 0),
      dangerSwitch1: bridgeDanger,
      dangerSwitch2: false,
      dangerSwitch3: false,
      dangerSwitch4: bridgeDanger && alertMode,
      gateIn: gatesOpen,
      gateOut: gatesOpen,
      buzzer: bridgeDanger,
      roadStatusOverride: bridgeDanger
          ? 'DANGER DETECTED'
          : gatesOpen
              ? 'ROAD OPEN'
              : 'ROAD CLOSED',
    );
  }
}
