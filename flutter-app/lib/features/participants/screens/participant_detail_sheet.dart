import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../checkin/models/attendance_mode.dart';
import '../../checkin/services/checkin_service.dart';
import '../models/participant_model.dart';

/// Modal sheet displaying participant details with real two-stage verification
/// for both Festival Arrival and Event Attendance workflows.
class ParticipantDetailSheet extends StatefulWidget {
  final ParticipantModel participant;
  final AttendanceMode mode;
  final String? eventId;
  final String? eventName;
  final String source; // 'qr' or 'manual'
  final VoidCallback? onActionSuccess;

  const ParticipantDetailSheet({
    super.key,
    required this.participant,
    this.mode = AttendanceMode.arrival,
    this.eventId,
    this.eventName,
    this.source = 'qr',
    this.onActionSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required ParticipantModel participant,
    AttendanceMode mode = AttendanceMode.arrival,
    String? eventId,
    String? eventName,
    String source = 'qr',
    VoidCallback? onActionSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ParticipantDetailSheet(
        participant: participant,
        mode: mode,
        eventId: eventId,
        eventName: eventName,
        source: source,
        onActionSuccess: onActionSuccess,
      ),
    );
  }

  @override
  State<ParticipantDetailSheet> createState() => _ParticipantDetailSheetState();
}

class _ParticipantDetailSheetState extends State<ParticipantDetailSheet> {
  late ParticipantModel _participant;
  final CheckinService _checkinService = CheckinService();

  bool _isLoadingInitialState = true;
  bool _isProcessingAction = false;

  // Validation Flags for Event Mode
  bool _hasArrived = false;
  DateTime? _arrivedAt;

  bool _isRegisteredForEvent = false;
  bool _hasAttendedEvent = false;
  DateTime? _eventAttendedAt;

  String? _successMessage;
  String? _warningMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _participant = widget.participant;
    _validateParticipantState();
  }

  Future<void> _validateParticipantState() async {
    setState(() => _isLoadingInitialState = true);

    try {
      final effectiveParticipantId = _participant.id.isNotEmpty
          ? _participant.id
          : _participant.participantCode;

      // 1. Check arrival check-in status
      final arrivalData = await _checkinService.getArrivalCheckin(effectiveParticipantId);
      _hasArrived = arrivalData != null;
      if (arrivalData != null && arrivalData['checked_in_at'] != null) {
        _arrivedAt = DateTime.tryParse(arrivalData['checked_in_at'].toString());
      }

      if (widget.mode == AttendanceMode.event && widget.eventId != null) {
        // 2. Check if registered for this event
        final regData = await _checkinService.getRegistration(
          participantId: effectiveParticipantId,
          eventId: widget.eventId!,
        );
        _isRegisteredForEvent = regData != null;

        // 3. Check if already attended this event
        final attendanceData = await _checkinService.getEventAttendance(
          participantId: effectiveParticipantId,
          eventId: widget.eventId!,
        );
        _hasAttendedEvent = attendanceData != null;
        if (attendanceData != null && attendanceData['marked_at'] != null) {
          _eventAttendedAt = DateTime.tryParse(attendanceData['marked_at'].toString());
        }
      }
    } catch (e) {
      _errorMessage = 'Could not verify status: $e';
    } finally {
      if (mounted) {
        setState(() => _isLoadingInitialState = false);
      }
    }
  }

  // Handle Arrival Check-in Action
  Future<void> _performArrivalCheckin() async {
    setState(() {
      _isProcessingAction = true;
      _errorMessage = null;
      _warningMessage = null;
      _successMessage = null;
    });

    try {
      final volunteerId = await _checkinService.getVolunteerId();
      final effectiveParticipantId = _participant.id.isNotEmpty
          ? _participant.id
          : _participant.participantCode;
      final result = await _checkinService.recordArrivalCheckin(
        participantId: effectiveParticipantId,
        checkedInByVolunteerId: volunteerId,
        source: widget.source,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        setState(() {
          _hasArrived = true;
          _arrivedAt = result.recordedAt ?? DateTime.now();
          _successMessage = '✓ Check-in successful';
        });
        widget.onActionSuccess?.call();
      } else if (result.isDuplicate) {
        setState(() {
          _hasArrived = true;
          _arrivedAt = result.recordedAt ?? _arrivedAt;
          _warningMessage = 'Already checked in';
        });
      } else {
        setState(() {
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Network error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  // Handle Event Attendance Action
  Future<void> _performEventAttendance() async {
    if (widget.eventId == null) return;

    setState(() {
      _isProcessingAction = true;
      _errorMessage = null;
      _warningMessage = null;
      _successMessage = null;
    });

    try {
      final volunteerId = await _checkinService.getVolunteerId();
      final effectiveParticipantId = _participant.id.isNotEmpty
          ? _participant.id
          : _participant.participantCode;
      final result = await _checkinService.recordEventAttendance(
        participantId: effectiveParticipantId,
        eventId: widget.eventId!,
        markedByVolunteerId: volunteerId,
        source: widget.source,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        setState(() {
          _hasAttendedEvent = true;
          _eventAttendedAt = result.recordedAt ?? DateTime.now();
          _successMessage = '✓ Event attendance marked';
        });
        widget.onActionSuccess?.call();
      } else if (result.isDuplicate) {
        setState(() {
          _hasAttendedEvent = true;
          _warningMessage = 'Already marked present';
        });
      } else {
        setState(() {
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Network error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: _isLoadingInitialState
          ? const SizedBox(
              height: 250,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.electricBlue),
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Workflow Context Banner
                _buildWorkflowHeader(),
                const SizedBox(height: 14),

                // Participant Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _participant.participantCode,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          color: AppColors.cyan,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Text(
                      'Source: ${widget.source.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Text(
                  _participant.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _participant.college ?? 'External Participant',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),

                // Status & Messages
                if (_successMessage != null) ...[
                  _buildStatusBanner(
                    color: AppColors.success,
                    bg: AppColors.successBg,
                    border: AppColors.successBorder,
                    icon: Icons.check_circle_rounded,
                    title: _successMessage!,
                  ),
                  const SizedBox(height: 16),
                ],

                if (_warningMessage != null) ...[
                  _buildStatusBanner(
                    color: AppColors.warning,
                    bg: AppColors.warningBg,
                    border: AppColors.warningBorder,
                    icon: Icons.warning_amber_rounded,
                    title: _warningMessage!,
                    subtitle: widget.mode == AttendanceMode.arrival
                        ? (_arrivedAt != null ? 'Checked in at ${_formatTime(_arrivedAt!)}' : null)
                        : (_eventAttendedAt != null ? 'Marked present at ${_formatTime(_eventAttendedAt!)}' : null),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_errorMessage != null) ...[
                  _buildStatusBanner(
                    color: AppColors.error,
                    bg: AppColors.errorBg,
                    border: AppColors.errorBorder,
                    icon: Icons.error_outline_rounded,
                    title: _errorMessage!,
                  ),
                  const SizedBox(height: 16),
                ],

                // Verification Details Checklist
                _buildVerificationChecklist(),
                const SizedBox(height: 20),

                // Dynamic Action Button based on Workflow
                _buildWorkflowActionButton(),
              ],
            ),
    );
  }

  Widget _buildWorkflowHeader() {
    final isArrival = widget.mode == AttendanceMode.arrival;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isArrival ? AppColors.cyan.withAlpha(20) : AppColors.electricBlue.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isArrival ? Icons.how_to_reg_rounded : Icons.event_available_rounded,
            size: 16,
            color: isArrival ? AppColors.electricBlue : AppColors.electricBlue,
          ),
          const SizedBox(width: 8),
          Text(
            isArrival
                ? 'FESTIVAL ARRIVAL CHECK-IN'
                : 'EVENT ATTENDANCE: ${widget.eventName ?? "Event"}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.electricBlue,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationChecklist() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          _buildCheckRow(
            label: 'Festival Arrival Check-in',
            isPositive: _hasArrived,
            positiveText: _arrivedAt != null ? 'Arrived (${_formatTime(_arrivedAt!)})' : 'Arrived',
            negativeText: 'Not checked in to SRISHTI yet',
          ),
          if (widget.mode == AttendanceMode.event) ...[
            const Divider(height: 16),
            _buildCheckRow(
              label: 'Event Registration',
              isPositive: _isRegisteredForEvent,
              positiveText: 'Registered',
              negativeText: 'Not registered for this event',
            ),
            const Divider(height: 16),
            _buildCheckRow(
              label: 'Event Attendance',
              isPositive: _hasAttendedEvent,
              positiveText: _eventAttendedAt != null
                  ? 'Present (${_formatTime(_eventAttendedAt!)})'
                  : 'Present',
              negativeText: 'Not marked yet',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckRow({
    required String label,
    required bool isPositive,
    required String positiveText,
    required String negativeText,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPositive ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 14,
              color: isPositive ? AppColors.success : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              isPositive ? positiveText : negativeText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isPositive ? AppColors.success : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWorkflowActionButton() {
    if (widget.mode == AttendanceMode.arrival) {
      if (_hasArrived) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(
            child: Text(
              'Participant Already Checked In',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        );
      }

      return GradientButton(
        onPressed: _isProcessingAction ? null : _performArrivalCheckin,
        label: 'Confirm Festival Check-in',
        icon: Icons.how_to_reg_rounded,
        isLoading: _isProcessingAction,
        height: 52,
      );
    } else {
      // Event Attendance Mode
      if (!_hasArrived) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warningBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Participant has not checked in to SRISHTI yet. Festival arrival check-in is required before event attendance.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GradientButton(
              onPressed: _isProcessingAction ? null : _performArrivalCheckin,
              label: 'Check into Festival First',
              icon: Icons.login_rounded,
              isLoading: _isProcessingAction,
              height: 48,
            ),
          ],
        );
      }

      if (!_isRegisteredForEvent) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.errorBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.errorBorder),
          ),
          child: const Center(
            child: Text(
              'Not registered for this event',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        );
      }

      if (_hasAttendedEvent) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(
            child: Text(
              'Already marked present',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        );
      }

      // Valid: ready to mark attendance
      return GradientButton(
        onPressed: _isProcessingAction ? null : _performEventAttendance,
        label: 'Mark Event Attendance',
        icon: Icons.check_circle_outline_rounded,
        isLoading: _isProcessingAction,
        height: 52,
      );
    }
  }

  Widget _buildStatusBanner({
    required Color color,
    required Color bg,
    required Color border,
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withAlpha(200),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
