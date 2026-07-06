import 'alert_model.dart';

enum MaintenanceSeverity {
  normal,
  warning,
  critical,
}

enum MaintenanceAlertStatus {
  newAlert,
  inProgress,
  resolved,
}

extension MaintenanceSeverityLabel on MaintenanceSeverity {
  String get label {
    switch (this) {
      case MaintenanceSeverity.normal:
        return 'Normal';
      case MaintenanceSeverity.warning:
        return 'Warning';
      case MaintenanceSeverity.critical:
        return 'Critical';
    }
  }
}

extension MaintenanceAlertStatusLabel on MaintenanceAlertStatus {
  String get label {
    switch (this) {
      case MaintenanceAlertStatus.newAlert:
        return 'New';
      case MaintenanceAlertStatus.inProgress:
        return 'In Progress';
      case MaintenanceAlertStatus.resolved:
        return 'Resolved';
    }
  }
}

class MaintenanceAlert {
  final String id;
  final String title;
  final String nodeName;
  final int nodeId;
  final String domain;
  final String domainLabel;
  final String location;
  final MaintenanceSeverity severity;
  final MaintenanceAlertStatus status;
  final String problem;
  final String reason;
  final String recommendedAction;
  final DateTime detectedAt;
  final AlertModel source;
  final Map<String, String> technicalValues;

  const MaintenanceAlert({
    required this.id,
    required this.title,
    required this.nodeName,
    required this.nodeId,
    required this.domain,
    required this.domainLabel,
    required this.location,
    required this.severity,
    required this.status,
    required this.problem,
    required this.reason,
    required this.recommendedAction,
    required this.detectedAt,
    required this.source,
    this.technicalValues = const {},
  });

  bool get isActive => status != MaintenanceAlertStatus.resolved;
  bool get isCritical => severity == MaintenanceSeverity.critical;
}
