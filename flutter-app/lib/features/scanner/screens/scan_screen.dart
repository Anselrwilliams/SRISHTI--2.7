import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/app_colors.dart';
import '../../checkin/models/attendance_mode.dart';
import '../../checkin/services/checkin_service.dart';
import '../../participants/models/participant_model.dart';
import '../../participants/screens/participant_detail_sheet.dart';
import '../../participants/screens/participant_search_screen.dart';
import '../../participants/services/participant_service.dart';
import '../../../core/navigation/route_observer.dart';
import '../services/qr_camera_manager.dart';
import '../widgets/scan_overlay.dart';

/// Technology-focused scanner screen supporting both:
/// 1. Festival Arrival Check-in (Main Gate)
/// 2. Event-Specific Attendance Check-in
///
/// Features strict camera lifecycle management:
/// - Camera remains completely stopped when inactive or offstage.
/// - Starts only on explicit user scanning action.
/// - Immediately stops before displaying participant details.
/// - Remains off when details sheet closes until user taps "Scan Again".
/// - Disposes camera when navigating away or on logout.
class ScanScreen extends StatefulWidget {
  final AttendanceMode mode;
  final String? eventId;
  final String? eventName;
  final VoidCallback? onScanComplete;
  final bool isActive;
  final VoidCallback? onBackPressed;

  const ScanScreen({
    super.key,
    this.mode = AttendanceMode.arrival,
    this.eventId,
    this.eventName,
    this.onScanComplete,
    this.isActive = true,
    this.onBackPressed,
  });

  /// Explicitly resumes or starts scanning on any active [ScanScreen] instance.
  static void resumeActiveScanner() {
    _ScanScreenState.resumeActiveScanner();
  }

  /// Explicitly pauses or stops scanning on any active [ScanScreen] instance.
  static void stopActiveScanner() {
    _ScanScreenState.stopActiveScanner();
  }

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver, RouteAware {
  static final Set<_ScanScreenState> _registeredStates = {};

  static void resumeActiveScanner() {
    for (final state in _registeredStates) {
      if (state.mounted && state.widget.isActive) {
        state._startCamera();
      }
    }
  }

  static void stopActiveScanner() {
    for (final state in _registeredStates) {
      if (state.mounted) {
        state._stopCamera();
      }
    }
  }

  MobileScannerController? _scannerController;
  bool _isCameraRunning = false;
  bool _isStartingCamera = false;
  bool _isProcessingScan = false;
  bool _hasScannedOnce = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _registeredStates.add(this);

    // Only start camera if this screen is actively visible/focused
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isActive) {
          _startCamera();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modalRoute = ModalRoute.of(context);
    if (modalRoute is PageRoute) {
      appRouteObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void didPushNext() {
    // Another route was pushed on top of ScanScreen (e.g. participant details or search)
    _stopCamera();
  }

  @override
  void didPopNext() {
    // Covered route was popped, returning to ScanScreen
    if (widget.isActive && !_hasScannedOnce) {
      _startCamera();
    }
  }

  @override
  void didPop() {
    // ScanScreen route itself was popped
    _disposeCamera();
  }

  @override
  void didUpdateWidget(ScanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _startCamera();
      } else {
        _disposeCamera();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      if (_isCameraRunning) {
        _stopCamera();
      }
    } else if (state == AppLifecycleState.resumed && widget.isActive && !_hasScannedOnce) {
      _startCamera();
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _registeredStates.remove(this);
    WidgetsBinding.instance.removeObserver(this);
    _isCameraRunning = false;
    _isTorchOn = false;
    final controller = _scannerController;
    _scannerController = null;
    controller?.stop();
    controller?.dispose();
    QrCameraManager.instance.stopAndDispose();
    super.dispose();
  }

  Future<void> _startCamera() async {
    if (!mounted || !widget.isActive || _isStartingCamera) return;
    setState(() {
      _isStartingCamera = true;
      _hasScannedOnce = false;
    });

    try {
      _isTorchOn = false;
      final controller = await QrCameraManager.instance.acquireController(
        facing: CameraFacing.back,
        detectionSpeed: DetectionSpeed.normal,
        torchEnabled: false,
      );

      if (!mounted || !widget.isActive) {
        await QrCameraManager.instance.stopAndDispose();
        return;
      }

      setState(() {
        _scannerController = controller;
        _isCameraRunning = true;
      });

      // Allow widget tree to attach MobileScanner widget before invoking start()
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || !widget.isActive || !_isCameraRunning) return;
        try {
          await QrCameraManager.instance.startActiveCamera();
        } catch (e) {
          debugPrint('ScanScreen: Error starting camera controller: $e');
        }
      });
    } catch (e) {
      debugPrint('ScanScreen: Error acquiring camera: $e');
      if (mounted) {
        setState(() => _isCameraRunning = false);
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingCamera = false);
      }
    }
  }

  Future<void> _stopCamera() async {
    if (mounted) {
      setState(() {
        _isCameraRunning = false;
        _isTorchOn = false;
      });
    } else {
      _isCameraRunning = false;
      _isTorchOn = false;
    }
    await QrCameraManager.instance.stopActiveCamera();
  }

  Future<void> _disposeCamera() async {
    if (mounted) {
      setState(() {
        _isCameraRunning = false;
        _scannerController = null;
        _isTorchOn = false;
      });
    } else {
      _isCameraRunning = false;
      _scannerController = null;
      _isTorchOn = false;
    }
    await QrCameraManager.instance.stopAndDispose();
  }

  Future<void> _handleBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessingScan || !_isCameraRunning) return;

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
        // Validation State: Participant not found - stop camera while showing dialog
        await _stopCamera();
        _hasScannedOnce = true;
        if (!mounted) return;
        final rescan = await _showInvalidCodeDialog(rawValue);
        if (rescan == true && mounted && widget.isActive) {
          await _startCamera();
        }
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

        // 4. When QR scan succeeds, immediately stop/pause the camera before showing the sheet
        await _stopCamera();
        _hasScannedOnce = true;
        if (!mounted) return;

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

        // 5. When participant details sheet is closed, camera must remain OFF
        // (Do NOT resume camera automatically; wait for explicit Scan Again tap)
      }
    } catch (e) {
      if (!mounted) return;
      await _stopCamera();
      _hasScannedOnce = true;
      if (!mounted) return;
      await _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isProcessingScan = false);
      }
    }
  }

  Future<bool?> _showInvalidCodeDialog(String code) {
    return showDialog<bool>(
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
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Scan Again', style: TextStyle(color: AppColors.cyan)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.electricBlue),
            onPressed: () {
              Navigator.of(context).pop(false);
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

  Widget _buildCameraStoppedView(bool isEventMode) {
    final buttonLabel = _hasScannedOnce
        ? 'Scan Again'
        : (isEventMode ? 'Scan participant QR' : 'Scan participant QR');

    return Container(
      color: AppColors.surfaceDark,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surfaceDarkCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _hasScannedOnce ? AppColors.electricBlue : AppColors.cyan.withAlpha(140),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_hasScannedOnce ? AppColors.electricBlue : AppColors.cyan).withAlpha(40),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: _hasScannedOnce
                        ? const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                          )
                        : AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_hasScannedOnce ? AppColors.electricBlue : AppColors.cyan).withAlpha(90),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _hasScannedOnce ? 'Scan Completed' : 'Camera Standby',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _hasScannedOnce
                      ? 'Camera paused to save battery. Tap below to scan the next participant.'
                      : (isEventMode
                          ? 'Tap below to activate the camera for event attendance.'
                          : 'Tap below to activate the camera for FEST arrival.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textDarkSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('scan_again_button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _hasScannedOnce ? AppColors.electricBlue : AppColors.cyan,
                      foregroundColor: _hasScannedOnce ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    onPressed: _startCamera,
                    icon: Icon(
                      _hasScannedOnce ? Icons.refresh_rounded : Icons.qr_code_scanner_rounded,
                      size: 20,
                    ),
                    label: Text(
                      buttonLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                if (_hasScannedOnce) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
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
                    icon: const Icon(Icons.search_rounded, size: 16, color: AppColors.textDarkSecondary),
                    label: const Text(
                      'Search Manually Instead',
                      style: TextStyle(color: AppColors.textDarkSecondary, fontSize: 12),
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

  @override
  Widget build(BuildContext context) {
    // If the scanner tab is not active, render an empty view to strictly ensure zero camera usage
    if (!widget.isActive) {
      return const Scaffold(
        backgroundColor: AppColors.surfaceDark,
        body: SizedBox.expand(),
      );
    }

    final isEventMode = widget.mode == AttendanceMode.event;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _disposeCamera();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surfaceDark,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Camera Preview or Standby View
            if (_isCameraRunning && _scannerController != null)
              MobileScanner(
                controller: _scannerController!,
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
                            onPressed: _startCamera,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry Camera'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            else
              _buildCameraStoppedView(isEventMode),

            // Cyber-Minimalist Frame & Laser Overlay (active while camera is streaming)
            if (_isCameraRunning && _scannerController != null)
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
                          // Back button if pushed modally or if custom onBackPressed provided
                          if (Navigator.of(context).canPop())
                            IconButton(
                              key: const Key('scan_top_back_button'),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black.withAlpha(160),
                                side: const BorderSide(color: AppColors.borderDarkSubtle),
                              ),
                              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                              onPressed: () {
                                _disposeCamera();
                                Navigator.of(context).pop();
                              },
                            )
                          else if (widget.onBackPressed != null)
                            IconButton(
                              key: const Key('scan_top_back_button'),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black.withAlpha(160),
                                side: const BorderSide(color: AppColors.borderDarkSubtle),
                              ),
                              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                              onPressed: () {
                                _disposeCamera();
                                widget.onBackPressed?.call();
                              },
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
                                isEventMode ? 'EVENT ATTENDANCE' : 'FEST ARRIVAL',
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
                              onPressed: (_isCameraRunning && _scannerController != null)
                                  ? () async {
                                      await _scannerController?.toggleTorch();
                                      setState(() => _isTorchOn = !_isTorchOn);
                                    }
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black.withAlpha(160),
                                side: const BorderSide(color: AppColors.borderDarkSubtle),
                              ),
                              icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 18),
                              onPressed: (_isCameraRunning && _scannerController != null)
                                  ? () => _scannerController?.switchCamera()
                                  : null,
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
                                      : 'Records arrival at SRISHTI FEST gate',
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
    ),
    );
  }
}
