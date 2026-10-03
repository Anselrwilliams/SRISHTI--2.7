import '../../events/models/event_model.dart';

/// Result returned from the SpotRegistrationService after processing registration.
class SpotRegistrationResult {
  final bool isSuccess;
  final bool isDuplicate;
  final String participantCode;
  final String message;
  final String? participantId;
  final String? registrationId;
  final Map<String, dynamic>? participant;
  final EventModel? event;
  final DateTime? registeredAt;
  final String registrationSource;

  const SpotRegistrationResult({
    required this.isSuccess,
    this.isDuplicate = false,
    required this.participantCode,
    required this.message,
    this.participantId,
    this.registrationId,
    this.participant,
    this.event,
    this.registeredAt,
    this.registrationSource = 'spot',
  });

  factory SpotRegistrationResult.success({
    required String participantCode,
    required String message,
    String? participantId,
    String? registrationId,
    Map<String, dynamic>? participant,
    EventModel? event,
    DateTime? registeredAt,
  }) {
    return SpotRegistrationResult(
      isSuccess: true,
      participantCode: participantCode,
      message: message,
      participantId: participantId,
      registrationId: registrationId,
      participant: participant,
      event: event,
      registeredAt: registeredAt ?? DateTime.now(),
      registrationSource: 'spot',
    );
  }

  factory SpotRegistrationResult.duplicate({
    required String message,
    required String participantCode,
    EventModel? event,
  }) {
    return SpotRegistrationResult(
      isSuccess: false,
      isDuplicate: true,
      participantCode: participantCode,
      message: message,
      event: event,
      registrationSource: 'spot',
    );
  }

  factory SpotRegistrationResult.failure({
    required String message,
    String participantCode = '',
  }) {
    return SpotRegistrationResult(
      isSuccess: false,
      isDuplicate: false,
      participantCode: participantCode,
      message: message,
      registrationSource: 'spot',
    );
  }
}
