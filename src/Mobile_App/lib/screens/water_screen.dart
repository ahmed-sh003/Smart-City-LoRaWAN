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
import '../models/water_model.dart';
import '../providers/ai_provider.dart';
import '../providers/dashboard_provider.dart';

class WaterScreen extends StatelessWidget {
  const WaterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<DashboardProvider>().water;
    if (model == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _WaterBody(model: model);
  }
}

class _WaterBody extends StatelessWidget {
  final WaterModel model;

  const _WaterBody({required this.model});

  Color get _leakColor {
    if (model.leakStatus >= 2 || model.leakProbability >= 80) {
      return AppColors.dangerRed;
    }
    if (model.leakStatus == 1 || model.leakProbability >= 40) {
      return AppColors.warningOrange;
    }
    return AppColors.successGreen;
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
                title: 'Water Network',
                subtitle: 'Rain, pipe soil, tanks, delta, leak detection',
                icon: Icons.water_drop_rounded,
                color: AppColors.waterColor,
                gradient: AppColors.waterGradient,
                online: model.status.online,
                imageAsset: 'assets/images/water_treatment_network.png',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: [
                _LeakBanner(model: model, color: _leakColor),
                const SizedBox(height: 20),
                const VisualAssetCard(
                  title: 'Water Network Diagram',
                  subtitle:
                      'Water intake, storage, filtration, treatment, and distribution path',
                  imageAsset: 'assets/images/water_treatment_network.png',
                  icon: Icons.account_tree_rounded,
                  color: AppColors.waterColor,
                  aspectRatio: 1.55,
                  fit: BoxFit.contain,
                  badges: ['Rain', 'Pipe Soil', 'Tank 1/2', 'Leak'],
                ),
                const SizedBox(height: 14),
                const NodeFlowCard(
                  title: 'Water Node Shape',
                  subtitle:
                      'Rain, pipe soil, two tank levels, delta, leak state, and actuator flag are shown live.',
                  icon: Icons.plumbing_rounded,
                  color: AppColors.waterColor,
                  steps: [
                    NodeFlowStep(
                      title: 'Rain',
                      subtitle: 'v1 weather input',
                      icon: Icons.grain_rounded,
                    ),
                    NodeFlowStep(
                      title: 'Pipe Soil',
                      subtitle: 'Moisture near pipe',
                      icon: Icons.grass_rounded,
                    ),
                    NodeFlowStep(
                      title: 'Tanks',
                      subtitle: 'Tank 1 / Tank 2',
                      icon: Icons.water_rounded,
                    ),
                    NodeFlowStep(
                      title: 'Leak Logic',
                      subtitle: 'Difference + status',
                      icon: Icons.warning_rounded,
                    ),
                    NodeFlowStep(
                      title: 'Gateway',
                      subtitle: 'SC1 upload',
                      icon: Icons.cell_tower_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SectionTitle(
                  title: 'Tank Levels',
                  icon: Icons.water_rounded,
                  iconColor: AppColors.waterColor,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _TankCard(label: 'Tank 1', percent: model.tank1),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TankCard(label: 'Tank 2', percent: model.tank2),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GlassCard(
                  borderColor: _leakColor.withOpacity(0.24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TelemetryRow(
                          label: 'Level Difference',
                          value: '${model.difference.toStringAsFixed(1)}%',
                        ),
                      ),
                      Expanded(
                        child: TelemetryRow(
                          label: 'Leak Status',
                          value: model.leakLabel,
                        ),
                      ),
                      Icon(
                        model.hasLeak
                            ? Icons.warning_rounded
                            : Icons.check_circle_rounded,
                        color: _leakColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionTitle(
                  title: 'Pipe & Environment',
                  icon: Icons.terrain_rounded,
                  iconColor: AppColors.waterColor,
                ),
                Row(
                  children: [
                    Expanded(
                      child: GlassCard(
                        borderColor: AppColors.waterColor.withOpacity(0.24),
                        child: _EnvironmentTile(
                          icon: Icons.grass_rounded,
                          title: '${model.pipeSoil.toStringAsFixed(0)}%',
                          subtitle: 'Pipe Soil Moisture',
                          color: model.pipeSoil > 70
                              ? AppColors.dangerRed
                              : AppColors.waterColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassCard(
                        borderColor: AppColors.neonBlue.withOpacity(0.24),
                        child: _EnvironmentTile(
                          icon: model.rain
                              ? Icons.grain_rounded
                              : Icons.wb_sunny_rounded,
                          title: model.rain ? 'Rain' : 'Dry',
                          subtitle: 'Rain Sensor',
                          color: model.rain
                              ? AppColors.neonBlue
                              : AppColors.warningOrange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SectionTitle(
                  title: 'Leak Probability',
                  icon: Icons.analytics_rounded,
                  iconColor: AppColors.waterColor,
                ),
                GlassCard(
                  borderColor: _leakColor.withOpacity(0.26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Estimated probability',
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${model.leakProbability.toStringAsFixed(0)}%',
                            style: GoogleFonts.inter(
                              color: _leakColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: model.leakProbability / 100,
                          minHeight: 10,
                          backgroundColor: AppColors.gaugeTrack,
                          valueColor: AlwaysStoppedAnimation(_leakColor),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        model.leakProbability >= 80
                            ? 'Immediate inspection recommended near pipe and tank delta zone.'
                            : model.leakProbability >= 40
                                ? 'Monitor closely and compare tank levels on next packets.'
                                : 'No leak pattern detected in the latest telemetry.',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
                  accentColor: AppColors.waterColor,
                ),
                const SizedBox(height: 14),
                Consumer<AiProvider>(
                  builder: (context, ai, _) => AiInsightCard(
                    anomaly: ai.getNodeAnomaly('water'),
                    maintenance: ai.getMaintenancePrediction('water'),
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

class _LeakBanner extends StatelessWidget {
  final WaterModel model;
  final Color color;

  const _LeakBanner({required this.model, required this.color});

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
            model.hasLeak ? Icons.plumbing_rounded : Icons.verified_rounded,
            color: color,
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.leakLabel.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tank delta ${model.difference.toStringAsFixed(1)}%, pipe soil ${model.pipeSoil.toStringAsFixed(0)}%',
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

class _TankCard extends StatelessWidget {
  final String label;
  final double percent;

  const _TankCard({required this.label, required this.percent});

  Color get _color {
    if (percent < 20) return AppColors.dangerRed;
    if (percent < 40) return AppColors.warningOrange;
    return AppColors.waterColor;
  }

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100).toInt();
    return GlassCard(
      borderColor: _color.withOpacity(0.3),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 72,
            height: 112,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _color.withOpacity(0.42), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: clamped / 100,
                  widthFactor: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _color.withOpacity(0.42),
                          _color.withOpacity(0.86),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${percent.toStringAsFixed(0)}%',
            style: GoogleFonts.inter(
              color: _color,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvironmentTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _EnvironmentTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
