import 'package:attendora/features/attendance/qr_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QrPayload encoding', () {
    test('signed payload round-trips through encode/parse', () {
      final token = QrPayload.generateToken();
      final payload = QrPayload(sessionId: 'abc123', slot: 42, token: token);

      final parsed = QrPayload.tryParse(payload.encode());

      expect(parsed, isNotNull);
      expect(parsed!.sessionId, 'abc123');
      expect(parsed.slot, 42);
      expect(parsed.token, token);
      expect(parsed.isSigned, isTrue);
    });

    test('signed payload carries the version prefix', () {
      final encoded = QrPayload(
        sessionId: 's1',
        slot: 7,
        token: 'tok',
      ).encode();
      expect(encoded, startsWith('${QrPayload.prefix}:'));
      expect(encoded, 'ATTNDRA1:s1:7:tok');
    });

    test('legacy unsigned codes still parse during the migration window', () {
      final parsed = QrPayload.tryParse('session42:9999');

      expect(parsed, isNotNull);
      expect(parsed!.sessionId, 'session42');
      expect(parsed.slot, 9999);
      expect(parsed.token, isNull);
      expect(parsed.isSigned, isFalse);
    });

    test('unsigned payload encodes back to the legacy form', () {
      expect(QrPayload(sessionId: 's1', slot: 7).encode(), 's1:7');
    });

    test('rejects codes that are not ours', () {
      for (final junk in [
        '',
        '   ',
        'https://example.com',
        'nonsense',
        'ATTNDRA1:onlythree:1',
        'ATTNDRA1:s1:notanumber:tok',
        'ATTNDRA1:s1:1:', // empty token
        'ATTNDRA1::1:tok', // empty session
        's1:notanumber',
      ]) {
        expect(
          QrPayload.tryParse(junk),
          isNull,
          reason: 'should reject "$junk"',
        );
      }
    });
  });

  group('QrPayload token generation', () {
    test('tokens are unique across generations', () {
      final tokens = List.generate(200, (_) => QrPayload.generateToken());
      expect(tokens.toSet().length, 200);
    });

    test('tokens carry the full entropy budget', () {
      final token = QrPayload.generateToken();
      // 32 bytes base64url-encoded without padding.
      expect(token.length, greaterThanOrEqualTo(42));
      expect(token, isNot(contains('=')));
      // base64url alphabet only, so the token survives QR encoding and the
      // ':' delimiter stays unambiguous.
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(token), isTrue);
    });
  });

  group('QrPayload freshness', () {
    test('accepts the current slot', () {
      final now = DateTime.now();
      final payload = QrPayload(
        sessionId: 's',
        slot: QrPayload.slotFor(now),
        token: 'tok',
      );
      expect(payload.isFresh(now: now), isTrue);
    });

    test('tolerates one slot of skew either side', () {
      final now = DateTime.now();
      final slot = QrPayload.slotFor(now);
      for (final offset in [-1, 0, 1]) {
        expect(
          QrPayload(sessionId: 's', slot: slot + offset).isFresh(now: now),
          isTrue,
          reason: 'offset $offset should be accepted',
        );
      }
    });

    test('rejects a code that is two or more rotations old', () {
      final now = DateTime.now();
      final slot = QrPayload.slotFor(now);
      expect(
        QrPayload(sessionId: 's', slot: slot - 2).isFresh(now: now),
        isFalse,
      );
      expect(
        QrPayload(sessionId: 's', slot: slot - 120).isFresh(now: now),
        isFalse,
      );
    });

    test('slot advances once per rotation interval', () {
      final base = DateTime.fromMillisecondsSinceEpoch(1000000000000);
      final next = base.add(QrPayload.rotationInterval);
      expect(QrPayload.slotFor(next) - QrPayload.slotFor(base), 1);
    });
  });
}
