import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_config.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/config_missing_screen.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/auth/models/volunteer_model.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/event_staff/screens/event_staff_dashboard_screen.dart';
import 'features/registration/screens/registration_dashboard_screen.dart';
import 'features/scanner/services/qr_camera_manager.dart';

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

class SrishtiVolunteerApp extends StatelessWidget {
  const SrishtiVolunteerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SRISHTI 2.7 Volunteer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: SupabaseConfig.isConfigured &&
              SupabaseService.instance.isInitialized
          ? const AuthGate()
          : const ConfigMissingScreen(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: SupabaseService.instance.authStateChanges,
      builder: (context, snapshot) {
        final session = snapshot.hasData
            ? snapshot.data?.session
            : SupabaseService.instance.currentSession;

        if (session == null) {
          QrCameraManager.instance.stopAndDispose();
          return const LoginScreen();
        }

        return const RoleGate();
      },
    );
  }
}

class RoleGate extends StatefulWidget {
  const RoleGate({super.key});

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  late Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    _profileFuture =
        SupabaseService.instance.getCurrentVolunteerProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return _ProfileErrorScreen(
            message: 'Unable to load your volunteer profile.',
            onRetry: () {
              setState(() {
                _loadProfile();
              });
            },
          );
        }

        final profile = snapshot.data;

        if (profile == null) {
          return _ProfileErrorScreen(
            message: 'No volunteer profile was found for this account.',
            onRetry: () {
              setState(() {
                _loadProfile();
              });
            },
          );
        }

        final volunteer = VolunteerModel.fromMap(
          profile,
          email: SupabaseService.instance.currentUserEmail,
        );

        if (volunteer.status != 'active') {
          return const _ProfileErrorScreen(
            message: 'Your volunteer account is not active.',
          );
        }

        switch (volunteer.role) {
          case 'admin':
            return AdminDashboardScreen(volunteer: volunteer);

          case 'registration':
            return RegistrationDashboardScreen(volunteer: volunteer);

          case 'event_staff':
            return EventStaffDashboardScreen(volunteer: volunteer);

          case 'volunteer':
            return DashboardScreen(volunteer: volunteer);

          default:
            return _ProfileErrorScreen(
              message: 'Unknown volunteer role: ${volunteer.role}',
            );
        }
      },
    );
  }
}

class _ProfileErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ProfileErrorScreen({
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
