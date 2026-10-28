import 'dart:async';

import 'package:flutter/foundation.dart';
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
import 'core/navigation/route_observer.dart';
import 'features/scanner/services/qr_camera_manager.dart';
import 'core/widgets/app_update_dialog.dart';
import 'services/app_update_service.dart';

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

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class SrishtiVolunteerApp extends StatelessWidget {
  const SrishtiVolunteerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'SRISHTI 2.7 Volunteer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorObservers: [appRouteObserver],
      home: SrishtiStartupSplash(
        initiallyReady:
            !SupabaseConfig.isConfigured ||
            !SupabaseService.instance.isInitialized,
        destinationBuilder: (onDestinationReady, splashComplete) {
          if (!SupabaseConfig.isConfigured ||
              !SupabaseService.instance.isInitialized) {
            return const ConfigMissingScreen();
          }
          return AuthGate(
            onDestinationReady: onDestinationReady,
            splashComplete: splashComplete,
          );
        },
      ),
    );
  }
}

class SrishtiStartupSplash extends StatefulWidget {
  const SrishtiStartupSplash({
    super.key,
    required this.destinationBuilder,
    this.initiallyReady = false,
  });

  final Widget Function(
    VoidCallback onReady,
    ValueListenable<bool> splashComplete,
  )
  destinationBuilder;
  final bool initiallyReady;

  @override
  State<SrishtiStartupSplash> createState() => _SrishtiStartupSplashState();
}

class _SrishtiStartupSplashState extends State<SrishtiStartupSplash> {
  bool _showSplash = true;
  bool _minimumDurationElapsed = false;
  bool _destinationReady = false;
  Timer? _timer;
  final ValueNotifier<bool> _splashComplete = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _destinationReady = widget.initiallyReady;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timer = Timer(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        _minimumDurationElapsed = true;
        _finishSplashIfReady();
      });
    });
  }

  void _destinationDidBecomeReady() {
    if (!mounted || _destinationReady) return;
    _destinationReady = true;
    _finishSplashIfReady();
  }

  void _finishSplashIfReady() {
    if (!_minimumDurationElapsed || !_destinationReady || !_showSplash) return;
    setState(() => _showSplash = false);
    _splashComplete.value = true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _splashComplete.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: _showSplash,
          child: widget.destinationBuilder(
            _destinationDidBecomeReady,
            _splashComplete,
          ),
        ),
        if (_showSplash)
          Scaffold(
            backgroundColor: Colors.black,
            body: LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/srishti_logo.png',
                        width: constraints.maxWidth * 0.18,
                        height: constraints.maxWidth * 0.18,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(height: constraints.maxWidth * 0.055),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.58,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'SRISHTI',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Akira Expanded',
                              fontSize: 42,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.onDestinationReady,
    this.splashComplete,
    this.authEvents,
    this.startupSession,
    this.profileLoader,
    this.currentEmail,
  });

  final VoidCallback? onDestinationReady;
  final ValueListenable<bool>? splashComplete;

  @visibleForTesting
  final Stream<AuthState>? authEvents;

  @visibleForTesting
  final Session? startupSession;

  @visibleForTesting
  final Future<Map<String, dynamic>?> Function()? profileLoader;

  @visibleForTesting
  final String? currentEmail;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _destinationWasReportedReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.splashComplete == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerUpdateCheck();
      });
    } else if (widget.splashComplete!.value) {
      _triggerUpdateCheck();
    } else {
      widget.splashComplete!.addListener(_onSplashComplete);
    }
  }

  void _onSplashComplete() {
    if (!widget.splashComplete!.value) return;
    widget.splashComplete!.removeListener(_onSplashComplete);
    _triggerUpdateCheck();
  }

  void _reportDestinationReady() {
    if (_destinationWasReportedReady || widget.onDestinationReady == null) {
      return;
    }
    _destinationWasReportedReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDestinationReady?.call();
    });
  }

  @override
  void dispose() {
    widget.splashComplete?.removeListener(_onSplashComplete);
    super.dispose();
  }

  Future<void> _triggerUpdateCheck() async {
    if (AppUpdateService.hasShownDialog || AppUpdateService.isCheckInProgress) {
      return;
    }
    AppUpdateService.isCheckInProgress = true;

    try {
      final update = await AppUpdateService.checkForUpdate();
      if (update == null) {
        AppUpdateService.isCheckInProgress = false;
        return;
      }

      if (AppUpdateService.hasShownDialog) {
        AppUpdateService.isCheckInProgress = false;
        return;
      }

      if (!mounted) {
        AppUpdateService.isCheckInProgress = false;
        return;
      }

      final navContext = appNavigatorKey.currentContext;
      final targetContext = (navContext != null && navContext.mounted)
          ? navContext
          : context;

      if (targetContext.mounted) {
        AppUpdateService.hasShownDialog = true;
        AppUpdateService.isCheckInProgress = false;
        AppUpdateDialog.show(targetContext, update);
      } else {
        AppUpdateService.isCheckInProgress = false;
      }
    } catch (e) {
      debugPrint('[AuthGate] Error checking for updates: $e');
      AppUpdateService.isCheckInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: widget.authEvents ?? SupabaseService.instance.authStateChanges,
      builder: (context, snapshot) {
        final session = snapshot.hasData
            ? snapshot.data?.session
            : widget.authEvents != null
            ? widget.startupSession
            : SupabaseService.instance.currentSession;

        if (session == null) {
          QrCameraManager.instance.stopAndDispose();
          _reportDestinationReady();
          return const LoginScreen();
        }

        return RoleGate(
          onDestinationReady: widget.onDestinationReady,
          profileLoader: widget.profileLoader,
          currentEmail: widget.currentEmail,
        );
      },
    );
  }
}

class RoleGate extends StatefulWidget {
  const RoleGate({
    super.key,
    this.onDestinationReady,
    this.profileLoader,
    this.currentEmail,
  });

  final VoidCallback? onDestinationReady;

  @visibleForTesting
  final Future<Map<String, dynamic>?> Function()? profileLoader;

  @visibleForTesting
  final String? currentEmail;

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  late Future<Map<String, dynamic>?> _profileFuture;
  bool _destinationWasReportedReady = false;
  bool _retryingProfile = false;
  String? _profileErrorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final lookup =
        widget.profileLoader?.call() ??
        SupabaseService.instance.getCurrentVolunteerProfile();
    _profileFuture = lookup.whenComplete(() {
      if (_retryingProfile && mounted) {
        setState(() => _retryingProfile = false);
      }
    });
  }

  void _reportDestinationReady() {
    if (_destinationWasReportedReady || widget.onDestinationReady == null) {
      return;
    }
    _destinationWasReportedReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDestinationReady?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (_retryingProfile) {
            return _ProfileErrorScreen(
              message:
                  _profileErrorMessage ??
                  'Unable to load your volunteer profile.',
              retrying: true,
            );
          }
          return const SizedBox.shrink();
        }

        _reportDestinationReady();

        if (snapshot.hasError) {
          _profileErrorMessage = 'Unable to load your volunteer profile.';
          return _ProfileErrorScreen(
            message: _profileErrorMessage!,
            onRetry: () {
              setState(() {
                _retryingProfile = true;
                _loadProfile();
              });
            },
          );
        }

        final profile = snapshot.data;

        if (profile == null) {
          _profileErrorMessage =
              'No volunteer profile was found for this account.';
          return _ProfileErrorScreen(
            message: _profileErrorMessage!,
            onRetry: () {
              setState(() {
                _retryingProfile = true;
                _loadProfile();
              });
            },
          );
        }

        final volunteer = VolunteerModel.fromMap(
          profile,
          email:
              widget.currentEmail ?? SupabaseService.instance.currentUserEmail,
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
  final bool retrying;

  const _ProfileErrorScreen({
    required this.message,
    this.onRetry,
    this.retrying = false,
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
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null || retrying) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: retrying ? null : onRetry,
                  child: retrying
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Retrying...'),
                          ],
                        )
                      : const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
