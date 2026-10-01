import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/supabase_config.dart';

/// Clean service wrapper for Supabase operations across the application.
///
/// Handles initialization, authentication lifecycle, session queries,
/// and provides client access for future modules (QR scanning, participant lookup,
/// arrival check-ins, event attendance).
class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  bool _isInitialized = false;

  /// Whether Supabase has been initialized in this app session.
  bool get isInitialized => _isInitialized;

  /// Initializes the Supabase client using credentials passed via `--dart-define`.
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

  /// The underlying [SupabaseClient] instance.
  SupabaseClient get client {
    if (!_isInitialized) {
      throw StateError(
        'SupabaseService has not been initialized. Call initialize() first.',
      );
    }
    return Supabase.instance.client;
  }

  // ===========================================================================
  // AUTHENTICATION
  // ===========================================================================

  /// Returns the current active [Session], or null if not logged in.
  Session? get currentSession => _isInitialized ? client.auth.currentSession : null;

  /// Returns the currently authenticated [User], or null if not logged in.
  User? get currentUser => _isInitialized ? client.auth.currentUser : null;

  /// Returns the currently authenticated user's email, or null.
  String? get currentUserEmail => currentUser?.email;

  /// Whether there is an active authenticated session.
  bool get isAuthenticated => currentSession != null;

  /// A broadcast stream of [AuthState] changes (sign-in, sign-out, token refresh).
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  /// Signs in a user with their [email] and [password].
  ///
  /// Throws [AuthException] on invalid credentials, unconfirmed email, etc.
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Signs out the current user and clears the local session.
  Future<void> signOut() async {
    await client.auth.signOut();
  }
}
