import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

/// Premium, futuristic dark login screen for authorized SRISHTI 2.7 volunteers.
///
/// Features a deep near-black backdrop, soft cyan/blue radial ambient glow,
/// glass-like translucent input surfaces, and responsive touch controls.
class LoginScreen extends StatefulWidget {
  final SupabaseService? supabaseService;

  const LoginScreen({super.key, this.supabaseService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  late final SupabaseService _supabaseService;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _supabaseService = widget.supabaseService ?? SupabaseService.instance;
    _usernameFocusNode.addListener(_onFocusChange);
    _passwordFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {});
  }

  @override
  void dispose() {
    _usernameFocusNode.removeListener(_onFocusChange);
    _passwordFocusNode.removeListener(_onFocusChange);
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _errorMessage = null);

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _formKey.currentState?.validate();
      setState(() {
        _errorMessage = 'Username and password are required';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      await _supabaseService.signInWithUsername(
        username: username,
        password: password,
      );

      // Auth state changes automatically navigate through AuthGate.
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
      });
    } on FunctionsHttpException catch (e) {
      if (!mounted) return;
      final details = e.details;
      String? errorMsg;
      if (details is Map) {
        errorMsg = details['error']?.toString();
      }
      setState(() {
        if (e.status == 400) {
          _errorMessage = errorMsg ?? 'Username and password are required';
        } else if (e.status == 401) {
          _errorMessage = errorMsg ?? 'Invalid username or password';
        } else if (e.status == 429) {
          _errorMessage = errorMsg ?? 'Too many failed login attempts. Please try again later.';
        } else if (e.status >= 500) {
          _errorMessage = 'Login service unavailable';
        } else {
          _errorMessage = errorMsg ?? 'Invalid username or password';
        }
      });
    } on FunctionsRelayException {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Login service unavailable';
      });
    } on FunctionsFetchException {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Network connection error';
      });
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Network connection error';
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Network connection error';
      });
    } catch (e) {
      if (!mounted) return;
      final str = e.toString().toLowerCase();
      setState(() {
        if (str.contains('network') ||
            str.contains('socket') ||
            str.contains('connection') ||
            str.contains('host lookup') ||
            str.contains('clientexception')) {
          _errorMessage = 'Network connection error';
        } else if (str.contains('unavailable') || str.contains('server')) {
          _errorMessage = 'Login service unavailable';
        } else if (str.contains('password') || str.contains('username')) {
          _errorMessage = 'Invalid username or password';
        } else {
          _errorMessage = 'Login service unavailable';
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: [
          // Main Responsive Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20.0,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top back button if navigation can pop
                        if (Navigator.of(context).canPop())
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0x0FFFFFFF),
                                side: const BorderSide(
                                  color: Color(0x1AFFFFFF),
                                ),
                              ),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          )
                        else
                          const SizedBox(height: 8),

                        const SizedBox(height: 12),

                        // Existing SRISHTI logo - cleanly placed without halo, card, or container
                        Center(
                          child: Hero(
                            tag: 'srishti_logo_hero',
                            child: ScreenBlend(
                              child: Image.asset(
                                'assets/images/srishti_logo.jpg',
                                width: 104,
                                height: 104,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const SizedBox(
                                    width: 104,
                                    height: 104,
                                    child: Center(
                                      child: Icon(
                                        Icons.auto_awesome,
                                        size: 44,
                                        color: AppColors.cyan,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Header: Title & Supporting Text
                        const Text(
                          'SRISHTI 2.7',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        const Text(
                          'Sign in to continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8E9BAE),
                            letterSpacing: -0.1,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Error Banner if present
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF221115),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0x99EF4444),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppColors.error,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFFCA5A5),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // 1. Username Field
                        const Text(
                          'Username',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                        const SizedBox(height: 8),

                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _usernameFocusNode.hasFocus
                                ? const [
                                    BoxShadow(
                                      color: Color(0x3300D2FF),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : [],
                          ),
                          child: TextFormField(
                            controller: _usernameController,
                            focusNode: _usernameFocusNode,
                            enabled: !_isLoading,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            textCapitalization: TextCapitalization.none,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter your username',
                              hintStyle: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF0D1420),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 15,
                              ),
                              prefixIcon: Icon(
                                Icons.person_outline_rounded,
                                size: 20,
                                color: _usernameFocusNode.hasFocus
                                    ? const Color(0xFF00D2FF)
                                    : const Color(0xFF64748B),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF1E293B),
                                  width: 1.0,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF00D2FF),
                                  width: 1.2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.error,
                                  width: 1.0,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.error,
                                  width: 1.2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your username';
                              }
                              return null;
                            },
                          ),
                        ),

                        const SizedBox(height: 18),

                        // 2. Password Field
                        const Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                        const SizedBox(height: 8),

                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _passwordFocusNode.hasFocus
                                ? const [
                                    BoxShadow(
                                      color: Color(0x3300D2FF),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : [],
                          ),
                          child: TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            enabled: !_isLoading,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleLogin(),
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter your password',
                              hintStyle: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF0D1420),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 15,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline_rounded,
                                size: 20,
                                color: _passwordFocusNode.hasFocus
                                    ? const Color(0xFF00D2FF)
                                    : const Color(0xFF64748B),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                  color: _passwordFocusNode.hasFocus
                                      ? const Color(0xFF00D2FF)
                                      : const Color(0xFF64748B),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF1E293B),
                                  width: 1.0,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF00D2FF),
                                  width: 1.2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.error,
                                  width: 1.0,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.error,
                                  width: 1.2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Primary "Sign In" Button
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: _isLoading
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF1E293B),
                                      Color(0xFF334155),
                                    ],
                                  )
                                : const LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Color(0xFF00D7FC), // Vibrant Cyan from reference
                                      Color(0xFF0068FD), // Bright Blue from reference
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _isLoading
                                ? []
                                : const [
                                    BoxShadow(
                                      color: Color(0x590068FD),
                                      blurRadius: 20,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isLoading ? null : _handleLogin,
                              borderRadius: BorderRadius.circular(12),
                              splashColor: const Color(0x33FFFFFF),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Security Message: Shield icon + Authorized message
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.shield_outlined,
                              size: 15,
                              color: Color(0xFF64748B),
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Authorized volunteers and event team only',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders its child using [BlendMode.screen] onto the canvas.
/// This allows images with pure black backgrounds (such as the existing SRISHTI logo)
/// to blend seamlessly and organically into the dark navy background without any card or container.
class ScreenBlend extends SingleChildRenderObjectWidget {
  const ScreenBlend({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderScreenBlend();
}

class _RenderScreenBlend extends RenderProxyBox {
  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.saveLayer(
      offset & size,
      Paint()..blendMode = BlendMode.screen,
    );
    super.paint(context, offset);
    context.canvas.restore();
  }
}

