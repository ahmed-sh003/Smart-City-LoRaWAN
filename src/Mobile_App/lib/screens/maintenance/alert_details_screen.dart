import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/mobile_app_frame.dart';
import '../../models/maintenance_alert.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/maintenance_view_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/maintenance/maintenance_style.dart';

class AlertDetailsScreen extends StatefulWidget {
  final MaintenanceAlert alert;

  const AlertDetailsScreen({
    super.key,
    required this.alert,
  });

  @override
  State<AlertDetailsScreen> createState() => _AlertDetailsScreenState();
}

class _AlertDetailsScreenState extends State<AlertDetailsScreen> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maintenance = context.watch<MaintenanceViewService>();
    final dashboard = context.watch<DashboardProvider>();
    final alert = maintenance.alerts(dashboard).firstWhere(
          (candidate) => candidate.id == widget.alert.id,
          orElse: () => widget.alert,
        );
    final notes = maintenance.notesFor(alert.id);
    final color = maintenanceSeverityColor(alert.severity);
    return MobileAppFrame(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: const Text('Alert Details'),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              GlassCard(
                borderRadius: 8,
                borderColor: color.withValues(alpha: 0.22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(maintenanceSeverityIcon(alert.severity),
                            color: color, size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert.title,
                                style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${alert.severity.label} - ${alert.status.label}',
                                style: GoogleFonts.inter(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailLine(label: 'Node', value: alert.nodeName),
                    _DetailLine(label: 'Domain', value: alert.domainLabel),
                    _DetailLine(label: 'Location', value: alert.location),
                    _DetailLine(
                      label: 'Time detected',
                      value: _timeLabel(alert.detectedAt),
                    ),
                    _DetailLine(
                      label: 'Current status',
                      value: alert.status.label,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SimpleSection(
                icon: Icons.help_rounded,
                title: 'Why this happened',
                text: alert.reason,
                color: color,
              ),
              const SizedBox(height: 12),
              _SimpleSection(
                icon: Icons.fact_check_rounded,
                title: 'What to check',
                text: _whatToCheck(alert),
                color: AppColors.gatewayColor,
              ),
              const SizedBox(height: 12),
              _SimpleSection(
                icon: Icons.task_alt_rounded,
                title: 'Recommended action',
                text: alert.recommendedAction,
                color: AppColors.successGreen,
              ),
              const SizedBox(height: 12),
              GlassCard(
                borderRadius: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Note',
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _noteController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Write what you checked...',
                        filled: true,
                        fillColor: AppColors.backgroundSecondary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () {
                          maintenance.addNote(
                            alert.id,
                            _noteController.text,
                          );
                          _noteController.clear();
                        },
                        icon: const Icon(Icons.note_add_rounded),
                        label: const Text('Save Note'),
                      ),
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      for (final note in notes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '- $note',
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                borderRadius: 8,
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text(
                    'Technical values',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  children: [
                    for (final entry in alert.technicalValues.entries)
                      _DetailLine(label: entry.key, value: entry.value),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _markInProgress(context, alert.id),
                    icon: const Icon(Icons.build_circle_rounded),
                    label: const Text('Mark In Progress'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _resolve(context, alert.id),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Mark Resolved'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _markInProgress(BuildContext context, String alertId) {
    context.read<MaintenanceViewService>().markInProgress(alertId);
    context.read<NotificationService>().acknowledgeLatestAlert();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alert marked in progress.')),
    );
  }

  Future<void> _resolve(BuildContext context, String alertId) async {
    context.read<MaintenanceViewService>().markResolvedLocal(alertId);
    context.read<NotificationService>().acknowledgeLatestAlert();
    await context.read<DashboardProvider>().resolveAlert(alertId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alert marked resolved.')),
    );
    Navigator.of(context).pop();
  }
}

class _SimpleSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color color;

  const _SimpleSection({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 8,
      borderColor: color.withValues(alpha: 0.16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
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
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _whatToCheck(MaintenanceAlert alert) {
  switch (alert.domain) {
    case 'building':
      return 'Check smoke, gas, temperature, wiring, and node battery.';
    case 'bridge':
      return 'Check bridge sensor mount, danger switches, gates, and buzzer.';
    case 'water':
      return 'Check pipe, valve, tank levels, and wet soil around the pipe.';
    case 'gateway':
      return 'Check gateway power, WiFi, Firebase sync, antenna, and distance.';
    default:
      return 'Check the node, power, antenna, and sensor wiring.';
  }
}

String _timeLabel(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
