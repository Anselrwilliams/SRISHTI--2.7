/// Specifies the QR scanning and check-in context.
enum AttendanceMode {
  /// Festival-wide arrival check-in (Main Gate).
  arrival,

  /// Event-specific competition / workshop attendance.
  event,
}

/// Validation states for the two-stage attendance workflow.
enum AttendanceValidationState {
  /// Ready to record check-in / attendance.
  valid,

  /// QR code does not match any participant in the database.
  participantNotFound,

  /// Participant has not checked into the festival yet (required before event attendance).
  participantNotArrived,

  /// Participant is not registered for the targeted event.
  notRegisteredForEvent,

  /// Participant already checked in to SRISHTI.
  alreadyCheckedIn,

  /// Participant already attended this specific event.
  alreadyAttended,

  /// Network or server error.
  networkError,
}
