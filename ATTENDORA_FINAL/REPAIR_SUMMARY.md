# Attendora repair summary

This replacement package contains the repaired Attendora Flutter project, a verified Android release APK, and a Firebase Hosting web build containing the same APK at `build/web/downloads/attendora.apk`.

## Repairs included

- Fixed the Android download button to use the hosted relative path `downloads/attendora.apk` instead of a stale hard-coded Drive URL.
- Prevented the student QR flow from showing “Present” before Firestore confirms the write.
- Added friendlier handling for unexpected QR, location, and Firestore failures.
- Added validation for invalid campus coordinates, radius, evidence photo, distance, and location accuracy.
- Made faculty check-in/check-out writes atomic with a Firestore transaction, preventing duplicate daily records during rapid retries.
- Hardened Firestore attendance rules against forged student IDs, session IDs, statuses, and out-of-radius distance values.
- Protected faculty attendance identity, institution, and date fields from ordinary-user mutation.
- Added a build workflow that produces the APK and copies it into the Firebase Hosting output.
- Applied safe Dart lint fixes; the Flutter analyzer reports no issues.

## Verified results

- `flutter analyze`: **No issues found**.
- `flutter test`: **All tests passed**.
- Android release APK: `build/releases/attendora-latest.apk`.
- Website APK download: `build/web/downloads/attendora.apk`.

## Replace and deploy

Copy the project contents into the local Attendora repository, then from the Flutter project root run:

```bash
flutter pub get
./scripts/build_mobile.sh android
firebase deploy --only hosting,firestore:rules
```

The Firebase command requires the Firebase CLI to be installed and authenticated to the existing Attendora project. Deploying the rules is important because the rules file is only a local source file until deployed.

## Important release notes

The included APK is a verified installable release build, but the project still uses the Android debug signing key. Configure a private release keystore before Play Store distribution; never commit the keystore or passwords. iOS production builds still require the Firebase-generated `ios/Runner/GoogleService-Info.plist` for the registered iOS app.

Do not commit `build/`, `.dart_tool/`, `android/local.properties`, or private signing files to Git. The included generated build is present in this ZIP only so the hosting download can be used immediately.
