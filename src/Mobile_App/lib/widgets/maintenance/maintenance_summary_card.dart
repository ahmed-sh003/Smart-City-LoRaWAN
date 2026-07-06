import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';

class MaintenanceSummaryCard extends StatelessWidget {
  final int critical;
  final int warning;
  final int resolved;
  final String healthyNodes;
  final String gatewayStatus;

  const MaintenanceSummaryCard({
    super.key,
    required this.critical,
    required this.warning,
    required this.resolved,
    required this.healthyNodes,
    required this.gatewayStatus,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today',
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryTile(
                label: 'Critical',
                value: '$critical',
                color: AppColors.dangerRed,
                icon: Icons.priority_high_rounded,
              ),
              _SummaryTile(
                label: 'Warning',
                value: '$warning',
                color: AppColors.warningOrange,
                icon: Icons.warning_amber_rounded,
              ),
              _SummaryTile(
                label: 'Resolved',
                value: '$resolved',
                color: AppColors.successGreen,
                icon: Icons.check_circle_rounded,
              ),
              _SummaryTile(
                label: 'Healthy nodes',
                value: healthyNodes,
                color: AppColors.neonBlue,
                icon: Icons.sensors_rounded,
              ),
              _SummaryTile(
                label: 'Gateway',
                value: gatewayStatus,
                color: gatewayStatus == 'Online'
                    ? AppColors.successGreen
                    : AppColors.dangerRed,
                icon: Icons.cell_tower_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 146, maxWidth: 210),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
