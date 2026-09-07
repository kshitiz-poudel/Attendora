# attendora iPhone / iOS Firebase setup

The Android and web versions already point to Firebase project `attendora-a0fc5`.

An iOS Firebase application must also be registered in that **same project** before an iPhone build can connect to the database. This is required because Firebase issues a platform-specific iOS App ID and `GoogleService-Info.plist`; those values cannot be safely invented in source code.

## One-time setup on your Mac

1. Open Firebase Console and select project **attendora-a0fc5**.
2. Project settings → Your apps → **Add app** → iOS.
3. Use the iOS Bundle ID shown in Xcode for `Runner` (or keep the existing `com.example.attendora` for local development).
4. Download `GoogleService-Info.plist`.
5. Copy it to `ios/Runner/GoogleService-Info.plist`.
6. In Xcode, open `ios/Runner.xcworkspace`, select the Runner target, choose your Apple Development Team and confirm the Bundle Identifier.
7. Connect your iPhone by cable, trust the Mac, and select the iPhone as the run target.

After that, the iPhone app, Android app and Chrome/web app will use the same Firebase Authentication, Firestore and Storage project.

Build with:

```bash
./scripts/build_mobile.sh ios
```

For direct development on the connected iPhone:

```bash
flutter run
```

The app display name is `attendora`.
