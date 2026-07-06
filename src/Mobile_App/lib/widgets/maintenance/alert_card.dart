import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/maintenance_alert.dart';
import 'maintenance_style.dart';

class MaintenanceAlertCard extends StatelessWidget {
  final MaintenanceAlert alert;
  final VoidCallback? onDetails;
  final VoidCallback? onInProgress;
  final VoidCallback? onResolved;

  const MaintenanceAlertCard({
    super.key,
    required this.alert,
    this.onDetails,
    this.onInProgress,
    this.onResolved,
  });

  @override
  Widget build(BuildContext context) {
    final color = maintenanceSeverityColor(alert.severity);
    return GlassCard(
      borderRadius: 8,
      borderColor: color.withValues(alpha: 0.20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(maintenanceSeverityIcon(alert.severity),
                  color: color, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${alert.severity.label} Alert',
                      style: GoogleFonts.inter(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      alert.title,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _SmallStatus(label: alert.status.label, color: color),
            ],
          ),
          const SizedBox(height: 12),
          _InfoLine(
              label: 'Node', value: '${alert.nodeName} - ${alert.domainLabel}'),
          _InfoLine(label: 'Location', value: alert.location),
          _InfoLine(label: 'Problem', value: alert.problem),
          _InfoLine(label: 'Action', value: alert.recommendedAction),
          _InfoLine(label: 'Time', value: _timeLabel(alert.detectedAt)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(
                label: 'View Details',
                icon: Icons.open_in_new_rounded,
                onPressed: onDetails,
                color: AppColors.neonBlue,
              ),
              _ActionButton(
                label: 'Mark In Progress',
                icon: Icons.build_circle_rounded,
                onPressed: alert.status == MaintenanceAlertStatus.resolved
                    ? null
                    : onInProgress,
                color: AppColors.warningOrange,
              ),
              _ActionButton(
                label: 'Mark Resolved',
                icon: Icons.check_circle_rounded,
                onPressed: alert.status == MaintenanceAlertStatus.resolved
                    ? null
                    : onResolved,
                color: AppColors.successGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _SmallStatus extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallStatus({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.24)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

String _timeLabel(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
