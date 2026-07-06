import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class MobileAppFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final Color backgroundColor;

  const MobileAppFrame({
    super.key,
    required this.child,
    this.maxWidth = 430,
    this.backgroundColor = AppColors.background,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 520) return child;

        return ColoredBox(
          color: backgroundColor,
          child: Center(
            child: Container(
              width: maxWidth,
              height: constraints.maxHeight,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: backgroundColor,
                border: Border.symmetric(
                  vertical: BorderSide(
                    color: AppColors.cardBorder.withValues(alpha: 0.72),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
