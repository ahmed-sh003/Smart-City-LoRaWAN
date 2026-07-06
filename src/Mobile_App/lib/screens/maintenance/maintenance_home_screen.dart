import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/maintenance_alert.dart';
import '../../models/maintenance_node.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/maintenance_view_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/maintenance/alert_card.dart';
import '../../widgets/maintenance/maintenance_summary_card.dart';
import '../../widgets/maintenance/node_status_card.dart';
import '../../widgets/maintenance/status_banner.dart';
import 'alert_details_screen.dart';
import 'node_details_screen.dart';

class MaintenanceHomeScreen extends StatelessWidget {
  const MaintenanceHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final maintenance = context.watch<MaintenanceViewService>();
    final nodes = maintenance.nodes(dashboard);
    final fieldNodes =
        nodes.where((node) => node.domain != 'gateway').toList(growable: false);
    final gateway = nodes.firstWhere((node) => node.domain == 'gateway');
    final activeAlerts =
        maintenance.alerts(dashboard).where((alert) => alert.isActive).toList();
    final highest = maintenance.highestPriorityAlert(dashboard);
    final severity = maintenance.citySeverity(dashboard);
    final critical = activeAlerts
        .where((alert) => alert.severity == MaintenanceSeverity.critical)
        .length;
    final warning = activeAlerts
        .where((alert) => alert.severity == MaintenanceSeverity.warning)
        .length;
    final resolved = maintenance
        .alerts(dashboard)
        .where((alert) => alert.status == MaintenanceAlertStatus.resolved)
        .length;
    final healthyNodes = nodes
        .where((node) => node.severity == MaintenanceSeverity.normal)
        .length;

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
                  'Maintenance Dashboard',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Simple status, alerts, locations, and actions',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          MaintenanceStatusBanner(
            title: maintenance.cityStatusTitle(dashboard),
            subtitle: highest == null
                ? 'Everything is working normally. No active alerts.'
                : '${highest.nodeName} at ${highest.location}: ${highest.problem}',
            severity: severity,
            activeAlerts: activeAlerts.length,
            gatewayStatus: gateway.online ? 'Online' : 'Offline',
            nodesOnline: '${dashboard.totalOnlineNodes}/3 online',
          ),
          const SizedBox(height: 14),
          MaintenanceSummaryCard(
            critical: critical,
            warning: warning,
            resolved: resolved,
            healthyNodes: '$healthyNodes/${nodes.length}',
            gatewayStatus: gateway.online ? 'Online' : 'Offline',
          ),
          const SizedBox(height: 14),
          if (highest != null) ...[
            _SectionHeader(
              title: 'Needs Attention First',
              subtitle: 'Open this alert before anything else',
              icon: Icons.priority_high_rounded,
            ),
            const SizedBox(height: 10),
            MaintenanceAlertCard(
              alert: highest,
              onDetails: () => _openAlert(context, highest),
              onInProgress: () => _markInProgress(context, highest),
              onResolved: () => _resolve(context, highest),
            ),
            const SizedBox(height: 14),
          ],
          _SectionHeader(
            title: 'Gateway and Nodes',
            subtitle: 'Gateway is central; node cards show simple status',
            icon: Icons.hub_rounded,
          ),
          const SizedBox(height: 10),
          NodeTopologyGrid(
            gateway: gateway,
            nodes: fieldNodes,
            onGatewayTap: () => _openNode(context, gateway),
            onNodeTap: (node) => _openNode(context, node),
          ),
        ],
      ),
    );
  }

  void _openAlert(BuildContext context, MaintenanceAlert alert) {
    Navigator.of(context).push(
      MaterialPageRoute(
        allowSnapshotting: false,
        builder: (_) => AlertDetailsScreen(alert: alert),
      ),
    );
  }

  void _openNode(BuildContext context, MaintenanceNode node) {
    Navigator.of(context).push(
      MaterialPageRoute(
        allowSnapshotting: false,
        builder: (_) => NodeDetailsScreen(node: node),
      ),
    );
  }

  void _markInProgress(BuildContext context, MaintenanceAlert alert) {
    context.read<MaintenanceViewService>().markInProgress(alert.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alert marked in progress.')),
    );
  }

  Future<void> _resolve(BuildContext context, MaintenanceAlert alert) async {
    context.read<MaintenanceViewService>().markResolvedLocal(alert.id);
    context.read<NotificationService>().acknowledgeLatestAlert();
    await context.read<DashboardProvider>().resolveAlert(alert.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alert marked resolved.')),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.neonBlue, size: 22),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
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
