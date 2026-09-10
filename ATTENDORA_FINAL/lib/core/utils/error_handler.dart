import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/design/app_colors.dart';

/// Professional error handling utility
/// Converts technical errors to user-friendly messages
class ErrorHandler {
  /// Get user-friendly error message
  static String getUserFriendlyMessage(dynamic error) {
    if (error == null) return 'An unexpected error occurred';

    final errorString = error.toString().toLowerCase();

    // Firebase Auth errors
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No account found with this email';
        case 'wrong-password':
          return 'Incorrect password';
        case 'email-already-in-use':
          return 'An account already exists with this email';
        case 'weak-password':
          return 'Please choose a stronger password';
        case 'invalid-email':
          return 'Please enter a valid email address';
        case 'user-disabled':
          return 'This account has been disabled';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later';
        case 'network-request-failed':
          return 'Network error. Please check your connection';
        case 'unauthorized-domain':
          return 'Domain not authorized in Firebase Console';
        case 'popup-closed-by-user':
          return 'Sign in cancelled by user';
        default:
          return 'Authentication failed. Please try again';
      }
    }

    // Firestore errors
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You don\'t have permission to perform this action';
        case 'not-found':
          return 'The requested data was not found';
        case 'already-exists':
          return 'This item already exists';
        case 'resource-exhausted':
          return 'Service temporarily unavailable. Please try again later';
        case 'cancelled':
          return 'Operation was cancelled';
        case 'unavailable':
          return 'Service is currently unavailable. Please try again';
        case 'deadline-exceeded':
          return 'Request timed out. Please try again';
        default:
          return 'Unable to complete the request. Please try again';
      }
    }

    // Network errors
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network error. Please check your internet connection';
    }

    // Timeout errors
    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return 'Request timed out. Please try again';
    }

    // File/Storage errors
    if (errorString.contains('storage') || errorString.contains('file')) {
      return 'Unable to access file. Please try again';
    }

    // Permission errors
    if (errorString.contains('permission') || errorString.contains('denied')) {
      return 'Permission denied. Please contact support';
    }

    // Location errors
    if (errorString.contains('location')) {
      return 'Unable to access location. Please enable location services';
    }

    // Generic fallback
    return 'Something went wrong. Please try again';
  }

  /// A short technical tag appended to the friendly message: the Firebase
  /// error code when there is one, otherwise a trimmed form of the raw
  /// error. Previously, passing `customMessage` (every call site in the app
  /// does) discarded the real exception entirely - every failure anywhere
  /// showed the same generic banner with no way to tell a permission
  /// problem from a network timeout from a bad write, for the person
  /// hitting it or for whoever they reported it to.
  static String? _technicalTag(dynamic error) {
    if (error is FirebaseException) return error.code;
    if (error is FirebaseAuthException) return error.code;
    if (error == null) return null;
    var text = error.toString();
    if (text.startsWith('Exception: ')) {
      text = text.substring('Exception: '.length);
    }
    return text.length > 140 ? '${text.substring(0, 140)}…' : text;
  }

  /// Show professional error SnackBar
  static void showErrorSnackBar(
    BuildContext context,
    dynamic error, {
    String? customMessage,
  }) {
    // Always logged, regardless of customMessage, so the real cause is at
    // least in the browser/device console even when the UI shows a
    // simplified message.
    debugPrint('ErrorHandler: $error');

    if (!context.mounted) return;

    final message = customMessage ?? getUserFriendlyMessage(error);
    final tag = _technicalTag(error);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: context.c.textPrimary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: TextStyle(color: context.c.textPrimary, fontSize: 14),
                  ),
                  // Shown whenever we have anything more specific than the
                  // friendly message, so an admin can read the actual
                  // reason (a permission code, a timeout, ...) without
                  // opening devtools.
                  if (tag != null && tag.isNotEmpty && tag != message)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: context.c.textPrimary.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: context.c.danger, // Red
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: context.c.textPrimary,
          onPressed: () {},
        ),
      ),
    );
  }

  /// Show professional success SnackBar
  static void showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: context.c.textPrimary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: context.c.textPrimary, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: context.c.accent, // Green
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show professional info SnackBar
  static void showInfoSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: context.c.textPrimary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: context.c.textPrimary, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: context.c.primary, // Blue
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show professional warning SnackBar
  static void showWarningSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: context.c.textPrimary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: context.c.textPrimary, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: context.c.warning, // Orange
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Build error widget for error states
  static Widget buildErrorWidget(dynamic error, {String? customMessage}) {
    final message = customMessage ?? getUserFriendlyMessage(error);

    // Builder supplies a BuildContext so the error styling can resolve theme
    // tokens, without every caller having to pass one in.
    return Builder(
      builder: (context) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.c.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: context.c.danger,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.c.danger,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      ),
    );
  }
}
