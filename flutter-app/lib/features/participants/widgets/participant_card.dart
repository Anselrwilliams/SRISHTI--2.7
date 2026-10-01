import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../models/participant_model.dart';

/// Clean Apple-style card displaying participant summary and check-in status.
class ParticipantCard extends StatelessWidget {
  final ParticipantModel participant;
  final VoidCallback? onTap;

  const ParticipantCard({
    super.key,
    required this.participant,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppColors.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Participant Avatar / Code Initials
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Text(
                      participant.name.isNotEmpty
                          ? participant.name.substring(0, 1).toUpperCase()
                          : 'P',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.electricBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Participant Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              participant.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSecondary,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Text(
                              participant.participantCode,
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: AppColors.electricBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          participant.college,
                          participant.department,
                        ].where((s) => s != null && s.isNotEmpty).join(' • '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      participant.isCheckedIn
                          ? AppStatusBadge.checkedIn()
                          : AppStatusBadge.notCheckedIn(),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
