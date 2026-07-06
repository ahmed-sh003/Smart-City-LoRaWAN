import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/mobile_app_frame.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/maintenance_view_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/maintenance/alert_sound_banner.dart';
import 'alert_details_screen.dart';
import 'maintenance_alerts_screen.dart';
import 'maintenance_home_screen.dart';
import 'maintenance_nodes_screen.dart';
import 'maintenance_settings_screen.dart';

class MaintenanceDashboardScreen extends StatefulWidget {
  const MaintenanceDashboardScreen({super.key});

  @override
  State<MaintenanceDashboardScreen> createState() =>
      _MaintenanceDashboardScreenState();
}

class _MaintenanceDashboardScreenState
    extends State<MaintenanceDashboardScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final maintenance = context.watch<MaintenanceViewService>();
    final notifications = context.watch<NotificationService>();
    final pages = [
      const MaintenanceHomeScreen(),
      const MaintenanceAlertsScreen(),
      const MaintenanceNodesScreen(),
      const MaintenanceSettingsScreen(),
    ];
    final latest = notifications.latestAlert;
    final showBanner = latest != null &&
        !latest.resolved &&
        !notifications.latestAlertAcknowledged;

    return MobileAppFrame(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            if (showBanner)
              SafeArea(
                bottom: false,
                child: AlertSoundBanner(
                  alert: latest,
                  onAcknowledge: () {
                    notifications.acknowledgeLatestAlert();
                    maintenance.acknowledge(latest.id);
                  },
                  onViewDetails: () => _openLatestAlert(
                    context,
                    dashboard,
                    maintenance,
                    latest.id,
                  ),
                ),
              ),
            Expanded(
              child: SizedBox.expand(
                child: pages[_index],
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          height: 72,
          selectedIndex: _index,
          backgroundColor: AppColors.backgroundSecondary,
          elevation: 8,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: dashboard.activeAlertCount > 0
                  ? Badge(
                      label: Text('${dashboard.activeAlertCount}'),
                      child: const Icon(Icons.notification_important_rounded),
                    )
                  : const Icon(Icons.notification_important_rounded),
              label: 'Alerts',
            ),
            const NavigationDestination(
              icon: Icon(Icons.sensors_rounded),
              label: 'Nodes',
            ),
            const NavigationDestination(
              icon: Icon(Icons.tune_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  void _openLatestAlert(
    BuildContext context,
    DashboardProvider dashboard,
    MaintenanceViewService maintenance,
    String alertId,
  ) {
    final matching =
        maintenance.alerts(dashboard).where((a) => a.id == alertId);
    if (matching.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        allowSnapshotting: false,
        builder: (_) => AlertDetailsScreen(alert: matching.first),
      ),
    );
  }
}
