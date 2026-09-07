# Mobile enhancement release notes

## Teacher session experience
- Removed the stale hard-coded APK download button from the web portal.
- Added clear Android/iPhone synchronization instructions.
- Improved teacher-facing mobile session wording.
- Added a visible GPS verification reminder before starting a session.
- Preserved the existing QR session, dynamic code and active-session flows.

## Cross-platform readiness
- Android keeps the existing Firebase configuration for `attendora-a0fc5`.
- iOS initialization now uses the native `GoogleService-Info.plist`, which is the correct production setup for a real iPhone build.
- Added build scripts and setup documentation for Android APK/AAB and iOS IPA/archive builds.
- Application display name is `attendora` on Android and iOS.

## Important
An iOS Firebase configuration file must be downloaded from the same Firebase project after registering the iOS app. This cannot be generated correctly without Firebase issuing the iOS App ID.
