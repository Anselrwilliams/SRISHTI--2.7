/// Configuration for the shared SRISHTI Supabase project.
/// The key below is public and is safe for client apps; never put a service_role key here.
class SupabaseConfig {
  SupabaseConfig._();

  static const String supabaseUrl = 'https://sdkadflrxjdhxduwvrsz.supabase.co';
  static const String supabasePublishableKey =
      'sb_publishable_WQB6od9EydJmJ_RmqncFuw_KzBjwg1w';

  static bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabasePublishableKey.trim().isNotEmpty;
}