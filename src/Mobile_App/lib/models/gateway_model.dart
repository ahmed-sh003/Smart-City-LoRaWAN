import '../core/utils/sc1_helpers.dart';

class NodeHealth {
  final String key;
  final String name;
  final bool reportedOnline;
  final int receivedPackets;
  final int lostPackets;
  final double pdr;
  final double rssi;
  final double snr;
  final int lastSeq;
  final int lastUpdate;
  final int batteryMv;

  const NodeHealth({
    required this.key,
    required this.name,
    required this.reportedOnline,
    required this.receivedPackets,
    required this.lostPackets,
    required this.pdr,
    required this.rssi,
    required this.snr,
    required this.lastSeq,
    required this.lastUpdate,
    this.batteryMv = 0,
  });

  bool get online => isOnlineFromLastUpdate(
        lastUpdate,
        reportedOnline: reportedOnline,
      );

  int get packets => receivedPackets;
  double get battery => batteryMv.toDouble();
  double get batteryPercent => batteryMvToPercent(batteryMv);
  String get lastUpdateLabel => formatTimeAgo(lastUpdate);

  factory NodeHealth.fromMap(
    String key,
    String name,
    Map<dynamic, dynamic> map, {
    Map<dynamic, dynamic>? nodeFallback,
  }) {
    final fallback = nodeFallback ?? const <dynamic, dynamic>{};
    return NodeHealth(
      key: key,
      name: name,
      reportedOnline:
          parseBool(map['online'] ?? fallback['online'], defaultValue: true),
      receivedPackets:
          parseInt(map['receivedPackets'] ?? map['packets'] ?? fallback['seq']),
      lostPackets: parseInt(map['lostPackets']),
      pdr: parseDouble(map['pdr']) ?? 0,
      rssi: parseDouble(map['rssi'] ?? fallback['rssi']) ?? 0,
      snr: parseDouble(map['snr'] ?? fallback['snr']) ?? 0,
      lastSeq: parseInt(map['lastSeq'] ?? fallback['seq']),
      lastUpdate: parseTimestamp(map['lastUpdate'] ?? fallback['lastUpdate']),
      batteryMv: parseInt(map['batteryMv'] ?? fallback['batteryMv']),
    );
  }

  factory NodeHealth.mock({
    required String key,
    required String name,
    required int receivedPackets,
    required int lostPackets,
    required double pdr,
    required double rssi,
    required double snr,
    required int lastSeq,
    required int batteryMv,
    int ageSeconds = 20,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return NodeHealth(
      key: key,
      name: name,
      reportedOnline: true,
      receivedPackets: receivedPackets,
      lostPackets: lostPackets,
      pdr: pdr,
      rssi: rssi,
      snr: snr,
      lastSeq: lastSeq,
      lastUpdate: now - ageSeconds,
      batteryMv: batteryMv,
    );
  }
}

class GatewayModel {
  final bool reportedOnline;
  final int uptime;
  final int totalPackets;
  final int connectedNodes;
  final String wifiStatus;
  final String firebaseStatus;
  final String lastRawPacket;
  final int lastUpdate;
  final String lastReceivedNode;
  final int nodeTimeoutSec;
  final NodeHealth buildingNode;
  final NodeHealth bridgeNode;
  final NodeHealth waterNode;

  const GatewayModel({
    required bool online,
    required this.uptime,
    required this.totalPackets,
    required this.connectedNodes,
    required this.wifiStatus,
    required this.firebaseStatus,
    required this.lastRawPacket,
    required this.lastUpdate,
    required this.lastReceivedNode,
    required this.nodeTimeoutSec,
    required this.buildingNode,
    required this.bridgeNode,
    required this.waterNode,
  }) : reportedOnline = online;

  bool get online => isOnlineFromLastUpdate(
        lastUpdate,
        reportedOnline: reportedOnline,
        timeout: Duration(seconds: nodeTimeoutSec <= 0 ? 120 : nodeTimeoutSec),
      );

  int get onlineNodes => connectedNodes > 0
      ? connectedNodes
      : [buildingNode.online, bridgeNode.online, waterNode.online]
          .where((online) => online)
          .length;

  int get lostNodes => 3 - onlineNodes.clamp(0, 3);

  double get averageRssi {
    final values = [buildingNode.rssi, bridgeNode.rssi, waterNode.rssi]
        .where((value) => value != 0)
        .toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double get averageSnr {
    final values = [buildingNode.snr, bridgeNode.snr, waterNode.snr]
        .where((value) => value != 0)
        .toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  String get lastUpdateLabel => formatTimestamp(lastUpdate);
  String get ageLabel => formatTimeAgo(lastUpdate);
  String get uptimeLabel => formatUptime(uptime);
  List<NodeHealth> get nodeHealth => [buildingNode, bridgeNode, waterNode];
  double get pdr {
    final values =
        nodeHealth.map((node) => node.pdr).where((value) => value > 0).toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  Map<String, int> get packetsPerNode => {
        'building': buildingNode.receivedPackets,
        'bridge': bridgeNode.receivedPackets,
        'water': waterNode.receivedPackets,
      };

  Map<String, int> get lostPackets => {
        'building': buildingNode.lostPackets,
        'bridge': bridgeNode.lostPackets,
        'water': waterNode.lostPackets,
      };

  Map<String, double> get rssiPerNode => {
        'building': buildingNode.rssi,
        'bridge': bridgeNode.rssi,
        'water': waterNode.rssi,
      };

  Map<String, double> get snrPerNode => {
        'building': buildingNode.snr,
        'bridge': bridgeNode.snr,
        'water': waterNode.snr,
      };

  factory GatewayModel.fromMap(
    Map<dynamic, dynamic> map, {
    Map<dynamic, dynamic>? nodesMap,
  }) {
    final nodeHealth = asMap(map['nodeHealth']);
    final pdr = asMap(map['pdr']);
    final nodes = nodesMap ?? const <dynamic, dynamic>{};

    NodeHealth buildNode(String key, String label) {
      final healthMap = asMap(nodeHealth[key]);
      if (healthMap.isEmpty && pdr.containsKey(key)) {
        healthMap['pdr'] = pdr[key];
      }
      return NodeHealth.fromMap(
        key,
        label,
        healthMap,
        nodeFallback: asMap(nodes[key]),
      );
    }

    return GatewayModel(
      online: parseBool(map['online'], defaultValue: true),
      uptime: parseInt(map['uptime'] ?? map['uptimeSec']),
      totalPackets: parseInt(map['totalPackets']),
      connectedNodes: parseInt(map['connectedNodes']),
      wifiStatus: (map['wifiStatus'] ?? 'Unknown').toString(),
      firebaseStatus: (map['firebaseStatus'] ?? 'Unknown').toString(),
      lastRawPacket: (map['lastRawPacket'] ?? '').toString(),
      lastUpdate: parseTimestamp(map['lastUpdate'] ?? map['lastSync']),
      lastReceivedNode: (map['lastReceivedNode'] ?? '').toString(),
      nodeTimeoutSec: parseInt(map['nodeTimeout'], defaultValue: 120),
      buildingNode: buildNode('building', 'Building'),
      bridgeNode: buildNode('bridge', 'Bridge'),
      waterNode: buildNode('water', 'Water'),
    );
  }

  factory GatewayModel.mock({
    bool offline = false,
    bool bridgeDanger = false,
    bool waterLeak = false,
    int tick = 0,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final total = 587 + tick * 3;
    final lastNode = waterLeak
        ? 'water'
        : bridgeDanger
            ? 'bridge'
            : 'building';
    return GatewayModel(
      online: !offline,
      uptime: 22100 + tick * 6,
      totalPackets: total,
      connectedNodes: offline ? 0 : 3,
      wifiStatus: offline ? 'Disconnected' : 'Connected',
      firebaseStatus: offline ? 'Upload paused' : 'Synced',
      lastRawPacket: waterLeak
          ? 'SC1|A|3|3|45|16410|19|0|86|78|50|28|1|0|D2'
          : bridgeDanger
              ? 'SC1|E|2|2|38|14320|19|11|13200|2|-1|0|0|0|7C'
              : 'SC1|P|1|1|42|18640|00|27.3|55|450|120|220|48|2500|1008.5|A41F',
      lastUpdate: now,
      lastReceivedNode: lastNode,
      nodeTimeoutSec: 120,
      buildingNode: NodeHealth.mock(
        key: 'building',
        name: 'Building',
        receivedPackets: 198 + tick,
        lostPackets: 2,
        pdr: 98.9,
        rssi: -68,
        snr: 9.1,
        lastSeq: 42 + tick,
        batteryMv: 3890,
        ageSeconds: 16,
      ),
      bridgeNode: NodeHealth.mock(
        key: 'bridge',
        name: 'Bridge',
        receivedPackets: 195 + tick,
        lostPackets: bridgeDanger ? 7 : 4,
        pdr: bridgeDanger ? 93.2 : 96.5,
        rssi: bridgeDanger ? -89 : -75,
        snr: bridgeDanger ? 5.6 : 7.2,
        lastSeq: 38 + tick,
        batteryMv: 3740,
        ageSeconds: 28,
      ),
      waterNode: NodeHealth.mock(
        key: 'water',
        name: 'Water',
        receivedPackets: 194 + tick,
        lostPackets: waterLeak ? 3 : 1,
        pdr: waterLeak ? 97.6 : 99.0,
        rssi: -68,
        snr: 9.4,
        lastSeq: 45 + tick,
        batteryMv: 3820,
        ageSeconds: 12,
      ),
    );
  }
}
