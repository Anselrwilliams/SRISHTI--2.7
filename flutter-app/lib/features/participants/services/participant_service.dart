import '../../../core/services/supabase_service.dart';
import '../../events/models/event_model.dart';

/// Service handling participant lookup and verification against the Supabase `participants`
/// and `registrations` tables.
class ParticipantService {
  final SupabaseService _supabaseService;

  ParticipantService({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService.instance;

  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Looks up a participant by their unique [participantCode] (e.g. scanned from QR code).
  Future<Map<String, dynamic>?> getParticipantByCode(String participantCode) async {
    final response = await _supabaseService.client
        .from('participants')
        .select()
        .eq('participant_code', participantCode.trim().toUpperCase())
        .maybeSingle();

    return response;
  }

  /// Searches participants by name, code, or phone number.
  Future<List<Map<String, dynamic>>> searchParticipants(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final response = await _supabaseService.client
        .from('participants')
        .select()
        .or('participant_code.ilike.%$cleanQuery%,name.ilike.%$cleanQuery%,phone.ilike.%$cleanQuery%')
        .limit(20);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetches all active registered events for a participant.
  ///
  /// Only returns records where `registrations.status == 'registered'`.
  /// Automatically filters out cancelled or waitlisted registrations.
  /// Results are sorted by event date -> start time -> event name.
  Future<List<EventModel>> getParticipantRegisteredEvents(String participantId) async {
    final clean = participantId.trim();
    if (clean.isEmpty) return [];

    String? resolvedId;
    if (_uuidRegex.hasMatch(clean)) {
      resolvedId = clean;
    } else {
      // Lookup participant ID by participant_code
      try {
        final res = await _supabaseService.client
            .from('participants')
            .select('id')
            .eq('participant_code', clean.toUpperCase())
            .maybeSingle();
        if (res != null && res['id'] != null) {
          resolvedId = res['id'].toString();
        }
      } catch (_) {}
    }

    if (resolvedId == null) {
      return [];
    }

    List<Map<String, dynamic>> rawEvents = [];
    bool joinedQuerySucceeded = false;
    List<dynamic> joinedRows = [];

    // 1. Try foreign-key joined query: registrations -> events
    try {
      final joined = await _supabaseService.client
          .from('registrations')
          .select('id, status, registered_at, event_id, events(*)')
          .eq('participant_id', resolvedId)
          .eq('status', 'registered');

      joinedRows = List<dynamic>.from(joined as List);
      joinedQuerySucceeded = true;
      for (final row in joinedRows) {
        if (row['events'] != null) {
          if (row['events'] is Map) {
            rawEvents.add(Map<String, dynamic>.from(row['events'] as Map));
          } else if (row['events'] is List && (row['events'] as List).isNotEmpty) {
            rawEvents.add(Map<String, dynamic>.from((row['events'] as List).first as Map));
          }
        }
      }
    } catch (_) {
      // Fallback if joined query is not supported by schema or PostgREST setup
    }

    // 2. Fallback: 2-step query if joined query failed OR returned rows without embedded events
    if (!joinedQuerySucceeded || (joinedRows.isNotEmpty && rawEvents.isEmpty)) {
      final regRows = await _supabaseService.client
          .from('registrations')
          .select('event_id')
          .eq('participant_id', resolvedId)
          .eq('status', 'registered');

      final eventIds = List<Map<String, dynamic>>.from(regRows)
          .map((r) => r['event_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      if (eventIds.isNotEmpty) {
        final eventsResponse = await _supabaseService.client
            .from('events')
            .select()
            .inFilter('id', eventIds);

        rawEvents = List<Map<String, dynamic>>.from(eventsResponse);
      }
    }

    final List<EventModel> models = rawEvents.map((m) => EventModel.fromMap(m)).toList();

    // 3. Sorting: event date -> start time -> event name
    sortEvents(models);

    return models;
  }

  /// Sorts a list of events by date -> start time -> event name.
  static void sortEvents(List<EventModel> events) {
    events.sort((a, b) {
      final dateA = a.date?.trim() ?? '';
      final dateB = b.date?.trim() ?? '';
      if (dateA.isNotEmpty && dateB.isNotEmpty && dateA != dateB) {
        return dateA.compareTo(dateB);
      } else if (dateA.isNotEmpty && dateB.isEmpty) {
        return -1;
      } else if (dateA.isEmpty && dateB.isNotEmpty) {
        return 1;
      }

      final timeA = a.startTime ?? a.time ?? '';
      final timeB = b.startTime ?? b.time ?? '';
      if (timeA.isNotEmpty || timeB.isNotEmpty) {
        final minutesA = _timeToMinutes(timeA);
        final minutesB = _timeToMinutes(timeB);
        if (minutesA != minutesB) {
          return minutesA.compareTo(minutesB);
        }
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  static int _timeToMinutes(String timeStr) {
    final clean = timeStr.trim().toUpperCase();
    if (clean.isEmpty) return 999999;

    final isPm = clean.contains('PM');
    final isAm = clean.contains('AM');

    final numPart = clean.replaceAll(RegExp(r'[^0-9:]'), '');
    final parts = numPart.split(':');
    if (parts.isEmpty || parts[0].isEmpty) return 999999;

    int hour = int.tryParse(parts[0]) ?? 0;
    int minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    if (isPm && hour < 12) {
      hour += 12;
    } else if (isAm && hour == 12) {
      hour = 0;
    }

    return hour * 60 + minute;
  }
}
