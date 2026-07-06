import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/firebase_paths.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/glass_card.dart';
import '../models/user_role.dart';
import '../providers/dashboard_provider.dart';
import '../providers/theme_provider.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';
import 'maintenance/maintenance_dashboard_screen.dart';

class SettingsScreen extends StatelessWidget {
  final bool isEmbedded;

  const SettingsScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final notifications = context.watch<NotificationService>();
    final role = context.watch<UserRoleController>();
    final body = SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mock scenarios, Firebase streams, and SC1 protocol reference',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            sliver: SliverList.list(
              children: [
                GlassCard(
                  borderColor: AppColors.neonBlue.withOpacity(0.22),
                  child: Column(
                    children: [
                      _SettingRow(
                        icon: Icons.data_usage_rounded,
                        color: AppColors.neonBlue,
                        title: 'Mock Data Mode',
                        subtitle: provider.useMockData
                            ? 'Local scenario data is active'
                            : 'Firebase Realtime Database streams are active',
                        trailing: Switch(
                          value: provider.useMockData,
                          activeColor: AppColors.neonBlue,
                          onChanged: provider.toggleMockData,
                        ),
                      ),
                      const Divider(color: AppColors.cardBorder),
                      _SettingRow(
                        icon: Icons.cloud_sync_rounded,
                        color: provider.firebaseLiveMode
                            ? AppColors.successGreen
                            : AppColors.textMuted,
                        title: 'Firebase Live Mode',
                        subtitle: provider.firebaseLiveMode
                            ? 'Listening to Firebase Realtime Database'
                            : 'Firebase disabled, mock stream active',
                        trailing: Switch(
                          value: provider.firebaseLiveMode,
                          activeColor: AppColors.successGreen,
                          onChanged: provider.toggleFirebaseMode,
                        ),
                      ),
                      const Divider(color: AppColors.cardBorder),
                      _SettingRow(
                        icon: Icons.sync_rounded,
                        color: provider.rotateMockScenarios
                            ? AppColors.successGreen
                            : AppColors.warningOrange,
                        title: 'Rotate Mock Scenarios',
                        subtitle: 'Current: ${provider.mockScenario.label}',
                        trailing: Switch(
                          value: provider.rotateMockScenarios,
                          activeColor: AppColors.successGreen,
                          onChanged: provider.useMockData
                              ? provider.toggleMockRotation
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  borderColor: AppColors.warningOrange.withOpacity(0.22),
                  child: Column(
                    children: [
                      _SettingRow(
                        icon: Icons.notifications_active_rounded,
                        color: AppColors.warningOrange,
                        title: 'Notifications',
                        subtitle:
                            'In-app notification center and mobile haptics',
                        trailing: Switch(
                          value: notifications.enabled,
                          activeColor: AppColors.warningOrange,
                          onChanged: notifications.setEnabled,
                        ),
                      ),
                      const Divider(color: AppColors.cardBorder),
                      _SettingRow(
                        icon: Icons.volume_up_rounded,
                        color: AppColors.neonBlue,
                        title: 'Alert Sound',
                        subtitle: 'Reserved for mobile local notification tone',
                        trailing: Switch(
                          value: notifications.soundEnabled,
                          activeColor: AppColors.neonBlue,
                          onChanged: notifications.setSoundEnabled,
                        ),
                      ),
                      const Divider(color: AppColors.cardBorder),
                      _SettingRow(
                        icon: Icons.vibration_rounded,
                        color: AppColors.gatewayColor,
                        title: 'Vibration',
                        subtitle: 'Critical alerts trigger mobile haptics',
                        trailing: Switch(
                          value: notifications.vibrationEnabled,
                          activeColor: AppColors.gatewayColor,
                          onChanged: notifications.setVibrationEnabled,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (role.isAdmin) ...[
                  GlassCard(
                    borderColor: AppColors.successGreen.withOpacity(0.22),
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          allowSnapshotting: false,
                          builder: (_) => const MaintenanceDashboardScreen(),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        const Icon(
                          Icons.engineering_rounded,
                          color: AppColors.successGreen,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Switch to Technician View',
                                style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Open the simplified maintenance app without hiding Admin access',
                                style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                GlassCard(
                  borderColor: AppColors.warningOrange.withOpacity(0.22),
                  child: Column(
                    children: [
                      _SettingRow(
                        icon: Icons.repeat_rounded,
                        color: AppColors.dangerRed,
                        title: 'Repeat Critical Alert Sound',
                        subtitle: 'Critical alerts repeat until acknowledged',
                        trailing: Switch(
                          value: notifications.repeatCriticalAlertSound,
                          activeColor: AppColors.dangerRed,
                          onChanged: notifications.setRepeatCriticalAlertSound,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  borderColor: AppColors.gatewayColor.withOpacity(0.22),
                  child: Column(
                    children: [
                      _SettingRow(
                        icon: Icons.dark_mode_rounded,
                        color: AppColors.gatewayColor,
                        title: 'Theme Mode',
                        subtitle: 'Premium dark mode is optimized for demos',
                        trailing: DropdownButton<ThemeMode>(
                          value: themeProvider.themeMode,
                          dropdownColor: AppColors.card,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(
                              value: ThemeMode.dark,
                              child: Text('Dark'),
                            ),
                            DropdownMenuItem(
                              value: ThemeMode.light,
                              child: Text('Light'),
                            ),
                            DropdownMenuItem(
                              value: ThemeMode.system,
                              child: Text('System'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              themeProvider.setThemeMode(value);
                            }
                          },
                        ),
                      ),
                      const Divider(color: AppColors.cardBorder),
                      _SettingRow(
                        icon: Icons.timer_rounded,
                        color: AppColors.successGreen,
                        title: 'Node Timeout',
                        subtitle:
                            '${themeProvider.nodeTimeoutSeconds}s before node is marked lost',
                        trailing: SizedBox(
                          width: 132,
                          child: Slider(
                            min: 30,
                            max: 300,
                            divisions: 9,
                            value: themeProvider.nodeTimeoutSeconds.toDouble(),
                            onChanged: (value) =>
                                themeProvider.setNodeTimeout(value.round()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mock Scenario',
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final scenario in MockScenario.values)
                            ChoiceChip(
                              label: Text(scenario.label),
                              selected: provider.mockScenario == scenario,
                              onSelected: provider.useMockData
                                  ? (_) => provider.setMockScenario(scenario)
                                  : null,
                              selectedColor:
                                  AppColors.neonBlue.withOpacity(0.16),
                              labelStyle: GoogleFonts.inter(
                                color: provider.mockScenario == scenario
                                    ? AppColors.neonBlue
                                    : AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              side: BorderSide(
                                color: provider.mockScenario == scenario
                                    ? AppColors.neonBlue.withOpacity(0.36)
                                    : AppColors.cardBorder,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  borderColor: AppColors.gatewayColor.withOpacity(0.22),
                  child: Column(
                    children: [
                      _InfoRow(
                          label: 'Firebase Status',
                          value: provider.firebaseStatus),
                      const Divider(color: AppColors.cardBorder),
                      _InfoRow(label: 'Root', value: FirebasePaths.root),
                      const Divider(color: AppColors.cardBorder),
                      _InfoRow(
                          label: 'Building', value: FirebasePaths.building),
                      const Divider(color: AppColors.cardBorder),
                      _InfoRow(label: 'Bridge', value: FirebasePaths.bridge),
                      const Divider(color: AppColors.cardBorder),
                      _InfoRow(label: 'Water', value: FirebasePaths.water),
                      const Divider(color: AppColors.cardBorder),
                      _InfoRow(label: 'Gateway', value: FirebasePaths.gateway),
                      const Divider(color: AppColors.cardBorder),
                      _InfoRow(label: 'Alerts', value: FirebasePaths.alerts),
                      const Divider(color: AppColors.cardBorder),
                      _InfoRow(
                          label: 'Settings', value: FirebasePaths.settings),
                      const Divider(color: AppColors.cardBorder),
                      _InfoRow(
                          label: 'Notify',
                          value: 'Firebase alerts + live SC1 node flags'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  child: Column(
                    children: const [
                      _InfoRow(
                        label: 'Protocol',
                        value:
                            'SC1|type|nodeId|domain|seq|uptimeSec|batteryMv|flags|v1..v7|crc',
                      ),
                      Divider(color: AppColors.cardBorder),
                      _InfoRow(
                          label: 'Domains',
                          value: '1 Building, 2 Bridge, 3 Water, 4 Gateway'),
                      Divider(color: AppColors.cardBorder),
                      _InfoRow(
                          label: 'Flags',
                          value:
                              'Alert, Low Battery, Sensor Error, Event, Actuator'),
                      Divider(color: AppColors.cardBorder),
                      _InfoRow(
                          label: 'Layout',
                          value: 'Mobile first, bottom navigation'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  borderColor: AppColors.dangerRed.withOpacity(0.22),
                  onTap: () => _confirmSignOut(context),
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded,
                          color: AppColors.dangerRed),
                      const SizedBox(width: 12),
                      Text(
                        'Sign Out',
                        style: GoogleFonts.inter(
                          color: AppColors.dangerRed,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isEmbedded) return body;
    return Scaffold(backgroundColor: AppColors.background, body: body);
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Sign Out',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  allowSnapshotting: false,
                  builder: (_) => const LoginScreen(),
                ),
                (_) => false,
              );
            },
            child: const Text('Sign Out'),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 11,
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
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
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
