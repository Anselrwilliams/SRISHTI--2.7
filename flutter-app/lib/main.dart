import 'package:flutter/material.dart';
import 'core/constants/supabase_config.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/config_missing_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    try {
      await SupabaseService.instance.initialize();
    } catch (e) {
      debugPrint('Error during Supabase initialization: $e');
    }
  }

  runApp(const SrishtiVolunteerApp());
}

/// Root widget of the SRISHTI 2.7 Volunteer application.
class SrishtiVolunteerApp extends StatelessWidget {
  const SrishtiVolunteerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SRISHTI 2.7 Volunteer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: SupabaseConfig.isConfigured && SupabaseService.instance.isInitialized
          ? const AuthGate()
          : const ConfigMissingScreen(),
    );
  }
}

/// Listens for Supabase authentication state changes and routes
/// between [LoginScreen] and [HomeScreen] reactively.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: SupabaseService.instance.authStateChanges,
      builder: (context, snapshot) {
        // If an active session exists (either from current stream event or stored session)
        final session = snapshot.hasData
            ? snapshot.data?.session
            : SupabaseService.instance.currentSession;

        if (session != null) {
          return const DashboardScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
