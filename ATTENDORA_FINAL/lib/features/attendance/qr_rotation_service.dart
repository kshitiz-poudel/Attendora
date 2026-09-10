import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/logger.dart';
import 'qr_token.dart';

/// Publishes the rotating QR secret for an active session.
///
/// The secret lives at `sessions/{id}/secure/qr`, a path students have no read
/// access to. Firestore rules can still `get()` it when validating an
/// attendance write, so the token is verified server-side without ever being
/// readable by the people it defends against.
///
/// Both the current and the previous token are stored: a student who scans
/// just as the code flips would otherwise submit a token the server has
/// already replaced.
class QrRotationService {
  QrRotationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Timer? _timer;
  String? _sessionId;
  String? _currentToken;
  int _currentSlot = 0;

  /// The token currently encoded into the displayed QR code.
  String? get currentToken => _currentToken;
  int get currentSlot => _currentSlot;

  DocumentReference<Map<String, dynamic>> _secureRef(String sessionId) =>
      _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('secure')
          .doc('qr');

  /// Starts rotating for [sessionId]. Safe to call repeatedly for the same
  /// session; the existing rotation is kept.
  ///
  /// [onRotate] fires after each successful publish so the UI can re-render.
  Future<void> start(
    String sessionId, {
    void Function(String token, int slot)? onRotate,
  }) async {
    if (_sessionId == sessionId && _timer != null) return;
    await stop();

    _sessionId = sessionId;
    await _rotate(onRotate: onRotate);

    _timer = Timer.periodic(
      QrPayload.rotationInterval,
      (_) => _rotate(onRotate: onRotate),
    );
  }

  Future<void> _rotate({void Function(String token, int slot)? onRotate}) async {
    final sessionId = _sessionId;
    if (sessionId == null) return;

    final previous = _currentToken;
    final next = QrPayload.generateToken();
    final slot = QrPayload.slotFor(DateTime.now());

    try {
      await _secureRef(sessionId).set({
        'token': next,
        // Keeping the previous token valid for one interval avoids rejecting a
        // scan that began microseconds before the flip.
        'prevToken': previous,
        'slot': slot,
        'rotatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _currentToken = next;
      _currentSlot = slot;
      onRotate?.call(next, slot);
    } catch (e) {
      // A failed rotation leaves the previous token in place and still valid,
      // so attendance keeps working until connectivity returns.
      appLogger.w('QR token rotation failed for $sessionId: $e');
    }
  }

  /// Stops rotating and clears the published secret so no code stays valid
  /// after the session ends.
  Future<void> stop({bool clearRemote = false}) async {
    _timer?.cancel();
    _timer = null;

    final sessionId = _sessionId;
    _sessionId = null;
    _currentToken = null;
    _currentSlot = 0;

    if (clearRemote && sessionId != null) {
      try {
        await _secureRef(sessionId).delete();
      } catch (e) {
        appLogger.w('Could not clear QR secret for $sessionId: $e');
      }
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
