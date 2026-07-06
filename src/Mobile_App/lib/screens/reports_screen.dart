import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/ai_command_center_widgets.dart';
import '../core/widgets/glass_card.dart';
import '../core/widgets/section_title.dart';
import '../models/alert_model.dart';
import '../models/mlops_models.dart';
import '../providers/ai_provider.dart';
import '../providers/dashboard_provider.dart';
import '../services/mlops_report_service.dart';
import '../services/mock_data_service.dart';

class ReportsScreen extends StatefulWidget {
  final bool isEmbedded;

  const ReportsScreen({super.key, this.isEmbedded = false});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final Future<MlopsSummary> _summaryFuture =
      const MlopsReportService().loadSummary();
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final ai = context.watch<AiProvider>();
    final body = SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Center & Reports',
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Simple AI guidance first, technical reports when needed',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Export report UI ready. PDF/CSV generation can be attached later.'),
                      ),
                    ),
                    icon: const Icon(Icons.file_download_rounded),
                    color: AppColors.neonBlue,
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            sliver: SliverList.list(
              children: [
                _ReportsModeTabs(
                  selectedIndex: _selectedTab,
                  onChanged: (index) => setState(() => _selectedTab = index),
                ),
                const SizedBox(height: 14),
                _selectedContent(provider, ai),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.isEmbedded) return body;
    return Scaffold(backgroundColor: AppColors.background, body: body);
  }

  Widget _selectedContent(DashboardProvider provider, AiProvider ai) {
    switch (_selectedTab) {
      case 1:
        return _SummaryFutureCard(
          future: _summaryFuture,
          builder: (summary) {
            final snapshot =
                AiCommandCenterSnapshot.from(provider, ai, summary);
            return Column(
              children: [
                LpwanNetworkIntelligenceSection(snapshot: snapshot),
                const SizedBox(height: 12),
                GatewayHealthCard(snapshot: snapshot),
              ],
            );
          },
        );
      case 2:
        return _SummaryFutureCard(
          future: _summaryFuture,
          builder: (summary) {
            final snapshot =
                AiCommandCenterSnapshot.from(provider, ai, summary);
            return Column(
              children: [
                PacketLossForecastCard(snapshot: snapshot),
                const SizedBox(height: 12),
                BatteryLifeCard(snapshot: snapshot),
              ],
            );
          },
        );
      case 3:
        return _SummaryFutureCard(
          future: _summaryFuture,
          builder: (summary) {
            final snapshot =
                AiCommandCenterSnapshot.from(provider, ai, summary);
            return Column(
              children: [
                AiRecommendationsSection(
                  recommendations: snapshot.recommendations,
                  onViewNode: _showViewNodeMessage,
                  onOpenReport: () => setState(() => _selectedTab = 4),
                  onMarkChecked: _showCheckedMessage,
                ),
                const SizedBox(height: 12),
                RootCauseExplanationCard(
                  reasons: snapshot.reasons,
                  statusColor: snapshot.statusColor,
                  technicalLines: snapshot.technicalReasonLines,
                ),
              ],
            );
          },
        );
      case 4:
        return _SummaryFutureCard(
          future: _summaryFuture,
          builder: (summary) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TechnicalDetailsAccordion(summary: summary),
              const SizedBox(height: 18),
              _TechnicalReportsTab(provider: provider),
            ],
          ),
        );
      default:
        return _SummaryFutureCard(
          future: _summaryFuture,
          builder: (summary) => AiCommandCenterScreen(
            dashboard: provider,
            ai: ai,
            summary: summary,
            onRunAnalysis: ai.isAnalyzing
                ? null
                : () => context.read<AiProvider>().runFullAnalysis(provider),
            onViewNode: _showViewNodeMessage,
            onOpenReport: () => setState(() => _selectedTab = 4),
            onMarkChecked: _showCheckedMessage,
          ),
        );
    }
  }

  void _showViewNodeMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Use the bottom navigation to open the selected node.'),
      ),
    );
  }

  void _showCheckedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI recommendation marked as checked.')),
    );
  }
}

class _ReportsModeTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _ReportsModeTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      _ReportModeItem('Simple AI Summary', Icons.auto_awesome_rounded),
      _ReportModeItem(
          'LPWAN Intelligence', Icons.settings_input_antenna_rounded),
      _ReportModeItem('Forecasts', Icons.timeline_rounded),
      _ReportModeItem('Recommendations', Icons.task_alt_rounded),
      _ReportModeItem('Advanced Analytics', Icons.article_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              SizedBox(
                width: items[index].label.length > 12 ? 158 : 126,
                child: _ReportModeButton(
                  item: items[index],
                  selected: selectedIndex == index,
                  onTap: () => onChanged(index),
                ),
              ),
              if (index != items.length - 1) const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportModeItem {
  final String label;
  final IconData icon;

  const _ReportModeItem(this.label, this.icon);
}

class _ReportModeButton extends StatelessWidget {
  final _ReportModeItem item;
  final bool selected;
  final VoidCallback onTap;

  const _ReportModeButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.neonBlue : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.neonBlue.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: color, size: 17),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                item.label,
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
      ),
    );
  }
}

class _SummaryFutureCard extends StatelessWidget {
  final Future<MlopsSummary> future;
  final Widget Function(MlopsSummary summary) builder;

  const _SummaryFutureCard({
    required this.future,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MlopsSummary>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const GlassCard(
            borderRadius: 8,
            child: SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        return builder(snapshot.data ?? MlopsSummary.fallback());
      },
    );
  }
}

class _TechnicalReportsTab extends StatelessWidget {
  final DashboardProvider provider;

  const _TechnicalReportsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          title: 'AI Production Monitor',
          icon: Icons.monitor_heart_rounded,
          iconColor: AppColors.gatewayColor,
        ),
        const _MlopsSummaryPanel(),
        const SizedBox(height: 18),
        const SectionTitle(
          title: 'Enterprise AI Platform',
          icon: Icons.hub_rounded,
          iconColor: AppColors.neonBlue,
        ),
        const _EnterpriseCommandCenterPanel(),
        const SizedBox(height: 18),
        const SectionTitle(
          title: 'LPWAN Research Center',
          icon: Icons.settings_input_antenna_rounded,
          iconColor: AppColors.gatewayColor,
        ),
        const _LpwanResearchPanel(),
        const SizedBox(height: 18),
        const SectionTitle(
          title: 'Last 24h Simulation',
          icon: Icons.show_chart_rounded,
          iconColor: AppColors.neonBlue,
        ),
        _TrendCard(provider: provider),
        const SizedBox(height: 18),
        const SectionTitle(
          title: 'Node Health',
          icon: Icons.health_and_safety_rounded,
          iconColor: AppColors.successGreen,
        ),
        _NodeHealthAnalytics(provider: provider),
        const SizedBox(height: 18),
        const SectionTitle(
          title: 'Alert Breakdown',
          icon: Icons.notification_important_rounded,
          iconColor: AppColors.dangerRed,
        ),
        _AlertBreakdown(alerts: provider.effectiveAlerts),
      ],
    );
  }
}

class _MlopsSummaryPanel extends StatefulWidget {
  const _MlopsSummaryPanel();

  @override
  State<_MlopsSummaryPanel> createState() => _MlopsSummaryPanelState();
}

class _MlopsSummaryPanelState extends State<_MlopsSummaryPanel> {
  late final Future<MlopsSummary> _future =
      const MlopsReportService().loadSummary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MlopsSummary>(
      future: _future,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        if (summary == null) {
          return const GlassCard(
            child: SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final statusColor = _statusColor(summary.status);
        return GlassCard(
          borderColor: statusColor.withValues(alpha: 0.26),
          glowColor: statusColor.withValues(alpha: 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_graph_rounded, color: statusColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Model ${summary.modelVersion}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Updated ${_ageLabel(summary.generatedAt)}',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(
                    label: summary.status.toUpperCase(),
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MlopsMetricTile(
                    label: 'Live Runs',
                    value: '${summary.monitoring.inferenceCount}',
                    icon: Icons.memory_rounded,
                    color: AppColors.gatewayColor,
                  ),
                  _MlopsMetricTile(
                    label: 'Avg Score',
                    value: _score(summary.monitoring.averageScore),
                    icon: Icons.speed_rounded,
                    color: AppColors.neonBlue,
                  ),
                  _MlopsMetricTile(
                    label: 'F1',
                    value: _percent(summary.metrics.f1),
                    icon: Icons.fact_check_rounded,
                    color: AppColors.successGreen,
                  ),
                  _MlopsMetricTile(
                    label: 'Latency',
                    value:
                        '${summary.monitoring.latencyMs.toStringAsFixed(3)} ms',
                    icon: Icons.bolt_rounded,
                    color: AppColors.warningOrange,
                  ),
                ],
              ),
              if (summary.training.hasData) ...[
                const SizedBox(height: 14),
                _MiniSectionHeader(
                  title: 'Training',
                  trailing: summary.training.phase,
                  color: AppColors.gatewayColor,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.dataset_rounded,
                      label: 'Rows',
                      value: '${summary.training.trainingRows}',
                      color: AppColors.gatewayColor,
                    ),
                    _InfoChip(
                      icon: Icons.public_rounded,
                      label: 'Real',
                      value: '${summary.training.realRows}',
                      color: AppColors.successGreen,
                    ),
                    _InfoChip(
                      icon: Icons.science_rounded,
                      label: 'Synthetic',
                      value: '${summary.training.syntheticRows}',
                      color: AppColors.warningOrange,
                    ),
                    _InfoChip(
                      icon: Icons.schema_rounded,
                      label: 'Features',
                      value: '${summary.training.featureCount}',
                      color: AppColors.neonBlue,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${(summary.training.realRatio * 100).toStringAsFixed(1)}% real-data training mix',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _ProductionDistribution(summary: summary),
              const SizedBox(height: 14),
              _MiniSectionHeader(
                title: 'Drift',
                trailing:
                    '${summary.drift.featuresDrifted} feature${summary.drift.featuresDrifted == 1 ? '' : 's'}',
                color: _statusColor(summary.drift.overallStatus),
              ),
              const SizedBox(height: 8),
              for (final item in summary.drift.topFeatureDrift.take(3))
                _DriftRow(item: item),
              const SizedBox(height: 14),
              _MiniSectionHeader(
                title: 'Top Drivers',
                trailing: summary.explainability.method,
                color: AppColors.neonBlue,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final feature
                      in summary.explainability.topFeatures.take(5))
                    _FeatureChip(
                      label: _featureLabel(feature.feature),
                      value: feature.importance.toStringAsFixed(2),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.inventory_2_rounded,
                    label: 'Registry',
                    value: summary.registry.activeVersion,
                    color: AppColors.gatewayColor,
                  ),
                  _InfoChip(
                    icon: Icons.science_rounded,
                    label: 'A/B',
                    value: summary.abTesting.status,
                    color: AppColors.neonBlue,
                  ),
                  _InfoChip(
                    icon: Icons.analytics_rounded,
                    label: 'Backend',
                    value: summary.monitoring.backend,
                    color: AppColors.successGreen,
                  ),
                ],
              ),
              if (summary.recommendations.isNotEmpty) ...[
                const SizedBox(height: 14),
                _MiniSectionHeader(
                  title: 'Recommended Action',
                  trailing: '',
                  color: statusColor,
                ),
                const SizedBox(height: 8),
                Text(
                  summary.recommendations.first,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EnterpriseCommandCenterPanel extends StatefulWidget {
  const _EnterpriseCommandCenterPanel();

  @override
  State<_EnterpriseCommandCenterPanel> createState() =>
      _EnterpriseCommandCenterPanelState();
}

class _EnterpriseCommandCenterPanelState
    extends State<_EnterpriseCommandCenterPanel> {
  late final Future<MlopsSummary> _future =
      const MlopsReportService().loadSummary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MlopsSummary>(
      future: _future,
      builder: (context, snapshot) {
        final enterprise = snapshot.data?.enterprise;
        if (enterprise == null) {
          return const GlassCard(
            child: SizedBox(
              height: 110,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (!enterprise.hasData) {
          return const SizedBox.shrink();
        }
        final statusColor = _statusColor(enterprise.status);
        return GlassCard(
          borderColor: statusColor.withValues(alpha: 0.24),
          glowColor: statusColor.withValues(alpha: 0.07),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_motion_rounded, color: statusColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enterprise AI Platform',
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Updated ${_ageLabel(enterprise.generatedAt)}',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(
                    label: enterprise.status.toUpperCase(),
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.dataset_rounded,
                    label: 'Rows',
                    value: _formatInt(enterprise.rows),
                    color: AppColors.gatewayColor,
                  ),
                  _InfoChip(
                    icon: Icons.public_rounded,
                    label: 'Real Mix',
                    value: _percent(enterprise.realRatio),
                    color: AppColors.successGreen,
                  ),
                  _InfoChip(
                    icon: Icons.travel_explore_rounded,
                    label: 'Catalog',
                    value: '${enterprise.catalogedDatasets}',
                    color: AppColors.neonBlue,
                  ),
                  _InfoChip(
                    icon: Icons.timeline_rounded,
                    label: 'Forecasts',
                    value: '${enterprise.forecastTasks}',
                    color: AppColors.warningOrange,
                  ),
                  _InfoChip(
                    icon: Icons.memory_rounded,
                    label: 'Edge',
                    value: '${enterprise.edgeAi.variants.length}',
                    color: AppColors.waterColor,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _MiniSectionHeader(
                title: 'Phase Coverage',
                trailing: enterprise.scientificValidation.publicationReadiness,
                color: AppColors.neonBlue,
              ),
              const SizedBox(height: 8),
              _PhaseCoverageWrap(phaseCoverage: enterprise.phaseCoverage),
              const SizedBox(height: 14),
              _MiniSectionHeader(
                title: 'Forecast Center',
                trailing: '${enterprise.bestForecasts.length} best models',
                color: AppColors.successGreen,
              ),
              const SizedBox(height: 8),
              for (final forecast in enterprise.bestForecasts.take(3))
                _ForecastRow(forecast: forecast),
              const SizedBox(height: 14),
              _MiniSectionHeader(
                title: 'Maintenance Center',
                trailing:
                    '${enterprise.maintenance.assetsEvaluated} assets evaluated',
                color: _maintenanceColor(enterprise.maintenance.priorityCounts),
              ),
              const SizedBox(height: 8),
              _MaintenancePriorityRow(maintenance: enterprise.maintenance),
              const SizedBox(height: 8),
              for (final asset in enterprise.maintenance.topAssets.take(2))
                _MaintenanceAssetRow(asset: asset),
              const SizedBox(height: 14),
              _MiniSectionHeader(
                title: 'Explainability Center',
                trailing: enterprise.rootCause.shapStatus,
                color: AppColors.gatewayColor,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final feature
                      in enterprise.rootCause.topFeatures.take(5))
                    _FeatureChip(
                      label: _featureLabel(feature.feature),
                      value: feature.importance.toStringAsFixed(2),
                    ),
                ],
              ),
              if (enterprise.rootCause.example.primaryCause.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '${enterprise.rootCause.example.primaryCause}: ${enterprise.rootCause.example.recommendedAction}',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _MiniSectionHeader(
                title: 'Model Monitoring Center',
                trailing: enterprise.advancedMlops.retrainingTriggered
                    ? 'Retraining review'
                    : 'Stable',
                color:
                    _statusColor(enterprise.advancedMlops.featureDriftStatus),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.blur_linear_rounded,
                    label: 'Feature Drift',
                    value: enterprise.advancedMlops.featureDriftStatus,
                    color: _statusColor(
                        enterprise.advancedMlops.featureDriftStatus),
                  ),
                  _InfoChip(
                    icon: Icons.change_circle_rounded,
                    label: 'Concept Drift',
                    value: enterprise.advancedMlops.conceptDriftStatus,
                    color: _statusColor(
                        enterprise.advancedMlops.conceptDriftStatus),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final check
                  in enterprise.advancedMlops.topDriftChecks.take(2))
                _EnterpriseDriftRow(check: check),
              const SizedBox(height: 14),
              _MiniSectionHeader(
                title: 'Edge AI Center',
                trailing: enterprise.edgeAi.selectedDeployment,
                color: AppColors.waterColor,
              ),
              const SizedBox(height: 8),
              for (final variant in enterprise.edgeAi.variants)
                _EdgeVariantRow(variant: variant),
              if (enterprise.honestyNotes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  enterprise.honestyNotes.first,
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PhaseCoverageWrap extends StatelessWidget {
  final Map<String, String> phaseCoverage;

  const _PhaseCoverageWrap({required this.phaseCoverage});

  @override
  Widget build(BuildContext context) {
    final entries = phaseCoverage.entries.take(10).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in entries)
          _InfoChip(
            icon: _phaseIcon(entry.key),
            label: _featureLabel(entry.key),
            value: entry.value,
            color: _phaseColor(entry.key),
          ),
      ],
    );
  }
}

class _ForecastRow extends StatelessWidget {
  final MlopsForecastSummary forecast;

  const _ForecastRow({required this.forecast});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.show_chart_rounded,
              color: AppColors.successGreen, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _compactTask(forecast.task),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${forecast.model} / ${forecast.rmse.toStringAsFixed(3)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenancePriorityRow extends StatelessWidget {
  final MlopsMaintenanceSummary maintenance;

  const _MaintenancePriorityRow({required this.maintenance});

  @override
  Widget build(BuildContext context) {
    final entries = maintenance.priorityCounts.entries.toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in entries)
          _InfoChip(
            icon: Icons.build_circle_rounded,
            label: entry.key,
            value: '${entry.value}',
            color: _priorityColor(entry.key),
          ),
      ],
    );
  }
}

class _MaintenanceAssetRow extends StatelessWidget {
  final MlopsMaintenanceAsset asset;

  const _MaintenanceAssetRow({required this.asset});

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(asset.maintenancePriority);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Icon(Icons.engineering_rounded, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_featureLabel(asset.domain)} / ${asset.nodeId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Risk ${_percent(asset.riskScore)}  RUL ${asset.estimatedRemainingLifeDays.toStringAsFixed(0)}d',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _StatusPill(label: asset.maintenancePriority, color: color),
          ],
        ),
      ),
    );
  }
}

class _EnterpriseDriftRow extends StatelessWidget {
  final MlopsDriftCheck check;

  const _EnterpriseDriftRow({required this.check});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(check.status);
    final value = check.psi.clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _featureLabel(check.feature),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'PSI ${check.psi.toStringAsFixed(2)}  KS ${check.ks.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: value,
              backgroundColor: AppColors.gaugeTrack,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _EdgeVariantRow extends StatelessWidget {
  final MlopsEdgeVariant variant;

  const _EdgeVariantRow({required this.variant});

  @override
  Widget build(BuildContext context) {
    final color = variant.status == 'active'
        ? AppColors.successGreen
        : AppColors.neonBlue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.memory_rounded, color: color, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              variant.name.toUpperCase(),
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            _fileSize(variant.sizeBytes),
            style: GoogleFonts.inter(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LpwanResearchPanel extends StatefulWidget {
  const _LpwanResearchPanel();

  @override
  State<_LpwanResearchPanel> createState() => _LpwanResearchPanelState();
}

class _LpwanResearchPanelState extends State<_LpwanResearchPanel> {
  late final Future<MlopsSummary> _future =
      const MlopsReportService().loadSummary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MlopsSummary>(
      future: _future,
      builder: (context, snapshot) {
        final lpwan = snapshot.data?.lpwan;
        if (lpwan == null) {
          return const GlassCard(
            child: SizedBox(
              height: 110,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (!lpwan.hasData) return const SizedBox.shrink();
        final statusColor = lpwan.isResearchGrade
            ? AppColors.successGreen
            : AppColors.warningOrange;
        final tasks = lpwan.tasks.entries.toList();
        return GlassCard(
          borderColor: statusColor.withValues(alpha: 0.24),
          glowColor: statusColor.withValues(alpha: 0.07),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.settings_input_antenna_rounded,
                      color: statusColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LoRaWAN Model Suite',
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'LoED + field telemetry, updated ${_ageLabel(lpwan.generatedAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(
                    label: lpwan.status.replaceAll('_', ' ').toUpperCase(),
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.dataset_rounded,
                    label: 'Rows',
                    value: _formatInt(lpwan.dataset.rowsAvailable),
                    color: AppColors.gatewayColor,
                  ),
                  _InfoChip(
                    icon: Icons.public_rounded,
                    label: 'Real',
                    value: _percent(lpwan.dataset.realRatio),
                    color: AppColors.successGreen,
                  ),
                  _InfoChip(
                    icon: Icons.science_rounded,
                    label: 'Synthetic',
                    value: _formatInt(lpwan.dataset.syntheticRows),
                    color: lpwan.dataset.syntheticRows == 0
                        ? AppColors.successGreen
                        : AppColors.warningOrange,
                  ),
                  _InfoChip(
                    icon: Icons.schema_rounded,
                    label: 'Features',
                    value: '${lpwan.featureCount}',
                    color: AppColors.neonBlue,
                  ),
                  _InfoChip(
                    icon: Icons.memory_rounded,
                    label: 'TFLite',
                    value: '${lpwan.tfliteAssets.length}',
                    color: AppColors.waterColor,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _MiniSectionHeader(
                title: 'Source Mix',
                trailing: '${lpwan.dataset.rowsUsedForTraining} train rows',
                color: AppColors.gatewayColor,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final source in lpwan.dataset.sourceTypes.entries)
                    _InfoChip(
                      icon: source.key == 'synthetic_lpwan'
                          ? Icons.science_rounded
                          : Icons.podcasts_rounded,
                      label: _featureLabel(source.key),
                      value: _formatInt(source.value),
                      color: source.key == 'synthetic_lpwan'
                          ? AppColors.warningOrange
                          : AppColors.successGreen,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _MiniSectionHeader(
                title: 'Model Tasks',
                trailing: '${tasks.length} trained',
                color: AppColors.neonBlue,
              ),
              const SizedBox(height: 8),
              for (final entry in tasks) _LpwanTaskRow(task: entry.value),
              const SizedBox(height: 14),
              _MiniSectionHeader(
                title: 'Top SHAP Drivers',
                trailing: 'computed',
                color: AppColors.successGreen,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final driver in _topLpwanDrivers(lpwan).take(6))
                    _FeatureChip(
                      label: _featureLabel(driver.feature),
                      value: driver.meanAbsShap.toStringAsFixed(2),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _MiniSectionHeader(
                title: 'Deployment Assets',
                trailing: 'mobile TFLite exports',
                color: AppColors.waterColor,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final task in tasks)
                    _InfoChip(
                      icon: Icons.memory_rounded,
                      label: _shortLpwanTask(task.key),
                      value: _fileSize(task.value.tfliteSizeBytes),
                      color: AppColors.waterColor,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LpwanTaskRow extends StatelessWidget {
  final MlopsLpwanTask task;

  const _LpwanTaskRow({required this.task});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.insights_rounded,
              color: AppColors.gatewayColor, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${task.bestModel} / F1 ${_percent(task.bestF1)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductionDistribution extends StatelessWidget {
  final MlopsSummary summary;

  const _ProductionDistribution({required this.summary});

  @override
  Widget build(BuildContext context) {
    final total = summary.monitoring.inferenceCount;
    final anomaly = total == 0 ? 0.0 : summary.monitoring.anomalies / total;
    final watch = total == 0 ? 0.0 : summary.monitoring.watch / total;
    final normal = (1 - anomaly - watch).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 9,
            child: Row(
              children: [
                Expanded(
                  flex: (normal * 1000).round().clamp(1, 1000).toInt(),
                  child: Container(color: AppColors.successGreen),
                ),
                Expanded(
                  flex: (watch * 1000).round().clamp(1, 1000).toInt(),
                  child: Container(color: AppColors.warningOrange),
                ),
                Expanded(
                  flex: (anomaly * 1000).round().clamp(1, 1000).toInt(),
                  child: Container(color: AppColors.dangerRed),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _TinyMetric(label: 'Normal', value: '${summary.monitoring.normal}'),
            _TinyMetric(label: 'Watch', value: '${summary.monitoring.watch}'),
            _TinyMetric(
                label: 'Anomaly', value: '${summary.monitoring.anomalies}'),
          ],
        ),
      ],
    );
  }
}

class _MlopsMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MlopsMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 52) / 2;
    return SizedBox(
      width: width.clamp(136.0, 250.0).toDouble(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.14)),
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
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
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
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final DashboardProvider provider;

  const _TrendCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final mock = MockDataService();
    final packetPoints = mock.last24hPackets(seed: provider.activeAlertCount);
    final alertPoints =
        mock.last24hAlerts(seed: provider.gateway?.totalPackets ?? 0);
    return GlassCard(
      borderColor: AppColors.neonBlue.withOpacity(0.22),
      child: SizedBox(
        height: 190,
        child: LineChart(
          LineChartData(
            minY: 0,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.cardBorder,
                strokeWidth: 1,
              ),
            ),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              _line(packetPoints, AppColors.neonBlue),
              _line(
                  alertPoints.map((v) => v * 8).toList(), AppColors.dangerRed),
            ],
          ),
        ),
      ),
    );
  }

  LineChartBarData _line(List<double> values, Color color) {
    return LineChartBarData(
      spots: [
        for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
      ],
      color: color,
      barWidth: 3,
      isCurved: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withOpacity(0.10),
      ),
    );
  }
}

class _MiniSectionHeader extends StatelessWidget {
  final String title;
  final String trailing;
  final Color color;

  const _MiniSectionHeader({
    required this.title,
    required this.trailing,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        if (trailing.isNotEmpty) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              trailing,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ] else
          const Spacer(),
      ],
    );
  }
}

class _DriftRow extends StatelessWidget {
  final MlopsFeatureDrift item;

  const _DriftRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(item.status);
    final progress = item.psi.clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _featureLabel(item.feature),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'PSI ${item.psi.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: progress,
              backgroundColor: AppColors.gaugeTrack,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeHealthAnalytics extends StatelessWidget {
  final DashboardProvider provider;

  const _NodeHealthAnalytics({required this.provider});

  @override
  Widget build(BuildContext context) {
    final gateway = provider.gateway;
    if (gateway == null) return const SizedBox.shrink();
    return Column(
      children: [
        for (final node in gateway.nodeHealth) ...[
          GlassCard(
            padding: const EdgeInsets.all(14),
            borderColor: node.online
                ? AppColors.successGreen.withOpacity(0.2)
                : AppColors.dangerRed,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${node.name} Node',
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${node.pdr.toStringAsFixed(1)}% PDR',
                      style: GoogleFonts.inter(
                        color: node.pdr >= 95
                            ? AppColors.successGreen
                            : AppColors.warningOrange,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: (node.pdr / 100).clamp(0, 1),
                    backgroundColor: AppColors.gaugeTrack,
                    valueColor: AlwaysStoppedAnimation(
                      node.pdr >= 95
                          ? AppColors.successGreen
                          : AppColors.warningOrange,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    _TinyMetric(
                        label: 'Battery',
                        value: '${node.batteryPercent.toStringAsFixed(0)}%'),
                    _TinyMetric(
                        label: 'RSSI',
                        value: '${node.rssi.toStringAsFixed(0)} dBm'),
                    _TinyMetric(
                        label: 'SNR',
                        value: '${node.snr.toStringAsFixed(1)} dB'),
                    _TinyMetric(label: 'Lost', value: '${node.lostPackets}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;
  final String value;

  const _FeatureChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.neonBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              color: AppColors.neonBlue,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
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
                color: AppColors.textPrimary,
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

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AlertBreakdown extends StatelessWidget {
  final List<AlertModel> alerts;

  const _AlertBreakdown({required this.alerts});

  @override
  Widget build(BuildContext context) {
    int count(String domain) =>
        alerts.where((alert) => alert.domain == domain).length;
    return GlassCard(
      child: Column(
        children: [
          _BreakdownRow(
              label: 'Building',
              value: count('building'),
              color: AppColors.buildingColor),
          _BreakdownRow(
              label: 'Bridge',
              value: count('bridge'),
              color: AppColors.bridgeColor),
          _BreakdownRow(
              label: 'Water',
              value: count('water'),
              color: AppColors.waterColor),
          _BreakdownRow(
              label: 'Gateway',
              value: count('gateway'),
              color: AppColors.gatewayColor),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'healthy':
    case 'low':
    case 'passed':
      return AppColors.successGreen;
    case 'watch':
    case 'medium':
      return AppColors.warningOrange;
    case 'attention':
    case 'high':
    case 'failed':
      return AppColors.dangerRed;
    default:
      return AppColors.textMuted;
  }
}

String _percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

String _score(double value) => value.toStringAsFixed(3);

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

String _fileSize(int bytes) {
  if (bytes <= 0) return '--';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}

String _compactTask(String task) {
  return _featureLabel(task)
      .replaceAll('Network ', '')
      .replaceAll('Environment ', '')
      .replaceAll('Probability', 'Prob')
      .replaceAll('Tomorrow', 'Next Day');
}

String _shortLpwanTask(String task) {
  switch (task) {
    case 'packet_loss':
      return 'Loss';
    case 'link_quality':
      return 'Link';
    case 'gateway_health':
      return 'Gateway';
    case 'energy_risk':
      return 'Energy';
    case 'optimal_sf':
      return 'SF';
    default:
      return _featureLabel(task);
  }
}

List<MlopsLpwanFeatureDriver> _topLpwanDrivers(MlopsLpwanSummary lpwan) {
  final byFeature = <String, MlopsLpwanFeatureDriver>{};
  for (final task in lpwan.tasks.values) {
    for (final driver in task.topFeatures) {
      final current = byFeature[driver.feature];
      if (current == null || driver.meanAbsShap > current.meanAbsShap) {
        byFeature[driver.feature] = driver;
      }
    }
  }
  final drivers = byFeature.values.toList()
    ..sort((a, b) => b.meanAbsShap.compareTo(a.meanAbsShap));
  return drivers;
}

IconData _phaseIcon(String key) {
  switch (key) {
    case 'data':
      return Icons.dataset_rounded;
    case 'features':
      return Icons.schema_rounded;
    case 'forecasting':
      return Icons.timeline_rounded;
    case 'maintenance':
      return Icons.engineering_rounded;
    case 'explainability':
      return Icons.psychology_rounded;
    case 'multiModel':
      return Icons.hub_rounded;
    case 'mlops':
      return Icons.monitor_heart_rounded;
    case 'edge':
      return Icons.memory_rounded;
    case 'science':
      return Icons.biotech_rounded;
    default:
      return Icons.check_circle_rounded;
  }
}

Color _phaseColor(String key) {
  switch (key) {
    case 'data':
    case 'science':
      return AppColors.gatewayColor;
    case 'features':
    case 'forecasting':
      return AppColors.neonBlue;
    case 'maintenance':
    case 'edge':
      return AppColors.waterColor;
    case 'explainability':
    case 'multiModel':
      return AppColors.successGreen;
    case 'mlops':
      return AppColors.warningOrange;
    default:
      return AppColors.textMuted;
  }
}

Color _priorityColor(String priority) {
  switch (priority.toUpperCase()) {
    case 'CRITICAL':
      return AppColors.dangerRed;
    case 'HIGH':
      return AppColors.warningOrange;
    case 'MEDIUM':
      return AppColors.neonBlue;
    case 'LOW':
      return AppColors.successGreen;
    default:
      return AppColors.textMuted;
  }
}

Color _maintenanceColor(Map<String, int> counts) {
  if ((counts['CRITICAL'] ?? 0) > 0) return AppColors.dangerRed;
  if ((counts['HIGH'] ?? 0) > 0) return AppColors.warningOrange;
  if ((counts['MEDIUM'] ?? 0) > 0) return AppColors.neonBlue;
  return AppColors.successGreen;
}

String _featureLabel(String feature) {
  return feature
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part.length <= 3
          ? part.toUpperCase()
          : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _ageLabel(DateTime date) {
  final diff = DateTime.now().difference(date.toLocal());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

class _TinyMetric extends StatelessWidget {
  final String label;
  final String value;

  const _TinyMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: GoogleFonts.inter(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '$value',
            style: GoogleFonts.inter(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
