import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Centralized manager for the QR scanner camera lifecycle.
///
/// Guarantees that at most ONE [MobileScannerController] exists across the entire app,
/// eliminates race conditions during initialization, and ensures proper cleanup on
/// navigation, app pause, and logout.
class QrCameraManager {
  QrCameraManager._();
  static final QrCameraManager instance = QrCameraManager._();

  MobileScannerController? _activeController;
  bool _isTransitioning = false;

  /// The currently active [MobileScannerController], if any.
  MobileScannerController? get activeController => _activeController;

  /// Whether an active controller is registered.
  bool get hasActiveController => _activeController != null;

  /// Whether the active camera is currently running.
  bool get isRunning => _activeController?.value.isRunning ?? false;

  /// Safely acquires and registers a new [MobileScannerController],
  /// automatically stopping and disposing any previous controller first.
  ///
  /// The returned controller is created with `autoStart: false` so that native
  /// camera resources and permissions are never invoked prematurely.
  Future<MobileScannerController> acquireController({
    CameraFacing facing = CameraFacing.back,
    DetectionSpeed detectionSpeed = DetectionSpeed.normal,
    bool torchEnabled = false,
  }) async {
    while (_isTransitioning) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    _isTransitioning = true;

    try {
      await _stopAndDisposeInternal();

      final controller = MobileScannerController(
        autoStart: false,
        facing: facing,
        detectionSpeed: detectionSpeed,
        torchEnabled: torchEnabled,
      );
      _activeController = controller;
      return controller;
    } finally {
      _isTransitioning = false;
    }
  }

  /// Starts the camera on the active controller safely.
  Future<void> startActiveCamera() async {
    final controller = _activeController;
    if (controller == null) return;
    if (controller.value.isRunning || controller.value.isStarting) return;

    try {
      await controller.start();
    } catch (e) {
      debugPrint('QrCameraManager: Error starting active camera: $e');
    }
  }

  /// Pauses or stops the active camera streaming without disposing the controller.
  Future<void> stopActiveCamera() async {
    final controller = _activeController;
    if (controller == null) return;

    try {
      if (controller.value.isRunning || controller.value.isStarting) {
        await controller.stop();
      }
    } catch (e) {
      debugPrint('QrCameraManager: Error stopping active camera: $e');
    }
  }

  /// Completely stops and disposes any active controller, releasing all camera resources.
  Future<void> stopAndDispose() async {
    while (_isTransitioning) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    _isTransitioning = true;

    try {
      await _stopAndDisposeInternal();
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> _stopAndDisposeInternal() async {
    final controller = _activeController;
    _activeController = null;
    if (controller != null) {
      try {
        if (controller.value.isRunning || controller.value.isStarting) {
          await controller.stop();
        }
      } catch (e) {
        debugPrint('QrCameraManager: Error stopping controller on dispose: $e');
      }
      try {
        await controller.dispose();
      } catch (e) {
        debugPrint('QrCameraManager: Error disposing controller: $e');
      }
    }
  }
}
