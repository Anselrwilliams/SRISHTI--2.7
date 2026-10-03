import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/unified/unified_design_system.dart';
import '../../auth/models/volunteer_model.dart';
import '../models/spot_registration_draft.dart';
import '../models/spot_registration_result.dart';
import 'spot_registration_screen.dart';

/// Step 4: Registration Success and Participant Pass Screen.
/// Displays the generated unique participant code and renders the scannable FEST Participant QR.
class SpotSuccessScreen extends StatelessWidget {
  final VolunteerModel volunteer;
  final SpotRegistrationResult result;
  final SpotRegistrationDraft draft;

  const SpotSuccessScreen({
    super.key,
    required this.volunteer,
    required this.result,
    required this.draft,
  });

  @override
  Widget build(BuildContext context) {
    final event = result.event ?? draft.selectedEvent!;
    final participantCode = result.participantCode;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Registration Pass',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Return to Home',
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: UnifiedBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Success Badge Banner
                _buildSuccessBanner(),
                const SizedBox(height: 18),

                // FEST Participant QR Pass Card
                _buildPassCard(context, event, participantCode),
                const SizedBox(height: 24),

                // Action Buttons
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.successBorder),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.success,
            radius: 20,
            child: Icon(Icons.check_rounded, color: Colors.white, size: 24),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registration Successful! 🎉',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Participant is now registered and ready for festival check-in.',
                  style: TextStyle(
                    fontSize: 12,
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

  Widget _buildPassCard(
    BuildContext context,
    dynamic event,
    String participantCode,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          // Pass Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              gradient: AppColors.darkHeroGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SRISHTI 2.7',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.cyan,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      event.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    event.isTeamEvent ? 'TEAM PASS' : 'ENTRY PASS',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Participant QR Code Display
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(12),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    // ONLY the unique participantCode is encoded in the QR for privacy & scanner compatibility
                    data: participantCode,
                    version: QrVersions.auto,
                    size: 200.0,
                    gapless: true,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF080B10),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF080B10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Prominent Participant Code
                Text(
                  participantCode,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.blue,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'FEST PARTICIPANT CODE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 16),

                // Metadata Rows
                _buildPassRow('Participant', draft.fullName),
                const SizedBox(height: 8),
                _buildPassRow('College', draft.college),
                const SizedBox(height: 8),
                _buildPassRow(
                  'Format',
                  event.isTeamEvent
                      ? 'Team (${draft.totalMembersCount} members)'
                      : 'Individual Entry',
                ),
                const SizedBox(height: 8),
                _buildPassRow('Venue / Date',
                    '${event.venue ?? "Main Campus"} • ${event.date ?? "Day 1"}'),
                const SizedBox(height: 8),
                _buildPassRow('Registration Source', 'Spot Registration Desk'),
              ],
            ),
          ),

          // Footer note on scanner compatibility
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary.withAlpha(120),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: const Row(
              children: [
                Icon(Icons.qr_code_scanner_rounded,
                    size: 18, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Compatible with the FEST Volunteer arrival check-in and event attendance scanners.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Register Another Participant
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.glowShadow,
          ),
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => SpotRegistrationScreen(
                    volunteer: volunteer,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.person_add_alt_1_rounded,
                color: Colors.white, size: 20),
            label: const Text(
              'Register Another Participant',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Done / Back to Registration Dashboard
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          icon: const Icon(Icons.home_rounded,
              color: AppColors.textPrimary, size: 20),
          label: const Text(
            'Back to Registration Desk',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}
