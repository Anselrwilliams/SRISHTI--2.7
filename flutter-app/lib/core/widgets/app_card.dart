import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Minimal Apple-style card container with refined borders and subtle shadows.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final Border? border;
  final double borderRadius;
  final bool showShadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
    this.border,
    this.borderRadius = 20,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.surface;
    final effectiveBorder = border ?? Border.all(color: AppColors.border, width: 1);

    final cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: effectiveBorder,
        boxShadow: showShadow ? AppColors.softShadow : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: AppColors.cyan.withAlpha(20),
          highlightColor: AppColors.electricBlue.withAlpha(10),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
