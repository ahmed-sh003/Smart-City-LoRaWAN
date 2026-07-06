import 'maintenance_alert.dart';

class MaintenanceNode {
  final String key;
  final String name;
  final String domain;
  final String domainLabel;
  final String location;
  final MaintenanceSeverity severity;
  final String statusLabel;
  final bool online;
  final String latestProblem;
  final String lastSeen;
  final double batteryPercent;
  final String batteryLabel;
  final String signalLabel;
  final MaintenanceAlert? latestAlert;
  final Map<String, String> technicalValues;

  const MaintenanceNode({
    required this.key,
    required this.name,
    required this.domain,
    required this.domainLabel,
    required this.location,
    required this.severity,
    required this.statusLabel,
    required this.online,
    required this.latestProblem,
    required this.lastSeen,
    required this.batteryPercent,
    required this.batteryLabel,
    required this.signalLabel,
    this.latestAlert,
    this.technicalValues = const {},
  });

  bool get hasProblem => severity != MaintenanceSeverity.normal;
}
