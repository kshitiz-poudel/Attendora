import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/widgets/background_pattern.dart';
import '../../shared/widgets/glass_card.dart';
import '../../../core/design/app_colors.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _idController = TextEditingController();
  bool _loading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _idController.dispose();
    super.dispose();
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter your email address',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: context.c.warning,
        ),
      );
      return;
    }

    // Basic email validation
    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a valid email address',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: context.c.warning,
        ),
      );
      return;
    }

    final idNumber = _idController.text.trim();
    if (idNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter your ID Number',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: context.c.warning,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // Verify ID and Email match
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw FirebaseAuthException(code: 'user-not-found');
      }

      final userData = query.docs.first.data();
      final storedId =
          userData['idNumber'] as String? ?? userData['rollNumber'] as String?;

      if (storedId != idNumber) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'ID Number does not match the email provided.',
                style: GoogleFonts.outfit(),
              ),
              backgroundColor: context.c.danger,
            ),
          );
        }
        return;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() {
        _loading = false;
        _emailSent = true;
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _loading = false);
      String message = 'An error occurred. Please try again.';

      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email address.';
          break;
        case 'invalid-email':
          message = 'Invalid email address format.';
          break;
        case 'too-many-requests':
          message = 'Too many requests. Please try again later.';
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: GoogleFonts.outfit()),
            backgroundColor: context.c.danger,
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'An unexpected error occurred: $e',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: context.c.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundPattern(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeInUp(
              duration: const Duration(milliseconds: 800),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header with icon and gradient
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              context.c.warning.withValues(alpha: 0.2),
                              context.c.danger.withValues(alpha: 0.2),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    context.c.warning,
                                    context.c.danger,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: context.c.warning
                                        .withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.lock_reset_rounded,
                                color: context.c.textPrimary,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Reset Password',
                              style: GoogleFonts.outfit(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: context.c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _emailSent
                                  ? 'Check your email for reset instructions'
                                  : 'Enter your email to receive a password reset link',
                              style: GoogleFonts.outfit(
                                color: context.c.textSecondary,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      // Form section
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: !_emailSent
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Email field
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Email Address',
                                        style: GoogleFonts.outfit(
                                          color: context.c.textSecondary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        style: GoogleFonts.outfit(
                                          color: context.c.textPrimary,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'you@example.com',
                                          hintStyle: GoogleFonts.outfit(
                                            color: context.c.textPrimary.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                          prefixIcon: Icon(
                                            Icons.email_outlined,
                                            color: context.c.textTertiary,
                                          ),
                                          filled: true,
                                          fillColor: context.c.textPrimary.withValues(
                                            alpha: 0.05,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: context.c.textPrimary.withValues(
                                                alpha: 0.1,
                                              ),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: context.c.textPrimary.withValues(
                                                alpha: 0.1,
                                              ),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: context.c.warning,
                                              width: 2,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 16,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // ID Number field
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ID Number',
                                        style: GoogleFonts.outfit(
                                          color: context.c.textSecondary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _idController,
                                        keyboardType: TextInputType.number,
                                        style: GoogleFonts.outfit(
                                          color: context.c.textPrimary,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'e.g., 1023670091',
                                          hintStyle: GoogleFonts.outfit(
                                            color: context.c.textPrimary.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                          prefixIcon: Icon(
                                            Icons.badge_outlined,
                                            color: context.c.textTertiary,
                                          ),
                                          filled: true,
                                          fillColor: context.c.textPrimary.withValues(
                                            alpha: 0.05,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: context.c.textPrimary.withValues(
                                                alpha: 0.1,
                                              ),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: context.c.textPrimary.withValues(
                                                alpha: 0.1,
                                              ),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: context.c.warning,
                                              width: 2,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 16,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 32),

                                  // Send reset email button
                                  SizedBox(
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _loading
                                          ? null
                                          : _sendPasswordResetEmail,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: context.c.warning,
                                        foregroundColor: context.c.textPrimary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: _loading
                                          ? SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: context.c.textPrimary,
                                              ),
                                            )
                                          : Text(
                                              'Send Reset Link',
                                              style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Back to login link
                                  Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Remember your password? ',
                                          style: GoogleFonts.outfit(
                                            color: context.c.textSecondary,
                                            fontSize: 14,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            context.go('/login');
                                          },
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(0, 0),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: Text(
                                            'Log in',
                                            style: GoogleFonts.outfit(
                                              color: context.c.warning,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Success message
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: context.c.accent
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: context.c.accent
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          color: context.c.accent,
                                          size: 48,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Email Sent!',
                                          style: GoogleFonts.outfit(
                                            color: context.c.accent,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'We\'ve sent a password reset link to:',
                                          style: GoogleFonts.outfit(
                                            color: context.c.textSecondary,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _emailController.text.trim(),
                                          style: GoogleFonts.outfit(
                                            color: context.c.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Please check your inbox and follow the instructions to reset your password.',
                                          style: GoogleFonts.outfit(
                                            color: context.c.textSecondary,
                                            fontSize: 13,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Resend button
                                  OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _emailSent = false;
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: context.c.warning,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                    child: Text(
                                      'Resend Email',
                                      style: GoogleFonts.outfit(
                                        color: context.c.warning,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Back to login button
                                  SizedBox(
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        context.go('/login');
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: context.c.accent,
                                        foregroundColor: context.c.textPrimary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        'Back to Login',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
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
    );
  }
}
