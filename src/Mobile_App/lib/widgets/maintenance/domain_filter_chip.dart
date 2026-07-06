import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../services/maintenance_view_service.dart';

class DomainFilterChip extends StatelessWidget {
  final MaintenanceAlertFilter filter;
  final bool selected;
  final VoidCallback onSelected;

  const DomainFilterChip({
    super.key,
    required this.filter,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final color = _filterColor(filter);
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      label: Text(filter.label),
      avatar: Icon(_filterIcon(filter), size: 16, color: color),
      selectedColor: color.withValues(alpha: 0.13),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? color.withValues(alpha: 0.34) : AppColors.cardBorder,
      ),
      labelStyle: GoogleFonts.inter(
        color: selected ? color : AppColors.textSecondary,
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

Color _filterColor(MaintenanceAlertFilter filter) {
  switch (filter) {
    case MaintenanceAlertFilter.critical:
      return AppColors.dangerRed;
    case MaintenanceAlertFilter.warning:
      return AppColors.warningOrange;
    case MaintenanceAlertFilter.building:
      return AppColors.buildingColor;
    case MaintenanceAlertFilter.bridge:
      return AppColors.bridgeColor;
    case MaintenanceAlertFilter.water:
      return AppColors.waterColor;
    case MaintenanceAlertFilter.gateway:
      return AppColors.gatewayColor;
    case MaintenanceAlertFilter.resolved:
      return AppColors.successGreen;
    case MaintenanceAlertFilter.all:
      return AppColors.neonBlue;
  }
}

IconData _filterIcon(MaintenanceAlertFilter filter) {
  switch (filter) {
    case MaintenanceAlertFilter.critical:
      return Icons.priority_high_rounded;
    case MaintenanceAlertFilter.warning:
      return Icons.warning_amber_rounded;
    case MaintenanceAlertFilter.building:
      return Icons.apartment_rounded;
    case MaintenanceAlertFilter.bridge:
      return Icons.alt_route_rounded;
    case MaintenanceAlertFilter.water:
      return Icons.water_drop_rounded;
    case MaintenanceAlertFilter.gateway:
      return Icons.cell_tower_rounded;
    case MaintenanceAlertFilter.resolved:
      return Icons.check_circle_rounded;
    case MaintenanceAlertFilter.all:
      return Icons.select_all_rounded;
  }
}
