import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/supabase_config.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(
        'Supabase configuration is missing. Pass SUPABASE_URL and '
        'SUPABASE_PUBLISHABLE_KEY via --dart-define when launching the app.',
      );
    }

    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      publishableKey: SupabaseConfig.supabasePublishableKey,
    );

    _isInitialized = true;
  }

  SupabaseClient get client {
    if (!_isInitialized) {
      throw StateError(
        'SupabaseService has not been initialized. Call initialize() first.',
      );
    }

    return Supabase.instance.client;
  }

  Session? get currentSession =>
      _isInitialized ? client.auth.currentSession : null;

  User? get currentUser =>
      _isInitialized ? client.auth.currentUser : null;

  String? get currentUserEmail => currentUser?.email;

  bool get isAuthenticated => currentSession != null;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<Map<String, dynamic>> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty || password.isEmpty) {
      throw const AuthException('Username and password are required');
    }

    final FunctionResponse response;
    try {
      response = await client.functions.invoke(
        'coordinator-login',
        body: {
          'username': cleanUsername,
          'password': password,
        },
      );
    } on FunctionsHttpException catch (e) {
      final details = e.details;
      String? errorMsg;
      if (details is Map) {
        errorMsg = details['error']?.toString();
      } else if (details is String && details.isNotEmpty) {
        try {
          final decoded = jsonDecode(details);
          if (decoded is Map && decoded['error'] != null) {
            errorMsg = decoded['error'].toString();
          }
        } catch (_) {
          errorMsg = details;
        }
      }

      if (e.status == 400) {
        throw AuthException(errorMsg ?? 'Username and password are required');
      } else if (e.status == 401) {
        throw AuthException(errorMsg ?? 'Invalid username or password');
      } else if (e.status == 429) {
        throw AuthException(errorMsg ?? 'Too many failed login attempts. Please try again later.');
      } else if (e.status >= 500) {
        throw const AuthException('Login service unavailable');
      } else {
        throw AuthException(errorMsg ?? 'Invalid username or password');
      }
    } on FunctionsRelayException {
      throw const AuthException('Login service unavailable');
    } on FunctionsFetchException {
      throw const AuthException('Network connection error');
    } on SocketException {
      throw const AuthException('Network connection error');
    } on TimeoutException {
      throw const AuthException('Network connection error');
    } catch (e) {
      if (e is AuthException) rethrow;
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socket') ||
          errStr.contains('network') ||
          errStr.contains('connection') ||
          errStr.contains('host lookup') ||
          errStr.contains('failed host lookup') ||
          errStr.contains('clientexception')) {
        throw const AuthException('Network connection error');
      }
      throw const AuthException('Login service unavailable');
    }

    final data = response.data;

    if (data is! Map) {
      throw const AuthException('Login service unavailable');
    }

    if (data['success'] != true) {
      throw AuthException(
        data['error']?.toString() ?? 'Invalid username or password',
      );
    }

    final sessionData = data['session'];

    if (sessionData is! Map) {
      throw const AuthException('Login service unavailable');
    }

    final refreshToken = sessionData['refresh_token']?.toString();

    if (refreshToken == null || refreshToken.isEmpty) {
      throw const AuthException('Login service unavailable');
    }

    await client.auth.setSession(refreshToken);

    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>?> getCurrentVolunteerProfile() async {
    final user = currentUser;

    if (user == null) {
      return null;
    }

    final response = await client
        .from('volunteers')
        .select('id, name, username, role, status')
        .eq('auth_user_id', user.id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  Future<List<Map<String, dynamic>>> getAssignedEvents(
    String volunteerId,
  ) async {
    // 1. Attempt joined select
    try {
      final joined = await client
          .from('event_staff')
          .select('event_id, events(*)')
          .eq('volunteer_id', volunteerId);

      final List<Map<String, dynamic>> results = [];
      for (final item in joined) {
        if (item['events'] != null && item['events'] is Map) {
          results.add(Map<String, dynamic>.from(item['events'] as Map));
        }
      }
      if (results.isNotEmpty) {
        return results;
      }
    } catch (_) {}

    // 2. Fallback to two-step select
    try {
      final response = await client
          .from('event_staff')
          .select('event_id')
          .eq('volunteer_id', volunteerId);

      final assignments = List<Map<String, dynamic>>.from(response);

      if (assignments.isEmpty) {
        return [];
      }

      final eventIds = assignments
          .map((assignment) => assignment['event_id'].toString())
          .where((id) => id.isNotEmpty)
          .toList();

      if (eventIds.isEmpty) return [];

      // Try by id first
      try {
        final eventsById = await client
            .from('events')
            .select(
              'id, event_code, name, category, date, start_time, '
              'end_time, venue, capacity, status',
            )
            .inFilter('id', eventIds);

        if (eventsById.isNotEmpty) {
          return List<Map<String, dynamic>>.from(eventsById);
        }
      } catch (_) {}

      // Try by event_code if ids were stored as event codes
      try {
        final eventsByCode = await client
            .from('events')
            .select(
              'id, event_code, name, category, date, start_time, '
              'end_time, venue, capacity, status',
            )
            .inFilter('event_code', eventIds);

        if (eventsByCode.isNotEmpty) {
          return List<Map<String, dynamic>>.from(eventsByCode);
        }
      } catch (_) {}

      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }
}
