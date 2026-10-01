import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'gradient_button.dart';

/// Minimal Apple-style empty state container.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                icon,
                size: 32,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onActionPressed != null) ...[
              const SizedBox(height: 24),
              GradientButton(
                onPressed: onActionPressed,
                label: actionLabel!,
                height: 44,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
