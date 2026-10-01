import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Clean minimalist metrics card displaying attendance and fest statistics.
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.electricBlue;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppColors.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        letterSpacing: -0.1,
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 18, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
