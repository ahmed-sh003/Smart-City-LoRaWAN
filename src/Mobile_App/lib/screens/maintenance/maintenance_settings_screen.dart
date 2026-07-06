import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/user_role.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/notification_service.dart';
import '../mobile_home_screen.dart';

class MaintenanceSettingsScreen extends StatelessWidget {
  const MaintenanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final notifications = context.watch<NotificationService>();
    final role = context.watch<UserRoleController>();

    return SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Maintenance Settings',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Alert behavior and demo scenarios',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            borderRadius: 8,
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.notifications_active_rounded,
                  color: AppColors.warningOrange,
                  title: 'Alert notifications',
                  subtitle: 'Show an in-app banner when an alert arrives',
                  trailing: Switch(
                    value: notifications.enabled,
                    onChanged: notifications.setEnabled,
                  ),
                ),
                const Divider(color: AppColors.cardBorder),
                _SettingRow(
                  icon: Icons.volume_up_rounded,
                  color: AppColors.neonBlue,
                  title: 'Alert sound',
                  subtitle: notifications.alertSoundType,
                  trailing: Switch(
                    value: notifications.soundEnabled,
                    onChanged: notifications.setSoundEnabled,
                  ),
                ),
                const Divider(color: AppColors.cardBorder),
                _SettingRow(
                  icon: Icons.vibration_rounded,
                  color: AppColors.gatewayColor,
                  title: 'Vibration',
                  subtitle: 'Use haptic feedback where supported',
                  trailing: Switch(
                    value: notifications.vibrationEnabled,
                    onChanged: notifications.setVibrationEnabled,
                  ),
                ),
                const Divider(color: AppColors.cardBorder),
                _SettingRow(
                  icon: Icons.repeat_rounded,
                  color: AppColors.dangerRed,
                  title: 'Repeat critical sound',
                  subtitle: 'Critical alerts repeat until acknowledged',
                  trailing: Switch(
                    value: notifications.repeatCriticalAlertSound,
                    onChanged: notifications.setRepeatCriticalAlertSound,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            borderRadius: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Demo Scenario',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final scenario in MockScenario.values)
                      ChoiceChip(
                        label: Text(scenario.label),
                        selected: dashboard.mockScenario == scenario,
                        onSelected: dashboard.useMockData
                            ? (_) => dashboard.setMockScenario(scenario)
                            : null,
                        selectedColor:
                            AppColors.successGreen.withValues(alpha: 0.14),
                        side: BorderSide(
                          color: dashboard.mockScenario == scenario
                              ? AppColors.successGreen.withValues(alpha: 0.34)
                              : AppColors.cardBorder,
                        ),
                        labelStyle: GoogleFonts.inter(
                          color: dashboard.mockScenario == scenario
                              ? AppColors.successGreen
                              : AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (role.isAdmin)
            GlassCard(
              borderRadius: 8,
              borderColor: AppColors.neonBlue.withValues(alpha: 0.22),
              onTap: () {
                role.setRole(UserRole.admin);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    allowSnapshotting: false,
                    builder: (_) => const MobileHomeScreen(),
                  ),
                );
              },
              child: Row(
                children: [
                  const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: AppColors.neonBlue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Switch to Admin View',
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
