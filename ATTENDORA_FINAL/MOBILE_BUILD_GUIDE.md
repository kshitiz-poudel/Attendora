# attendora mobile build guide

## What is shared

The Android, iPhone and Chrome versions are Flutter clients connected to the same Firebase project: `attendora-a0fc5`. They therefore share:

- Firebase Authentication accounts
- Cloud Firestore users and roles
- attendance sessions
- QR session state
- class groups
- geo-attendance records and uploaded evidence

## Android

```bash
chmod +x scripts/build_mobile.sh
./scripts/build_mobile.sh android
```

APK output:

`build/app/outputs/flutter-apk/app-release.apk`

## iPhone / iOS

Complete `IOS_FIREBASE_SETUP.md` once, because the Firebase Console must generate the iOS-specific configuration file. Then:

```bash
./scripts/build_mobile.sh ios
```

For your own iPhone during development, connect the phone to the Mac and use:

```bash
flutter run
```

## App identity

Display name: **attendora**

The current Android Firebase configuration is preserved so it continues to connect to the existing project. Do not arbitrarily change the Android application ID unless you register the new ID in the same Firebase project and download a matching `google-services.json`.
