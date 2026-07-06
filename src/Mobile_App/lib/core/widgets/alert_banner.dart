import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class AlertBanner extends StatelessWidget {
  final String message;
  final AlertBannerType type;
  final IconData? icon;

  const AlertBanner({
    super.key,
    required this.message,
    required this.type,
    this.icon,
  });

  Color get _color {
    switch (type) {
      case AlertBannerType.normal:
        return AppColors.successGreen;
      case AlertBannerType.warning:
        return AppColors.warningOrange;
      case AlertBannerType.critical:
        return AppColors.dangerRed;
    }
  }

  IconData get _icon {
    if (icon != null) return icon!;
    switch (type) {
      case AlertBannerType.normal:
        return Icons.check_circle_rounded;
      case AlertBannerType.warning:
        return Icons.warning_rounded;
      case AlertBannerType.critical:
        return Icons.error_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_color.withOpacity(0.2), _color.withOpacity(0.05)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        children: [
          Icon(_icon, color: _color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: _color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum AlertBannerType { normal, warning, critical }
