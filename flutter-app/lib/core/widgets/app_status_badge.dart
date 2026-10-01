import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum BadgeStatus {
  checkedIn,
  notCheckedIn,
  pending,
  live,
  completed,
  invalid,
  verified,
}

/// Minimalist status pill with subtle background and crisp dot indicator.
class AppStatusBadge extends StatelessWidget {
  final String label;
  final BadgeStatus status;
  final Color? customColor;

  const AppStatusBadge({
    super.key,
    required this.label,
    this.status = BadgeStatus.pending,
    this.customColor,
  });

  factory AppStatusBadge.checkedIn({String label = 'Checked In'}) {
    return AppStatusBadge(label: label, status: BadgeStatus.checkedIn);
  }

  factory AppStatusBadge.notCheckedIn({String label = 'Not Checked In'}) {
    return AppStatusBadge(label: label, status: BadgeStatus.notCheckedIn);
  }

  factory AppStatusBadge.live({String label = 'Live'}) {
    return AppStatusBadge(label: label, status: BadgeStatus.live);
  }

  factory AppStatusBadge.completed({String label = 'Completed'}) {
    return AppStatusBadge(label: label, status: BadgeStatus.completed);
  }

  factory AppStatusBadge.invalid({String label = 'Invalid'}) {
    return AppStatusBadge(label: label, status: BadgeStatus.invalid);
  }

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bg;
    Color border;

    if (customColor != null) {
      color = customColor!;
      bg = customColor!.withAlpha(20);
      border = customColor!.withAlpha(50);
    } else {
      switch (status) {
        case BadgeStatus.checkedIn:
        case BadgeStatus.verified:
          color = AppColors.success;
          bg = AppColors.successBg;
          border = AppColors.successBorder;
          break;
        case BadgeStatus.live:
          color = AppColors.electricBlue;
          bg = AppColors.infoBg;
          border = AppColors.infoBorder;
          break;
        case BadgeStatus.invalid:
          color = AppColors.error;
          bg = AppColors.errorBg;
          border = AppColors.errorBorder;
          break;
        case BadgeStatus.pending:
          color = AppColors.warning;
          bg = AppColors.warningBg;
          border = AppColors.warningBorder;
          break;
        case BadgeStatus.notCheckedIn:
        case BadgeStatus.completed:
          color = AppColors.textSecondary;
          bg = AppColors.backgroundSecondary;
          border = AppColors.border;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}
