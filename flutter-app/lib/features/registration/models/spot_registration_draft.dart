import '../../events/models/event_model.dart';
import 'team_member_model.dart';

/// Draft state holding form and payment progression during a spot registration flow.
class SpotRegistrationDraft {
  // Primary participant (Team Leader for team events)
  final String fullName;
  final String phone;
  final String email;
  final String college;
  final String yearOfStudy;

  // Selected event
  final EventModel? selectedEvent;

  // Team members (excluding leader)
  final List<TeamMemberModel> teamMembers;

  // Payment state
  final double amount;
  final bool isPaymentVerified;
  final String? transactionRef;
  final DateTime? verifiedAt;

  const SpotRegistrationDraft({
    this.fullName = '',
    this.phone = '',
    this.email = '',
    this.college = '',
    this.yearOfStudy = '1st Year',
    this.selectedEvent,
    this.teamMembers = const [],
    this.amount = 0.0,
    this.isPaymentVerified = false,
    this.transactionRef,
    this.verifiedAt,
  });

  bool get isTeamRegistration => selectedEvent?.isTeamEvent ?? false;

  /// Total count of participants registered under this ticket: Leader (1) + Members.
  int get totalMembersCount => 1 + teamMembers.length;

  /// Determines registration fee dynamically based on event fee configuration.
  /// If the event provides a registration fee, uses it. Default fallback is ₹100 per member or base ₹150.
  double get effectiveAmount {
    if (amount > 0) return amount;
    if (selectedEvent != null && selectedEvent!.registrationFee != null && selectedEvent!.registrationFee! > 0) {
      return selectedEvent!.registrationFee!;
    }
    // Dynamic default: ₹150 for individual, or ₹100 per member for team
    return isTeamRegistration ? (100.0 * totalMembersCount) : 150.0;
  }

  /// UPI Deep-link / QR payload string for Indian UPI payment apps.
  String get upiPaymentUrl {
    final amt = effectiveAmount.toStringAsFixed(0);
    final eventName = Uri.encodeComponent(selectedEvent?.name ?? 'Event');
    final pName = Uri.encodeComponent(fullName.isNotEmpty ? fullName : 'Participant');
    final note = Uri.encodeComponent('SRISHTI Spot Reg - $eventName - $pName');

    return 'upi://pay?pa=srishti2026@upi&pn=SRISHTI%202.7&am=$amt&cu=INR&tn=$note';
  }

  SpotRegistrationDraft copyWith({
    String? fullName,
    String? phone,
    String? email,
    String? college,
    String? yearOfStudy,
    EventModel? selectedEvent,
    List<TeamMemberModel>? teamMembers,
    double? amount,
    bool? isPaymentVerified,
    String? transactionRef,
    DateTime? verifiedAt,
  }) {
    return SpotRegistrationDraft(
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      college: college ?? this.college,
      yearOfStudy: yearOfStudy ?? this.yearOfStudy,
      selectedEvent: selectedEvent ?? this.selectedEvent,
      teamMembers: teamMembers ?? this.teamMembers,
      amount: amount ?? this.amount,
      isPaymentVerified: isPaymentVerified ?? this.isPaymentVerified,
      transactionRef: transactionRef ?? this.transactionRef,
      verifiedAt: verifiedAt ?? this.verifiedAt,
    );
  }
}
