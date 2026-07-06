import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/gateway_model.dart';
import '../../models/node_status.dart';
import '../../providers/dashboard_provider.dart';
import '../theme/app_colors.dart';
import 'status_chip.dart';

enum _ArchitectureFilter { all, nodes, gateway, protocol, energy }

class SystemArchitectureSection extends StatefulWidget {
  final DashboardProvider provider;

  const SystemArchitectureSection({
    super.key,
    required this.provider,
  });

  @override
  State<SystemArchitectureSection> createState() =>
      _SystemArchitectureSectionState();
}

class _SystemArchitectureSectionState extends State<SystemArchitectureSection> {
  _ArchitectureFilter _filter = _ArchitectureFilter.all;

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final building = _NodeTelemetry.fromStatus(
      title: 'Building',
      subtitle: 'DHT11, BMP280, MQ, soil, rain',
      icon: Icons.apartment_rounded,
      color: AppColors.buildingColor,
      status: provider.building?.status,
      health: provider.gateway?.buildingNode,
    );
    final bridge = _NodeTelemetry.fromStatus(
      title: 'Bridge',
      subtitle: 'IR counters, gates, buzzer',
      icon: Icons.alt_route_rounded,
      color: AppColors.bridgeColor,
      status: provider.bridge?.status,
      health: provider.gateway?.bridgeNode,
    );
    final water = _NodeTelemetry.fromStatus(
      title: 'Water',
      subtitle: 'Rain, pipe soil, tanks',
      icon: Icons.water_drop_rounded,
      color: AppColors.waterColor,
      status: provider.water?.status,
      health: provider.gateway?.waterNode,
    );

    final cards = <_ArchitectureTile>[
      _ArchitectureTile(
        filter: _ArchitectureFilter.all,
        child: _LiveLoRaStarTopologyCard(
          nodes: [building, bridge, water],
          gateway: provider.gateway,
        ),
        fullWidth: true,
      ),
      _ArchitectureTile(
        filter: _ArchitectureFilter.nodes,
        child: _BuildingNodeArchitectureCard(status: provider.building?.status),
      ),
      _ArchitectureTile(
        filter: _ArchitectureFilter.nodes,
        child: _BridgeNodeArchitectureCard(
          status: provider.bridge?.status,
          carsInside: provider.bridge?.carsInside ?? 0,
          capacityLimit: provider.bridge?.capacityLimit ?? 10,
          roadStatus: provider.bridge?.roadStatus ?? 'ROAD OPEN',
        ),
      ),
      _ArchitectureTile(
        filter: _ArchitectureFilter.nodes,
        child: _WaterNodeArchitectureCard(status: provider.water?.status),
      ),
      _ArchitectureTile(
        filter: _ArchitectureFilter.gateway,
        child: _GatewayFlowArchitectureCard(gateway: provider.gateway),
        fullWidth: true,
      ),
      const _ArchitectureTile(
        filter: _ArchitectureFilter.protocol,
        child: _Sc1ProtocolArchitectureCard(),
      ),
      const _ArchitectureTile(
        filter: _ArchitectureFilter.energy,
        child: _EnergyEfficiencyArchitectureCard(),
      ),
    ];

    final visible = cards
        .where((tile) =>
            _filter == _ArchitectureFilter.all ||
            tile.filter == _filter ||
            tile.filter == _ArchitectureFilter.all)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ArchitectureHeader(
          cityStatus: provider.cityStatus,
          totalPackets: provider.gateway?.totalPackets ?? 0,
          onlineNodes: provider.totalOnlineNodes,
        ),
        const SizedBox(height: 12),
        _ArchitectureFilterBar(
          value: _filter,
          onChanged: (value) => setState(() => _filter = value),
        ),
        const SizedBox(height: 14),
        _ArchitectureGrid(tiles: visible),
      ],
    );
  }
}

class _ArchitectureTile {
  final _ArchitectureFilter filter;
  final Widget child;
  final bool fullWidth;

  const _ArchitectureTile({
    required this.filter,
    required this.child,
    this.fullWidth = false,
  });
}

class _ArchitectureHeader extends StatelessWidget {
  final String cityStatus;
  final int totalPackets;
  final int onlineNodes;

  const _ArchitectureHeader({
    required this.cityStatus,
    required this.totalPackets,
    required this.onlineNodes,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = cityStatus == 'SAFE'
        ? AppColors.successGreen
        : cityStatus == 'WARNING'
            ? AppColors.warningOrange
            : AppColors.dangerRed;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: AppColors.cardGradient,
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.neonBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.neonBlue.withOpacity(0.2)),
                ),
                child: const Icon(
                  Icons.account_tree_rounded,
                  color: AppColors.neonBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Architecture',
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Hardware, SC1 packet flow, LoRa gateway, Firebase, and Flutter live UI.',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              _DarkStatPill(
                label: cityStatus,
                value: '$onlineNodes/3',
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DarkBadge(
                label: 'SX1278 433MHz',
                icon: Icons.settings_input_antenna_rounded,
                color: AppColors.neonBlue,
              ),
              _DarkBadge(
                label: 'ESP32 Gateway',
                icon: Icons.router_rounded,
                color: AppColors.gatewayColor,
              ),
              _DarkBadge(
                label: 'Firebase RTDB',
                icon: Icons.cloud_sync_rounded,
                color: AppColors.successGreen,
              ),
              _DarkBadge(
                label: '$totalPackets Packets',
                icon: Icons.swap_horiz_rounded,
                color: AppColors.warningOrange,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArchitectureFilterBar extends StatelessWidget {
  final _ArchitectureFilter value;
  final ValueChanged<_ArchitectureFilter> onChanged;

  const _ArchitectureFilterBar({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filters = [
      (
        filter: _ArchitectureFilter.all,
        label: 'All',
        icon: Icons.auto_awesome_rounded
      ),
      (
        filter: _ArchitectureFilter.nodes,
        label: 'Nodes',
        icon: Icons.sensors_rounded
      ),
      (
        filter: _ArchitectureFilter.gateway,
        label: 'Gateway',
        icon: Icons.router_rounded
      ),
      (
        filter: _ArchitectureFilter.protocol,
        label: 'SC1',
        icon: Icons.code_rounded
      ),
      (
        filter: _ArchitectureFilter.energy,
        label: 'Power',
        icon: Icons.battery_charging_full_rounded
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final item in filters) ...[
            _ArchitectureFilterPill(
              label: item.label,
              icon: item.icon,
              selected: value == item.filter,
              onTap: () => onChanged(item.filter),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ArchitectureGrid extends StatelessWidget {
  final List<_ArchitectureTile> tiles;

  const _ArchitectureGrid({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 860;
        if (!twoColumns) {
          return Column(
            children: [
              for (final tile in tiles) ...[
                tile.child,
                const SizedBox(height: 14),
              ],
            ],
          );
        }
        final rows = <Widget>[];
        for (var i = 0; i < tiles.length; i++) {
          final tile = tiles[i];
          if (tile.fullWidth) {
            rows.add(tile.child);
            rows.add(const SizedBox(height: 14));
            continue;
          }
          final next = i + 1 < tiles.length ? tiles[i + 1] : null;
          if (next != null && !next.fullWidth) {
            rows.add(Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: tile.child),
                const SizedBox(width: 14),
                Expanded(child: next.child),
              ],
            ));
            rows.add(const SizedBox(height: 14));
            i++;
          } else {
            rows.add(Row(
              children: [
                Expanded(child: tile.child),
                const SizedBox(width: 14),
                const Expanded(child: SizedBox.shrink()),
              ],
            ));
            rows.add(const SizedBox(height: 14));
          }
        }
        return Column(children: rows);
      },
    );
  }
}

class _LiveLoRaStarTopologyCard extends StatefulWidget {
  final List<_NodeTelemetry> nodes;
  final GatewayModel? gateway;

  const _LiveLoRaStarTopologyCard({
    required this.nodes,
    required this.gateway,
  });

  @override
  State<_LiveLoRaStarTopologyCard> createState() =>
      _LiveLoRaStarTopologyCardState();
}

class _LiveLoRaStarTopologyCardState extends State<_LiveLoRaStarTopologyCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gateway = widget.gateway;
    return _ArchitectureCardShell(
      title: 'Live LoRa Star Topology',
      subtitle:
          'Building, Bridge, and Water nodes send SX1278 433MHz packets to ESP32 Gateway, then Firebase updates Flutter.',
      icon: Icons.hub_rounded,
      color: AppColors.gatewayColor,
      badge: 'LIVE',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          final height = compact ? 440.0 : 330.0;
          return Column(
            children: [
              SizedBox(
                height: height,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _TopologyPainter(
                              animation: _controller.value,
                              compact: compact,
                              nodes: widget.nodes,
                              gatewayOnline: gateway?.online ?? false,
                            ),
                          ),
                        ),
                        for (var i = 0; i < widget.nodes.length; i++)
                          _TopologyPositionedNode(
                            telemetry: widget.nodes[i],
                            index: i,
                            compact: compact,
                          ),
                        _TopologyPositionedBox(
                          compact: compact,
                          alignment: compact
                              ? const Alignment(0, -0.05)
                              : const Alignment(-0.02, 0),
                          width: compact ? 150 : 164,
                          child: _TopologyCoreBox(
                            title: 'ESP32 Gateway',
                            subtitle: '${gateway?.onlineNodes ?? 0}/3 nodes',
                            icon: Icons.router_rounded,
                            color: AppColors.gatewayColor,
                            online: gateway?.online ?? false,
                          ),
                        ),
                        _TopologyPositionedBox(
                          compact: compact,
                          alignment: compact
                              ? const Alignment(0, 0.55)
                              : const Alignment(0.55, -0.28),
                          width: 142,
                          child: _TopologyCoreBox(
                            title: 'Firebase',
                            subtitle: gateway?.firebaseStatus ?? 'Waiting',
                            icon: Icons.cloud_sync_rounded,
                            color: AppColors.successGreen,
                            online: gateway?.firebaseStatus
                                    .toLowerCase()
                                    .contains('sync') ??
                                false,
                          ),
                        ),
                        _TopologyPositionedBox(
                          compact: compact,
                          alignment: compact
                              ? const Alignment(0, 0.96)
                              : const Alignment(0.9, 0.28),
                          width: 142,
                          child: _TopologyCoreBox(
                            title: 'Flutter App',
                            subtitle: 'Live UI',
                            icon: Icons.phone_android_rounded,
                            color: AppColors.neonBlue,
                            online: true,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricPill(
                    label: 'Total Packets',
                    value: '${gateway?.totalPackets ?? 0}',
                    color: AppColors.gatewayColor,
                  ),
                  _MetricPill(
                    label: 'Avg RSSI',
                    value:
                        '${gateway?.averageRssi.toStringAsFixed(0) ?? '--'} dBm',
                    color: AppColors.neonBlue,
                  ),
                  _MetricPill(
                    label: 'Avg SNR',
                    value:
                        '${gateway?.averageSnr.toStringAsFixed(1) ?? '--'} dB',
                    color: AppColors.waterColor,
                  ),
                  _MetricPill(
                    label: 'WiFi',
                    value: gateway?.wifiStatus ?? 'Unknown',
                    color: AppColors.successGreen,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BuildingNodeArchitectureCard extends StatelessWidget {
  final NodeStatus? status;

  const _BuildingNodeArchitectureCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return _NodeArchitectureCard(
      title: 'Building & Irrigation Node',
      subtitle:
          'ESP32 + SX1278 + ST7789 with environmental and irrigation sensors.',
      icon: Icons.apartment_rounded,
      color: AppColors.buildingColor,
      status: status,
      core: 'ESP32',
      radio: 'SX1278 433MHz',
      display: 'ST7789 TFT',
      components: const [
        'DHT11 temp/humidity',
        'BMP280 pressure',
        'MQ135 air quality',
        'MQ2 smoke',
        'MQ5 gas',
        'Soil moisture',
        'Rain sensor',
        'Battery monitor',
      ],
      flow: const [
        'Wake Up',
        'Read Sensors',
        'Check Alerts',
        'Build SC1 Packet',
        'Send LoRa',
        'Sleep',
      ],
      mapping: const [
        ('v1', 'temperature'),
        ('v2', 'humidity'),
        ('v3', 'air quality'),
        ('v4', 'smoke'),
        ('v5', 'soil moisture'),
        ('v6', 'rain'),
        ('v7', 'pressure'),
      ],
    );
  }
}

class _BridgeNodeArchitectureCard extends StatelessWidget {
  final NodeStatus? status;
  final int carsInside;
  final int capacityLimit;
  final String roadStatus;

  const _BridgeNodeArchitectureCard({
    required this.status,
    required this.carsInside,
    required this.capacityLimit,
    required this.roadStatus,
  });

  @override
  Widget build(BuildContext context) {
    return _NodeArchitectureCard(
      title: 'Bridge / Road Node',
      subtitle:
          'Arduino UNO + SX1278 + LCD 20x4 with counters, danger switches, gates, and buzzer.',
      icon: Icons.alt_route_rounded,
      color: AppColors.bridgeColor,
      status: status,
      core: 'Arduino UNO',
      radio: 'SX1278 433MHz',
      display: 'LCD 20x4',
      components: const [
        'IR sensor IN',
        'IR sensor OUT',
        '4 danger switches',
        'Entry servo gate',
        'Exit servo gate',
        'Buzzer output',
        'Battery monitor',
      ],
      flow: const [
        'Read IR In/Out',
        'Count Cars',
        'Read Danger Switches',
        'Decide Road Status',
        'Control Gates/Buzzer',
        'Send LoRa',
      ],
      logicTitle: 'Road Safety Logic',
      logic:
          'If any danger switch is active OR car count exceeds limit, close gates, activate buzzer, and send an alert packet.',
      mapping: [
        ('cars', '$carsInside / $capacityLimit inside'),
        ('status', roadStatus),
        ('actuator', status?.actuatorActive == true ? 'active' : 'clear'),
      ],
    );
  }
}

class _WaterNodeArchitectureCard extends StatelessWidget {
  final NodeStatus? status;

  const _WaterNodeArchitectureCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return _NodeArchitectureCard(
      title: 'Water Network Node',
      subtitle:
          'ESP32 + SX1278 + LCD 16x2 monitoring rain, pipe soil, tanks, and leak state.',
      icon: Icons.water_drop_rounded,
      color: AppColors.waterColor,
      status: status,
      core: 'ESP32',
      radio: 'SX1278 433MHz',
      display: 'LCD 16x2',
      components: const [
        'Rain sensor',
        'Pipe soil moisture',
        'Tank 1 level',
        'Tank 2 level',
        'Battery monitor',
      ],
      flow: const [
        'Read Rain',
        'Read Pipe Soil',
        'Read Tank Levels',
        'Compare Difference',
        'Detect Leak',
        'Send LoRa',
      ],
      logicTitle: 'Leak Logic',
      logic:
          'Leak detected if tank difference > 20% OR pipe soil is wet while no rain is detected.',
      mapping: const [
        ('v1', 'rain'),
        ('v2', 'pipe soil'),
        ('v3', 'tank1'),
        ('v4', 'tank2'),
        ('v5', 'difference'),
        ('v6', 'leak status'),
        ('v7', 'reserved'),
      ],
    );
  }
}

class _GatewayFlowArchitectureCard extends StatelessWidget {
  final GatewayModel? gateway;

  const _GatewayFlowArchitectureCard({required this.gateway});

  @override
  Widget build(BuildContext context) {
    final avgPdr = _average([
      gateway?.buildingNode.pdr ?? 0,
      gateway?.bridgeNode.pdr ?? 0,
      gateway?.waterNode.pdr ?? 0,
    ]);
    return _ArchitectureCardShell(
      title: 'Gateway Flow',
      subtitle:
          'ESP32 receiver validates SC1 packets, updates local TFT, uploads Firebase, then Flutter updates live.',
      icon: Icons.router_rounded,
      color: AppColors.gatewayColor,
      badge: gateway?.firebaseStatus ?? 'Gateway',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ProcessFlow(
            steps: [
              'Receive LoRa Packet',
              'Validate CRC',
              'Parse SC1',
              'Identify Domain',
              'Update TFT',
              'Upload Firebase',
              'Flutter App Updates Live',
            ],
            color: AppColors.gatewayColor,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(
                label: 'Total',
                value: '${gateway?.totalPackets ?? 0}',
                color: AppColors.gatewayColor,
              ),
              _MetricPill(
                label: 'PDR',
                value: '${avgPdr.toStringAsFixed(1)}%',
                color: AppColors.successGreen,
              ),
              _MetricPill(
                label: 'RSSI',
                value: '${gateway?.averageRssi.toStringAsFixed(0) ?? '--'} dBm',
                color: AppColors.neonBlue,
              ),
              _MetricPill(
                label: 'SNR',
                value: '${gateway?.averageSnr.toStringAsFixed(1) ?? '--'} dB',
                color: AppColors.waterColor,
              ),
              _MetricPill(
                label: 'Firebase',
                value: gateway?.firebaseStatus ?? 'Unknown',
                color: AppColors.warningOrange,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CodeBlock(
            title: 'Last Raw Packet',
            code: gateway?.lastRawPacket.isNotEmpty == true
                ? gateway!.lastRawPacket
                : 'Waiting for SC1 packet...',
          ),
        ],
      ),
    );
  }
}

class _Sc1ProtocolArchitectureCard extends StatelessWidget {
  const _Sc1ProtocolArchitectureCard();

  @override
  Widget build(BuildContext context) {
    return _ArchitectureCardShell(
      title: 'SC1 Protocol',
      subtitle:
          'Fixed packet contract used by all sender nodes and the gateway.',
      icon: Icons.code_rounded,
      color: AppColors.neonBlue,
      badge: 'XOR CRC',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CodeBlock(
            title: 'Packet Format',
            code:
                'SC1|type|nodeId|domain|seq|uptimeSec|batteryMv|flags|v1|v2|v3|v4|v5|v6|v7|crc',
          ),
          const SizedBox(height: 12),
          _InfoGrid(
            items: const [
              ('type P', 'periodic packet'),
              ('type A', 'alert packet'),
              ('domain 1', 'Building'),
              ('domain 2', 'Bridge'),
              ('domain 3', 'Water'),
              ('CRC', 'XOR checksum'),
            ],
            color: AppColors.neonBlue,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _ProtocolFlag(label: 'Alert', color: AppColors.dangerRed),
              _ProtocolFlag(
                  label: 'Low Battery', color: AppColors.warningOrange),
              _ProtocolFlag(label: 'Sensor Error', color: AppColors.dangerRed),
              _ProtocolFlag(
                  label: 'Event Packet', color: AppColors.gatewayColor),
              _ProtocolFlag(
                  label: 'Actuator Active', color: AppColors.successGreen),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnergyEfficiencyArchitectureCard extends StatelessWidget {
  const _EnergyEfficiencyArchitectureCard();

  @override
  Widget build(BuildContext context) {
    return _ArchitectureCardShell(
      title: 'Energy Efficiency',
      subtitle:
          'Duty-cycled sensing keeps field nodes battery friendly while event packets remain responsive.',
      icon: Icons.battery_charging_full_rounded,
      color: AppColors.successGreen,
      badge: 'LOW POWER',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ProcessFlow(
            steps: ['Sleep', 'Wake Up', 'Measure', 'Transmit', 'Sleep'],
            color: AppColors.successGreen,
          ),
          const SizedBox(height: 14),
          _InfoGrid(
            items: const [
              ('Duty Cycle', 'wake only when needed'),
              ('Alerts', 'event-driven packets'),
              ('Battery', 'mV plus percentage'),
              ('Strategy', 'short radio airtime'),
            ],
            color: AppColors.successGreen,
          ),
          const SizedBox(height: 12),
          Text(
            'Every node reports batteryMv in SC1, so Flutter can show low battery flags and estimate charge without changing the embedded protocol.',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeArchitectureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final NodeStatus? status;
  final String core;
  final String radio;
  final String display;
  final List<String> components;
  final List<String> flow;
  final List<(String, String)> mapping;
  final String? logicTitle;
  final String? logic;

  const _NodeArchitectureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.status,
    required this.core,
    required this.radio,
    required this.display,
    required this.components,
    required this.flow,
    required this.mapping,
    this.logicTitle,
    this.logic,
  });

  @override
  Widget build(BuildContext context) {
    return _ArchitectureCardShell(
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      badge: status?.online == true ? 'ONLINE' : 'LOST',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HardwareDiagram(
            color: color,
            core: core,
            radio: radio,
            display: display,
            components: components,
          ),
          const SizedBox(height: 14),
          _ProcessFlow(steps: flow, color: color),
          if (logic != null) ...[
            const SizedBox(height: 12),
            _LogicBox(
              title: logicTitle ?? 'Logic',
              text: logic!,
              color: color,
            ),
          ],
          const SizedBox(height: 12),
          _MappingGrid(mapping: mapping, color: color),
          const SizedBox(height: 12),
          _NodeStatusStrip(status: status, color: color),
        ],
      ),
    );
  }
}

class _ArchitectureCardShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String badge;
  final Widget child;

  const _ArchitectureCardShell({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.child,
    this.badge = '',
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.07),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: color.withOpacity(0.18)),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withOpacity(0.18)),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.inter(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _HardwareDiagram extends StatelessWidget {
  final Color color;
  final String core;
  final String radio;
  final String display;
  final List<String> components;

  const _HardwareDiagram({
    required this.color,
    required this.core,
    required this.radio,
    required this.display,
    required this.components,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 480;
          final main = _ChipBlock(
            label: core,
            icon: Icons.memory_rounded,
            color: color,
            filled: true,
          );
          final hardware = [
            _ChipBlock(
              label: radio,
              icon: Icons.settings_input_antenna_rounded,
              color: AppColors.neonBlue,
            ),
            _ChipBlock(
              label: display,
              icon: Icons.monitor_rounded,
              color: AppColors.gatewayColor,
            ),
          ];
          final sensorChips = components
              .map((item) => _TinyComponentChip(label: item, color: color))
              .toList();
          if (compact) {
            return Column(
              children: [
                main,
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: hardware),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: sensorChips),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: main),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.sync_alt_rounded, color: color),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: hardware),
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: sensorChips),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProcessFlow extends StatelessWidget {
  final List<String> steps;
  final Color color;

  const _ProcessFlow({
    required this.steps,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                _FlowStep(step: steps[i], index: i + 1, color: color),
                if (i != steps.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: color, size: 18),
                  ),
              ],
            ],
          );
        }
        return Wrap(
          spacing: 6,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              _FlowStep(step: steps[i], index: i + 1, color: color),
              if (i != steps.length - 1)
                Icon(Icons.arrow_forward_rounded, color: color, size: 18),
            ],
          ],
        );
      },
    );
  }
}

class _FlowStep extends StatelessWidget {
  final String step;
  final int index;
  final Color color;

  const _FlowStep({
    required this.step,
    required this.index,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 118),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              step,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MappingGrid extends StatelessWidget {
  final List<(String, String)> mapping;
  final Color color;

  const _MappingGrid({
    required this.mapping,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in mapping)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.14)),
            ),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 10.5),
                children: [
                  TextSpan(
                    text: '${item.$1}: ',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: item.$2,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _NodeStatusStrip extends StatelessWidget {
  final NodeStatus? status;
  final Color color;

  const _NodeStatusStrip({
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        StatusChip(
          label: status?.online == true ? 'ONLINE' : 'LOST',
          type: status?.online == true ? StatusType.online : StatusType.offline,
          animated: false,
        ),
        _MetricPill(
          label: 'RSSI',
          value: '${status?.rssi.toStringAsFixed(0) ?? '--'} dBm',
          color: color,
        ),
        _MetricPill(
          label: 'SNR',
          value: '${status?.snr.toStringAsFixed(1) ?? '--'} dB',
          color: AppColors.neonBlue,
        ),
        _MetricPill(
          label: 'Battery',
          value: status?.batteryPercentStr ?? '--',
          color: status?.lowBattery == true
              ? AppColors.warningOrange
              : AppColors.successGreen,
        ),
        _MetricPill(
          label: 'Seq',
          value: '#${status?.seq ?? 0}',
          color: AppColors.gatewayColor,
        ),
      ],
    );
  }
}

class _TopologyPainter extends CustomPainter {
  final double animation;
  final bool compact;
  final List<_NodeTelemetry> nodes;
  final bool gatewayOnline;

  const _TopologyPainter({
    required this.animation,
    required this.compact,
    required this.nodes,
    required this.gatewayOnline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final positions = _TopologyLayout.positions(size, compact);
    final gateway = positions.gateway;
    final firebase = positions.firebase;
    final app = positions.app;
    for (var i = 0; i < nodes.length; i++) {
      _drawLink(
        canvas,
        positions.nodes[i],
        gateway,
        nodes[i].color,
        nodes[i].online && gatewayOnline,
        i * 0.18,
      );
    }
    _drawLink(
      canvas,
      gateway,
      firebase,
      AppColors.successGreen,
      gatewayOnline,
      0.1,
    );
    _drawLink(
      canvas,
      firebase,
      app,
      AppColors.neonBlue,
      gatewayOnline,
      0.38,
    );
  }

  void _drawLink(
    Canvas canvas,
    Offset start,
    Offset end,
    Color color,
    bool active,
    double phase,
  ) {
    final base = Paint()
      ..color = (active ? color : AppColors.textMuted).withOpacity(0.24)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final glow = Paint()
      ..color = (active ? color : AppColors.textMuted).withOpacity(0.12)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawLine(start, end, glow);
    canvas.drawLine(start, end, base);
    if (!active) return;
    final t = (animation + phase) % 1;
    final dot = Offset.lerp(start, end, Curves.easeInOut.transform(t))!;
    canvas.drawCircle(
      dot,
      6,
      Paint()
        ..color = color.withOpacity(0.24)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(dot, 3.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TopologyPainter oldDelegate) {
    return animation != oldDelegate.animation ||
        compact != oldDelegate.compact ||
        gatewayOnline != oldDelegate.gatewayOnline ||
        nodes != oldDelegate.nodes;
  }
}

class _TopologyLayout {
  final List<Offset> nodes;
  final Offset gateway;
  final Offset firebase;
  final Offset app;

  const _TopologyLayout({
    required this.nodes,
    required this.gateway,
    required this.firebase,
    required this.app,
  });

  static _TopologyLayout positions(Size size, bool compact) {
    Offset p(double x, double y) => Offset(size.width * x, size.height * y);
    if (compact) {
      return _TopologyLayout(
        nodes: [p(0.2, 0.14), p(0.5, 0.14), p(0.8, 0.14)],
        gateway: p(0.5, 0.42),
        firebase: p(0.5, 0.66),
        app: p(0.5, 0.88),
      );
    }
    return _TopologyLayout(
      nodes: [p(0.12, 0.2), p(0.12, 0.5), p(0.12, 0.8)],
      gateway: p(0.47, 0.5),
      firebase: p(0.72, 0.35),
      app: p(0.9, 0.64),
    );
  }
}

class _TopologyPositionedNode extends StatelessWidget {
  final _NodeTelemetry telemetry;
  final int index;
  final bool compact;

  const _TopologyPositionedNode({
    required this.telemetry,
    required this.index,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final alignments = compact
        ? const [
            Alignment(-0.86, -0.96),
            Alignment(0, -0.96),
            Alignment(0.86, -0.96),
          ]
        : const [
            Alignment(-1, -0.88),
            Alignment(-1, 0),
            Alignment(-1, 0.88),
          ];
    return _TopologyPositionedBox(
      compact: compact,
      alignment: alignments[index],
      width: compact ? 116 : 152,
      child: _TopologyNodeBox(telemetry: telemetry),
    );
  }
}

class _TopologyPositionedBox extends StatelessWidget {
  final bool compact;
  final Alignment alignment;
  final double width;
  final Widget child;

  const _TopologyPositionedBox({
    required this.compact,
    required this.alignment,
    required this.width,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: SizedBox(width: width, child: child),
    );
  }
}

class _TopologyNodeBox extends StatelessWidget {
  final _NodeTelemetry telemetry;

  const _TopologyNodeBox({required this.telemetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withOpacity(0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: telemetry.online
              ? telemetry.color.withOpacity(0.28)
              : AppColors.cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: telemetry.color.withOpacity(0.09),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(telemetry.icon, color: telemetry.color, size: 18),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  telemetry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            telemetry.online ? 'Online' : 'Lost',
            style: GoogleFonts.inter(
              color: telemetry.online
                  ? AppColors.successGreen
                  : AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${telemetry.rssi.toStringAsFixed(0)} dBm / ${telemetry.snr.toStringAsFixed(1)} dB',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${telemetry.packetCount} pkts / ${telemetry.batteryPercent.toStringAsFixed(0)}%',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopologyCoreBox extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool online;

  const _TopologyCoreBox({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.online,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.44)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: online
                        ? AppColors.successGreen
                        : Colors.white.withOpacity(0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeTelemetry {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool online;
  final double rssi;
  final double snr;
  final int packetCount;
  final double batteryPercent;

  const _NodeTelemetry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.online,
    required this.rssi,
    required this.snr,
    required this.packetCount,
    required this.batteryPercent,
  });

  factory _NodeTelemetry.fromStatus({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    NodeStatus? status,
    NodeHealth? health,
  }) {
    return _NodeTelemetry(
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      online: status?.online ?? health?.online ?? false,
      rssi: status?.rssi ?? health?.rssi ?? 0,
      snr: status?.snr ?? health?.snr ?? 0,
      packetCount: health?.receivedPackets ?? status?.seq ?? 0,
      batteryPercent: status?.batteryPercent ?? health?.batteryPercent ?? 0,
    );
  }
}

class _ChipBlock extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;

  const _ChipBlock({
    required this.label,
    required this.icon,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: filled ? color : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: filled ? Colors.white : color),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: filled ? Colors.white : AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyComponentChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TinyComponentChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LogicBox extends StatelessWidget {
  final String title;
  final String text;
  final Color color;

  const _LogicBox({
    required this.title,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.rule_rounded, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchitectureFilterPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ArchitectureFilterPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? AppColors.background : AppColors.textSecondary;
    return Material(
      color: selected ? AppColors.neonBlue : AppColors.card,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? AppColors.neonBlue : AppColors.cardBorder,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: AppColors.neonBlue.withOpacity(0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 7),
              Text(
                label,
                softWrap: false,
                style: GoogleFonts.inter(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _DarkBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkStatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DarkStatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final List<(String, String)> items;
  final Color color;

  const _InfoGrid({
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            width: 140,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.$1,
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.$2,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String title;
  final String code;

  const _CodeBlock({
    required this.title,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: AppColors.neonBlue,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            code,
            style: GoogleFonts.sourceCodePro(
              color: Colors.white.withOpacity(0.9),
              fontSize: 11,
              height: 1.38,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProtocolFlag extends StatelessWidget {
  final String label;
  final Color color;

  const _ProtocolFlag({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

double _average(List<double> values) {
  final usable = values.where((value) => value > 0).toList();
  if (usable.isEmpty) return 0;
  return usable.reduce((a, b) => a + b) / usable.length;
}
