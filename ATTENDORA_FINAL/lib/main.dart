import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'core/ios_firebase_bootstrap.dart';
import 'firebase_options_ios.dart';
import 'firebase_setup_needed_app.dart';
import 'core/firestore_init.dart';
import 'core/services/notification_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'core/services/offline_service.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app.dart';
import 'error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _bootstrap();
  } catch (e, st) {
    debugPrint('BOOTSTRAP_FAILURE: $e\n$st');
    rethrow;
  }
}

Future<void> _bootstrap() async {
  
  // Set up global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (!kDebugMode) {
      runApp(ErrorApp(details: details));
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Caught async error: $error');
    debugPrint(stack.toString());
    return true;
  };

  const useEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

  // Web and Android use the generated FlutterFire options. iPhone uses the
  // options written by scripts/ios_setup.sh from GoogleService-Info.plist; if
  // there are none it tries a plist added through Xcode, and if that is missing
  // too it shows a setup screen. Without this, an unconfigured iPhone build
  // would fail here and leave a blank screen with no explanation.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    try {
      // In emulator mode with no real iOS config this falls back to a
      // placeholder, so the project can be run in Xcode against fake data
      // without access to the real Firebase project.
      await Firebase.initializeApp(
        options: resolveIosFirebaseOptions(
          configured: iosFirebaseOptions,
          useEmulator: useEmulator,
        ),
      );
    } catch (e) {
      debugPrint('Firebase is not configured for iOS: $e');
      runApp(FirebaseSetupNeededApp(error: e));
      return;
    }
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // Point at local emulators when explicitly asked
  // (--dart-define=USE_FIREBASE_EMULATOR=true). Off by default, so normal
  // builds are completely unaffected and this can never accidentally target
  // an emulator in production.
  if (useEmulator) {
    // Where the emulators are. The default works for the web, the iOS
    // Simulator and the Android emulator. A real phone cannot reach
    // "localhost" on the computer: pass the computer's address with
    // --dart-define=EMULATOR_HOST=192.168.x.x (see tool/emulator/README.md).
    const hostOverride = String.fromEnvironment('EMULATOR_HOST');
    final emulatorHost = hostOverride.isNotEmpty
        ? hostOverride
        : (kIsWeb || defaultTargetPlatform != TargetPlatform.android
              ? 'localhost'
              : '10.0.2.2');
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8180);
    await FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
    debugPrint('🧪 Connected to local Firebase emulators at $emulatorHost');
  }

  if (kIsWeb) {
    // Forcing long-polling was previously always-on. Firestore's automatic
    // transport negotiation (the default) uses a streaming connection when
    // available, which is materially faster for an app with this many
    // concurrent listeners (every dashboard screen watches several
    // StreamProviders at once) - forcing long-polling made every listener
    // update pay a full HTTP round trip. Only force it when explicitly
    // requested for a network that is known to break the streaming
    // transport (e.g. some corporate proxies).
    const forceLongPolling = bool.fromEnvironment('FORCE_LONG_POLLING');
    FirebaseFirestore.instance.settings = Settings(
      // Deliberately disabled, not merely inherited: enabling this earlier
      // in the session (while wiring in the emulator flag, which is
      // unrelated) reproduced a real crash - "FIRESTORE INTERNAL ASSERTION
      // FAILED: Unexpected state (ID: b815)" - on a genuine write against
      // production. That assertion is a known Firestore Web SDK failure
      // mode in its IndexedDB persistence layer (commonly from multiple
      // tabs of the same origin sharing one persisted cache). Persistence
      // was off before this session and stays off.
      persistenceEnabled: false,
      webExperimentalForceLongPolling: forceLongPolling,
      webExperimentalAutoDetectLongPolling: !forceLongPolling,
    );
  }

  try {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  } catch (e) {
    debugPrint('Error setting auth persistence: $e');
  }

  final firestoreInit = FirestoreInitService();
  firestoreInit.logRequiredIndexes();

  // Not awaited: on a fresh install iOS shows a permission pop-up here, and
  // waiting for the answer left the app a blank white screen until it was
  // tapped (it looked broken). The pop-up now appears over the login screen.
  unawaited(NotificationService().initialize());

  // Only the transparent status bar is set here. Brightness and the system
  // navigation bar colour depend on the active theme, so they are applied in
  // AttendoraApp where the resolved ThemeMode is known - pinning them to the
  // dark palette here left light mode with an unreadable system bar.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        offlineServiceProvider.overrideWithValue(OfflineService(prefs)),
      ],
      child: const AttendoraApp(),
    ),
  );
}
