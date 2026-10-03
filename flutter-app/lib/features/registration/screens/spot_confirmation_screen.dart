import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/unified/unified_design_system.dart';
import '../../auth/models/volunteer_model.dart';
import '../models/spot_registration_draft.dart';
import '../services/spot_registration_service.dart';
import 'spot_success_screen.dart';

/// Step 3: Final Registration Confirmation Screen.
/// Displays registration summary and performs database registration via SpotRegistrationService.
class SpotConfirmationScreen extends StatefulWidget {
  final VolunteerModel volunteer;
  final SpotRegistrationDraft draft;
  final SpotRegistrationService? spotRegistrationService;

  const SpotConfirmationScreen({
    super.key,
    required this.volunteer,
    required this.draft,
    this.spotRegistrationService,
  });

  @override
  State<SpotConfirmationScreen> createState() => _SpotConfirmationScreenState();
}

class _SpotConfirmationScreenState extends State<SpotConfirmationScreen> {
  late final SpotRegistrationService _service;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _service = widget.spotRegistrationService ?? SpotRegistrationService();
  }

  Future<void> _completeRegistration() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final result = await _service.createSpotRegistration(
        draft: widget.draft,
        volunteerId: widget.volunteer.id,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => SpotSuccessScreen(
              volunteer: widget.volunteer,
              result: result,
              draft: widget.draft,
            ),
          ),
          (route) => route.isFirst,
        );
      } else if (result.isDuplicate) {
        setState(() => _isSubmitting = false);
        _showDuplicateDialog(result.message);
      } else {
        setState(() => _isSubmitting = false);
        _showFailureDialog(result.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showFailureDialog(
        SpotRegistrationService.databaseFailureMessage,
      );
    }
  }

  void _showFailureDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text(
              'Registration Failed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          message.isNotEmpty
              ? message
              : SpotRegistrationService.databaseFailureMessage,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Back',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _completeRegistration();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDuplicateDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Duplicate Registration'),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Edit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.draft.selectedEvent!;
    final draft = widget.draft;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Confirm Registration',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: UnifiedBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(),
                const SizedBox(height: 20),

                // Card 1: Participant Summary
                _buildInfoCard(
                  title: 'PARTICIPANT DETAILS',
                  icon: Icons.person_rounded,
                  rows: [
                    ['Full Name', draft.fullName],
                    ['Phone', draft.phone],
                    ['Email', draft.email],
                    ['College', draft.college],
                    ['Year', draft.yearOfStudy],
                  ],
                ),
                const SizedBox(height: 16),

                // Card 2: Event Details
                _buildInfoCard(
                  title: 'EVENT DETAILS',
                  icon: Icons.event_available_rounded,
                  rows: [
                    ['Event Name', event.name],
                    ['Event Code', event.eventCode],
                    ['Category', event.category],
                    ['Venue', event.venue ?? 'Main Campus'],
                    ['Schedule', '${event.date ?? "Day 1"} • ${event.time ?? "TBA"}'],
                    ['Format', event.isTeamEvent ? 'Team Event' : 'Individual'],
                  ],
                ),
                const SizedBox(height: 16),

                // Card 3: Team Roster (If team event)
                if (event.isTeamEvent) ...[
                  _buildTeamRosterCard(draft),
                  const SizedBox(height: 16),
                ],

                // Card 4: Payment Verification Summary
                _buildPaymentVerifiedCard(draft),
                const SizedBox(height: 26),

                // Action Button
                _buildCompleteButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.softShadow,
      ),
      child: const Row(
        children: [
          Icon(Icons.assignment_turned_in_rounded,
              color: AppColors.blue, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step 3 of 3: Final Review',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Verify all information before writing registration to FEST registry',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<List<String>> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.blue),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 10),
          for (final r in rows) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    r[0],
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      r[1],
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamRosterCard(SpotRegistrationDraft draft) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.purple.withAlpha(80)),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, size: 20, color: AppColors.purple),
              const SizedBox(width: 8),
              Text(
                'TEAM MEMBERS (${draft.totalMembersCount})',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 8),

          // Leader
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.purple,
              child: Text(
                '1',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              '${draft.fullName} (Team Leader)',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${draft.phone} • ${draft.college}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ),

          // Additional members
          for (int i = 0; i < draft.teamMembers.length; i++) ...[
            const Divider(height: 1, color: AppColors.borderLight),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.purple.withAlpha(40),
                child: Text(
                  '${i + 2}',
                  style: const TextStyle(
                    color: AppColors.purple,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                draft.teamMembers[i].name,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${draft.teamMembers[i].phone} • ${draft.teamMembers[i].college ?? draft.college}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentVerifiedCard(SpotRegistrationDraft draft) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.successBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PAYMENT VERIFIED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  'Amount Paid: ₹${draft.effectiveAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Verified by ${widget.volunteer.name}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.glowShadow,
      ),
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _completeRegistration,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppColors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSubmitting) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Registering Participant...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ] else ...[
              const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              const Text(
                'Complete Registration',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
