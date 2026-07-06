import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/node_telemetry_card.dart';
import '../models/ai_models.dart';
import '../models/alert_model.dart';
import '../providers/ai_provider.dart';
import '../providers/dashboard_provider.dart';

class AlertsScreen extends StatefulWidget {
  final bool isEmbedded;

  const AlertsScreen({super.key, this.isEmbedded = false});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final ai = context.watch<AiProvider>();
    final alerts = _sortByAi(provider.effectiveAlerts, ai);
    final aiDetected = alerts.where((alert) {
      final score = ai.getAlertScore(alert.id);
      return score != null &&
          (score.severityLevel >= 2 || score.severityLabel == 'false_alarm');
    }).toList(growable: false);
    final body = SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications & Alerts',
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${provider.activeAlertCount} active notifications from Firebase and live node flags',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  provider.activeAlertCount > 0
                      ? Icons.notification_important_rounded
                      : Icons.check_circle_rounded,
                  color: provider.activeAlertCount > 0
                      ? AppColors.dangerRed
                      : AppColors.successGreen,
                ),
              ],
            ),
          ),
          _AlertOverview(provider: provider, alerts: alerts),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicator: BoxDecoration(
                color: AppColors.neonBlue.withOpacity(0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.neonBlue,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              tabs: [
                Tab(text: 'All (${alerts.length})'),
                Tab(
                    text:
                        'Active (${alerts.where((a) => !a.resolved).length})'),
                Tab(
                    text:
                        'Resolved (${alerts.where((a) => a.resolved).length})'),
                Tab(text: 'AI (${aiDetected.length})'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _AlertList(alerts: alerts),
                _AlertList(alerts: alerts.where((a) => !a.resolved).toList()),
                _AlertList(alerts: alerts.where((a) => a.resolved).toList()),
                _AlertList(alerts: aiDetected),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.isEmbedded) return body;
    return Scaffold(backgroundColor: AppColors.background, body: body);
  }

  List<AlertModel> _sortByAi(List<AlertModel> alerts, AiProvider ai) {
    final sorted = [...alerts];
    sorted.sort((a, b) {
      final aScore = ai.getAlertScore(a.id)?.severityLevel ?? 0;
      final bScore = ai.getAlertScore(b.id)?.severityLevel ?? 0;
      final byAi = bScore.compareTo(aScore);
      if (byAi != 0) return byAi;
      return b.timestamp.compareTo(a.timestamp);
    });
    return sorted;
  }
}

class _AlertOverview extends StatelessWidget {
  final DashboardProvider provider;
  final List<AlertModel> alerts;

  const _AlertOverview({
    required this.provider,
    required this.alerts,
  });

  @override
  Widget build(BuildContext context) {
    final active = alerts.where((alert) => !alert.resolved).length;
    final critical = alerts
        .where((alert) => !alert.resolved && alert.severity == 'critical')
        .length;
    final warning = alerts
        .where((alert) => !alert.resolved && alert.severity == 'warning')
        .length;
    final liveFlagNodes = [
      provider.building?.status.flags ?? 0,
      provider.bridge?.status.flags ?? 0,
      provider.water?.status.flags ?? 0,
    ].where((flags) => flags != 0).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active > 0
              ? AppColors.dangerRed.withOpacity(0.25)
              : AppColors.cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/alerts.webp',
                  width: 88,
                  height: 62,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 88,
                    height: 62,
                    color: AppColors.dangerRed.withOpacity(0.08),
                    child: const Icon(
                      Icons.notification_important_rounded,
                      color: AppColors.dangerRed,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active > 0 ? 'Action required' : 'System clear',
                      style: GoogleFonts.inter(
                        color: active > 0
                            ? AppColors.dangerRed
                            : AppColors.successGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Alerts combine Firebase records with live SC1 node flags, low battery, sensor errors, events, and actuator state.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.28,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AlertCountTile(
                  label: 'Active',
                  value: '$active',
                  color:
                      active > 0 ? AppColors.dangerRed : AppColors.successGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AlertCountTile(
                  label: 'Critical',
                  value: '$critical',
                  color: AppColors.dangerRed,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AlertCountTile(
                  label: 'Warning',
                  value: '$warning',
                  color: AppColors.warningOrange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AlertCountTile(
                  label: 'Flags',
                  value: '$liveFlagNodes',
                  color: AppColors.gatewayColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertCountTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AlertCountTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 16,
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
    );
  }
}

class _AlertList extends StatelessWidget {
  final List<AlertModel> alerts;

  const _AlertList({required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: AppColors.successGreen, size: 54),
            const SizedBox(height: 14),
            Text(
              'No alerts in this category',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      itemCount: alerts.length,
      itemBuilder: (context, index) => _AlertCard(alert: alerts[index]),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final AlertModel alert;

  const _AlertCard({required this.alert});

  Color _color(AlertScore? score) {
    if (score?.severityLabel == 'false_alarm') return AppColors.textMuted;
    if (alert.resolved) return AppColors.successGreen;
    switch (alert.severity) {
      case 'critical':
        return AppColors.dangerRed;
      case 'warning':
        return AppColors.warningOrange;
      default:
        return AppColors.neonBlue;
    }
  }

  IconData get _domainIcon {
    switch (alert.domain) {
      case 'building':
      case '1':
        return Icons.apartment_rounded;
      case 'bridge':
      case '2':
        return Icons.alt_route_rounded;
      case 'water':
      case '3':
        return Icons.water_drop_rounded;
      case 'gateway':
      case '4':
        return Icons.router_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiScore = context.watch<AiProvider>().getAlertScore(alert.id);
    final color = _color(aiScore);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_domainIcon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.message,
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _SmallChip(label: alert.domainLabel, color: color),
              if (aiScore != null)
                _SmallChip(
                  label:
                      'AI ${aiScore.severityLabel.replaceAll('_', ' ').toUpperCase()}',
                  color: color,
                ),
              _SmallChip(
                label:
                    alert.resolved ? 'RESOLVED' : alert.severity.toUpperCase(),
                color: alert.resolved ? AppColors.successGreen : color,
              ),
              if (alert.nodeId > 0)
                _SmallChip(
                    label: 'Node ${alert.nodeId}',
                    color: AppColors.gatewayColor),
              Text(
                DateFormat('HH:mm, MMM d').format(alert.dateTime),
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (alert.flags != 0) ...[
            const SizedBox(height: 10),
            FlagChips(flags: alert.flags),
          ],
          if (!alert.resolved) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    context.read<DashboardProvider>().resolveAlert(alert.id),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text('Resolve'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.successGreen,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.22)),
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
