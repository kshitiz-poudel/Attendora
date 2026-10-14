import 'package:firebase_core/firebase_core.dart';

/// Firebase configuration for the iPhone app.
///
/// This is a placeholder until you add the iOS app in the Firebase console and
/// run `scripts/ios_setup.sh path/to/GoogleService-Info.plist`, which
/// overwrites this file with the real values from that plist. (These are client
/// identifiers, not secrets - the same kind of values already in
/// firebase_options.dart for web and Android.)
///
/// While [iosFirebaseOptions] is null the app falls back to a native
/// GoogleService-Info.plist added through Xcode, and if that is missing too it
/// shows a setup screen instead of a blank page.
const FirebaseOptions? iosFirebaseOptions = null;

/// OAuth client id for Google Sign-In on iOS (CLIENT_ID in the plist).
const String? iosGoogleClientId = null;
