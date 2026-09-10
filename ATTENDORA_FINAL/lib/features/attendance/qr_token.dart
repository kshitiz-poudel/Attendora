import 'dart:convert';
import 'dart:math';

/// Encoding and validation for attendance QR payloads.
///
/// The previous scheme encoded `"<sessionId>:<slot>"`, where the slot was just
/// `epochMillis ~/ 5000`. That contains no secret: anyone who learned a
/// session id could regenerate a "current" code indefinitely, from anywhere,
/// and the freshness check ran only on the scanning device — the security
/// rules never saw the token at all.
///
/// The signed scheme carries a high-entropy token that only the presenting
/// teacher's device can produce, kept in a subcollection students cannot read
/// and verified server-side by the Firestore rules on the attendance write.
class QrPayload {
  const QrPayload({
    required this.sessionId,
    required this.slot,
    this.token,
  });

  /// Marks a payload as using the signed scheme, and lets the scanner reject
  /// unrelated QR codes quickly.
  static const String prefix = 'ATTNDRA1';

  /// The token rotates on this cadence.
  static const Duration rotationInterval = Duration(seconds: 5);

  /// Bytes of entropy per rotation. 32 bytes makes guessing infeasible.
  static const int tokenBytes = 32;

  final String sessionId;
  final int slot;

  /// Null for a legacy (unsigned) payload produced by an older build.
  final String? token;

  bool get isSigned => token != null && token!.isNotEmpty;

  /// The wall-clock slot index for [time], shared by both schemes.
  static int slotFor(DateTime time) =>
      time.millisecondsSinceEpoch ~/ rotationInterval.inMilliseconds;

  /// Generates a fresh, cryptographically random rotation token.
  static String generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(tokenBytes, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// `ATTNDRA1:<sessionId>:<slot>:<token>` for signed codes.
  String encode() {
    if (!isSigned) return '$sessionId:$slot';
    return '$prefix:$sessionId:$slot:$token';
  }

  /// Parses either scheme. Returns null when the text is not an Attendora code.
  ///
  /// Session ids are Firestore auto-ids and never contain ':', so splitting is
  /// unambiguous.
  static QrPayload? tryParse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final parts = text.split(':');

    if (parts.first == prefix) {
      if (parts.length != 4) return null;
      final slot = int.tryParse(parts[2]);
      if (slot == null) return null;
      if (parts[1].isEmpty || parts[3].isEmpty) return null;
      return QrPayload(sessionId: parts[1], slot: slot, token: parts[3]);
    }

    // Legacy "<sessionId>:<slot>" form, still accepted during the migration
    // window so already-installed builds keep working.
    if (parts.length == 2) {
      final slot = int.tryParse(parts[1]);
      if (slot == null || parts[0].isEmpty) return null;
      return QrPayload(sessionId: parts[0], slot: slot);
    }

    return null;
  }

  /// Whether the code was displayed recently enough to still be accepted.
  ///
  /// One slot of tolerance either side absorbs clock skew and the moment
  /// between rendering a frame and the scan completing. The authoritative
  /// check is still server-side: the rules only accept the session's current
  /// or immediately previous token.
  bool isFresh({DateTime? now, int toleranceSlots = 1}) {
    final currentSlot = slotFor(now ?? DateTime.now());
    return (slot - currentSlot).abs() <= toleranceSlots;
  }
}
