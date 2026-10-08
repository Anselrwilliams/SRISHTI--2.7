import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../events/models/event_model.dart';
import '../models/spot_registration_draft.dart';
import '../models/spot_registration_result.dart';

/// Service abstraction handling Spot Registration logic, event loading,
/// and Supabase Edge Function (`spot-register`) integration.
class SpotRegistrationService {
  final SupabaseService _supabaseService;

  static const String databaseFailureMessage =
      'Registration could not be completed. No registration was saved.';

  SpotRegistrationService({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService.instance;

  @visibleForTesting
  bool get isDatabaseReady => _supabaseService.isInitialized;

  /// Fetches available events from Supabase.
  /// If Supabase cannot load events or returns no events, returns an empty event list.
  Future<List<EventModel>> getAvailableEvents() async {
    try {
      if (isDatabaseReady) {
        final response = await _supabaseService.client
            .from('events')
            .select()
            .order('event_code');

        final List<Map<String, dynamic>> rawList =
            List<Map<String, dynamic>>.from(response);

        if (rawList.isNotEmpty) {
          return rawList.map((m) => EventModel.fromMap(m)).toList();
        }
      }
    } catch (e) {
      debugPrint('SpotRegistrationService: Note on fetching events: $e');
    }

    return [];
  }

  /// Hook to invoke the `spot-register` Edge Function. Can be overridden in tests.
  @visibleForTesting
  Future<FunctionResponse> invokeSpotRegisterFunction(
    Map<String, dynamic> payload,
  ) async {
    if (!isDatabaseReady) {
      throw StateError('Supabase connection unavailable');
    }
    return await _supabaseService.client.functions.invoke(
      'spot-register',
      body: payload,
    );
  }

  /// Creates a spot registration record via the server-side `spot-register` Edge Function.
  /// Enforces coordinator authentication, payment verification, and server-side atomicity.
  Future<SpotRegistrationResult> createSpotRegistration({
    required SpotRegistrationDraft draft,
    required String volunteerId,
  }) async {
    // 1. Client-Side Payment Verification Pre-check
    if (!draft.isPaymentVerified) {
      return SpotRegistrationResult.failure(
        message: 'Payment has not been verified yet. Please verify payment first.',
      );
    }

    // 2. Validate Event
    final event = draft.selectedEvent;
    if (event == null) {
      return SpotRegistrationResult.failure(
        message: 'Please select an event for registration.',
      );
    }

    // 3. Validate Team Rules
    if (event.isTeamEvent) {
      final max = event.effectiveMaxTeamSize;
      if (draft.totalMembersCount > max) {
        return SpotRegistrationResult.failure(
          message: 'Team size exceeds the maximum allowed limit of $max for ${event.name}.',
        );
      }
      for (int i = 0; i < draft.teamMembers.length; i++) {
        final member = draft.teamMembers[i];
        if (!member.isValid) {
          return SpotRegistrationResult.failure(
            message: 'Please provide valid details for Team Member ${i + 2}.',
          );
        }
      }
    }

    // 4. Verify Supabase availability before calling the backend
    if (!isDatabaseReady) {
      debugPrint('SpotRegistrationService: Supabase is not initialized');
      return SpotRegistrationResult.failure(
        message: databaseFailureMessage,
      );
    }

    // 5. Construct Edge Function Payload
    final payload = {
      'event_id': event.id,
      'participant': {
        'name': draft.fullName.trim(),
        'phone': draft.phone.trim(),
        'email': draft.email.trim(),
        'college': draft.college.trim(),
        'department': 'General',
        'year': draft.yearOfStudy,
      },
      'team_members': draft.teamMembers
          .map((m) => {
                'name': m.name.trim(),
                'phone': m.phone.trim(),
                'college': m.college?.trim() ?? draft.college.trim(),
              })
          .toList(),
      'payment': {
        'amount': draft.effectiveAmount,
        'method': 'upi', // Default spot flow verification
        'reference': (draft.transactionRef != null && draft.transactionRef!.trim().isNotEmpty)
            ? draft.transactionRef!.trim()
            : 'UPI-VERIFIED',
        'verified': draft.isPaymentVerified,
      },
    };

    // 6. Invoke Server-Side spot-register Edge Function
    try {
      final FunctionResponse response = await invokeSpotRegisterFunction(payload);
      final dynamic rawData = response.data;

      Map<String, dynamic> data;
      if (rawData is Map) {
        data = Map<String, dynamic>.from(rawData);
      } else if (rawData is String && rawData.isNotEmpty) {
        try {
          data = Map<String, dynamic>.from(jsonDecode(rawData));
        } catch (_) {
          return SpotRegistrationResult.failure(message: databaseFailureMessage);
        }
      } else {
        return SpotRegistrationResult.failure(message: databaseFailureMessage);
      }

      // Check success
      if (data['success'] == true && data['data'] is Map) {
        final resData = Map<String, dynamic>.from(data['data'] as Map);
        final participantCode = resData['participant_code']?.toString() ?? '';
        final participantId = resData['participant_id']?.toString();
        final registrationId = resData['registration_id']?.toString();

        if (participantCode.isEmpty || registrationId == null || participantId == null) {
          return SpotRegistrationResult.failure(message: databaseFailureMessage);
        }

        return SpotRegistrationResult.success(
          participantCode: participantCode,
          message: 'Spot Registration completed successfully!',
          participantId: participantId,
          registrationId: registrationId,
          participant: {
            'id': participantId,
            'participant_code': participantCode,
            'name': draft.fullName.trim(),
            'college': draft.college.trim(),
            'phone': draft.phone.trim(),
            'email': draft.email.trim(),
            'year': draft.yearOfStudy,
          },
          event: event,
          registeredAt: DateTime.now(),
        );
      }

      // If success is false
      final errorMsg = data['error']?.toString() ?? databaseFailureMessage;
      if (data['is_duplicate'] == true || errorMsg.contains('DUPLICATE_REGISTRATION')) {
        return SpotRegistrationResult.duplicate(
          participantCode: '',
          message: '${draft.fullName} is already registered for ${event.name}.',
          event: event,
        );
      }

      return SpotRegistrationResult.failure(message: errorMsg);
    } on FunctionsHttpException catch (fe) {
      debugPrint('SpotRegistrationService: FunctionsHttpException: status=${fe.status}, details=${fe.details}');
      final status = fe.status;
      final details = fe.details;
      String? errorMsg;
      bool isDuplicate = false;

      if (details is Map) {
        errorMsg = details['error']?.toString();
        isDuplicate = details['is_duplicate'] == true;
      } else if (details is String && details.isNotEmpty) {
        try {
          final decoded = jsonDecode(details);
          if (decoded is Map) {
            errorMsg = decoded['error']?.toString();
            isDuplicate = decoded['is_duplicate'] == true;
          }
        } catch (_) {
          errorMsg = details;
        }
      }

      if (status == 409 || isDuplicate || (errorMsg != null && errorMsg.contains('DUPLICATE_REGISTRATION'))) {
        return SpotRegistrationResult.duplicate(
          participantCode: '',
          message: '${draft.fullName} is already registered for ${event.name}.',
          event: event,
        );
      } else if (status == 403) {
        return SpotRegistrationResult.failure(
          message: 'Access Denied: Only Registration Coordinators can register participants.',
        );
      } else if (status == 401) {
        return SpotRegistrationResult.failure(
          message: 'Session expired. Please log in again to continue.',
        );
      } else if (status == 422) {
        return SpotRegistrationResult.failure(
          message: errorMsg ?? 'Spot registration is not available for this event.',
        );
      } else if (status == 400) {
        return SpotRegistrationResult.failure(
          message: errorMsg ?? 'Validation failed. Please verify the entered information.',
        );
      } else {
        return SpotRegistrationResult.failure(
          message: databaseFailureMessage,
        );
      }
    } on SocketException {
      return SpotRegistrationResult.failure(message: 'Network connection error');
    } on TimeoutException {
      return SpotRegistrationResult.failure(message: 'Network connection error');
    } catch (e) {
      debugPrint('SpotRegistrationService: Unexpected error: $e');
      return SpotRegistrationResult.failure(message: databaseFailureMessage);
    }
  }
}
