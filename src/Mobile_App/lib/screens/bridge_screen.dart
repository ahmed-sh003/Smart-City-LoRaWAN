import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/ai_insight_card.dart';
import '../core/widgets/domain_header.dart';
import '../core/widgets/glass_card.dart';
import '../core/widgets/node_flow_card.dart';
import '../core/widgets/node_telemetry_card.dart';
import '../core/widgets/section_title.dart';
import '../core/widgets/telemetry_row.dart';
import '../core/widgets/visual_asset_card.dart';
import '../models/bridge_model.dart';
import '../providers/ai_provider.dart';
import '../providers/dashboard_provider.dart';

class BridgeScreen extends StatelessWidget {
  const BridgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<DashboardProvider>().bridge;
    if (model == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _BridgeBody(model: model);
  }
}

class _BridgeBody extends StatelessWidget {
  final BridgeModel model;

  const _BridgeBody({required this.model});

  Color get _roadStatusColor {
    switch (model.roadStatus) {
      case 'DANGER DETECTED':
        return AppColors.dangerRed;
      case 'ROAD CLOSED':
        return AppColors.warningOrange;
      default:
        return AppColors.successGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 188,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: DomainHeader(
                title: 'Bridge / Road',
                subtitle: 'IR counters, danger switches, gates, buzzer',
                icon: Icons.alt_route_rounded,
                color: AppColors.bridgeColor,
                gradient: AppColors.bridgeGradient,
                online: model.status.online,
                imageAsset: 'assets/images/bridge_lora_monitoring.webp',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: [
                _RoadStatusBanner(model: model, color: _roadStatusColor),
                const SizedBox(height: 20),
                const VisualAssetCard(
                  title: 'Bridge Tilt Monitoring Diagram',
                  subtitle:
                      'LoRa bridge tilt and structure telemetry routed through gateway and cloud software',
                  imageAsset: 'assets/images/bridge_lora_monitoring.webp',
                  icon: Icons.alt_route_rounded,
                  color: AppColors.bridgeColor,
                  aspectRatio: 1.8,
                  fit: BoxFit.cover,
                  badges: ['Bridge', 'Tilt', 'LoRa Gateway', 'Cloud'],
                ),
                const SizedBox(height: 14),
                _BridgeSchematicCard(model: model, color: _roadStatusColor),
                const SizedBox(height: 14),
                const NodeFlowCard(
                  title: 'Bridge Node Shape',
                  subtitle:
                      'IR entry/exit counters, four danger switches, gates, and buzzer become one SC1 road packet.',
                  icon: Icons.route_rounded,
                  color: AppColors.bridgeColor,
                  steps: [
                    NodeFlowStep(
                      title: 'Entry IR',
                      subtitle: 'Cars entered',
                      icon: Icons.login_rounded,
                    ),
                    NodeFlowStep(
                      title: 'Exit IR',
                      subtitle: 'Cars exited',
                      icon: Icons.logout_rounded,
                    ),
                    NodeFlowStep(
                      title: 'Danger SW',
                      subtitle: '4 switch inputs',
                      icon: Icons.report_rounded,
                    ),
                    NodeFlowStep(
                      title: 'Actuators',
                      subtitle: 'Gates + buzzer',
                      icon: Icons.meeting_room_rounded,
                    ),
                    NodeFlowStep(
                      title: 'SC1 Road',
                      subtitle: 'Status + flags',
                      icon: Icons.cell_tower_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SectionTitle(
                  title: 'Traffic Counter',
                  icon: Icons.directions_car_rounded,
                  iconColor: AppColors.bridgeColor,
                ),
                GlassCard(
                  borderColor: AppColors.bridgeColor.withOpacity(0.24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _CounterTile(
                              label: 'Inside',
                              value: model.carsInside,
                              color: model.overloadAlert
                                  ? AppColors.dangerRed
                                  : AppColors.bridgeColor,
                              icon: Icons.directions_car_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CounterTile(
                              label: 'Entered',
                              value: model.carsEntered,
                              color: AppColors.successGreen,
                              icon: Icons.login_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CounterTile(
                              label: 'Exited',
                              value: model.carsExited,
                              color: AppColors.neonBlue,
                              icon: Icons.logout_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _OccupancyBar(model: model),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          TelemetryRow(
                            label: 'Estimated Load',
                            value: '${model.loadKg.toStringAsFixed(0)} kg',
                          ),
                          TelemetryRow(label: 'Risk', value: model.riskLabel),
                          TelemetryRow(
                            label: 'Overload',
                            value: model.overloadAlert ? 'Yes' : 'No',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionTitle(
                  title: 'Gate & Actuator Status',
                  icon: Icons.meeting_room_rounded,
                  iconColor: AppColors.bridgeColor,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _GateTile(
                        label: 'Entry Gate',
                        open: model.gateIn,
                        icon: Icons.login_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GateTile(
                        label: 'Exit Gate',
                        open: model.gateOut,
                        icon: Icons.logout_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GlassCard(
                  borderColor: (model.buzzer
                          ? AppColors.dangerRed
                          : AppColors.cardBorder)
                      .withOpacity(0.35),
                  child: Row(
                    children: [
                      Icon(
                        model.buzzer
                            ? Icons.volume_up_rounded
                            : Icons.volume_mute_rounded,
                        color: model.buzzer
                            ? AppColors.dangerRed
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          model.buzzer
                              ? 'Buzzer active. Road alert is sounding.'
                              : 'Buzzer silent. No road alarm output.',
                          style: GoogleFonts.inter(
                            color: model.buzzer
                                ? AppColors.dangerRed
                                : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionTitle(
                  title: 'Danger Switches',
                  icon: Icons.report_rounded,
                  iconColor: AppColors.dangerRed,
                ),
                GlassCard(
                  borderColor: model.anyDangerSwitch
                      ? AppColors.dangerRed.withOpacity(0.35)
                      : AppColors.cardBorder,
                  child: Row(
                    children: [
                      Expanded(
                        child: _SwitchTile(
                          label: 'SW1',
                          active: model.dangerSwitch1,
                        ),
                      ),
                      Expanded(
                        child: _SwitchTile(
                          label: 'SW2',
                          active: model.dangerSwitch2,
                        ),
                      ),
                      Expanded(
                        child: _SwitchTile(
                          label: 'SW3',
                          active: model.dangerSwitch3,
                        ),
                      ),
                      Expanded(
                        child: _SwitchTile(
                          label: 'SW4',
                          active: model.dangerSwitch4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionTitle(
                  title: 'SC1 Telemetry',
                  icon: Icons.settings_input_antenna_rounded,
                  iconColor: AppColors.neonBlue,
                ),
                NodeTelemetryCard(
                  status: model.status,
                  accentColor: AppColors.bridgeColor,
                ),
                const SizedBox(height: 14),
                Consumer<AiProvider>(
                  builder: (context, ai, _) => AiInsightCard(
                    anomaly: ai.getNodeAnomaly('bridge'),
                    maintenance: ai.getMaintenancePrediction('bridge'),
                    signal: ai.getSignalPrediction('gateway'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadStatusBanner extends StatelessWidget {
  final BridgeModel model;
  final Color color;

  const _RoadStatusBanner({required this.model, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.18), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(
            model.roadStatus == 'ROAD OPEN'
                ? Icons.check_circle_rounded
                : model.roadStatus == 'ROAD CLOSED'
                    ? Icons.block_rounded
                    : Icons.warning_rounded,
            color: color,
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.roadStatus,
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${model.carsInside}/${model.capacityLimit} cars inside, actuator flag ${model.status.actuatorActive ? 'active' : 'clear'}',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
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

class _BridgeSchematicCard extends StatelessWidget {
  final BridgeModel model;
  final Color color;

  const _BridgeSchematicCard({
    required this.model,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 8,
      borderColor: color.withOpacity(0.26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_rounded, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Live Road Diagram',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                model.roadStatus,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 2.4,
            child: CustomPaint(
              painter: _BridgeSchematicPainter(
                color: color,
                gateInOpen: model.gateIn,
                gateOutOpen: model.gateOut,
                dangerSwitches: [
                  model.dangerSwitch1,
                  model.dangerSwitch2,
                  model.dangerSwitch3,
                  model.dangerSwitch4,
                ],
              ),
              child: Center(
                child: Text(
                  '${model.carsInside} cars inside',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniLegend(
                label: model.gateIn ? 'Entry gate open' : 'Entry gate closed',
                color:
                    model.gateIn ? AppColors.successGreen : AppColors.dangerRed,
              ),
              _MiniLegend(
                label: model.gateOut ? 'Exit gate open' : 'Exit gate closed',
                color: model.gateOut
                    ? AppColors.successGreen
                    : AppColors.dangerRed,
              ),
              _MiniLegend(
                label: model.buzzer ? 'Buzzer active' : 'Buzzer silent',
                color: model.buzzer ? AppColors.dangerRed : AppColors.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BridgeSchematicPainter extends CustomPainter {
  final Color color;
  final bool gateInOpen;
  final bool gateOutOpen;
  final List<bool> dangerSwitches;

  const _BridgeSchematicPainter({
    required this.color,
    required this.gateInOpen,
    required this.gateOutOpen,
    required this.dangerSwitches,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final deck = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.12, size.height * 0.36, size.width * 0.76,
          size.height * 0.24),
      const Radius.circular(12),
    );
    final deckPaint = Paint()..color = color.withOpacity(0.16);
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withOpacity(0.55);
    canvas.drawRRect(deck, deckPaint);
    canvas.drawRRect(deck, borderPaint);

    final lanePaint = Paint()
      ..color = AppColors.textMuted.withOpacity(0.6)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.48),
      Offset(size.width * 0.82, size.height * 0.48),
      lanePaint,
    );

    void drawGate(double x, bool open, String label) {
      final gateColor = open ? AppColors.successGreen : AppColors.dangerRed;
      final paint = Paint()
        ..color = gateColor
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      final y = size.height * 0.48;
      canvas.drawLine(
        Offset(x, y - 24),
        Offset(open ? x + 28 : x, open ? y - 2 : y + 24),
        paint,
      );
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: GoogleFonts.inter(
            color: gateColor,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(x - 24, y + 34));
    }

    drawGate(size.width * 0.18, gateInOpen, 'IN');
    drawGate(size.width * 0.82, gateOutOpen, 'OUT');

    final switchXs = [0.27, 0.42, 0.58, 0.73];
    for (var i = 0; i < dangerSwitches.length; i++) {
      final active = dangerSwitches[i];
      final switchColor = active ? AppColors.dangerRed : AppColors.successGreen;
      final center = Offset(size.width * switchXs[i], size.height * 0.28);
      canvas.drawCircle(
        center,
        9,
        Paint()..color = switchColor.withOpacity(0.18),
      );
      canvas.drawCircle(
        center,
        4.5,
        Paint()..color = switchColor,
      );
      canvas.drawLine(
        center.translate(0, 10),
        Offset(size.width * switchXs[i], size.height * 0.36),
        Paint()
          ..color = switchColor.withOpacity(0.42)
          ..strokeWidth = 1.2,
      );
    }

    final pylonPaint = Paint()
      ..color = AppColors.textSecondary.withOpacity(0.32);
    canvas.drawRect(
      Rect.fromLTWH(
          size.width * 0.13, size.height * 0.6, 12, size.height * 0.22),
      pylonPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
          size.width * 0.84, size.height * 0.6, 12, size.height * 0.22),
      pylonPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BridgeSchematicPainter oldDelegate) {
    return color != oldDelegate.color ||
        gateInOpen != oldDelegate.gateInOpen ||
        gateOutOpen != oldDelegate.gateOutOpen ||
        dangerSwitches != oldDelegate.dangerSwitches;
  }
}

class _MiniLegend extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniLegend({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CounterTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _CounterTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style:
                GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _OccupancyBar extends StatelessWidget {
  final BridgeModel model;

  const _OccupancyBar({required this.model});

  @override
  Widget build(BuildContext context) {
    final color = model.occupancyPercent > 90
        ? AppColors.dangerRed
        : model.occupancyPercent > 70
            ? AppColors.warningOrange
            : AppColors.successGreen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Occupancy',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Text(
              '${model.occupancyPercent.toStringAsFixed(0)}%',
              style: GoogleFonts.inter(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: model.occupancyPercent / 100,
            minHeight: 9,
            backgroundColor: AppColors.gaugeTrack,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _GateTile extends StatelessWidget {
  final String label;
  final bool open;
  final IconData icon;

  const _GateTile({
    required this.label,
    required this.open,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = open ? AppColors.successGreen : AppColors.dangerRed;
    return GlassCard(
      borderColor: color.withOpacity(0.28),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(
            open ? 'OPEN' : 'CLOSED',
            style: GoogleFonts.inter(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style:
                GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String label;
  final bool active;

  const _SwitchTile({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.dangerRed : AppColors.successGreen;
    return Column(
      children: [
        Icon(
          active ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
          color: color,
          size: 34,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          active ? 'ALERT' : 'OK',
          style: GoogleFonts.inter(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
