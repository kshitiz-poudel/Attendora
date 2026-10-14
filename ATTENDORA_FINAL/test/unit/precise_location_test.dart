import 'package:attendora/core/services/precise_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class _FakeGateway implements LocationAccuracyGateway {
  _FakeGateway({
    this.hasApproximateMode = true,
    required this.initial,
    this.afterRequest = LocationAccuracyStatus.precise,
    this.requestThrows = false,
  });

  @override
  final bool hasApproximateMode;
  final LocationAccuracyStatus initial;
  final LocationAccuracyStatus afterRequest;
  final bool requestThrows;

  int statusCalls = 0;
  final List<String> requestedKeys = [];

  @override
  Future<LocationAccuracyStatus> currentStatus() async {
    statusCalls++;
    return initial;
  }

  @override
  Future<LocationAccuracyStatus> requestTemporaryFullAccuracy(
    String purposeKey,
  ) async {
    requestedKeys.add(purposeKey);
    if (requestThrows) throw Exception('platform error');
    return afterRequest;
  }
}

void main() {
  test('does nothing where there is no approximate mode (Android, web)', () async {
    final g = _FakeGateway(
      hasApproximateMode: false,
      initial: LocationAccuracyStatus.reduced,
    );
    await ensurePreciseLocation(gateway: g);
    expect(g.statusCalls, 0, reason: 'must not even query the platform');
    expect(g.requestedKeys, isEmpty);
  });

  test('already precise: no prompt', () async {
    final g = _FakeGateway(initial: LocationAccuracyStatus.precise);
    await ensurePreciseLocation(gateway: g);
    expect(g.requestedKeys, isEmpty);
  });

  test('approximate, then the person allows precise: succeeds', () async {
    final g = _FakeGateway(
      initial: LocationAccuracyStatus.reduced,
      afterRequest: LocationAccuracyStatus.precise,
    );
    await ensurePreciseLocation(gateway: g);
    expect(g.requestedKeys, [kPreciseLocationPurposeKey]);
  });

  test('approximate and the person declines: tells them where to fix it', () async {
    final g = _FakeGateway(
      initial: LocationAccuracyStatus.reduced,
      afterRequest: LocationAccuracyStatus.reduced,
    );
    expect(
      () => ensurePreciseLocation(gateway: g),
      throwsA(
        isA<PreciseLocationException>().having(
          (e) => e.message,
          'message',
          contains('Precise Location'),
        ),
      ),
    );
  });

  test('a failing platform prompt is treated as declined, not a crash', () async {
    final g = _FakeGateway(
      initial: LocationAccuracyStatus.reduced,
      requestThrows: true,
    );
    expect(
      () => ensurePreciseLocation(gateway: g),
      throwsA(isA<PreciseLocationException>()),
    );
  });

  test('an unknown status is not treated as approximate', () async {
    final g = _FakeGateway(initial: LocationAccuracyStatus.unknown);
    await ensurePreciseLocation(gateway: g);
    expect(g.requestedKeys, isEmpty);
  });

  test('the exception prints as its bare message', () {
    const e = PreciseLocationException('hello');
    expect(e.toString(), 'hello');
  });

  test('purpose key matches the one declared in Info.plist', () {
    expect(kPreciseLocationPurposeKey, 'AttendancePrecise');
  });
}
