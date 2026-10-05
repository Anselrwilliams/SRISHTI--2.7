import 'package:flutter/services.dart';

/// Reusable service providing tactile haptic and vibration feedback for
/// scanner operations, participant verification, and check-in workflows.
///
/// Vibration patterns are calibrated to be:
/// - Short, crisp, and professional.
/// - Noticeable when the device is held in hand.
/// - Distinct enough to differentiate between success, invalid QR, and duplicate status
///   without requiring the operator to look at the screen.
/// - Fire-and-forget: does not block UI rendering, database transactions, or test execution.
class HapticFeedbackService {
  HapticFeedbackService._();

  static final HapticFeedbackService instance = HapticFeedbackService._();

  /// Optional hook for testing to observe or verify haptic events.
  static void Function(String event)? testHook;

  /// Whether haptic feedback is globally enabled (default: true).
  bool enabled = true;

  /// Triggered when a QR code is successfully scanned and recognized, or when
  /// event attendance / arrival check-in is successfully marked.
  ///
  /// Pattern: A single crisp medium impact vibration.
  Future<void> success() async {
    testHook?.call('success');
    if (!enabled) return;
    _triggerAsync(() => HapticFeedback.mediumImpact());
  }

  /// Triggered when a QR code is scanned but is invalid or not found in the system.
  ///
  /// Pattern: A distinct double heavy impact pattern to immediately alert the
  /// volunteer of an invalid code without looking at the screen.
  Future<void> error() async {
    testHook?.call('error');
    if (!enabled) return;
    _triggerAsync(() async {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 120));
      await HapticFeedback.heavyImpact();
    });
  }

  /// Triggered when a duplicate FEST arrival or duplicate event attendance is detected
  /// (indicating "already checked in" / "already marked present").
  ///
  /// Pattern: A rapid triple-pulse sequence (click-impact-click) distinct from both
  /// a single success and a double-heavy error.
  Future<void> duplicate() async {
    testHook?.call('duplicate');
    if (!enabled) return;
    _triggerAsync(() async {
      await HapticFeedback.selectionClick();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.selectionClick();
    });
  }

  /// Dispatches the haptic feedback asynchronously without blocking the caller or
  /// interfering with Flutter widget pump cycles in tests.
  void _triggerAsync(Future<void> Function() action) {
    action().timeout(
      const Duration(milliseconds: 200),
      onTimeout: () {},
    ).catchError((_) {});
  }
}
