import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Raised when an approval action fails, carrying a message that is safe and
/// useful to show directly to an administrator.
class FacultyApprovalException implements Exception {
  FacultyApprovalException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Single source of truth for approving, rejecting and revoking faculty
/// accounts.
///
/// This previously lived inline in five separate widgets (the approval page,
/// the users page, the dashboard, the notifications page and the notification
/// dropdown), which let the write shapes drift apart. Everything now routes
/// through here so the document always ends up in a consistent state.
class FacultyApprovalService {
  FacultyApprovalService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _firestore.collection('users').doc(uid);

  /// Approves a faculty account.
  ///
  /// [adminInstitutionCode] is used to repair legacy teacher documents that
  /// were created without an `institutionCode`. Those documents otherwise fail
  /// the Firestore rule check (which matches the admin's institution against
  /// the target's) and the approval is rejected with a permission error.
  Future<void> approve({
    required String teacherId,
    String? adminInstitutionCode,
  }) async {
    await _write(
      teacherId: teacherId,
      adminInstitutionCode: adminInstitutionCode,
      action: 'approve',
      fields: {
        'approved': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': _auth.currentUser?.uid,
        'rejectedAt': FieldValue.delete(),
        'rejectionReason': FieldValue.delete(),
      },
    );
  }

  /// Revokes a previously granted approval. The account is kept, but the
  /// teacher is routed back to the pending screen on their next frame.
  Future<void> revoke({
    required String teacherId,
    String? adminInstitutionCode,
    String? reason,
  }) async {
    await _write(
      teacherId: teacherId,
      adminInstitutionCode: adminInstitutionCode,
      action: 'revoke',
      fields: {
        'approved': false,
        'revokedAt': FieldValue.serverTimestamp(),
        'revokedBy': _auth.currentUser?.uid,
        if (reason != null && reason.trim().isNotEmpty)
          'revocationReason': reason.trim(),
      },
    );
  }

  /// Marks an application as rejected. Kept distinct from [revoke] so the
  /// admin UI can tell "never approved" apart from "approval withdrawn".
  Future<void> reject({
    required String teacherId,
    String? adminInstitutionCode,
    String? reason,
  }) async {
    await _write(
      teacherId: teacherId,
      adminInstitutionCode: adminInstitutionCode,
      action: 'reject',
      fields: {
        'approved': false,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': _auth.currentUser?.uid,
        if (reason != null && reason.trim().isNotEmpty)
          'rejectionReason': reason.trim(),
      },
    );
  }

  Future<void> _write({
    required String teacherId,
    required String action,
    required Map<String, dynamic> fields,
    String? adminInstitutionCode,
  }) async {
    if (teacherId.trim().isEmpty) {
      throw FacultyApprovalException('Missing teacher account id.');
    }
    if (_auth.currentUser == null) {
      throw FacultyApprovalException(
        'Your session has expired. Please sign in again.',
      );
    }

    final ref = _userRef(teacherId);

    try {
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        throw FacultyApprovalException(
          'This account no longer exists. It may have already been removed.',
        );
      }

      final data = snapshot.data() ?? const <String, dynamic>{};
      final payload = <String, dynamic>{
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Backfill the tenant code on legacy documents so this and every future
      // admin write passes the institution check in firestore.rules.
      final existingCode = (data['institutionCode'] as String?)?.trim();
      if ((existingCode == null || existingCode.isEmpty) &&
          adminInstitutionCode != null &&
          adminInstitutionCode.trim().isNotEmpty) {
        payload['institutionCode'] = adminInstitutionCode.trim();
      }

      await ref.set(payload, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FacultyApprovalException(_friendlyError(e, action));
    }
  }

  String _friendlyError(FirebaseException e, String action) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to $action this account. This '
            'usually means the teacher belongs to a different institution, or '
            'your admin role has changed. Refresh and try again.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Could not reach the server. Check your connection and retry.';
      case 'not-found':
        return 'This account no longer exists.';
      default:
        return 'Could not $action the account: ${e.message ?? e.code}';
    }
  }
}

final facultyApprovalServiceProvider = Provider<FacultyApprovalService>(
  (ref) => FacultyApprovalService(),
);
