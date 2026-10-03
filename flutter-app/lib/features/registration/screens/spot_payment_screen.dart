import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/unified/unified_design_system.dart';
import '../../auth/models/volunteer_model.dart';
import '../../events/models/event_model.dart';
import '../models/spot_registration_draft.dart';
import '../services/spot_registration_service.dart';
import 'spot_confirmation_screen.dart';

/// Step 2: Payment and Coordinator Verification Screen.
/// Displays UPI payment QR, event fee breakdown, and explicit payment verification.
class SpotPaymentScreen extends StatefulWidget {
  final VolunteerModel volunteer;
  final SpotRegistrationDraft draft;
  final SpotRegistrationService? spotRegistrationService;

  const SpotPaymentScreen({
    super.key,
    required this.volunteer,
    required this.draft,
    this.spotRegistrationService,
  });

  @override
  State<SpotPaymentScreen> createState() => _SpotPaymentScreenState();
}

class _SpotPaymentScreenState extends State<SpotPaymentScreen> {
  late SpotRegistrationDraft _draft;
  bool _isVerifying = false;
  final _refController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
  }

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  Future<void> _verifyPayment() async {
    if (_draft.isPaymentVerified || _isVerifying) return;

    setState(() => _isVerifying = true);

    // Simulate fast coordinator verification check
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    setState(() {
      _draft = _draft.copyWith(
        isPaymentVerified: true,
        verifiedAt: DateTime.now(),
        transactionRef: _refController.text.trim().isNotEmpty
            ? _refController.text.trim()
            : 'CASH-OR-UPI-VERIFIED',
      );
      _isVerifying = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment verified by Registration Coordinator!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _proceedToConfirmation() {
    if (!_draft.isPaymentVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment must be verified by the coordinator before confirming registration.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SpotConfirmationScreen(
          volunteer: widget.volunteer,
          draft: _draft,
          spotRegistrationService: widget.spotRegistrationService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = _draft.selectedEvent!;
    final feeAmount = _draft.effectiveAmount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Payment Verification',
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
                // Step Indicator
                _buildStepHeader(),
                const SizedBox(height: 18),

                // Event & Registration Summary Card
                _buildSummaryCard(event, feeAmount),
                const SizedBox(height: 20),

                // UPI QR Code Card
                _buildUpiQrCard(feeAmount),
                const SizedBox(height: 20),

                // Coordinator Verification Section
                _buildVerificationCard(),
                const SizedBox(height: 24),

                // Continue Button
                _buildContinueButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _draft.isPaymentVerified ? AppColors.success : AppColors.warning,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _draft.isPaymentVerified
                  ? Icons.check_circle_rounded
                  : Icons.payment_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Step 2 of 3: Fee & Payment',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _draft.isPaymentVerified
                      ? 'Payment Verified • Ready to confirm'
                      : 'Scan UPI QR or collect cash at desk',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _draft.isPaymentVerified
                  ? AppColors.successBg
                  : AppColors.warningBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _draft.isPaymentVerified
                    ? AppColors.successBorder
                    : AppColors.warningBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _draft.isPaymentVerified
                      ? Icons.check_circle_rounded
                      : Icons.pending_rounded,
                  size: 13,
                  color: _draft.isPaymentVerified
                      ? AppColors.success
                      : AppColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  _draft.isPaymentVerified ? 'Verified' : 'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _draft.isPaymentVerified
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(EventModel event, double feeAmount) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                event.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: event.isTeamEvent
                      ? AppColors.purple.withAlpha(25)
                      : AppColors.blue.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  event.isTeamEvent ? 'Team Event' : 'Individual',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: event.isTeamEvent ? AppColors.purple : AppColors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),

          _buildRowInfo('Lead Participant', _draft.fullName),
          const SizedBox(height: 6),
          _buildRowInfo('College', _draft.college),
          const SizedBox(height: 6),
          _buildRowInfo(
            'Registration Size',
            event.isTeamEvent
                ? '${_draft.totalMembersCount} Members (${_draft.fullName} + ${_draft.teamMembers.length} team)'
                : '1 Participant (Solo)',
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Payable Amount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '₹${feeAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.blue,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRowInfo(String label, String value) {
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
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpiQrCard(double feeAmount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_2_rounded, size: 20, color: AppColors.blue),
              const SizedBox(width: 8),
              const Text(
                'PAYMENT QR',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Scan to pay ₹${feeAmount.toStringAsFixed(0)} via any UPI App',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          // Render UPI QR Code
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: _draft.upiPaymentUrl,
              version: QrVersions.auto,
              size: 190.0,
              gapless: true,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF0A0F1D),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF0A0F1D),
              ),
            ),
          ),

          const SizedBox(height: 14),
          const Text(
            'Google Pay • PhonePe • Paytm • BHIM • Any UPI App',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Alert banner
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warningBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Displaying the QR does NOT prove that payment succeeded. Coordinator must explicitly verify receipt.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
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

  Widget _buildVerificationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _draft.isPaymentVerified ? AppColors.successBg : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _draft.isPaymentVerified
              ? AppColors.successBorder
              : AppColors.borderLight,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _draft.isPaymentVerified
                    ? Icons.verified_rounded
                    : Icons.admin_panel_settings_rounded,
                size: 20,
                color: _draft.isPaymentVerified ? AppColors.success : AppColors.blue,
              ),
              const SizedBox(width: 8),
              Text(
                'COORDINATOR VERIFICATION',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: _draft.isPaymentVerified
                      ? AppColors.success
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (!_draft.isPaymentVerified) ...[
            TextFormField(
              controller: _refController,
              decoration: InputDecoration(
                labelText: 'UPI Ref ID / Cash Note (Optional)',
                hintText: 'e.g. Last 4 digits of UPI transaction',
                isDense: true,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 14),

            ElevatedButton.icon(
              onPressed: _isVerifying ? null : _verifyPayment,
              icon: _isVerifying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, color: Colors.white),
              label: Text(
                _isVerifying ? 'Verifying...' : 'Verify Payment Received',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.successBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Verified',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                        Text(
                          'Verified by ${widget.volunteer.name} • ${_draft.transactionRef ?? "Desk Verified"}',
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
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    final isReady = _draft.isPaymentVerified;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isReady ? AppColors.glowShadow : [],
      ),
      child: ElevatedButton(
        onPressed: isReady ? _proceedToConfirmation : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: isReady ? AppColors.blue : Colors.grey.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isReady ? 'Confirm Registration' : 'Verify Payment to Continue',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
