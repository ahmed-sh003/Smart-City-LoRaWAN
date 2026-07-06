import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class BatteryIndicator extends StatelessWidget {
  final double percent; // 0-100
  final bool showLabel;
  final double width;
  final double height;

  const BatteryIndicator({
    super.key,
    required this.percent,
    this.showLabel = true,
    this.width = 28,
    this.height = 14,
  });

  Color get _color {
    if (percent > 50) return AppColors.successGreen;
    if (percent > 20) return AppColors.warningOrange;
    return AppColors.dangerRed;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width + 3,
          height: height,
          child: Stack(
            children: [
              // Battery body
              Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  border:
                      Border.all(color: _color.withOpacity(0.7), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percent / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _color,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                ),
              ),
              // Battery tip
              Positioned(
                right: 0,
                top: (height / 2) - 3,
                child: Container(
                  width: 3,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.7),
                    borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(1)),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 5),
          Text(
            '${percent.toStringAsFixed(0)}%',
            style: GoogleFonts.inter(
              color: _color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
