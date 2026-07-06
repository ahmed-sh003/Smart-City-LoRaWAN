import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/maintenance_alert.dart';
import 'maintenance_style.dart';

class MaintenanceStatusBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final MaintenanceSeverity severity;
  final int activeAlerts;
  final String gatewayStatus;
  final String nodesOnline;

  const MaintenanceStatusBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.severity,
    required this.activeAlerts,
    required this.gatewayStatus,
    required this.nodesOnline,
  });

  @override
  Widget build(BuildContext context) {
    final color = maintenanceSeverityColor(severity);
    return GlassCard(
      borderRadius: 8,
      borderColor: color.withValues(alpha: 0.28),
      glowColor: color.withValues(alpha: 0.08),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: 0.14),
          Colors.white,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  maintenanceSeverityIcon(severity),
                  color: color,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _BannerPill(
                label: 'Active alerts',
                value: '$activeAlerts',
                color: activeAlerts > 0 ? color : AppColors.successGreen,
              ),
              _BannerPill(
                label: 'Gateway',
                value: gatewayStatus,
                color: gatewayStatus == 'Online'
                    ? AppColors.successGreen
                    : AppColors.dangerRed,
              ),
              _BannerPill(
                label: 'Nodes',
                value: nodesOnline,
                color: nodesOnline.startsWith('3/')
                    ? AppColors.successGreen
                    : AppColors.warningOrange,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BannerPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
