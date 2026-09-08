#!/usr/bin/env bash
set -euo pipefail
PLATFORM="${1:-android}"
flutter clean
flutter pub get
case "$PLATFORM" in
  android)
    flutter build apk --release
    mkdir -p build/releases
    cp build/app/outputs/flutter-apk/app-release.apk build/releases/attendora-latest.apk
    flutter build web --release
    mkdir -p build/web/downloads
    cp build/releases/attendora-latest.apk build/web/downloads/attendora.apk
    echo "Android APK: build/releases/attendora-latest.apk"
    echo "Web download copy: build/web/downloads/attendora.apk"
    ;;
  android-appbundle)
    flutter build appbundle --release
    echo "Android App Bundle: build/app/outputs/bundle/release/app-release.aab"
    ;;
  ios)
    if [ ! -f "ios/Runner/GoogleService-Info.plist" ]; then
      echo "Missing ios/Runner/GoogleService-Info.plist" >&2
      echo "Follow IOS_FIREBASE_SETUP.md first, then run this command again." >&2
      exit 1
    fi
    flutter build ipa --release
    echo "iOS archive/export created under build/ios/archive or build/ios/ipa"
    ;;
  *)
    echo "Usage: ./scripts/build_mobile.sh [android|android-appbundle|ios]" >&2
    exit 2
    ;;
esac
