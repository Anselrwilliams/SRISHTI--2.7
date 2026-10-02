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

  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Helper to test whether a string is a standard UUID.
  bool isUuid(String? value) {
    if (value == null) return false;
    return _uuidRegex.hasMatch(value.trim());
  }

  /// Resolves an event code, preview ID, or UUID into a valid database event UUID.
  Future<String?> resolveEventId(String eventIdOrCode) async {
    final clean = eventIdOrCode.trim();
    if (clean.isEmpty) return null;

    // 1. If it's already a valid UUID, verify or return directly
    if (isUuid(clean)) {
      try {
        final res = await _supabaseService.client
            .from('events')
            .select('id')
            .eq('id', clean)
            .maybeSingle();
        if (res != null && res['id'] != null) {
          return res['id'].toString();
        }
      } catch (_) {}
      return clean;
    }

    // 2. Lookup in events table by event_code
    try {
      final byCode = await _supabaseService.client
          .from('events')
          .select('id')
          .eq('event_code', clean.toUpperCase())
          .maybeSingle();
      if (byCode != null && byCode['id'] != null) {
        return byCode['id'].toString();
      }
    } catch (_) {}

    // 3. Fallback normalization for preview/sample codes
    String candidate = clean.toUpperCase();
    if (candidate == 'E1' || candidate == 'EV-01') candidate = 'TEST-EV-01';
    if (candidate == 'E2' || candidate == 'EV-02') candidate = 'TEST-EV-02';
    if (candidate == 'E3' || candidate == 'EV-03') candidate = 'TEST-EV-03';
    if (!candidate.startsWith('TEST-') && candidate.startsWith('EV-')) {
      candidate = 'TEST-$candidate';
    }

    try {
      final byCandidate = await _supabaseService.client
          .from('events')
          .select('id')
          .eq('event_code', candidate)
          .maybeSingle();
      if (byCandidate != null && byCandidate['id'] != null) {
        return byCandidate['id'].toString();
      }
    } catch (_) {}

    // 4. Fallback search by ilike pattern on event_code or name
    try {
      final byPattern = await _supabaseService.client
          .from('events')
          .select('id')
          .or('event_code.ilike.%$clean%,name.ilike.%$clean%')
          .limit(1)
          .maybeSingle();
      if (byPattern != null && byPattern['id'] != null) {
        return byPattern['id'].toString();
      }
    } catch (_) {}

    return null;
  }

  /// Resolves a participant code or UUID into a valid database participant UUID.
  Future<String?> resolveParticipantId(String participantIdOrCode) async {
    final clean = participantIdOrCode.trim();
    if (clean.isEmpty) return null;

    // 1. If it's already a valid UUID, verify or return directly
    if (isUuid(clean)) {
      try {
        final res = await _supabaseService.client
            .from('participants')
            .select('id')
            .eq('id', clean)
            .maybeSingle();
        if (res != null && res['id'] != null) {
          return res['id'].toString();
        }
      } catch (_) {}
      return clean;
    }

    // 2. Lookup in participants table by participant_code
    try {
      final byCode = await _supabaseService.client
          .from('participants')
          .select('id')
          .eq('participant_code', clean.toUpperCase())
          .maybeSingle();
      if (byCode != null && byCode['id'] != null) {
        return byCode['id'].toString();
      }
    } catch (_) {}

    // 3. Fallback search by ilike pattern on participant_code
    try {
      final byPattern = await _supabaseService.client
          .from('participants')
          .select('id')
          .or('participant_code.ilike.%$clean%')
          .limit(1)
          .maybeSingle();
      if (byPattern != null && byPattern['id'] != null) {
        return byPattern['id'].toString();
      }
    } catch (_) {}

    return null;
  }

  // ===========================================================================
  // ARRIVAL CHECK-IN
  // ===========================================================================

  /// Checks if a participant has already performed festival arrival check-in.
  /// Supports both participant UUID and participant code (e.g. 'TEST-SRI27-002').
  Future<Map<String, dynamic>?> getArrivalCheckin(String participantId) async {
    try {
      final pId = await resolveParticipantId(participantId) ?? (isUuid(participantId) ? participantId : null);
      if (pId == null) return null;

      final response = await _supabaseService.client
          .from('arrival_checkins')
          .select()
          .eq('participant_id', pId)
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
    final pId = await resolveParticipantId(participantId) ?? (isUuid(participantId) ? participantId : null);
    if (pId == null) {
      return AttendanceActionResult.error(
        message: 'Could not resolve participant record.',
      );
    }

    // 1. Check if already checked in before inserting
    final existing = await getArrivalCheckin(pId);
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
        'participant_id': pId,
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
  /// Supports participant UUID or code, and event UUID, event code, or preview ID.
  Future<Map<String, dynamic>?> getRegistration({
    required String participantId,
    required String eventId,
  }) async {
    try {
      final pId = await resolveParticipantId(participantId);
      final eId = await resolveEventId(eventId);

      // 1. Direct lookup by resolved UUIDs
      if (pId != null && eId != null && isUuid(pId) && isUuid(eId)) {
        try {
          final response = await _supabaseService.client
              .from('registrations')
              .select()
              .eq('participant_id', pId)
              .eq('event_id', eId)
              .maybeSingle();

          if (response != null) {
            return response;
          }
        } catch (_) {}
      }

      // 2. Fallback: Joined query matching on participant_code and event_code
      try {
        final pCode = participantId.trim().toUpperCase();
        final eCode = eventId.trim().toUpperCase();

        var query = _supabaseService.client
            .from('registrations')
            .select('*, participants!inner(id, participant_code), events!inner(id, event_code)');

        if (pId != null && isUuid(pId)) {
          query = query.eq('participant_id', pId);
        } else {
          query = query.or('participant_code.eq.$pCode,participant_code.ilike.%$pCode%', referencedTable: 'participants');
        }

        if (eId != null && isUuid(eId)) {
          query = query.eq('event_id', eId);
        } else {
          query = query.or('event_code.eq.$eCode,event_code.ilike.%$eCode%', referencedTable: 'events');
        }

        final joined = await query.maybeSingle();
        if (joined != null) {
          return joined;
        }
      } catch (_) {}

      // 3. Fallback: Direct query if both originally provided were UUIDs
      if (isUuid(participantId) && isUuid(eventId)) {
        try {
          final fallback = await _supabaseService.client
              .from('registrations')
              .select()
              .eq('participant_id', participantId)
              .eq('event_id', eventId)
              .maybeSingle();
          if (fallback != null) {
            return fallback;
          }
        } catch (_) {}
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Checks if attendance has already been recorded for a participant in a specific event.
  /// Supports participant UUID or code, and event UUID or code.
  Future<Map<String, dynamic>?> getEventAttendance({
    required String participantId,
    required String eventId,
  }) async {
    try {
      final pId = await resolveParticipantId(participantId) ?? (isUuid(participantId) ? participantId : null);
      final eId = await resolveEventId(eventId) ?? (isUuid(eventId) ? eventId : null);
      if (pId == null || eId == null) return null;

      final response = await _supabaseService.client
          .from('event_attendance')
          .select()
          .eq('participant_id', pId)
          .eq('event_id', eId)
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
    final pId = await resolveParticipantId(participantId) ?? (isUuid(participantId) ? participantId : null);
    final eId = await resolveEventId(eventId) ?? (isUuid(eventId) ? eventId : null);

    if (pId == null) {
      return AttendanceActionResult.error(
        message: 'Could not resolve participant record.',
      );
    }
    if (eId == null) {
      return AttendanceActionResult.error(
        message: 'Could not resolve event record.',
      );
    }

    // 1. Verify participant has arrived at SRISHTI
    final arrival = await getArrivalCheckin(pId);
    if (arrival == null) {
      return AttendanceActionResult.error(
        message: 'Participant has not checked in to SRISHTI yet.',
      );
    }

    // 2. Verify participant is registered for this event
    final registration = await getRegistration(
      participantId: pId,
      eventId: eId,
    );
    if (registration == null) {
      return AttendanceActionResult.error(
        message: 'Participant is not registered for this event.',
      );
    }

    // 3. Check if already attended
    final existingAttendance = await getEventAttendance(
      participantId: pId,
      eventId: eId,
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
        'participant_id': pId,
        'event_id': eId,
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

  // ===========================================================================
  // ROLE-BASED DASHBOARD QUERIES & METRICS
  // ===========================================================================

  /// Returns registration count and attendance count for a given event ID or code.
  Future<Map<String, int>> getEventCounts(String eventId) async {
    final eId = await resolveEventId(eventId) ?? (isUuid(eventId) ? eventId : null);
    if (eId == null) {
      return {'registered': 0, 'attended': 0};
    }

    int registered = 0;
    int attended = 0;

    try {
      registered = await _supabaseService.client
          .from('registrations')
          .count(CountOption.exact)
          .eq('event_id', eId);
    } catch (_) {}

    try {
      attended = await _supabaseService.client
          .from('event_attendance')
          .count(CountOption.exact)
          .eq('event_id', eId);
    } catch (_) {}

    return {'registered': registered, 'attended': attended};
  }

  /// Returns recent event attendances specifically for a single event.
  Future<List<ActivityItem>> getEventRecentActivities(String eventId, {int limit = 20}) async {
    final eId = await resolveEventId(eventId) ?? (isUuid(eventId) ? eventId : null);
    if (eId == null) return [];

    final List<ActivityItem> items = [];
    try {
      final attendances = await _supabaseService.client
          .from('event_attendance')
          .select('id, marked_at, source, participants(name, participant_code), events(name)')
          .eq('event_id', eId)
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

    return items;
  }

  /// Returns recent festival arrival check-ins only.
  Future<List<ActivityItem>> getRecentArrivals({int limit = 20}) async {
    final List<ActivityItem> items = [];
    try {
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

    return items;
  }

  /// Returns total registered participants in the system.
  Future<int> getTotalParticipantsCount() async {
    try {
      return await _supabaseService.client
          .from('participants')
          .count(CountOption.exact);
    } catch (_) {
      return 0;
    }
  }

  /// Returns total festival arrival check-ins.
  Future<int> getTotalArrivalsCount() async {
    try {
      return await _supabaseService.client
          .from('arrival_checkins')
          .count(CountOption.exact);
    } catch (_) {
      return 0;
    }
  }

  /// Returns total event registrations across all events.
  Future<int> getTotalRegistrationsCount() async {
    try {
      return await _supabaseService.client
          .from('registrations')
          .count(CountOption.exact);
    } catch (_) {
      return 0;
    }
  }

  /// Returns total event attendance records across all events.
  Future<int> getTotalEventAttendanceCount() async {
    try {
      return await _supabaseService.client
          .from('event_attendance')
          .count(CountOption.exact);
    } catch (_) {
      return 0;
    }
  }

  /// Returns total number of events.
  Future<int> getTotalEventsCount() async {
    try {
      return await _supabaseService.client
          .from('events')
          .count(CountOption.exact);
    } catch (_) {
      return 0;
    }
  }

  /// Returns total active volunteers.
  Future<int> getTotalActiveVolunteersCount() async {
    try {
      return await _supabaseService.client
          .from('volunteers')
          .count(CountOption.exact)
          .eq('status', 'active');
    } catch (_) {
      return 0;
    }
  }

  /// Returns total scans performed by a specific volunteer.
  Future<Map<String, int>> getVolunteerActivityCounts(String volunteerId) async {
    int arrivals = 0;
    int events = 0;
    try {
      arrivals = await _supabaseService.client
          .from('arrival_checkins')
          .count(CountOption.exact)
          .eq('checked_in_by', volunteerId);
    } catch (_) {}
    try {
      events = await _supabaseService.client
          .from('event_attendance')
          .count(CountOption.exact)
          .eq('marked_by', volunteerId);
    } catch (_) {}
    return {
      'arrivals': arrivals,
      'events': events,
      'total': arrivals + events,
    };
  }

  /// Returns registered participants roster for a specific event with arrival & attendance status.
  Future<List<Map<String, dynamic>>> getEventRoster(String eventId) async {
    final eId = await resolveEventId(eventId) ?? (isUuid(eventId) ? eventId : null);
    if (eId == null) return [];

    try {
      final registrations = await _supabaseService.client
          .from('registrations')
          .select('id, status, registered_at, participant_id, participants(*)')
          .eq('event_id', eId)
          .order('registered_at', ascending: true);

      return List<Map<String, dynamic>>.from(registrations);
    } catch (_) {
      return [];
    }
  }
}

