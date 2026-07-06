import '../core/utils/sc1_helpers.dart';

class NodeStatus {
  final bool reportedOnline;
  final bool alert;
  final String packetType;
  final int nodeId;
  final int domain;
  final int seq;
  final int uptimeSec;
  final int batteryMv;
  final int flags;
  final double rssi;
  final double snr;
  final int lastUpdate;
  final String lastRawPacket;

  const NodeStatus({
    bool online = true,
    required this.alert,
    required this.packetType,
    required this.nodeId,
    required this.domain,
    required this.seq,
    required this.uptimeSec,
    required this.batteryMv,
    required this.flags,
    required this.rssi,
    required this.snr,
    required this.lastUpdate,
    required this.lastRawPacket,
  }) : reportedOnline = online;

  bool get online => isOnlineFromLastUpdate(
        lastUpdate,
        reportedOnline: reportedOnline,
      );

  double get batteryPercent => batteryMvToPercent(batteryMv);

  String get batteryPercentStr =>
      batteryMv <= 0 ? 'N/A' : '${batteryPercent.toStringAsFixed(0)}%';

  bool get hasBattery => batteryMv > 0;
  bool get hasAlertFlag => hasAlertFlagFromFlags;
  bool get hasAlertFlagFromFlags => hasAlertFlagHelper(flags);
  bool get lowBattery =>
      isLowBattery(flags) || (hasBattery && batteryPercent <= 20);
  bool get sensorError => hasSensorError(flags);
  bool get eventPacket => isEventPacket(flags);
  bool get actuatorActive => isActuatorActive(flags);
  bool get effectiveAlert => alert || hasAlertFlagFromFlags || sensorError;
  List<String> get decodedFlags => decodeFlags(flags);
  String get flagSummary =>
      decodedFlags.isEmpty ? 'No flags' : decodedFlags.join(', ');
  String get lastUpdateLabel => formatTimestamp(lastUpdate);
  String get ageLabel => formatTimeAgo(lastUpdate);
  String get uptimeLabel => formatUptime(uptimeSec);

  factory NodeStatus.fromMap(
    Map<dynamic, dynamic> map, {
    required int defaultNodeId,
    required int defaultDomain,
  }) {
    final flags = parseFlags(map['flags']);
    final explicitAlert = parseBool(map['alert']);
    final batteryMv = parseInt(map['batteryMv']);
    return NodeStatus(
      online: parseBool(map['online'], defaultValue: true),
      alert: explicitAlert ||
          hasAlertFlagHelper(flags) ||
          hasSensorError(flags) ||
          isLowBattery(flags),
      packetType: (map['packetType'] ?? map['type'] ?? 'P').toString(),
      nodeId:
          parseInt(map['nodeId'] ?? map['node'], defaultValue: defaultNodeId),
      domain: parseInt(map['domain'], defaultValue: defaultDomain),
      seq: parseInt(map['seq']),
      uptimeSec: parseInt(map['uptimeSec'] ?? map['uptime']),
      batteryMv: batteryMv,
      flags: flags,
      rssi: parseDouble(map['rssi']) ?? 0,
      snr: parseDouble(map['snr']) ?? 0,
      lastUpdate: parseTimestamp(map['lastUpdate'] ?? map['timestamp']),
      lastRawPacket: (map['lastRawPacket'] ?? '').toString(),
    );
  }

  factory NodeStatus.mock({
    bool online = true,
    bool alert = false,
    String packetType = 'P',
    required int nodeId,
    required int domain,
    int seq = 1,
    int uptimeSec = 0,
    int batteryMv = 3800,
    int flags = 0,
    double rssi = -70,
    double snr = 8.5,
    String lastRawPacket = '',
  }) {
    final effectiveFlags = alert ? (flags | flagAlert) : flags;
    return NodeStatus(
      online: online,
      alert: alert ||
          hasAlertFlagHelper(effectiveFlags) ||
          hasSensorError(effectiveFlags) ||
          isLowBattery(effectiveFlags),
      packetType: packetType,
      nodeId: nodeId,
      domain: domain,
      seq: seq,
      uptimeSec: uptimeSec,
      batteryMv: batteryMv,
      flags: effectiveFlags,
      rssi: rssi,
      snr: snr,
      lastUpdate: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      lastRawPacket: lastRawPacket,
    );
  }
}

bool hasAlertFlagHelper(int flags) => (flags & flagAlert) != 0;
