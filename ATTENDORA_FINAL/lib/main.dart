import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'core/firestore_init.dart';
import 'core/services/notification_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'core/services/offline_service.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app.dart';
import 'error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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

  // Web and Android use the generated FlutterFire options. iOS uses the
  // native GoogleService-Info.plist generated for the SAME Firebase project.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    await Firebase.initializeApp();
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
      webExperimentalForceLongPolling: true,
      webExperimentalAutoDetectLongPolling: false,
    );
  }

  try {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  } catch (e) {
    debugPrint('Error setting auth persistence: $e');
  }

  final firestoreInit = FirestoreInitService();
  firestoreInit.logRequiredIndexes();

  await NotificationService().initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, 
      systemNavigationBarColor: Color(0xFF0B1121), 
      systemNavigationBarIconBrightness: Brightness.light,
    ),
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
