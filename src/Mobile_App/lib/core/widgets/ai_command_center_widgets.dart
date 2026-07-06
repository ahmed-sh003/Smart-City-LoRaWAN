import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/ai_models.dart';
import '../../models/mlops_models.dart';
import '../../providers/ai_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';

class AiCommandCenter extends StatelessWidget {
  final DashboardProvider dashboard;
  final AiProvider ai;
  final MlopsSummary summary;
  final bool compact;
  final VoidCallback? onRunAnalysis;
  final VoidCallback? onViewNode;
  final VoidCallback? onOpenReport;
  final VoidCallback? onMarkChecked;

  const AiCommandCenter({
    super.key,
    required this.dashboard,
    required this.ai,
    required this.summary,
    this.compact = false,
    this.onRunAnalysis,
    this.onViewNode,
    this.onOpenReport,
    this.onMarkChecked,
  });

  @override
  Widget build(BuildContext context) {
    final snapshot = AiCommandCenterSnapshot.from(dashboard, ai, summary);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth > 760 ? 720.0 : double.infinity;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AiStatusHeaderCard(
                  snapshot: snapshot,
                  onRunAnalysis: onRunAnalysis,
                ),
                const SizedBox(height: 12),
                SmartCityHealthOverview(risks: snapshot.domainRisks),
                const SizedBox(height: 12),
                if (!compact) ...[
                  LpwanNetworkIntelligenceSection(snapshot: snapshot),
                  const SizedBox(height: 12),
                ],
                AiRecommendationsSection(
                  recommendations: snapshot.recommendations,
                  onViewNode: onViewNode,
                  onOpenReport: onOpenReport,
                  onMarkChecked: onMarkChecked,
                ),
                const SizedBox(height: 12),
                RootCauseExplanationCard(
                  reasons: snapshot.reasons,
                  statusColor: snapshot.statusColor,
                  technicalLines: snapshot.technicalReasonLines,
                ),
                const SizedBox(height: 12),
                if (!compact) ...[
                  PacketLossForecastCard(snapshot: snapshot),
                  const SizedBox(height: 12),
                  BatteryLifeCard(snapshot: snapshot),
                  const SizedBox(height: 12),
                  GatewayHealthCard(snapshot: snapshot),
                  const SizedBox(height: 12),
                ],
                ModelTrustCard(snapshot: snapshot, summary: summary),
                if (!compact) ...[
                  const SizedBox(height: 12),
                  TechnicalDetailsAccordion(summary: summary),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class AiCommandCenterScreen extends StatelessWidget {
  final DashboardProvider dashboard;
  final AiProvider ai;
  final MlopsSummary summary;
  final VoidCallback? onRunAnalysis;
  final VoidCallback? onViewNode;
  final VoidCallback? onOpenReport;
  final VoidCallback? onMarkChecked;

  const AiCommandCenterScreen({
    super.key,
    required this.dashboard,
    required this.ai,
    required this.summary,
    this.onRunAnalysis,
    this.onViewNode,
    this.onOpenReport,
    this.onMarkChecked,
  });

  @override
  Widget build(BuildContext context) {
    return AiCommandCenter(
      dashboard: dashboard,
      ai: ai,
      summary: summary,
      onRunAnalysis: onRunAnalysis,
      onViewNode: onViewNode,
      onOpenReport: onOpenReport,
      onMarkChecked: onMarkChecked,
    );
  }
}

class AiHomeInsightCard extends StatelessWidget {
  final DashboardProvider dashboard;
  final AiProvider ai;
  final MlopsSummary summary;
  final VoidCallback? onRunAnalysis;
  final VoidCallback? onOpenAiCenter;

  const AiHomeInsightCard({
    super.key,
    required this.dashboard,
    required this.ai,
    required this.summary,
    this.onRunAnalysis,
    this.onOpenAiCenter,
  });

  @override
  Widget build(BuildContext context) {
    final snapshot = AiCommandCenterSnapshot.from(dashboard, ai, summary);
    final action = snapshot.primaryRecommendation;
    final mainReason = snapshot.reasons.isEmpty
        ? 'Readings look stable'
        : snapshot.reasons.first.title;
    return GlassCard(
      borderRadius: 8,
      borderColor: snapshot.statusColor.withValues(alpha: 0.24),
      glowColor: snapshot.statusColor.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: snapshot.statusColor, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Status',
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      snapshot.shortSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              AiStatusBadge(
                label: snapshot.statusLabel,
                color: snapshot.statusColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CompactMetric(
                  label: 'Highest risk',
                  value: snapshot.highestRisk.title,
                  color: snapshot.highestRisk.color,
                  icon: snapshot.highestRisk.icon,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactMetric(
                  label: 'Risk level',
                  value: '${snapshot.highestRiskPercent.toStringAsFixed(0)}%',
                  color: snapshot.highestRisk.color,
                  icon: Icons.speed_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SmallChip(
            label: 'Main reason: $mainReason',
            color: snapshot.statusColor,
          ),
          const SizedBox(height: 12),
          _InlineAction(
            title: action.title,
            subtitle: action.detail,
            color: action.color,
            impact: action.impact,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenAiCenter,
                  icon: const Icon(Icons.hub_rounded, size: 18),
                  label: const Text('Open AI Center'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.neonBlue,
                    side: BorderSide(
                      color: AppColors.neonBlue.withValues(alpha: 0.32),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: ai.isAnalyzing ? null : onRunAnalysis,
                icon: Icon(
                  ai.isAnalyzing
                      ? Icons.hourglass_top_rounded
                      : Icons.play_arrow_rounded,
                ),
                color: snapshot.statusColor,
                tooltip: ai.isAnalyzing ? 'AI is checking now' : 'Run AI check',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AiStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const AiStatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class AiRiskCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final double risk;
  final String status;
  final Color color;
  final String detail;

  const AiRiskCard({
    super.key,
    required this.title,
    required this.icon,
    required this.risk,
    required this.status,
    required this.color,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${(risk * 100).toStringAsFixed(0)}%',
            style: GoogleFonts.inter(
              color: color,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            status,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          RiskProgressBar(value: risk, color: color),
          const SizedBox(height: 8),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 10.5,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class SmartCityRiskCard extends StatelessWidget {
  final AiDomainRisk risk;

  const SmartCityRiskCard({
    super.key,
    required this.risk,
  });

  @override
  Widget build(BuildContext context) {
    return AiRiskCard(
      title: risk.title,
      icon: risk.icon,
      risk: risk.score,
      status: risk.statusLabel,
      color: risk.color,
      detail: risk.detail,
    );
  }
}

class RiskProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final String? label;

  const RiskProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: 7,
            color: color,
            backgroundColor: AppColors.gaugeTrack,
          ),
        ),
      ],
    );
  }
}

class AiExplanationCard extends StatelessWidget {
  final List<AiReason> reasons;
  final Color statusColor;
  final List<String> technicalLines;

  const AiExplanationCard({
    super.key,
    required this.reasons,
    required this.statusColor,
    required this.technicalLines,
  });

  @override
  Widget build(BuildContext context) {
    final visibleReasons = reasons.take(3).toList();
    return GlassCard(
      borderRadius: 8,
      borderColor: statusColor.withValues(alpha: 0.20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SimpleSectionHeader(
            icon: Icons.psychology_alt_rounded,
            title: 'Why AI Thinks This',
            subtitle: 'Top reasons in plain language before technical detail.',
            color: statusColor,
          ),
          const SizedBox(height: 14),
          if (visibleReasons.isEmpty)
            Text(
              'No strong problem reason is visible right now.',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            for (var index = 0; index < visibleReasons.length; index++) ...[
              _ReasonRow(
                number: index + 1,
                reason: visibleReasons[index],
                color: statusColor,
              ),
              if (index != visibleReasons.length - 1)
                const SizedBox(height: 10),
            ],
          if (technicalLines.isNotEmpty) ...[
            const SizedBox(height: 10),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                'View technical drivers',
                style: GoogleFonts.inter(
                  color: AppColors.neonBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final line in technicalLines.take(8))
                        _SmallChip(
                          label: line,
                          color: AppColors.gatewayColor,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class AiRecommendedActionCard extends StatelessWidget {
  final AiRecommendation recommendation;
  final List<AiRecommendation> alternatives;
  final VoidCallback? onViewNode;
  final VoidCallback? onOpenReport;
  final VoidCallback? onMarkChecked;

  const AiRecommendedActionCard({
    super.key,
    required this.recommendation,
    this.alternatives = const [],
    this.onViewNode,
    this.onOpenReport,
    this.onMarkChecked,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 8,
      borderColor: recommendation.color.withValues(alpha: 0.20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SimpleSectionHeader(
            icon: Icons.task_alt_rounded,
            title: 'Recommended next step',
            subtitle: 'A field action written for operators, not model logs.',
            color: recommendation.color,
          ),
          const SizedBox(height: 14),
          _InlineAction(
            title: recommendation.title,
            subtitle: recommendation.detail,
            color: recommendation.color,
            impact: recommendation.impact,
          ),
          if (alternatives.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in alternatives)
                  _SmallChip(
                    label: '${item.impact}: ${item.title}',
                    color: item.color,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(
                label: 'View node',
                icon: Icons.open_in_new_rounded,
                onPressed: onViewNode,
                color: AppColors.neonBlue,
              ),
              _ActionButton(
                label: 'Open report',
                icon: Icons.article_rounded,
                onPressed: onOpenReport,
                color: AppColors.gatewayColor,
              ),
              _ActionButton(
                label: 'Mark checked',
                icon: Icons.check_circle_rounded,
                onPressed: onMarkChecked,
                color: AppColors.successGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AiForecastMiniChart extends StatelessWidget {
  final AiCommandCenterSnapshot snapshot;

  const AiForecastMiniChart({
    super.key,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    return PacketLossForecastCard(snapshot: snapshot);
  }
}

class AiModelHealthCard extends StatelessWidget {
  final AiCommandCenterSnapshot snapshot;

  const AiModelHealthCard({
    super.key,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    return ModelTrustCard(snapshot: snapshot);
  }
}

class MiniTrendChart extends StatelessWidget {
  final List<FlSpot> spots;
  final Color color;
  final double height;

  const MiniTrendChart({
    super.key,
    required this.spots,
    required this.color,
    this.height = 132,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 1,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.cardBorder,
              strokeWidth: 1,
            ),
          ),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots.isEmpty ? const [FlSpot(0, 0)] : spots,
              isCurved: true,
              barWidth: 3,
              color: color,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LpwanNetworkIntelligenceSection extends StatelessWidget {
  final AiCommandCenterSnapshot snapshot;

  const LpwanNetworkIntelligenceSection({
    super.key,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LpwanNetworkHealthCard(snapshot: snapshot),
        const SizedBox(height: 12),
        SignalQualityCard(snapshot: snapshot),
        const SizedBox(height: 12),
        _PacketLossStatusCard(snapshot: snapshot),
        const SizedBox(height: 12),
        AdaptiveSfRecommendationCard(snapshot: snapshot),
      ],
    );
  }
}

class LpwanNetworkHealthCard extends StatelessWidget {
  final AiCommandCenterSnapshot snapshot;

  const LpwanNetworkHealthCard({
    super.key,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 8,
      borderColor: snapshot.networkHealthColor.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SimpleSectionHeader(
            icon: Icons.settings_input_antenna_rounded,
            title: 'LPWAN Network Intelligence',
            subtitle:
                'Delivery, weak links, and LoRa health from gateway data.',
            color: snapshot.networkHealthColor,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallStat(
                label: 'Health',
                value: '${snapshot.networkHealth.toStringAsFixed(0)}%',
                color: snapshot.networkHealthColor,
              ),
              _SmallStat(
                label: 'Delivery',
                value: '${snapshot.deliveryRatio.toStringAsFixed(1)}%',
                color: snapshot.packetLossColor,
              ),
              _SmallStat(
                label: 'Packet loss',
                value: '${snapshot.currentPacketLoss.toStringAsFixed(1)}%',
                color: snapshot.packetLossColor,
              ),
              _SmallStat(
                label: 'Connected',
                value: '${snapshot.activeNodes}/3 nodes',
                color: snapshot.activeNodes == 3
                    ? AppColors.successGreen
                    : AppColors.warningOrange,
              ),
              _SmallStat(
                label: 'Weak links',
                value: '${snapshot.weakLinks}',
                color: snapshot.weakLinks == 0
                    ? AppColors.successGreen
                    : AppColors.warningOrange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          RiskProgressBar(
            label: snapshot.networkHealthLabel,
            value: snapshot.networkHealth / 100,
            color: snapshot.networkHealthColor,
          ),
        ],
      ),
    );
  }
}

class SignalQualityCard extends StatelessWidget {
  final AiCommandCenterSnapshot snapshot;

  const SignalQualityCard({
    super.key,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(snapshot.signalQuality);
    return GlassCard(
      borderRadius: 8,
      borderColor: color.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SimpleSectionHeader(
            icon: Icons.network_check_rounded,
            title: 'Signal Quality',
            subtitle: snapshot.signalExplanation,
            color: color,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallStat(
                label: 'Average RSSI',
                value: snapshot.averageRssi == 0
                    ? 'Not available'
                    : '${snapshot.averageRssi.toStringAsFixed(1)} dBm',
                color: AppColors.gatewayColor,
              ),
              _SmallStat(
                label: 'Average SNR',
                value: snapshot.averageSnr == 0
                    ? 'Not available'
                    : '${snapshot.averageSnr.toStringAsFixed(1)} dB',
                color: AppColors.neonBlue,
              ),
              _SmallStat(
                label: 'Signal',
                value: snapshot.signalQuality,
                color: color,
              ),
              _SmallStat(
                label: 'Link',
                value: snapshot.linkQuality,
                color: _statusColor(snapshot.linkQuality),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PacketLossStatusCard extends StatelessWidget {
  final AiCommandCenterSnapshot snapshot;

  const _PacketLossStatusCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 8,
      borderColor: snapshot.packetLossColor.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SimpleSectionHeader(
            icon: Icons.podcasts_rounded,
            title: 'Packet Loss Watch',
            subtitle:
                'Current packet loss risk and direction from recent data.',
            color: snapshot.packetLossColor,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallStat(
                label: 'Current loss',
                value: '${snapshot.currentPacketLoss.toStringAsFixed(1)}%',
                color: snapshot.packetLossColor,
              ),
              _SmallStat(
                label: 'Risk',
                value: snapshot.packetLossLevel,
                color: snapshot.packetLossColor,
              ),
              _SmallStat(
                label: 'Trend',
                value: snapshot.packetLossTrend,
                color: snapshot.packetLossTrend == 'Rising'
                    ? AppColors.warningOrange
                    : AppColors.successGreen,
              ),
              _SmallStat(
                label: 'Congestion',
                value: snapshot.congestionRisk,
                color: _statusColor(snapshot.congestionRisk),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PacketLossForecastCard extends StatelessWidget {
  final AiCommandCenterSnapshot snapshot;

  const PacketLossForecastCard({
    super.key,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final modelLabel = snapshot.forecastModelConnected
        ? 'Forecast asset available'
        : 'Model not connected';
    return GlassCard(
      borderRadius: 8,
      borderColor: AppColors.neonBlue.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SimpleSectionHeader(
            icon: Icons.timeline_rounded,
            title: 'Forecast Center',
            subtitle:
                'Live trend is shown; missing forecast outputs are labeled clearly.',
            color: AppColors.neonBlue,
          ),
          const SizedBox(height: 12),
          MiniTrendChart(
            spots: snapshot.forecastSpots,
            color: snapshot.statusColor,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallStat(
                label: 'Forecast model',
                value: modelLabel,
                color: snapshot.forecastModelConnected
                    ? AppColors.successGreen
                    : AppColors.textMuted,
              ),
              _SmallStat(
                label: 'Next 10 min',
                value: snapshot.forecastModelConnected
                    ? 'Awaiting live output'
                    : 'Model not connected',
                color: AppColors.gatewayColor,
              ),
              _SmallStat(
                label: 'Next 30 min',
                value: snapshot.forecastModelConnected
                    ? 'Awaiting live output'
                    : 'Model not connected',
                color: AppColors.gatewayColor,
              ),
              _SmallStat(
                label: 'Trend risk',
                value: '${(snapshot.nextHourRisk * 100).toStringAsFixed(0)}%',
                color: snapshot.statusColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdaptiveSfRecommendationCard extends StatelessWidget {
  final AiCommandCenterSnapshot snapshot;

  const AdaptiveSfRecommendationCard({
    super.key,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 8,
      borderColor: AppColors.gatewayColor.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SimpleSectionHeader(
            icon: Icons.tune_rounded,
            title: 'Adaptive SF Recommendation',
            subtitle:
                'Radio optimization is shown only when a live output exists.',
            color: AppColors.gatewayColor,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallStat(
                label: 'Current mode',
                value: snapshot.currentRadioMode,
                color: AppColors.gatewayColor,
              ),
              _SmallStat(
                label: 'Recommended',
                value: snapshot.recommendedRadioMode,
                color: snapshot.recommendedRadioMode.contains('available')
                    ? AppColors.neonBlue
                    : AppColors.textMuted,
              ),
              _SmallStat(
                label: 'Expected gain',
                value: snapshot.sfImprovementLabel,
                color: AppColors.warningOrange,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AiRecommendationsSection extends StatelessWidget {
  final List<AiRecommendation> recommendations;
  final VoidCallback? onViewNode;
  final VoidCallback? onOpenReport;
  final VoidCallback? onMarkChecked;

  const AiRecommendationsSection({
    super.key,
    required this.recommendations,
    this.onViewNode,
    this.onOpenReport,
    this.onMarkChecked,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: _SimpleSectionHeader(
            icon: Icons.task_alt_rounded,
            title: 'AI Recommendations',
            subtitle: 'Clear actions ranked for the field team.',
            color: AppColors.successGreen,
          ),
        ),
        for (var index = 0; index < recommendations.length; index++) ...[
          AiRecommendationCard(
            recommendation: recommendations[index],
            primary: index == 0,
            onViewNode: onViewNode,
            onOpenReport: onOpenReport,
            onMarkChecked: onMarkChecked,
          ),
          if (index != recommendations.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class AiRecommendationCard extends StatelessWidget {
  final AiRecommendation recommendation;
  final bool primary;
  final VoidCallback? onViewNode;
  final VoidCallback? onOpenReport;
  final VoidCallback? onMarkChecked;

  const AiRecommendationCard({
    super.key,
    required this.recommendation,
    this.primary = false,
    this.onViewNode,
    this.onOpenReport,
    this.onMarkChecked,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 8,
      borderColor:
          recommendation.color.withValues(alpha: primary ? 0.24 : 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                primary
                    ? Icons.priority_high_rounded
                    : Icons.check_circle_rounded,
                color: recommendation.color,
                size: 21,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  recommendation.title,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              AiStatusBadge(
                label: recommendation.impact,
                color: recommendation.color,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            recommendation.detail,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _SmallChip(
            label: recommendation.expectedImprovement,
            color: recommendation.color,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(
                label: recommendation.actionLabel,
                icon: Icons.open_in_new_rounded,
                onPressed: onViewNode,
                color: AppColors.neonBlue,
              ),
              _ActionButton(
                label: 'Open report',
                icon: Icons.article_rounded,
                onPressed: onOpenReport,
                color: AppColors.gatewayColor,
              ),
              _ActionButton(
                label: 'Mark checked',
                icon: Icons.check_circle_rounded,
                onPressed: onMarkChecked,
                color: AppColors.successGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RootCauseExplanationCard extends StatelessWidget {
  final List<AiReason> reasons;
  final Color statusColor;
  final List<String> technicalLines;

  const RootCauseExplanationCard({
    super.key,
    required this.reasons,
    required this.statusColor,
    required this.technicalLines,
  });

  @override
  Widget build(BuildContext context) {
    return AiExplanationCard(
      reasons: reasons,
      statusColor: statusColor,
      technicalLines: technicalLines,
    );
  }
}

class BatteryLifeCard extends StatelessWidget {
  final AiCommandCenterSnapshot snapshot;

  const BatteryLifeCard({
    super.key,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 8,
      borderColor: snapshot.batteryColor.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SimpleSectionHeader(
            icon: Icons.battery_charging_full_rounded,
            title: 'Battery & Energy Prediction',
            subtitle:
                'Estimated from battery telemetry until a live RUL output is connected.',
            color: snapshot.batteryColor,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallStat(
                label: 'Weakest node',
                value: snapshot.weakestNode,
                color: snapshot.batteryColor,
              ),
              _SmallStat(
                label: 'Average battery',
                value: '${snapshot.averageBatteryPercent.toStringAsFixed(0)}%',
                color: AppColors.successGreen,
              ),
              _SmallStat(
                label: 'Remaining life',
                value: '${snapshot.remainingDays.toStringAsFixed(0)} days',
                color: snapshot.batteryColor,
              ),
              _SmallStat(
                label: 'Energy risk',
                value: snapshot.energyRiskLabel,
                color: _riskColor(snapshot.energyRisk),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RiskProgressBar(
            label: snapshot.batteryTrend,
            value: 1 - snapshot.energyRisk,
            color: snapshot.batteryColor,
          ),
        ],
      ),
    );
  }
}

class GatewayHealthCard extends StatelessWidget {
  final AiCommandCenterSnapshot snapshot;

  const GatewayHealthCard({
    super.key,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(snapshot.gatewayStatus);
    return GlassCard(
      borderRadius: 8,
      borderColor: statusColor.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SimpleSectionHeader(
            icon: Icons.cell_tower_rounded,
            title: 'Gateway Health',
            subtitle: snapshot.gatewayAction,
            color: statusColor,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallStat(
                label: 'Gateway',
                value: snapshot.gatewayStatus,
                color: statusColor,
              ),
              _SmallStat(
                label: 'Connected',
                value: '${snapshot.activeNodes}/3',
                color: snapshot.activeNodes == 3
                    ? AppColors.successGreen
                    : AppColors.warningOrange,
              ),
              _SmallStat(
                label: 'Total packets',
                value: _formatInt(snapshot.totalPackets),
                color: AppColors.gatewayColor,
              ),
              _SmallStat(
                label: 'WiFi',
                value: snapshot.gatewayWifiStatus,
                color: AppColors.neonBlue,
              ),
              _SmallStat(
                label: 'Firebase',
                value: snapshot.gatewayFirebaseStatus,
                color: AppColors.waterColor,
              ),
              _SmallStat(
                label: 'Last sync',
                value: snapshot.lastUpdatedLabel,
                color: AppColors.gatewayColor,
              ),
            ],
          ),
          if (snapshot.lastRawPacket.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SmallChip(
              label: 'Last raw packet: ${snapshot.lastRawPacket}',
              color: AppColors.gatewayColor,
            ),
          ],
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallChip(
                  label: 'Building -> Gateway', color: AppColors.buildingColor),
              _SmallChip(
                  label: 'Bridge -> Gateway', color: AppColors.bridgeColor),
              _SmallChip(
                  label: 'Water -> Gateway', color: AppColors.waterColor),
            ],
          ),
        ],
      ),
    );
  }
}

class ModelTrustCard extends StatelessWidget {
  final AiCommandCenterSnapshot snapshot;
  final MlopsSummary? summary;

  const ModelTrustCard({
    super.key,
    required this.snapshot,
    this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final healthColor = snapshot.modelHealthColor;
    return GlassCard(
      borderRadius: 8,
      borderColor: healthColor.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SimpleSectionHeader(
            icon: Icons.verified_rounded,
            title: 'Model Trust',
            subtitle: snapshot.modelHealthSentence,
            color: healthColor,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallStat(
                label: 'Model status',
                value: snapshot.inferenceStatus,
                color: healthColor,
              ),
              _SmallStat(
                label: 'Real data used',
                value: '${(snapshot.realDataRatio * 100).toStringAsFixed(0)}%',
                color: AppColors.successGreen,
              ),
              _SmallStat(
                label: 'AI checks',
                value: _formatInt(snapshot.aiChecks),
                color: AppColors.neonBlue,
              ),
              _SmallStat(
                label: 'Response time',
                value: snapshot.responseTimeLabel,
                color: AppColors.warningOrange,
              ),
              _SmallStat(
                label: 'Model version',
                value: snapshot.modelVersion,
                color: AppColors.gatewayColor,
              ),
              if (summary != null)
                _SmallStat(
                  label: 'F1 score',
                  value: _percent(summary!.metrics.f1),
                  color: AppColors.waterColor,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class AiTechnicalDetailsAccordion extends StatelessWidget {
  final MlopsSummary summary;

  const AiTechnicalDetailsAccordion({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final lpwanTasks = summary.lpwan.tasks.entries.toList();
    return GlassCard(
      borderRadius: 8,
      borderColor: AppColors.textMuted.withValues(alpha: 0.16),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          'Advanced Analytics',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          'Advanced metrics are hidden by default.',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SmallStat(
                  label: 'F1',
                  value: _percent(summary.metrics.f1),
                  color: AppColors.successGreen,
                ),
                _SmallStat(
                  label: 'Precision',
                  value: _percent(summary.metrics.precision),
                  color: AppColors.neonBlue,
                ),
                _SmallStat(
                  label: 'Recall',
                  value: _percent(summary.metrics.recall),
                  color: AppColors.waterColor,
                ),
                _SmallStat(
                  label: 'Version',
                  value: _modelVersion(summary),
                  color: AppColors.gatewayColor,
                ),
                _SmallStat(
                  label: 'Backend',
                  value: summary.monitoring.backend,
                  color: AppColors.gatewayColor,
                ),
                _SmallStat(
                  label: 'Data changed',
                  value: summary.drift.overallStatus,
                  color: _statusColor(summary.drift.overallStatus),
                ),
                _SmallStat(
                  label: 'TFLite variants',
                  value: '${summary.enterprise.edgeAi.variants.length}',
                  color: AppColors.waterColor,
                ),
                _SmallStat(
                  label: 'LPWAN models',
                  value: '${summary.lpwan.tasks.length}',
                  color: AppColors.neonBlue,
                ),
              ],
            ),
          ),
          if (summary.drift.topFeatureDrift.isNotEmpty) ...[
            const SizedBox(height: 12),
            _TechnicalBlock(
              title: 'Data changed since training',
              children: [
                for (final item in summary.drift.topFeatureDrift.take(3))
                  _SmallChip(
                    label:
                        '${_plainFeature(item.feature)} PSI ${item.psi.toStringAsFixed(2)}',
                    color: _statusColor(item.status),
                  ),
              ],
            ),
          ],
          if (summary.lpwan.dataset.sourceDatasets.isNotEmpty) ...[
            const SizedBox(height: 12),
            _TechnicalBlock(
              title: 'Source datasets',
              children: [
                for (final entry
                    in summary.lpwan.dataset.sourceDatasets.entries)
                  _SmallChip(
                    label: '${entry.key}: ${_formatInt(entry.value)}',
                    color: AppColors.gatewayColor,
                  ),
              ],
            ),
          ],
          if (lpwanTasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            _TechnicalBlock(
              title: 'LPWAN model benchmarks',
              children: [
                for (final entry in lpwanTasks)
                  _SmallChip(
                    label:
                        '${_plainFeature(entry.key)} ${entry.value.bestModel} ${_percent(entry.value.bestF1)}',
                    color: AppColors.neonBlue,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class TechnicalDetailsAccordion extends StatelessWidget {
  final MlopsSummary summary;

  const TechnicalDetailsAccordion({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return AiTechnicalDetailsAccordion(summary: summary);
  }
}

class AiStatusHeaderCard extends StatelessWidget {
  final AiCommandCenterSnapshot snapshot;
  final VoidCallback? onRunAnalysis;

  const AiStatusHeaderCard({
    super.key,
    required this.snapshot,
    this.onRunAnalysis,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 8,
      borderColor: snapshot.statusColor.withValues(alpha: 0.28),
      glowColor: snapshot.statusColor.withValues(alpha: 0.10),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          snapshot.statusColor.withValues(alpha: 0.12),
          Colors.white,
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
                  color: snapshot.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  snapshot.statusIcon,
                  color: snapshot.statusColor,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Command Center',
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Last updated ${snapshot.lastUpdatedLabel}',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              AiStatusBadge(
                label: snapshot.statusLabel,
                color: snapshot.statusColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            snapshot.summarySentence,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 13.5,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _ConfidenceLine(
                      confidence: snapshot.confidence,
                      color: snapshot.statusColor,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _TinyTextMetric(
                          label: 'Active alerts',
                          value: '${snapshot.activeAlerts}',
                          color: snapshot.activeAlerts > 0
                              ? AppColors.warningOrange
                              : AppColors.successGreen,
                        ),
                        const SizedBox(width: 8),
                        _TinyTextMetric(
                          label: 'Updated',
                          value: snapshot.lastUpdatedLabel,
                          color: AppColors.gatewayColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: onRunAnalysis,
                icon: Icon(
                  snapshot.isAnalyzing
                      ? Icons.hourglass_top_rounded
                      : Icons.play_arrow_rounded,
                ),
                color: snapshot.statusColor,
                tooltip: 'Run AI check',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SmartCityHealthOverview extends StatelessWidget {
  final List<AiDomainRisk> risks;

  const SmartCityHealthOverview({
    super.key,
    required this.risks,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 8,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SimpleSectionHeader(
            icon: Icons.dashboard_customize_rounded,
            title: 'Smart City Health Overview',
            subtitle: 'Which part of the city needs attention now.',
            color: AppColors.neonBlue,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 330;
              final cardWidth = twoColumns
                  ? ((constraints.maxWidth - 10) / 2)
                      .clamp(130.0, 320.0)
                      .toDouble()
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final risk in risks)
                    SizedBox(
                      width: cardWidth,
                      child: SmartCityRiskCard(risk: risk),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  final int number;
  final AiReason reason;
  final Color color;

  const _ReasonRow({
    required this.number,
    required this.reason,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 27,
          height: 27,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$number',
            style: GoogleFonts.inter(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reason.title,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: reason.weight.clamp(0.0, 1.0).toDouble(),
                  color: color,
                  backgroundColor: AppColors.gaugeTrack,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InlineAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final String impact;
  final Color color;

  const _InlineAction({
    required this.title,
    required this.subtitle,
    required this.impact,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates_rounded, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AiStatusBadge(label: impact, color: color),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.24)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _ConfidenceLine extends StatelessWidget {
  final double confidence;
  final Color color;

  const _ConfidenceLine({
    required this.confidence,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Prediction trusted',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '${(confidence * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.inter(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: confidence.clamp(0.0, 1.0).toDouble(),
            minHeight: 7,
            color: color,
            backgroundColor: AppColors.gaugeTrack,
          ),
        ),
      ],
    );
  }
}

class _SimpleSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _SimpleSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 9),
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
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 11.2,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _CompactMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}

class _TinyTextMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TinyTextMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SmallStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Flexible(
            child: Text(
              value.isEmpty ? '--' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: color,
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

class _SmallChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontSize: 11,
          height: 1.25,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TechnicalBlock extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _TechnicalBlock({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

class AiCommandCenterSnapshot {
  final String statusLabel;
  final Color statusColor;
  final IconData statusIcon;
  final String summarySentence;
  final String shortSummary;
  final String lastUpdatedLabel;
  final double confidence;
  final bool isAnalyzing;
  final int activeAlerts;
  final List<AiDomainRisk> domainRisks;
  final AiDomainRisk highestRisk;
  final double highestRiskPercent;
  final double networkHealth;
  final String networkHealthLabel;
  final Color networkHealthColor;
  final double deliveryRatio;
  final double currentPacketLoss;
  final double packetLossRisk;
  final String packetLossTrend;
  final String packetLossLevel;
  final Color packetLossColor;
  final double averageRssi;
  final double averageSnr;
  final String signalQuality;
  final String signalExplanation;
  final String linkQuality;
  final bool forecastModelConnected;
  final double remainingDays;
  final String lowestBatteryNode;
  final String highestBatteryNode;
  final String weakestNode;
  final double averageBatteryPercent;
  final double energyRisk;
  final String energyRiskLabel;
  final Color batteryColor;
  final String batteryTrend;
  final int activeNodes;
  final int weakLinks;
  final String gatewayStatus;
  final String gatewayAction;
  final String gatewayWifiStatus;
  final String gatewayFirebaseStatus;
  final String lastRawPacket;
  final int totalPackets;
  final String congestionRisk;
  final String currentRadioMode;
  final String recommendedRadioMode;
  final String sfImprovementLabel;
  final String modelVersion;
  final double realDataRatio;
  final int aiChecks;
  final String responseTimeLabel;
  final String inferenceStatus;
  final Color modelHealthColor;
  final String modelHealthSentence;
  final List<AiReason> reasons;
  final List<String> technicalReasonLines;
  final List<AiRecommendation> recommendations;
  final List<FlSpot> forecastSpots;
  final double nextHourRisk;

  const AiCommandCenterSnapshot({
    required this.statusLabel,
    required this.statusColor,
    required this.statusIcon,
    required this.summarySentence,
    required this.shortSummary,
    required this.lastUpdatedLabel,
    required this.confidence,
    required this.isAnalyzing,
    required this.activeAlerts,
    required this.domainRisks,
    required this.highestRisk,
    required this.highestRiskPercent,
    required this.networkHealth,
    required this.networkHealthLabel,
    required this.networkHealthColor,
    required this.deliveryRatio,
    required this.currentPacketLoss,
    required this.packetLossRisk,
    required this.packetLossTrend,
    required this.packetLossLevel,
    required this.packetLossColor,
    required this.averageRssi,
    required this.averageSnr,
    required this.signalQuality,
    required this.signalExplanation,
    required this.linkQuality,
    required this.forecastModelConnected,
    required this.remainingDays,
    required this.lowestBatteryNode,
    required this.highestBatteryNode,
    required this.weakestNode,
    required this.averageBatteryPercent,
    required this.energyRisk,
    required this.energyRiskLabel,
    required this.batteryColor,
    required this.batteryTrend,
    required this.activeNodes,
    required this.weakLinks,
    required this.gatewayStatus,
    required this.gatewayAction,
    required this.gatewayWifiStatus,
    required this.gatewayFirebaseStatus,
    required this.lastRawPacket,
    required this.totalPackets,
    required this.congestionRisk,
    required this.currentRadioMode,
    required this.recommendedRadioMode,
    required this.sfImprovementLabel,
    required this.modelVersion,
    required this.realDataRatio,
    required this.aiChecks,
    required this.responseTimeLabel,
    required this.inferenceStatus,
    required this.modelHealthColor,
    required this.modelHealthSentence,
    required this.reasons,
    required this.technicalReasonLines,
    required this.recommendations,
    required this.forecastSpots,
    required this.nextHourRisk,
  });

  AiRecommendation get primaryRecommendation => recommendations.first;

  static AiCommandCenterSnapshot from(
    DashboardProvider dashboard,
    AiProvider ai,
    MlopsSummary summary,
  ) {
    final gateway = dashboard.gateway;
    final domainRisks = <AiDomainRisk>[
      AiDomainRisk.fromValues(
        key: 'building',
        title: 'Building',
        icon: Icons.apartment_rounded,
        colorSeed: AppColors.buildingColor,
        anomaly: ai.getNodeAnomaly('building'),
        alert: dashboard.building?.hasAlert == true,
        online: dashboard.building?.online ?? true,
        batteryPct: dashboard.building?.batteryPercent ?? 100,
        pdr: gateway?.buildingNode.pdr ?? 100,
        rssi: dashboard.building?.rssi ?? gateway?.buildingNode.rssi ?? 0,
        snr: dashboard.building?.snr ?? gateway?.buildingNode.snr ?? 0,
        detail: _buildingDetail(dashboard),
      ),
      AiDomainRisk.fromValues(
        key: 'bridge',
        title: 'Bridge',
        icon: Icons.alt_route_rounded,
        colorSeed: AppColors.bridgeColor,
        anomaly: ai.getNodeAnomaly('bridge'),
        alert: dashboard.bridge?.hasAlert == true,
        online: dashboard.bridge?.online ?? true,
        batteryPct: dashboard.bridge?.batteryPercent ?? 100,
        pdr: gateway?.bridgeNode.pdr ?? 100,
        rssi: dashboard.bridge?.rssi ?? gateway?.bridgeNode.rssi ?? 0,
        snr: dashboard.bridge?.snr ?? gateway?.bridgeNode.snr ?? 0,
        detail: _bridgeDetail(dashboard),
      ),
      AiDomainRisk.fromValues(
        key: 'water',
        title: 'Water',
        icon: Icons.water_drop_rounded,
        colorSeed: AppColors.waterColor,
        anomaly: ai.getNodeAnomaly('water'),
        alert: dashboard.water?.hasAlert == true,
        online: dashboard.water?.online ?? true,
        batteryPct: dashboard.water?.batteryPercent ?? 100,
        pdr: gateway?.waterNode.pdr ?? 100,
        rssi: dashboard.water?.rssi ?? gateway?.waterNode.rssi ?? 0,
        snr: dashboard.water?.snr ?? gateway?.waterNode.snr ?? 0,
        detail: _waterDetail(dashboard),
      ),
      AiDomainRisk.fromValues(
        key: 'gateway',
        title: 'Gateway',
        icon: Icons.cell_tower_rounded,
        colorSeed: AppColors.gatewayColor,
        anomaly: null,
        alert: gateway?.online == false || (gateway?.lostNodes ?? 0) > 0,
        online: gateway?.online ?? true,
        batteryPct: 100,
        pdr: gateway?.pdr ?? 100,
        rssi: gateway?.averageRssi ?? 0,
        snr: gateway?.averageSnr ?? 0,
        detail: gateway == null
            ? 'Waiting for gateway telemetry.'
            : '${gateway.onlineNodes}/3 nodes connected, ${gateway.pdr.toStringAsFixed(1)}% delivery.',
      ),
    ]..sort((a, b) => b.score.compareTo(a.score));

    final highestRisk = domainRisks.first;
    final activeAlerts = dashboard.activeAlertCount;
    final activeProblems = activeAlerts + ai.totalActiveAnomalies;
    final gatewayPdr = gateway?.pdr ?? 100;
    final deliveryRatio = gatewayPdr.clamp(0.0, 100.0).toDouble();
    final currentPacketLoss =
        (100 - deliveryRatio).clamp(0.0, 100.0).toDouble();
    final averageRssi = gateway?.averageRssi ?? 0;
    final averageSnr = gateway?.averageSnr ?? 0;
    final signalQuality = _signalQualityLabel(averageRssi, averageSnr);
    final signalExplanation = _signalExplanation(averageRssi, averageSnr);
    final linkQuality = _linkQualityLabel(
      deliveryRatio,
      averageRssi,
      averageSnr,
      gateway?.online ?? true,
    );
    final onlineScore = dashboard.totalOnlineNodes / 3 * 100;
    final networkHealth = (gatewayPdr * 0.68 +
            onlineScore * 0.22 -
            math.min(activeProblems * 4.0, 18.0) +
            (gateway?.online == false ? -18.0 : 0.0))
        .clamp(0.0, 100.0)
        .toDouble();
    final packetLossRisk =
        (100 - gatewayPdr + activeProblems * 2.0).clamp(0.0, 100.0).toDouble();
    final batteries = _batteryNodes(dashboard);
    final lowestBattery = batteries.reduce(
      (a, b) => a.percent <= b.percent ? a : b,
    );
    final highestBattery = batteries.reduce(
      (a, b) => a.percent >= b.percent ? a : b,
    );
    final averageBattery =
        batteries.map((item) => item.percent).reduce((a, b) => a + b) /
            batteries.length;
    final energyRisk = (((100 - averageBattery) / 100) +
            (lowestBattery.percent < 25 ? 0.22 : 0.0) +
            (currentPacketLoss / 100 * 0.18))
        .clamp(0.0, 1.0)
        .toDouble();
    final remainingDays = (averageBattery * 1.8).clamp(1.0, 240.0).toDouble();
    final confidence = _confidenceFrom(summary, ai);
    final modelHealthColor = _confidenceColor(confidence);
    final status = _statusFor(
      highestRisk.score,
      activeProblems,
      networkHealth,
      confidence,
    );
    final statusColor = _statusColor(status);
    final reasons = _reasonsFor(dashboard, ai, summary, highestRisk);
    final recommendations =
        _recommendationsFor(dashboard, summary, highestRisk, reasons);
    final forecastSpots = _forecastSpots(ai, highestRisk.score);
    final nextHourRisk = _nextRiskFrom(forecastSpots, highestRisk.score);
    final weakLinks = gateway == null
        ? 0
        : gateway.nodeHealth.where((node) {
            final weakPdr = node.pdr > 0 && node.pdr < 95;
            final weakRssi = node.rssi != 0 && node.rssi < -100;
            final weakSnr = node.snr != 0 && node.snr < 0;
            return !node.online || weakPdr || weakRssi || weakSnr;
          }).length;
    final gatewayStatus = gateway == null
        ? 'Waiting'
        : gateway.online
            ? weakLinks > 0
                ? 'Watch'
                : 'Healthy'
            : 'Critical';
    final gatewayAction = gateway == null
        ? 'Waiting for gateway health telemetry from Firebase.'
        : gateway.online
            ? weakLinks > 0
                ? 'Check weak node line of sight and antenna placement.'
                : 'Gateway is receiving node packets normally.'
            : 'Restore gateway power, WiFi, and Firebase upload.';
    final hasSfModel = summary.lpwan.tasks.containsKey('optimal_sf');

    return AiCommandCenterSnapshot(
      statusLabel: status,
      statusColor: statusColor,
      statusIcon: _statusIcon(status),
      summarySentence: _summarySentence(status, highestRisk, reasons),
      shortSummary: _shortSummary(status, highestRisk),
      lastUpdatedLabel: _ageLabel(ai.lastAnalysisAt ?? dashboard.lastSync),
      confidence: confidence,
      isAnalyzing: ai.isAnalyzing,
      activeAlerts: activeAlerts,
      domainRisks: domainRisks,
      highestRisk: highestRisk,
      highestRiskPercent: highestRisk.score * 100,
      networkHealth: networkHealth,
      networkHealthLabel: networkHealth > 95
          ? 'Strong network'
          : networkHealth >= 80
              ? 'Needs watching'
              : 'Needs attention',
      networkHealthColor: networkHealth > 95
          ? AppColors.successGreen
          : networkHealth >= 80
              ? AppColors.warningOrange
              : AppColors.dangerRed,
      deliveryRatio: deliveryRatio,
      currentPacketLoss: currentPacketLoss,
      packetLossRisk: packetLossRisk,
      packetLossTrend: _trendLabel(forecastSpots),
      packetLossLevel: _riskLevel(packetLossRisk / 100),
      packetLossColor: _riskColor(packetLossRisk / 100),
      averageRssi: averageRssi,
      averageSnr: averageSnr,
      signalQuality: signalQuality,
      signalExplanation: signalExplanation,
      linkQuality: linkQuality,
      forecastModelConnected: _hasPacketForecast(summary),
      remainingDays: remainingDays,
      lowestBatteryNode: lowestBattery.title,
      highestBatteryNode: highestBattery.title,
      weakestNode: lowestBattery.title,
      averageBatteryPercent: averageBattery,
      energyRisk: energyRisk,
      energyRiskLabel: _riskLevel(energyRisk),
      batteryColor: lowestBattery.percent < 25
          ? AppColors.warningOrange
          : AppColors.successGreen,
      batteryTrend: lowestBattery.percent < 25 ? 'Watch' : 'Stable',
      activeNodes: gateway?.onlineNodes ?? dashboard.totalOnlineNodes,
      weakLinks: weakLinks,
      gatewayStatus: gatewayStatus,
      gatewayAction: gatewayAction,
      gatewayWifiStatus: gateway?.wifiStatus ?? 'Not available',
      gatewayFirebaseStatus: gateway?.firebaseStatus ?? 'Not available',
      lastRawPacket: gateway?.lastRawPacket ?? '',
      totalPackets: gateway?.totalPackets ?? 0,
      congestionRisk: packetLossRisk >= 30
          ? 'High'
          : packetLossRisk >= 12
              ? 'Watch'
              : 'Low',
      currentRadioMode: 'Not exposed by gateway',
      recommendedRadioMode: hasSfModel
          ? 'Model available, live SF pending'
          : 'Model not connected',
      sfImprovementLabel: hasSfModel ? 'Needs live SF output' : 'Unavailable',
      modelVersion: _modelVersion(summary),
      realDataRatio: _realRatio(summary),
      aiChecks: summary.monitoring.inferenceCount,
      responseTimeLabel: summary.monitoring.latencyMs <= 0
          ? 'local fallback'
          : '${summary.monitoring.latencyMs.toStringAsFixed(2)} ms',
      inferenceStatus: ai.isModelLoaded ? 'TFLite ready' : 'Fallback ready',
      modelHealthColor: modelHealthColor,
      modelHealthSentence: confidence >= 0.75
          ? 'Model is stable and the current prediction is trusted.'
          : 'Model is available, but confidence is lower than usual.',
      reasons: reasons,
      technicalReasonLines: _technicalReasonLines(summary, highestRisk),
      recommendations: recommendations,
      forecastSpots: forecastSpots,
      nextHourRisk: nextHourRisk,
    );
  }
}

class AiDomainRisk {
  final String key;
  final String title;
  final IconData icon;
  final double score;
  final String statusLabel;
  final Color color;
  final String detail;

  const AiDomainRisk({
    required this.key,
    required this.title,
    required this.icon,
    required this.score,
    required this.statusLabel,
    required this.color,
    required this.detail,
  });

  factory AiDomainRisk.fromValues({
    required String key,
    required String title,
    required IconData icon,
    required Color colorSeed,
    required AnomalyResult? anomaly,
    required bool alert,
    required bool online,
    required double batteryPct,
    required double pdr,
    required double rssi,
    required double snr,
    required String detail,
  }) {
    final signalRisk = _signalRisk(rssi, snr);
    final pdrRisk = pdr <= 0 ? 0.0 : ((100 - pdr) / 100).clamp(0.0, 1.0);
    final batteryRisk = batteryPct < 20
        ? 0.68
        : batteryPct < 35
            ? 0.42
            : 0.0;
    final score = [
      anomaly?.anomalyScore ?? 0.0,
      alert ? 0.72 : 0.0,
      online ? 0.0 : 0.88,
      signalRisk,
      pdrRisk.toDouble(),
      batteryRisk,
    ].reduce(math.max).clamp(0.0, 1.0).toDouble();
    return AiDomainRisk(
      key: key,
      title: title,
      icon: icon,
      score: score,
      statusLabel: _riskLevel(score),
      color: _riskColor(score, normalColor: colorSeed),
      detail: detail,
    );
  }
}

class AiReason {
  final String title;
  final double weight;

  const AiReason({
    required this.title,
    required this.weight,
  });
}

class AiRecommendation {
  final String title;
  final String detail;
  final String impact;
  final Color color;
  final String expectedImprovement;
  final String actionLabel;

  const AiRecommendation({
    required this.title,
    required this.detail,
    required this.impact,
    required this.color,
    this.expectedImprovement = 'Expected improvement unavailable',
    this.actionLabel = 'View node',
  });
}

class _BatteryNode {
  final String title;
  final double percent;

  const _BatteryNode(this.title, this.percent);
}

String _buildingDetail(DashboardProvider dashboard) {
  final building = dashboard.building;
  if (building == null) return 'Waiting for building telemetry.';
  if (building.hasAlert) return 'Air, smoke, gas, or soil values need review.';
  return 'Air and irrigation readings look normal.';
}

String _bridgeDetail(DashboardProvider dashboard) {
  final bridge = dashboard.bridge;
  if (bridge == null) return 'Waiting for bridge telemetry.';
  if (bridge.hasAlert) return bridge.roadStatus;
  return '${bridge.carsInside} cars inside, road is open.';
}

String _waterDetail(DashboardProvider dashboard) {
  final water = dashboard.water;
  if (water == null) return 'Waiting for water telemetry.';
  if (water.hasLeak) {
    return 'Leak probability ${water.leakProbability.toStringAsFixed(0)}%.';
  }
  return 'Tank difference ${water.difference.toStringAsFixed(0)}%, no leak.';
}

List<_BatteryNode> _batteryNodes(DashboardProvider dashboard) {
  final nodes = <_BatteryNode>[
    _BatteryNode('Building', dashboard.building?.batteryPercent ?? 100),
    _BatteryNode('Bridge', dashboard.bridge?.batteryPercent ?? 100),
    _BatteryNode('Water', dashboard.water?.batteryPercent ?? 100),
  ];
  return nodes;
}

double _confidenceFrom(MlopsSummary summary, AiProvider ai) {
  if (summary.metrics.confidenceMean > 0) {
    return summary.metrics.confidenceMean.clamp(0.0, 1.0).toDouble();
  }
  final risks = ai.topRiskNodes;
  if (risks.isEmpty) return 0.82;
  final values = risks
      .map((risk) => ai.getNodeAnomaly(risk.nodeId)?.confidence ?? 0.72)
      .toList();
  return (values.reduce((a, b) => a + b) / values.length)
      .clamp(0.0, 1.0)
      .toDouble();
}

String _statusFor(
  double highestRisk,
  int activeProblems,
  double networkHealth,
  double confidence,
) {
  if (highestRisk >= 0.78 || networkHealth < 70 || activeProblems >= 4) {
    return 'Critical';
  }
  if (highestRisk >= 0.58 || networkHealth < 82 || activeProblems >= 2) {
    return 'Attention';
  }
  if (highestRisk >= 0.32 || confidence < 0.70 || activeProblems == 1) {
    return 'Watch';
  }
  return 'Healthy';
}

String _summarySentence(
  String status,
  AiDomainRisk highestRisk,
  List<AiReason> reasons,
) {
  final cause = reasons.isEmpty
      ? 'current readings look stable'
      : reasons.first.title.toLowerCase();
  if (status == 'Healthy') {
    return 'AI sees a stable city network. The highest watched area is ${highestRisk.title}, and no urgent action is needed.';
  }
  return 'AI detected ${highestRisk.title.toLowerCase()} risk mainly because $cause.';
}

String _shortSummary(String status, AiDomainRisk highestRisk) {
  if (status == 'Healthy') {
    return 'Risk is low across the monitored nodes.';
  }
  return '${highestRisk.title} needs attention first.';
}

List<AiReason> _reasonsFor(
  DashboardProvider dashboard,
  AiProvider ai,
  MlopsSummary summary,
  AiDomainRisk highestRisk,
) {
  final reasons = <AiReason>[];
  final anomaly = ai.getNodeAnomaly(highestRisk.key);
  final maintenance = ai.getMaintenancePrediction(highestRisk.key);
  for (final feature in anomaly?.affectedFeatures ?? const <String>[]) {
    reasons.add(AiReason(title: _plainReason(feature), weight: 0.78));
  }
  for (final factor in maintenance?.riskFactors ?? const <String>[]) {
    reasons.add(AiReason(title: _plainReason(factor), weight: 0.68));
  }
  if (highestRisk.key == 'bridge' && dashboard.bridge?.hasAlert == true) {
    reasons.add(const AiReason(
      title: 'Bridge safety switches or traffic load changed',
      weight: 0.82,
    ));
  }
  if (highestRisk.key == 'water' && dashboard.water?.hasAlert == true) {
    reasons.add(const AiReason(
      title: 'Water level difference increased',
      weight: 0.84,
    ));
  }
  if (highestRisk.key == 'building' && dashboard.building?.hasAlert == true) {
    reasons.add(const AiReason(
      title: 'Air, smoke, gas, or soil readings changed',
      weight: 0.80,
    ));
  }
  final lpwanDrivers = summary.lpwan.tasks.values
      .expand((task) => task.topFeatures)
      .toList()
    ..sort((a, b) => b.meanAbsShap.compareTo(a.meanAbsShap));
  for (final driver in lpwanDrivers.take(3)) {
    reasons.add(AiReason(
      title: _plainReason(driver.feature),
      weight: (driver.meanAbsShap / 6).clamp(0.25, 0.90).toDouble(),
    ));
  }
  if (summary.drift.featuresDrifted > 0) {
    reasons.add(AiReason(
      title: 'Data changed since training',
      weight: summary.drift.featuresDrifted >= 3 ? 0.65 : 0.45,
    ));
  }
  if (reasons.isEmpty) {
    reasons.addAll(const [
      AiReason(title: 'Sensor readings are within normal range', weight: 0.22),
      AiReason(title: 'Packet delivery is stable', weight: 0.18),
      AiReason(title: 'Battery levels are acceptable', weight: 0.16),
    ]);
  }
  final deduped = <String, AiReason>{};
  for (final reason in reasons) {
    final key = reason.title.toLowerCase();
    final current = deduped[key];
    if (current == null || reason.weight > current.weight) {
      deduped[key] = reason;
    }
  }
  return deduped.values.toList()..sort((a, b) => b.weight.compareTo(a.weight));
}

List<AiRecommendation> _recommendationsFor(
  DashboardProvider dashboard,
  MlopsSummary summary,
  AiDomainRisk highestRisk,
  List<AiReason> reasons,
) {
  final output = <AiRecommendation>[];
  final reasonText =
      reasons.map((reason) => reason.title.toLowerCase()).join(' ');
  if (highestRisk.key == 'bridge' || reasonText.contains('bridge')) {
    output.add(const AiRecommendation(
      title: 'Inspect bridge gates and safety switches',
      detail:
          'Check the entry and exit gates, danger switches, and buzzer before allowing more traffic.',
      impact: 'High',
      color: AppColors.dangerRed,
      expectedImprovement: 'Expected safety improvement after field check',
      actionLabel: 'Open bridge',
    ));
  }
  if (highestRisk.key == 'water' || reasonText.contains('water')) {
    output.add(const AiRecommendation(
      title: 'Check water tanks and pipe area',
      detail:
          'Compare both tank levels and inspect wet soil around the pipe for leakage.',
      impact: 'High',
      color: AppColors.waterColor,
      expectedImprovement: 'Expected leak confirmation after inspection',
      actionLabel: 'Open water',
    ));
  }
  if (highestRisk.key == 'building' || reasonText.contains('air')) {
    output.add(const AiRecommendation(
      title: 'Inspect building air and irrigation sensors',
      detail:
          'Review smoke, gas, air quality, and soil readings. Ventilate the area if gas or smoke is elevated.',
      impact: 'Medium',
      color: AppColors.buildingColor,
      expectedImprovement: 'Expected safety improvement after sensor check',
      actionLabel: 'Open building',
    ));
  }
  if (highestRisk.key == 'gateway' ||
      reasonText.contains('signal') ||
      reasonText.contains('packet')) {
    output.add(const AiRecommendation(
      title: 'Check gateway antenna position',
      detail:
          'Confirm the gateway is powered, WiFi is stable, and the antenna has a clear position.',
      impact: 'High',
      color: AppColors.gatewayColor,
      expectedImprovement:
          'Expected signal reliability improvement after antenna check',
      actionLabel: 'Open gateway',
    ));
  }
  if (reasonText.contains('battery') || _lowestBatteryPercent(dashboard) < 30) {
    output.add(const AiRecommendation(
      title: 'Inspect the lowest battery node',
      detail:
          'Recharge or replace the weakest node battery before it affects packet delivery.',
      impact: 'Medium',
      color: AppColors.warningOrange,
      expectedImprovement:
          'Expected battery stability improvement after service',
      actionLabel: 'View battery',
    ));
  }
  if (summary.lpwan.tasks.containsKey('optimal_sf')) {
    output.add(const AiRecommendation(
      title: 'Review spreading factor recommendation',
      detail:
          'Use the LPWAN model output to reduce airtime when signal quality allows it.',
      impact: 'Medium',
      color: AppColors.neonBlue,
      expectedImprovement: 'Live SF improvement not connected yet',
      actionLabel: 'Review LPWAN',
    ));
  }
  if (output.isEmpty) {
    output.add(const AiRecommendation(
      title: 'Continue normal monitoring',
      detail:
          'No urgent action is needed. Keep collecting real bridge, water, and gateway readings.',
      impact: 'Low',
      color: AppColors.successGreen,
      expectedImprovement: 'No improvement needed right now',
      actionLabel: 'Keep watching',
    ));
  }
  return output;
}

double _lowestBatteryPercent(DashboardProvider dashboard) {
  return _batteryNodes(dashboard)
      .map((item) => item.percent)
      .reduce(math.min)
      .clamp(0.0, 100.0)
      .toDouble();
}

List<String> _technicalReasonLines(MlopsSummary summary, AiDomainRisk risk) {
  final lines = <String>[
    '${risk.title} risk ${(risk.score * 100).toStringAsFixed(1)}%',
    'Model accuracy ${_percent(summary.metrics.f1)}',
    'AI response ${summary.monitoring.latencyMs.toStringAsFixed(2)} ms',
  ];
  for (final feature in summary.explainability.topFeatures.take(3)) {
    lines.add(
        '${_plainFeature(feature.feature)} ${feature.importance.toStringAsFixed(2)}');
  }
  return lines;
}

List<FlSpot> _forecastSpots(AiProvider ai, double fallbackRisk) {
  final now = DateTime.now();
  final cutoff = now.subtract(const Duration(hours: 24));
  final points = ai.anomalyHistory
      .where((point) => point.timestamp.isAfter(cutoff))
      .toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  if (points.length < 2) {
    final base = fallbackRisk.clamp(0.04, 0.95).toDouble();
    return [
      FlSpot(0, (base * 0.82).clamp(0.0, 1.0).toDouble()),
      FlSpot(6, (base * 0.94).clamp(0.0, 1.0).toDouble()),
      FlSpot(12, base),
      FlSpot(18, (base * 1.06).clamp(0.0, 1.0).toDouble()),
      FlSpot(24, (base * 1.02).clamp(0.0, 1.0).toDouble()),
    ];
  }
  return points.map((point) {
    final x = point.timestamp.difference(cutoff).inMinutes / 60.0;
    return FlSpot(
      x.clamp(0.0, 24.0).toDouble(),
      point.score.clamp(0.0, 1.0).toDouble(),
    );
  }).toList(growable: false);
}

double _nextRiskFrom(List<FlSpot> spots, double fallbackRisk) {
  if (spots.isEmpty) return fallbackRisk.clamp(0.0, 1.0).toDouble();
  if (spots.length == 1) return spots.first.y.clamp(0.0, 1.0).toDouble();
  final last = spots.last.y;
  final previous = spots[spots.length - 2].y;
  return (last + (last - previous) * 0.35).clamp(0.0, 1.0).toDouble();
}

String _trendLabel(List<FlSpot> spots) {
  if (spots.length < 2) return 'Stable';
  final last = spots.last.y;
  final previous = spots[spots.length - 2].y;
  if (last > previous + 0.05) return 'Rising';
  if (last < previous - 0.05) return 'Improving';
  return 'Stable';
}

String _signalQualityLabel(double rssi, double snr) {
  if (rssi == 0 && snr == 0) return 'Not available';
  final risk = _signalRisk(rssi, snr);
  if (risk >= 0.70) return 'Weak';
  if (risk >= 0.45) return 'Watch';
  if (risk >= 0.25) return 'Fair';
  return 'Strong';
}

String _signalExplanation(double rssi, double snr) {
  if (rssi == 0 && snr == 0) {
    return 'Gateway has not exposed RSSI/SNR averages yet.';
  }
  if (rssi < -105 || snr < 0) {
    return 'Signal is weak enough to raise packet loss risk.';
  }
  if (rssi < -95 || snr < 5) {
    return 'Signal is usable but should be watched.';
  }
  return 'Signal quality is healthy for the current node links.';
}

String _linkQualityLabel(
  double deliveryRatio,
  double rssi,
  double snr,
  bool gatewayOnline,
) {
  if (!gatewayOnline) return 'Critical';
  if (deliveryRatio < 85 || _signalRisk(rssi, snr) >= 0.70) {
    return 'Weak';
  }
  if (deliveryRatio < 95 || _signalRisk(rssi, snr) >= 0.45) {
    return 'Watch';
  }
  return 'Good';
}

bool _hasPacketForecast(MlopsSummary summary) {
  return summary.enterprise.bestForecasts.any((forecast) {
    final task = forecast.task.toLowerCase();
    return task.contains('packet') ||
        task.contains('loss') ||
        task.contains('pdr') ||
        task.contains('delivery');
  });
}

double _signalRisk(double rssi, double snr) {
  final rssiRisk = rssi == 0
      ? 0.0
      : rssi < -115
          ? 0.72
          : rssi < -105
              ? 0.48
              : rssi < -95
                  ? 0.28
                  : 0.0;
  final snrRisk = snr == 0
      ? 0.0
      : snr < -8
          ? 0.72
          : snr < 0
              ? 0.48
              : snr < 5
                  ? 0.26
                  : 0.0;
  return math.max(rssiRisk, snrRisk);
}

String _riskLevel(double score) {
  if (score >= 0.75) return 'Critical';
  if (score >= 0.55) return 'Attention';
  if (score >= 0.30) return 'Watch';
  return 'Normal';
}

Color _riskColor(double score, {Color normalColor = AppColors.successGreen}) {
  if (score >= 0.75) return AppColors.dangerRed;
  if (score >= 0.55) return AppColors.warningOrange;
  if (score >= 0.30) return AppColors.warningOrange;
  return normalColor == AppColors.successGreen
      ? AppColors.successGreen
      : normalColor;
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'healthy':
    case 'normal':
    case 'low':
    case 'stable':
    case 'strong':
    case 'good':
    case 'online':
      return AppColors.successGreen;
    case 'watch':
    case 'medium':
    case 'fair':
    case 'waiting':
      return AppColors.warningOrange;
    case 'attention':
    case 'critical':
    case 'high':
    case 'weak':
      return AppColors.dangerRed;
    default:
      return AppColors.textMuted;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'Healthy':
      return Icons.check_circle_rounded;
    case 'Watch':
      return Icons.visibility_rounded;
    case 'Attention':
      return Icons.report_problem_rounded;
    default:
      return Icons.priority_high_rounded;
  }
}

Color _confidenceColor(double confidence) {
  if (confidence >= 0.82) return AppColors.successGreen;
  if (confidence >= 0.65) return AppColors.warningOrange;
  return AppColors.dangerRed;
}

String _modelVersion(MlopsSummary summary) {
  if (summary.modelVersion != 'unknown' && summary.modelVersion.isNotEmpty) {
    return summary.modelVersion;
  }
  if (summary.lpwan.tasks.isNotEmpty) {
    return 'LPWAN suite';
  }
  return 'local model';
}

double _realRatio(MlopsSummary summary) {
  if (summary.lpwan.dataset.realRatio > 0) {
    return summary.lpwan.dataset.realRatio;
  }
  return summary.training.realRatio;
}

String _plainReason(String raw) {
  final text = raw.toLowerCase();
  if (text.contains('snr')) return 'Signal quality dropped';
  if (text.contains('rssi') || text.contains('signal')) {
    return 'Signal is getting weaker';
  }
  if (text.contains('packet') ||
      text.contains('delivery') ||
      text.contains('crc')) {
    return 'Packet loss increased';
  }
  if (text.contains('battery') || text.contains('energy')) {
    return 'Battery behavior changed';
  }
  if (text.contains('current')) return 'Current consumption is high';
  if (text.contains('distance')) return 'Node distance is affecting the link';
  if (text.contains('gateway')) return 'Gateway condition changed';
  if (text.contains('water') || text.contains('leak')) {
    return 'Water readings suggest a leak risk';
  }
  if (text.contains('bridge') || text.contains('load')) {
    return 'Bridge load or safety state changed';
  }
  if (text.contains('smoke') || text.contains('gas') || text.contains('air')) {
    return 'Air safety readings changed';
  }
  if (text.contains('drift')) return 'Data changed since training';
  return _plainFeature(raw);
}

String _plainFeature(String raw) {
  final words = raw
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word.length <= 2
          ? word.toUpperCase()
          : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
  return words.isEmpty ? 'Unknown' : words;
}

String _ageLabel(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (time.millisecondsSinceEpoch <= 0) return 'not available';
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String _formatInt(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final remaining = raw.length - i;
    buffer.write(raw[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String _percent(double value) => '${(value * 100).toStringAsFixed(1)}%';
