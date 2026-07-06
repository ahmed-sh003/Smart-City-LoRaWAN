import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFFF4F7FB);
  static const Color backgroundSecondary = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardGlass = Color(0xF2FFFFFF);
  static const Color cardBorder = Color(0xFFE5E7EB);

  // Primary accents
  static const Color neonBlue = Color(0xFF00D1FF);
  static const Color neonBlueGlow = Color(0x3300D1FF);
  static const Color successGreen = Color(0xFF22C55E);
  static const Color successGlow = Color(0x3322C55E);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color warningGlow = Color(0x33FF9800);
  static const Color dangerRed = Color(0xFFEF4444);
  static const Color dangerGlow = Color(0x33EF4444);

  // Text
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF94A3B8);

  // Domain colors
  static const Color agricultureColor = Color(0xFF00C853);
  static const Color buildingColor = Color(0xFF3B82F6);
  static const Color bridgeColor = Color(0xFFF59E0B);
  static const Color waterColor = Color(0xFF06B6D4);
  static const Color gatewayColor = Color(0xFF8B5CF6);

  // Gauges
  static const Color gaugeTrack = Color(0xFFE2E8F0);

  // Chart
  static const Color chartLine = Color(0xFF00D1FF);

  // Gradients
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF07111F), Color(0xFF0A1628), Color(0xFF07111F)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FBFF)],
  );

  static const LinearGradient buildingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEAF6FF), Color(0xFFFFFFFF)],
  );

  static const LinearGradient bridgeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFF5E8), Color(0xFFFFFFFF)],
  );

  static const LinearGradient waterGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8FBFF), Color(0xFFFFFFFF)],
  );

  static const LinearGradient gatewayGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF4ECFF), Color(0xFFFFFFFF)],
  );
}
