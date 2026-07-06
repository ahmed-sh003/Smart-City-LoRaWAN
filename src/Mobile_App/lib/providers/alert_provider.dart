import 'package:flutter/foundation.dart';

import '../models/alert_model.dart';
import '../services/notification_service.dart';
import 'dashboard_provider.dart';

class AlertProvider extends ChangeNotifier {
  final List<AlertModel> _alerts = [];
  NotificationService? _notifications;

  List<AlertModel> get alerts => List.unmodifiable(_alerts);
  List<AlertModel> get activeAlerts =>
      _alerts.where((alert) => !alert.resolved).toList(growable: false);
  int get activeCount => activeAlerts.length;
  int get criticalCount =>
      activeAlerts.where((alert) => alert.severity == 'critical').length;
  int get warningCount =>
      activeAlerts.where((alert) => alert.severity == 'warning').length;

  void attach(NotificationService service) {
    _notifications = service;
  }

  void syncFromDashboard(DashboardProvider dashboard) {
    final next = dashboard.effectiveAlerts;
    final signature = next
        .map((alert) =>
            '${alert.id}:${alert.resolved}:${alert.severity}:${alert.message}')
        .join('|');
    final currentSignature = _alerts
        .map((alert) =>
            '${alert.id}:${alert.resolved}:${alert.severity}:${alert.message}')
        .join('|');
    if (signature == currentSignature) return;
    _alerts
      ..clear()
      ..addAll(next);
    _notifyNewCriticals(next);
    notifyListeners();
  }

  List<AlertModel> byDomain(String domain) {
    return _alerts
        .where((alert) =>
            alert.domain == domain ||
            (domain == 'building' && alert.domain == '1') ||
            (domain == 'bridge' && alert.domain == '2') ||
            (domain == 'water' && alert.domain == '3') ||
            (domain == 'gateway' && alert.domain == '4'))
        .toList(growable: false);
  }

  void _notifyNewCriticals(List<AlertModel> alerts) {
    final notifications = _notifications;
    if (notifications == null) return;
    for (final alert in alerts.where((alert) => !alert.resolved)) {
      if (alert.severity == 'critical') {
        if (alert.id.contains('leak')) {
          notifications.showLeakAlert(alert);
        } else if (alert.id.contains('bridge') ||
            alert.title.toLowerCase().contains('danger')) {
          notifications.showBridgeDangerAlert(alert);
        } else if (alert.id.contains('gas') || alert.id.contains('smoke')) {
          notifications.showGasAlert(alert);
        } else {
          notifications.showCriticalAlert(alert);
        }
      } else if (alert.severity == 'warning') {
        notifications.showWarningAlert(alert);
      }
    }
  }
}
