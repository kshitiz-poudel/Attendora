import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../auth/providers.dart';
import '../../auth/services/biometric_service.dart';
import '../../shared/widgets/background_pattern.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/glass_text_field.dart';
import '../../shared/widgets/error_dialog.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/responsive_utils.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _idNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _idNumberController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showDebugLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final logs = prefs.getStringList('auth_debug_logs') ?? ['No logs found'];

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: context.c.surface,
        child: Container(
          width: double.infinity,
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Debug Logs',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.c.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: context.c.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(color: context.c.border),
              Expanded(
                child: ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      logs[index],
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: context.c.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  await prefs.remove('auth_debug_logs');
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                child: const Text('Clear Logs'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (ModalRoute.of(context)?.isCurrent != true) return;
      if (next.error != null &&
          next.error!.isNotEmpty &&
          next.error != prev?.error) {
        ErrorDialog.showAuthError(context, next.error!).then((_) {
          ref.read(authControllerProvider.notifier).clearError();
        });
      }
      if (prev?.role != next.role || prev?.isAdmin != next.isAdmin) {
        if (next.isAdmin || next.role == UserRole.admin) {
          context.go('/admin');
        } else {
          switch (next.role) {
            case UserRole.teacher:
              context.go('/teacher');
              break;
            case UserRole.student:
              context.go('/student');
              break;
            case UserRole.none:
              break;
            case UserRole.admin:
              context.go('/admin');
              break;
          }
        }
      }
    });

    final state = ref.watch(authControllerProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.error != null &&
          state.error!.isNotEmpty &&
          ModalRoute.of(context)?.isCurrent == true) {
        ErrorDialog.showAuthError(context, state.error!).then((_) {
          ref.read(authControllerProvider.notifier).clearError();
        });
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          BackgroundPattern(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(context.isMobile ? 12 : 24),
                child: FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  context.c.accent
                                      .withValues(alpha: 0.2),
                                  context.c.primary
                                      .withValues(alpha: 0.2),
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        context.c.accent,
                                        context.c.primary,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.c.accent
                                            .withValues(alpha: 0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.login_rounded,
                                    color: context.c.textPrimary,
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                GestureDetector(
                                  onLongPress: _showDebugLogs,
                                  child: Text(
                                    'Attendora',
                                    style: GoogleFonts.outfit(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: context.c.textPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Welcome back! Please login to continue.',
                                  style: GoogleFonts.outfit(
                                    color: context.c.textSecondary,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                          // Form
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                GlassTextField(
                                  controller: _idNumberController,
                                  label: 'ID Number',
                                  hintText: '102367001',
                                  prefixIcon: Icons.badge_outlined,
                                ),
                                const SizedBox(height: 20),
                                GlassTextField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  hintText: '••••••••',
                                  prefixIcon: Icons.lock_outline,
                                  obscureText: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: context.c.textTertiary,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),

                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      context.push('/forgot-password');
                                    },
                                    child: Text(
                                      'Forgot password?',
                                      style: GoogleFonts.outfit(
                                        color: context.c.accent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                SizedBox(
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: state.loading
                                        ? null
                                        : () async {
                                            final idNumber = _idNumberController
                                                .text
                                                .trim();
                                            final password =
                                                _passwordController.text;

                                            if (idNumber.isEmpty) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Please enter your ID Number',
                                                      ),
                                                      backgroundColor:
                                                          context.c.warning,
                                                    ),
                                                  );
                                              return;
                                            }

                                            if (idNumber.length < 3) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'ID Number must be at least 3 characters',
                                                      ),
                                                      backgroundColor:
                                                          context.c.warning,
                                                    ),
                                                  );
                                              return;
                                            }

                                            if (password.isEmpty) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Please enter your password',
                                                      ),
                                                      backgroundColor:
                                                          context.c.warning,
                                                    ),
                                                  );
                                              return;
                                            }

                                            if (password.length < 6) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Password must be at least 6 characters',
                                                      ),
                                                      backgroundColor:
                                                          context.c.warning,
                                                    ),
                                                  );
                                              return;
                                            }
                                            await ref
                                                .read(
                                                  authControllerProvider
                                                      .notifier,
                                                )
                                                .signInWithRollAndPassword(
                                                  rollNumber:
                                                      _idNumberController.text
                                                          .trim(),
                                                  password:
                                                      _passwordController.text,
                                                );
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: context.c.accent,
                                      foregroundColor: context.c.textPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                      shadowColor: context.c.accent
                                          .withValues(alpha: 0.5),
                                    ),
                                    child: state.loading
                                        ? SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: context.c.textPrimary,
                                            ),
                                          )
                                        : Text(
                                            'Log In',
                                            style: GoogleFonts.outfit(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),

                                Consumer(
                                  builder: (context, ref, _) {
                                    return FutureBuilder<bool>(
                                      future: ref
                                          .watch(biometricServiceProvider)
                                          .isAvailable(),
                                      builder: (context, snapshot) {
                                        if (snapshot.data == true) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 16,
                                            ),
                                            child: SizedBox(
                                              height: 56,
                                              child: OutlinedButton.icon(
                                                onPressed: state.loading
                                                    ? null
                                                    : () => ref
                                                          .read(
                                                            authControllerProvider
                                                                .notifier,
                                                          )
                                                          .signInWithBiometrics(),
                                                icon: const Icon(
                                                  Icons.fingerprint_rounded,
                                                ),
                                                label: Text(
                                                  'Login with Biometrics',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: context.c.textPrimary,
                                                  side: BorderSide(
                                                    color: context.c.textPrimary
                                                        .withValues(alpha: 0.3),
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    );
                                  },
                                ),

                                const SizedBox(height: 24),

                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: context.c.warning
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: context.c.warning
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        color: context.c.warning,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Note: Your account will be locked to this device. You cannot log in from another device once logged in.',
                                          style: GoogleFonts.outfit(
                                            color: context.c.warning,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 32),

                                Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Don't have an account? ",
                                        style: GoogleFonts.outfit(
                                          color: context.c.textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          context.push('/signup');
                                        },
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 0),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          'Sign up',
                                          style: GoogleFonts.outfit(
                                            color: context.c.accent,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (state.loading)
            Container(
              color: Colors.black54,
              child: Center(
                child: GlassCard(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: context.c.accent),
                      const SizedBox(height: 24),
                      Text(
                        'Authenticating...',
                        style: GoogleFonts.outfit(
                          color: context.c.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
