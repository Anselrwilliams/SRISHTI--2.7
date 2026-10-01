import '../../../core/services/supabase_service.dart';

/// Service handling participant lookup and verification against the Supabase `participants` table.
///
/// Designed for integration with QR scanner and manual lookup modules.
class ParticipantService {
  final SupabaseService _supabaseService;

  ParticipantService({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService.instance;

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
}
