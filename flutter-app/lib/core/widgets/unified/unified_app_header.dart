import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../srishti_logo.dart';

/// Reusable application header matching the exact visual structure from the reference screenshot.
/// Features the small uppercase date, bold greeting, role/name highlighted in FEST blue,
/// cyan status indicator with subtitle, and the SRISHTI/FEST brand logo on the right.
class UnifiedAppHeader extends StatelessWidget {
  final String dateText;
  final String greeting;
  final String highlightedText;
  final String roleSubtitle;
  final Color statusIndicatorColor;
  final Widget? trailing;

  const UnifiedAppHeader({
    super.key,
    required this.dateText,
    required this.greeting,
    required this.highlightedText,
    required this.roleSubtitle,
    this.statusIndicatorColor = AppColors.cyan,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Small uppercase date
              Text(
                dateText.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7B8B9E),
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),

              // Two-line bold greeting with FEST blue highlight
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$greeting,\n',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                        height: 1.15,
                      ),
                    ),
                    TextSpan(
                      text: highlightedText,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.electricBlue,
                        letterSpacing: -0.5,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Cyan status dot & role description
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: statusIndicatorColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: statusIndicatorColor.withValues(alpha: 0.6),
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      roleSubtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        trailing ?? const SrishtiLogo(size: 52, compact: true),
      ],
    );
  }
}
