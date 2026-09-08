# Attendora APK download setup

The Android download button uses the relative URL `downloads/attendora.apk`. The mobile build script creates this file in the Firebase Hosting output.

## Build

From the Flutter project root:

```bash
flutter pub get
./scripts/build_mobile.sh android
```

The APK is created at `build/releases/attendora-latest.apk`, and a copy is placed at `build/web/downloads/attendora.apk`.

## Deploy

Deploy the web output with Firebase Hosting after the script completes:

```bash
firebase deploy --only hosting
```

The website download button then serves the same APK produced by the build. The current Android Gradle file uses the debug signing key for local/release builds. Before public Play Store distribution, configure a private release keystore and replace that signing configuration; never commit the keystore or passwords.
