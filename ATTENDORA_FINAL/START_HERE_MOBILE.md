# attendora — Mobile release starter

This project is prepared as a Flutter application for Chrome/web, Android and iPhone.

## Same backend

All supported clients are designed to use the Firebase project:

`attendora-a0fc5`

That means a teacher who starts a session on the mobile app can use the same account and share attendance/session data with the Chrome portal through Firebase.

## Fastest Android build

```bash
chmod +x scripts/build_mobile.sh
./scripts/build_mobile.sh android
```

## iPhone

First complete `IOS_FIREBASE_SETUP.md`. Firebase must generate the iOS-specific `GoogleService-Info.plist` for this same Firebase project. Then connect the iPhone to the Mac and run:

```bash
flutter run
```

or create an archive/IPA with:

```bash
./scripts/build_mobile.sh ios
```

## App name

The display name is **attendora**.
