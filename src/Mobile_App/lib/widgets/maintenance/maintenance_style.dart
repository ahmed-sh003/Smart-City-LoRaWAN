import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/maintenance_alert.dart';

Color maintenanceSeverityColor(MaintenanceSeverity severity) {
  switch (severity) {
    case MaintenanceSeverity.normal:
      return AppColors.successGreen;
    case MaintenanceSeverity.warning:
      return AppColors.warningOrange;
    case MaintenanceSeverity.critical:
      return AppColors.dangerRed;
  }
}

IconData maintenanceDomainIcon(String domain) {
  switch (domain) {
    case 'building':
      return Icons.apartment_rounded;
    case 'bridge':
      return Icons.alt_route_rounded;
    case 'water':
      return Icons.water_drop_rounded;
    case 'gateway':
      return Icons.cell_tower_rounded;
    default:
      return Icons.sensors_rounded;
  }
}

IconData maintenanceSeverityIcon(MaintenanceSeverity severity) {
  switch (severity) {
    case MaintenanceSeverity.normal:
      return Icons.check_circle_rounded;
    case MaintenanceSeverity.warning:
      return Icons.warning_amber_rounded;
    case MaintenanceSeverity.critical:
      return Icons.priority_high_rounded;
  }
}
