import 'package:flutter/foundation.dart';

import '../../attendance/qr_token.dart';

@immutable
class ActiveSession {
  const ActiveSession({
    required this.sessionId,
    required this.expiresAt,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.qrToken,
    this.qrSlot = 0,
  });

  final String sessionId;
  final DateTime expiresAt;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  /// The rotating secret currently published for this session. Produced by
  /// [QrRotationService] and verified server-side on the attendance write.
  final String? qrToken;
  final int qrSlot;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// True once a rotating secret has been published, meaning the QR code being
  /// displayed cannot be reconstructed by anyone who merely knows the session
  /// id.
  bool get isSecured => qrToken != null && qrToken!.isNotEmpty;

  /// The payload to encode into the QR image.
  ///
  /// Falls back to the legacy unsigned form only until the first rotation
  /// lands, so the screen is never blank while the first write is in flight.
  String get currentDynamicToken => QrPayload(
    sessionId: sessionId,
    slot: isSecured ? qrSlot : QrPayload.slotFor(DateTime.now()),
    token: qrToken,
  ).encode();

  ActiveSession copyWith({String? qrToken, int? qrSlot}) => ActiveSession(
    sessionId: sessionId,
    expiresAt: expiresAt,
    latitude: latitude,
    longitude: longitude,
    radiusMeters: radiusMeters,
    qrToken: qrToken ?? this.qrToken,
    qrSlot: qrSlot ?? this.qrSlot,
  );
}
