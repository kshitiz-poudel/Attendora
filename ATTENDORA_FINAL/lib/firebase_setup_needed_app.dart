import 'package:flutter/material.dart';

/// Shown instead of a blank screen when Firebase cannot start on iPhone
/// because the iOS app has not been connected to the Firebase project yet.
///
/// Plain Material widgets only: nothing here may depend on Firebase, fonts
/// downloaded at runtime, or the app theme, since none of those are available
/// when this is the screen being shown.
class FirebaseSetupNeededApp extends StatelessWidget {
  const FirebaseSetupNeededApp({super.key, this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F172A);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.settings_suggest_rounded,
                      color: Color(0xFFF59E0B),
                      size: 44,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'This iPhone build is not connected to Firebase yet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '1. In the Firebase console, add an iOS app to project '
                      'attendora-a0fc5 and download GoogleService-Info.plist.\n\n'
                      '2. On your Mac, run:\n'
                      '   scripts/ios_setup.sh path/to/GoogleService-Info.plist\n\n'
                      '3. Run the app again.\n\n'
                      'Full steps are in IOS_FIREBASE_SETUP.md.',
                      style: TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 18),
                      Text(
                        '$error',
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
