import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/app_colors.dart';
import '../../checkin/models/attendance_mode.dart';
import '../../checkin/services/checkin_service.dart';
import '../../participants/models/participant_model.dart';
import '../../participants/screens/participant_detail_sheet.dart';
import '../../participants/screens/participant_search_screen.dart';
import '../../participants/services/participant_service.dart';
import '../widgets/scan_overlay.dart';

/// Technology-focused scanner screen supporting both:
/// 1. Festival Arrival Check-in (Main Gate)
/// 2. Event-Specific Attendance Check-in
class ScanScreen extends StatefulWidget {
  final AttendanceMode mode;
  final String? eventId;
  final String? eventName;
  final VoidCallback? onScanComplete;

  const ScanScreen({
    super.key,
    this.mode = AttendanceMode.arrival,
    this.eventId,
    this.eventName,
    this.onScanComplete,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessingScan = false;
  bool _isTorchOn = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessingScan) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue?.trim();
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _isProcessingScan = true);

    try {
      // 1. Look up participant from Supabase
      final participantData = await ParticipantService().getParticipantByCode(rawValue);

      if (!mounted) return;

      if (participantData == null) {
        // Validation State: Participant not found
        await _showInvalidCodeDialog(rawValue);
      } else {
        // Fetch checkin status
        final checkinData = await CheckinService().getArrivalCheckin(
          participantData['id'].toString(),
        );

        if (!mounted) return;

        final participant = ParticipantModel.fromMap(
          participantData,
          isCheckedIn: checkinData != null,
          checkedInAt: checkinData != null && checkinData['checked_in_at'] != null
              ? DateTime.tryParse(checkinData['checked_in_at'].toString())
              : null,
        );

        // Display participant detail sheet with current workflow context
        await ParticipantDetailSheet.show(
          context,
          participant: participant,
          mode: widget.mode,
          eventId: widget.eventId,
          eventName: widget.eventName,
          source: 'qr',
          onActionSuccess: () {
            widget.onScanComplete?.call();
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        // Delay slightly before re-enabling scanner to prevent immediate double-scan
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          setState(() => _isProcessingScan = false);
        }
      }
    }
  }

  Future<void> _showInvalidCodeDialog(String code) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDarkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderDarkSubtle),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
            SizedBox(width: 10),
            Text(
              'Participant Not Found',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invalid QR / Participant not found in system:',
              style: TextStyle(color: AppColors.textDarkSecondary, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: AppColors.cyan,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Scan Again', style: TextStyle(color: AppColors.cyan)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.electricBlue),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ParticipantSearchScreen(
                    mode: widget.mode,
                    eventId: widget.eventId,
                    eventName: widget.eventName,
                  ),
                ),
              );
            },
            child: const Text('Search Manually'),
          ),
        ],
      ),
    );
  }

  Future<void> _showErrorDialog(String error) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDarkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Network Error', style: TextStyle(color: Colors.white)),
        content: Text(
          'An error occurred while connecting to Supabase: $error',
          style: const TextStyle(color: AppColors.textDarkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: AppColors.cyan)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEventMode = widget.mode == AttendanceMode.event;

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcodeDetected,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.videocam_off_outlined,
                        size: 56,
                        color: AppColors.textDarkSecondary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera Unavailable',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please ensure camera permissions are granted in settings.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textDarkSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.cyan,
                          side: const BorderSide(color: AppColors.cyan),
                        ),
                        onPressed: () => _scannerController.start(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry Camera'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Cyber-Minimalist Frame & Laser Overlay
          const Center(
            child: ScanOverlay(scanAreaSize: 260),
          ),

          // Top Header Bar
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back button if pushed modally (e.g. from Events Screen)
                        if (Navigator.of(context).canPop())
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withAlpha(160),
                              side: const BorderSide(color: AppColors.borderDarkSubtle),
                            ),
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                          )
                        else
                          const SizedBox(width: 8),

                        // Mode Indicator Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(180),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isEventMode ? AppColors.electricBlue : AppColors.cyan,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isEventMode
                                    ? Icons.event_available_rounded
                                    : Icons.how_to_reg_rounded,
                                size: 16,
                                color: isEventMode ? AppColors.electricBlue : AppColors.cyan,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isEventMode ? 'EVENT ATTENDANCE' : 'FESTIVAL ARRIVAL',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Controls: Torch & Camera Switch
                        Row(
                          children: [
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black.withAlpha(160),
                                side: const BorderSide(color: AppColors.borderDarkSubtle),
                              ),
                              icon: Icon(
                                _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                color: _isTorchOn ? AppColors.cyan : Colors.white,
                                size: 18,
                              ),
                              onPressed: () async {
                                await _scannerController.toggleTorch();
                                setState(() => _isTorchOn = !_isTorchOn);
                              },
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black.withAlpha(160),
                                side: const BorderSide(color: AppColors.borderDarkSubtle),
                              ),
                              icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 18),
                              onPressed: () => _scannerController.switchCamera(),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Subtitle Banner for Event Mode
                    if (isEventMode && widget.eventName != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDarkElevated.withAlpha(220),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderDarkSubtle),
                        ),
                        child: Text(
                          widget.eventName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Bottom Instruction Card & Manual Search Shortcut
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isProcessingScan) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(200),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.cyan),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.cyan),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Verifying participant details...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(180),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderDarkSubtle),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isEventMode ? Icons.qr_code_2_rounded : Icons.center_focus_strong_rounded,
                            color: AppColors.cyan,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEventMode ? 'Scan participant QR' : 'Align arrival QR in frame',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  isEventMode
                                      ? 'Verifies arrival & event registration'
                                      : 'Records arrival at SRISHTI festival gate',
                                  style: const TextStyle(
                                    color: AppColors.textDarkSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.cyan,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ParticipantSearchScreen(
                                    mode: widget.mode,
                                    eventId: widget.eventId,
                                    eventName: widget.eventName,
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              'Manual',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
