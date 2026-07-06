import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/sc1_helpers.dart';
import '../core/widgets/ai_insight_card.dart';
import '../core/widgets/glass_card.dart';
import '../core/widgets/node_flow_card.dart';
import '../core/widgets/section_title.dart';
import '../core/widgets/status_chip.dart';
import '../core/widgets/telemetry_row.dart';
import '../models/gateway_model.dart';
import '../providers/ai_provider.dart';
import '../providers/dashboard_provider.dart';

class GatewayScreen extends StatelessWidget {
  final bool isEmbedded;

  const GatewayScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final model = provider.gateway;
    final body = model == null
        ? const Center(child: CircularProgressIndicator())
        : _GatewayBody(
            model: model,
            lastSync: provider.lastSync,
            showBackButton: !isEmbedded,
          );

    if (isEmbedded) return body;
    return Scaffold(backgroundColor: AppColors.background, body: body);
  }
}

class _GatewayBody extends StatelessWidget {
  final GatewayModel model;
  final DateTime lastSync;
  final bool showBackButton;

  const _GatewayBody({
    required this.model,
    required this.lastSync,
    required this.showBackButton,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 84,
          backgroundColor: AppColors.background,
          automaticallyImplyLeading: showBackButton,
          title: Row(
            children: [
              const Icon(Icons.cell_tower_rounded,
                  color: AppColors.gatewayColor, size: 22),
              const SizedBox(width: 10),
              Text(
                'Gateway Health',
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList.list(
            children: [
              const _GatewayImageHero(),
              const SizedBox(height: 14),
              GlassCard(
                borderColor: AppColors.gatewayColor.withOpacity(0.28),
                gradient: AppColors.gatewayGradient,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.gatewayColor.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.router_rounded,
                          color: AppColors.gatewayColor, size: 34),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ESP32 LoRa Gateway',
                            style: GoogleFonts.inter(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              StatusChip(
                                label: model.online ? 'ONLINE' : 'OFFLINE',
                                type: model.online
                                    ? StatusType.online
                                    : StatusType.offline,
                              ),
                              StatusChip(
                                label: model.firebaseStatus,
                                type: model.firebaseStatus
                                        .toLowerCase()
                                        .contains('sync')
                                    ? StatusType.online
                                    : StatusType.warning,
                                animated: false,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const NodeFlowCard(
                title: 'Gateway Data Path',
                subtitle:
                    'ESP32 receiver publishes SC1 packets and health metrics into Firebase for the mobile app.',
                icon: Icons.hub_rounded,
                color: AppColors.gatewayColor,
                steps: [
                  NodeFlowStep(
                    title: 'Nodes',
                    subtitle: 'Building, bridge, water',
                    icon: Icons.sensors_rounded,
                  ),
                  NodeFlowStep(
                    title: 'LoRa',
                    subtitle: 'SC1 packet',
                    icon: Icons.cell_tower_rounded,
                  ),
                  NodeFlowStep(
                    title: 'Gateway',
                    subtitle: 'RSSI, SNR, PDR',
                    icon: Icons.router_rounded,
                  ),
                  NodeFlowStep(
                    title: 'Firebase',
                    subtitle: 'nodes + alerts',
                    icon: Icons.cloud_sync_rounded,
                  ),
                  NodeFlowStep(
                    title: 'App',
                    subtitle: 'Live dashboard',
                    icon: Icons.phone_android_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatCard(
                    label: 'Connected Nodes',
                    value: '${model.onlineNodes}/3',
                    icon: Icons.hub_rounded,
                    color: AppColors.successGreen,
                  ),
                  _StatCard(
                    label: 'RSSI',
                    value: '${model.averageRssi.toStringAsFixed(0)} dBm',
                    icon: Icons.signal_cellular_alt_rounded,
                    color: AppColors.neonBlue,
                  ),
                  _StatCard(
                    label: 'SNR',
                    value: '${model.averageSnr.toStringAsFixed(1)} dB',
                    icon: Icons.network_check_rounded,
                    color: AppColors.waterColor,
                  ),
                  _StatCard(
                    label: 'Total Packets',
                    value: '${model.totalPackets}',
                    icon: Icons.swap_horiz_rounded,
                    color: AppColors.gatewayColor,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const SectionTitle(
                title: 'Network Topology',
                icon: Icons.account_tree_rounded,
                iconColor: AppColors.gatewayColor,
              ),
              _TopologyView(model: model),
              const SizedBox(height: 20),
              const SectionTitle(
                title: 'Node Packet Delivery',
                icon: Icons.devices_rounded,
                iconColor: AppColors.gatewayColor,
              ),
              _NodeHealthCard(
                node: model.buildingNode,
                icon: Icons.apartment_rounded,
                color: AppColors.buildingColor,
              ),
              const SizedBox(height: 10),
              _NodeHealthCard(
                node: model.bridgeNode,
                icon: Icons.alt_route_rounded,
                color: AppColors.bridgeColor,
              ),
              const SizedBox(height: 10),
              _NodeHealthCard(
                node: model.waterNode,
                icon: Icons.water_drop_rounded,
                color: AppColors.waterColor,
              ),
              const SizedBox(height: 20),
              const SectionTitle(
                title: 'Gateway State',
                icon: Icons.cloud_sync_rounded,
                iconColor: AppColors.gatewayColor,
              ),
              GlassCard(
                child: Wrap(
                  spacing: 18,
                  runSpacing: 14,
                  children: [
                    TelemetryRow(label: 'WiFi', value: model.wifiStatus),
                    TelemetryRow(
                        label: 'Firebase', value: model.firebaseStatus),
                    TelemetryRow(label: 'Uptime', value: model.uptimeLabel),
                    TelemetryRow(
                        label: 'Last Node',
                        value: model.lastReceivedNode.isEmpty
                            ? '--'
                            : model.lastReceivedNode),
                    TelemetryRow(
                        label: 'Node Timeout',
                        value: '${model.nodeTimeoutSec}s'),
                    TelemetryRow(
                        label: 'Last Sync',
                        value: formatTimeAgo(
                            lastSync.millisecondsSinceEpoch ~/ 1000)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Consumer<AiProvider>(
                builder: (context, ai, _) => AiInsightCard(
                  title: 'Gateway AI Signal',
                  anomaly: null,
                  maintenance: null,
                  signal: ai.getSignalPrediction('gateway'),
                ),
              ),
              const SizedBox(height: 20),
              const SectionTitle(
                title: 'Last Raw Packet',
                icon: Icons.receipt_long_rounded,
                iconColor: AppColors.gatewayColor,
              ),
              GlassCard(
                child: Text(
                  model.lastRawPacket.isEmpty
                      ? 'No packet received'
                      : model.lastRawPacket,
                  style: GoogleFonts.sourceCodePro(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 96),
            ],
          ),
        ),
      ],
    );
  }
}

class _GatewayImageHero extends StatelessWidget {
  const _GatewayImageHero();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 2.4,
            child: Image.asset(
              'assets/images/lorawan_city_topology.webp',
              fit: BoxFit.contain,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withOpacity(0.62),
                    Colors.black.withOpacity(0.08),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: Text(
              'Gateway -> Firebase',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 42) / 2;
    return SizedBox(
      width: width.clamp(150, 260),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderColor: color.withOpacity(0.2),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopologyView extends StatelessWidget {
  final GatewayModel model;

  const _TopologyView({required this.model});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: AppColors.gatewayColor.withOpacity(0.22),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TopologyNode(
                label: 'Building',
                icon: Icons.apartment_rounded,
                color: AppColors.buildingColor,
                online: model.buildingNode.online,
              ),
              _TopologyNode(
                label: 'Bridge',
                icon: Icons.alt_route_rounded,
                color: AppColors.bridgeColor,
                online: model.bridgeNode.online,
              ),
              _TopologyNode(
                label: 'Water',
                icon: Icons.water_drop_rounded,
                color: AppColors.waterColor,
                online: model.waterNode.online,
              ),
            ],
          ),
          const SizedBox(height: 8),
          CustomPaint(
            size: const Size(double.infinity, 42),
            painter: _TopologyLinePainter([
              model.buildingNode.online,
              model.bridgeNode.online,
              model.waterNode.online,
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.gatewayColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.gatewayColor.withOpacity(0.32),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.router_rounded,
                    color: AppColors.gatewayColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Gateway',
                  style: GoogleFonts.inter(
                    color: AppColors.gatewayColor,
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

class _TopologyNode extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool online;

  const _TopologyNode({
    required this.label,
    required this.icon,
    required this.color,
    required this.online,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = online ? color : AppColors.textMuted;
    return Column(
      children: [
        Icon(icon, color: effectiveColor, size: 28),
        const SizedBox(height: 6),
        Text(
          '$label -> Gateway',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        StatusChip(
          label: online ? 'UP' : 'TIMEOUT',
          type: online ? StatusType.online : StatusType.offline,
          animated: false,
        ),
      ],
    );
  }
}

class _TopologyLinePainter extends CustomPainter {
  final List<bool> onlineStates;

  const _TopologyLinePainter(this.onlineStates);

  @override
  void paint(Canvas canvas, Size size) {
    final positions = [size.width * 0.14, size.width * 0.5, size.width * 0.86];
    final center = Offset(size.width / 2, size.height);
    for (var i = 0; i < 3; i++) {
      final color = onlineStates[i] ? AppColors.neonBlue : AppColors.textMuted;
      canvas.drawLine(
        Offset(positions[i], 0),
        center,
        Paint()
          ..color = color.withOpacity(0.42)
          ..strokeWidth = 1.6,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TopologyLinePainter oldDelegate) => false;
}

class _NodeHealthCard extends StatelessWidget {
  final NodeHealth node;
  final IconData icon;
  final Color color;

  const _NodeHealthCard({
    required this.node,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: node.online ? color.withOpacity(0.24) : AppColors.cardBorder,
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: node.online ? color : AppColors.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${node.name} Node',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusChip(
                label: node.online ? 'ONLINE' : 'LOST',
                type: node.online ? StatusType.online : StatusType.offline,
                animated: false,
              ),
            ],
          ),
          const Divider(color: AppColors.cardBorder, height: 22),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              TelemetryRow(label: 'Received', value: '${node.receivedPackets}'),
              TelemetryRow(label: 'Lost', value: '${node.lostPackets}'),
              TelemetryRow(
                  label: 'PDR', value: '${node.pdr.toStringAsFixed(1)}%'),
              TelemetryRow(
                  label: 'RSSI', value: '${node.rssi.toStringAsFixed(0)} dBm'),
              TelemetryRow(
                  label: 'SNR', value: '${node.snr.toStringAsFixed(1)} dB'),
              TelemetryRow(label: 'Last Seq', value: '#${node.lastSeq}'),
              TelemetryRow(label: 'Last Seen', value: node.lastUpdateLabel),
            ],
          ),
        ],
      ),
    );
  }
}
