import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/glass_card.dart';
import '../core/widgets/mobile_app_frame.dart';
import '../models/user_role.dart';
import '../providers/dashboard_provider.dart';
import 'login_screen.dart';
import 'maintenance/maintenance_dashboard_screen.dart';
import 'mobile_home_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MobileAppFrame(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.neonBlue.withValues(alpha: 0.18),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.hub_rounded,
                          color: AppColors.neonBlue,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'SmartCity LPWAN',
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose the view for this session',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _RoleCard(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Continue as Admin',
                  subtitle:
                      'Full dashboard, AI Command Center, Reports, MLOps, LPWAN analytics, gateway, and settings.',
                  color: AppColors.neonBlue,
                  onTap: () => _openRole(context, UserRole.admin),
                ),
                const SizedBox(height: 14),
                _RoleCard(
                  icon: Icons.engineering_rounded,
                  title: 'Continue as Technician',
                  subtitle:
                      'Simple maintenance dashboard with alerts, nodes, gateway health, actions, and resolved status.',
                  color: AppColors.successGreen,
                  onTap: () => _openRole(context, UserRole.technician),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        allowSnapshotting: false,
                        builder: (_) => const LoginScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Admin Sign In'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gatewayColor,
                      side: BorderSide(
                        color: AppColors.gatewayColor.withValues(alpha: 0.28),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openRole(BuildContext context, UserRole role) {
    context.read<UserRoleController>().setRole(role);
    context.read<DashboardProvider>().toggleMockData(true);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        allowSnapshotting: false,
        builder: (_) => role.isAdmin
            ? const MobileHomeScreen()
            : const MaintenanceDashboardScreen(),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 8,
      borderColor: color.withValues(alpha: 0.22),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 28),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: color),
        ],
      ),
    );
  }
}
