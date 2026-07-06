import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../theme/app_colors.dart';

class SensorGauge extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final String unit;
  final Color color;
  final double size;

  const SensorGauge({
    super.key,
    required this.label,
    required this.value,
    required this.maxValue,
    required this.unit,
    required this.color,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (value / maxValue).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularPercentIndicator(
          radius: size / 2,
          lineWidth: 8,
          percent: percent,
          center: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value >= 1000
                    ? '${(value / 1000).toStringAsFixed(1)}k'
                    : value.toStringAsFixed(value < 10 ? 1 : 0),
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: size > 100 ? 18 : 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                unit,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: size > 100 ? 11 : 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          progressColor: color,
          backgroundColor: AppColors.gaugeTrack,
          circularStrokeCap: CircularStrokeCap.round,
          animation: true,
          animationDuration: 800,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// Mini horizontal gauge for compact display
class MiniGauge extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final String unit;
  final Color color;

  const MiniGauge({
    super.key,
    required this.label,
    required this.value,
    required this.maxValue,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (value / maxValue).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 12)),
            Text('${value.toStringAsFixed(1)} $unit',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 6,
            backgroundColor: AppColors.gaugeTrack,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
