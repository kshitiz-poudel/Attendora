import 'package:attendora/core/ios_firebase_bootstrap.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const real = FirebaseOptions(
    apiKey: 'AIzaReal',
    appId: '1:623151828674:ios:aaaabbbbccccdddd',
    messagingSenderId: '623151828674',
    projectId: 'attendora-a0fc5',
  );

  group('resolveIosFirebaseOptions', () {
    test('real generated options always win, even in emulator mode', () {
      expect(
        resolveIosFirebaseOptions(configured: real, useEmulator: true),
        same(real),
      );
      expect(
        resolveIosFirebaseOptions(configured: real, useEmulator: false),
        same(real),
      );
    });

    test('no config + emulator mode -> the sandbox placeholder', () {
      expect(
        resolveIosFirebaseOptions(configured: null, useEmulator: true),
        same(kEmulatorOnlyIosOptions),
      );
    });

    test('no config + normal build -> null, so the setup screen is shown', () {
      // The placeholder must never be used outside the sandbox: a production
      // build with no real config has to fail visibly, not talk to a project
      // with a fake key.
      expect(
        resolveIosFirebaseOptions(configured: null, useEmulator: false),
        isNull,
      );
    });
  });

  group('the placeholder satisfies the Firebase iOS SDK checks', () {
    // Mirrors FirebaseCore's FIRApp validateAppID for a version-1 app id:
    // "1:<project number>:ios:<hex>", platform exactly "ios", and the hex part
    // fits in an unsigned 64-bit integer (the hash itself is not checked on
    // the client).
    final parts = kEmulatorOnlyIosOptions.appId.split(':');

    test('has four parts, version 1, platform ios', () {
      expect(parts.length, 4);
      expect(parts[0], '1');
      expect(parts[2], 'ios');
    });

    test('project number is numeric and equals the sender id', () {
      expect(int.tryParse(parts[1]), isNotNull);
      expect(parts[1], kEmulatorOnlyIosOptions.messagingSenderId);
    });

    test('hash part is 1-16 hex digits', () {
      expect(RegExp(r'^[0-9a-fA-F]{1,16}$').hasMatch(parts[3]), isTrue);
    });

    test('an Android or web app id would NOT pass the platform check', () {
      for (final id in [
        '1:623151828674:android:b4c9784d56022fb24e355b',
        '1:623151828674:web:5fe4c614fc8839db4e355b',
      ]) {
        expect(id.split(':')[2], isNot('ios'));
      }
    });

    test('API key satisfies Firebase Installations (the check that crashed)', () {
      // Mirrors +[FIRInstallations validateAPIKey:]: exactly 39 characters,
      // first character 'A', only alphanumerics plus '-' and '_'. Violating
      // this throws an uncaught exception on launch, before any UI appears.
      final key = kEmulatorOnlyIosOptions.apiKey;
      expect(key.length, 39);
      expect(key.startsWith('A'), isTrue);
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(key), isTrue);
    });

    test('has a storage bucket (the sandbox start-up needs one)', () {
      expect(kEmulatorOnlyIosOptions.storageBucket, isNotEmpty);
    });

    test('is clearly not a real key and targets the seeded project', () {
      expect(kEmulatorOnlyIosOptions.apiKey, contains('NOT_A_REAL_KEY'));
      expect(kEmulatorOnlyIosOptions.projectId, 'attendora-a0fc5');
    });
  });
}
