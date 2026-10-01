import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../history/models/activity_item.dart';

/// Result object for arrival check-in and event attendance operations.
class AttendanceActionResult {
  final bool isSuccess;
  final bool isDuplicate;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime? recordedAt;

  const AttendanceActionResult({
    required this.isSuccess,
    this.isDuplicate = false,
    required this.message,
    this.data,
    this.recordedAt,
  });

  factory AttendanceActionResult.success({
    required String message,
    Map<String, dynamic>? data,
    DateTime? recordedAt,
  }) {
    return AttendanceActionResult(
      isSuccess: true,
      message: message,
      data: data,
      recordedAt: recordedAt ?? DateTime.now(),
    );
  }

  factory AttendanceActionResult.duplicate({
    required String message,
    DateTime? recordedAt,
    Map<String, dynamic>? data,
  }) {
    return AttendanceActionResult(
      isSuccess: false,
      isDuplicate: true,
      message: message,
      recordedAt: recordedAt,
      data: data,
    );
  }

  factory AttendanceActionResult.error({
    required String message,
  }) {
    return AttendanceActionResult(
      isSuccess: false,
      isDuplicate: false,
      message: message,
    );
  }
}

/// Service handling festival arrival check-ins, event attendance verification,
/// duplicate prevention, and real metrics queries against Supabase.
class CheckinService {
  final SupabaseService _supabaseService;

  CheckinService({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService.instance;

  /// Resolves the volunteer ID from the `volunteers` table for the current authenticated user.
  /// Falls back to the Supabase Auth user ID if not found in `volunteers`.
  Future<String> getVolunteerId() async {
    final authUser = _supabaseService.currentUser;
    if (authUser == null) return 'anonymous-volunteer';

    try {
      final res = await _supabaseService.client
          .from('volunteers')
          .select('id')
          .eq('auth_user_id', authUser.id)
          .maybeSingle();

      if (res != null && res['id'] != null) {
        return res['id'].toString();
      }
    } catch (_) {
      // Fallback if volunteers table lookup fails or is restricted by RLS
    }

    return authUser.id;
  }

  // ===========================================================================
  // ARRIVAL CHECK-IN
  // ===========================================================================

  /// Checks if a participant has already performed festival arrival check-in.
  Future<Map<String, dynamic>?> getArrivalCheckin(String participantId) async {
    try {
      final response = await _supabaseService.client
          .from('arrival_checkins')
          .select()
          .eq('participant_id', participantId)
          .maybeSingle();

      return response;
    } catch (_) {
      return null;
    }
  }

  /// Records a festival arrival check-in for a participant.
  ///
  /// Prevents duplicates at both application and database level.
  Future<AttendanceActionResult> recordArrivalCheckin({
    required String participantId,
    required String checkedInByVolunteerId,
    String source = 'qr', // 'qr' or 'manual'
    String? notes,
  }) async {
    // 1. Check if already checked in before inserting
    final existing = await getArrivalCheckin(participantId);
    if (existing != null) {
      final existingTime = existing['checked_in_at'] != null
          ? DateTime.tryParse(existing['checked_in_at'].toString())
          : null;
      return AttendanceActionResult.duplicate(
        message: 'Participant is already checked in to SRISHTI.',
        recordedAt: existingTime,
        data: existing,
      );
    }

    // 2. Perform insert
    try {
      final payload = <String, dynamic>{
        'participant_id': participantId,
        'checked_in_by': checkedInByVolunteerId,
        'source': source,
      };
      if (notes != null && notes.isNotEmpty) {
        payload['notes'] = notes;
      }

      final response = await _supabaseService.client
          .from('arrival_checkins')
          .insert(payload)
          .select()
          .single();

      final checkinTime = response['checked_in_at'] != null
          ? DateTime.tryParse(response['checked_in_at'].toString())
          : DateTime.now();

      return AttendanceActionResult.success(
        message: 'Arrival check-in recorded successfully.',
        data: response,
        recordedAt: checkinTime,
      );
    } on PostgrestException catch (e) {
      // Catch unique violation (PostgreSQL code 23505)
      if (e.code == '23505') {
        return AttendanceActionResult.duplicate(
          message: 'Participant was already checked in just now.',
        );
      }
      return AttendanceActionResult.error(
        message: 'Database error: ${e.message}',
      );
    } catch (e) {
      return AttendanceActionResult.error(
        message: 'Could not record check-in: $e',
      );
    }
  }

  // ===========================================================================
  // EVENT ATTENDANCE
  // ===========================================================================

  /// Checks if a participant is registered for a specific event in `registrations`.
  Future<Map<String, dynamic>?> getRegistration({
    required String participantId,
    required String eventId,
  }) async {
    try {
      final response = await _supabaseService.client
          .from('registrations')
          .select()
          .eq('participant_id', participantId)
          .eq('event_id', eventId)
          .maybeSingle();

      return response;
    } catch (_) {
      return null;
    }
  }

  /// Checks if attendance has already been recorded for a participant in a specific event.
  Future<Map<String, dynamic>?> getEventAttendance({
    required String participantId,
    required String eventId,
  }) async {
    try {
      final response = await _supabaseService.client
          .from('event_attendance')
          .select()
          .eq('participant_id', participantId)
          .eq('event_id', eventId)
          .maybeSingle();

      return response;
    } catch (_) {
      return null;
    }
  }

  /// Records attendance for a specific event.
  ///
  /// Enforces:
  /// 1. Arrival check-in verification
  /// 2. Event registration verification
  /// 3. Duplicate attendance prevention
  Future<AttendanceActionResult> recordEventAttendance({
    required String participantId,
    required String eventId,
    required String markedByVolunteerId,
    String source = 'qr', // 'qr' or 'manual'
    String? notes,
  }) async {
    // 1. Verify participant has arrived at SRISHTI
    final arrival = await getArrivalCheckin(participantId);
    if (arrival == null) {
      return AttendanceActionResult.error(
        message: 'Participant has not checked in to SRISHTI yet.',
      );
    }

    // 2. Verify participant is registered for this event
    final registration = await getRegistration(
      participantId: participantId,
      eventId: eventId,
    );
    if (registration == null) {
      return AttendanceActionResult.error(
        message: 'Participant is not registered for this event.',
      );
    }

    // 3. Check if already attended
    final existingAttendance = await getEventAttendance(
      participantId: participantId,
      eventId: eventId,
    );
    if (existingAttendance != null) {
      final attendedTime = existingAttendance['marked_at'] != null
          ? DateTime.tryParse(existingAttendance['marked_at'].toString())
          : null;
      return AttendanceActionResult.duplicate(
        message: 'Participant is already marked present for this event.',
        recordedAt: attendedTime,
        data: existingAttendance,
      );
    }

    // 4. Insert event attendance
    try {
      final payload = <String, dynamic>{
        'participant_id': participantId,
        'event_id': eventId,
        'marked_by': markedByVolunteerId,
        'source': source,
      };
      if (notes != null && notes.isNotEmpty) {
        payload['notes'] = notes;
      }

      final response = await _supabaseService.client
          .from('event_attendance')
          .insert(payload)
          .select()
          .single();

      final markedTime = response['marked_at'] != null
          ? DateTime.tryParse(response['marked_at'].toString())
          : DateTime.now();

      return AttendanceActionResult.success(
        message: 'Event attendance marked successfully.',
        data: response,
        recordedAt: markedTime,
      );
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return AttendanceActionResult.duplicate(
          message: 'Attendance was already marked for this event.',
        );
      }
      return AttendanceActionResult.error(
        message: 'Database error: ${e.message}',
      );
    } catch (e) {
      return AttendanceActionResult.error(
        message: 'Could not record event attendance: $e',
      );
    }
  }

  // ===========================================================================
  // REAL HOME STATISTICS
  // ===========================================================================

  /// Returns today's arrival check-in count from Supabase.
  Future<int> getTodayArrivalCheckinsCount() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

      final count = await _supabaseService.client
          .from('arrival_checkins')
          .count(CountOption.exact)
          .gte('checked_in_at', todayStart);

      return count;
    } catch (_) {
      // If gte filter fails or table is empty
      try {
        final count = await _supabaseService.client
            .from('arrival_checkins')
            .count(CountOption.exact);
        return count;
      } catch (_) {
        return 0;
      }
    }
  }

  /// Returns today's live event attendance count from Supabase.
  Future<int> getTodayEventAttendanceCount() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

      final count = await _supabaseService.client
          .from('event_attendance')
          .count(CountOption.exact)
          .gte('marked_at', todayStart);

      return count;
    } catch (_) {
      try {
        final count = await _supabaseService.client
            .from('event_attendance')
            .count(CountOption.exact);
        return count;
      } catch (_) {
        return 0;
      }
    }
  }

  // ===========================================================================
  // EVENTS & ACTIVITY LOGS
  // ===========================================================================

  /// Retrieves list of events from the database.
  Future<List<Map<String, dynamic>>> getActiveEvents() async {
    try {
      final response = await _supabaseService.client
          .from('events')
          .select()
          .order('event_code');

      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  /// Retrieves recent activity records from Supabase combining arrivals and event attendances.
  Future<List<ActivityItem>> getRecentActivities({int limit = 20}) async {
    final List<ActivityItem> items = [];

    try {
      // Fetch recent arrival check-ins with participant name
      final arrivals = await _supabaseService.client
          .from('arrival_checkins')
          .select('id, checked_in_at, source, participants(name, participant_code)')
          .order('checked_in_at', ascending: false)
          .limit(limit);

      for (final a in arrivals) {
        final participant = a['participants'] as Map<String, dynamic>?;
        items.add(
          ActivityItem(
            id: a['id']?.toString() ?? '',
            participantName: participant?['name']?.toString() ?? 'Participant',
            participantCode: participant?['participant_code']?.toString() ?? '—',
            actionType: 'Arrival Check-in',
            source: a['source']?.toString().toUpperCase() == 'MANUAL' ? 'Manual Search' : 'QR Scan',
            timestamp: a['checked_in_at'] != null
                ? DateTime.tryParse(a['checked_in_at'].toString()) ?? DateTime.now()
                : DateTime.now(),
          ),
        );
      }
    } catch (_) {}

    try {
      // Fetch recent event attendances with participant and event name
      final attendances = await _supabaseService.client
          .from('event_attendance')
          .select('id, marked_at, source, participants(name, participant_code), events(name)')
          .order('marked_at', ascending: false)
          .limit(limit);

      for (final att in attendances) {
        final participant = att['participants'] as Map<String, dynamic>?;
        final event = att['events'] as Map<String, dynamic>?;

        items.add(
          ActivityItem(
            id: att['id']?.toString() ?? '',
            participantName: participant?['name']?.toString() ?? 'Participant',
            participantCode: participant?['participant_code']?.toString() ?? '—',
            eventName: event?['name']?.toString(),
            actionType: 'Event Attendance',
            source: att['source']?.toString().toUpperCase() == 'MANUAL' ? 'Manual Search' : 'QR Scan',
            timestamp: att['marked_at'] != null
                ? DateTime.tryParse(att['marked_at'].toString()) ?? DateTime.now()
                : DateTime.now(),
          ),
        );
      }
    } catch (_) {}

    // Sort by timestamp descending
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (items.length > limit) {
      return items.sublist(0, limit);
    }
    return items;
  }
}
