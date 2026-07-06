import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/maintenance_alert.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/maintenance_view_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/maintenance/alert_card.dart';
import '../../widgets/maintenance/domain_filter_chip.dart';
import 'alert_details_screen.dart';

class MaintenanceAlertsScreen extends StatefulWidget {
  const MaintenanceAlertsScreen({super.key});

  @override
  State<MaintenanceAlertsScreen> createState() =>
      _MaintenanceAlertsScreenState();
}

class _MaintenanceAlertsScreenState extends State<MaintenanceAlertsScreen> {
  MaintenanceAlertFilter _filter = MaintenanceAlertFilter.all;

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final maintenance = context.watch<MaintenanceViewService>();
    final alerts = maintenance.filteredAlerts(dashboard, _filter);
    return SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Technician Alerts',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Simple filters and clear field actions',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      for (final filter in MaintenanceAlertFilter.values) ...[
                        DomainFilterChip(
                          filter: filter,
                          selected: _filter == filter,
                          onSelected: () => setState(() => _filter = filter),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            _EmptyAlerts(filter: _filter)
          else
            for (var index = 0; index < alerts.length; index++) ...[
              MaintenanceAlertCard(
                alert: alerts[index],
                onDetails: () => _openAlert(alerts[index]),
                onInProgress:
                    alerts[index].status == MaintenanceAlertStatus.resolved
                        ? null
                        : () => _markInProgress(alerts[index]),
                onResolved:
                    alerts[index].status == MaintenanceAlertStatus.resolved
                        ? null
                        : () => _resolve(alerts[index]),
              ),
              if (index != alerts.length - 1) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  void _openAlert(MaintenanceAlert alert) {
    Navigator.of(context).push(
      MaterialPageRoute(
        allowSnapshotting: false,
        builder: (_) => AlertDetailsScreen(alert: alert),
      ),
    );
  }

  void _markInProgress(MaintenanceAlert alert) {
    context.read<MaintenanceViewService>().markInProgress(alert.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alert marked in progress.')),
    );
  }

  Future<void> _resolve(MaintenanceAlert alert) async {
    context.read<MaintenanceViewService>().markResolvedLocal(alert.id);
    context.read<NotificationService>().acknowledgeLatestAlert();
    await context.read<DashboardProvider>().resolveAlert(alert.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alert marked resolved.')),
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  final MaintenanceAlertFilter filter;

  const _EmptyAlerts({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.successGreen,
            size: 42,
          ),
          const SizedBox(height: 10),
          Text(
            filter == MaintenanceAlertFilter.resolved
                ? 'No resolved alerts yet'
                : 'No active alerts here',
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Everything in this filter is clear.',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
