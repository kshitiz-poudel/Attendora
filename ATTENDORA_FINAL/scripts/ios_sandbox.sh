#!/usr/bin/env bash
#
# Gets the iPhone app ready to run in Xcode against the local sandbox (fake
# data on your own Mac - no Firebase account or access needed).
#
#   scripts/ios_sandbox.sh              # for the iPhone Simulator
#   scripts/ios_sandbox.sh --iphone     # for a real iPhone on the same Wi-Fi
#
# It checks your tools, fetches the dependencies, tells Xcode to build the
# sandbox version (Xcode cannot pass build flags itself), and opens the
# project. You still start the sandbox (tool/emulator/start.sh) yourself.
#
# Options:
#   --iphone    point the app at this Mac's Wi-Fi address instead of localhost
#   --no-open   do not open Xcode at the end

set -euo pipefail

IPHONE=0
OPEN=1
for arg in "$@"; do
  case "$arg" in
    --iphone) IPHONE=1 ;;
    --no-open) OPEN=0 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "error: unknown option '$arg' (see --help)" >&2; exit 1 ;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }

[ "$(uname)" = "Darwin" ] || die "this needs a Mac."

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -d "$ROOT/ios/Runner.xcodeproj" ] || die "run this from the Attendora project (the folder with lib/ and ios/)."
cd "$ROOT"

# CocoaPods crashes with an "Unicode Normalization" error under the plain
# "C" locale some terminals start with.
export LANG="${LANG:-en_US.UTF-8}"
case "$LANG" in *UTF-8*|*utf8*) ;; *) export LANG=en_US.UTF-8 ;; esac
export LC_ALL="$LANG"

# --- Xcode -----------------------------------------------------------------
XCODE_OUT="$(xcodebuild -version 2>&1 || true)"
XCODE_MAJOR="$(printf '%s' "$XCODE_OUT" | sed -n 's/^Xcode \([0-9]*\).*/\1/p' | head -1)"
if [ -z "$XCODE_MAJOR" ]; then
  echo "$XCODE_OUT" | head -3 >&2
  die "Xcode is not ready. Install it from the App Store, open it once, then run:
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -license accept
  sudo xcodebuild -runFirstLaunch"
fi

# --- Flutter ---------------------------------------------------------------
command -v flutter >/dev/null || die "Flutter is not installed or not on your PATH. See https://docs.flutter.dev/get-started/install/macos"
FLUTTER_VER="$(flutter --version 2>/dev/null | sed -n 's/^Flutter \([0-9]*\.[0-9]*\).*/\1/p' | head -1)"
F_MAJOR="${FLUTTER_VER%%.*}"; F_MINOR="${FLUTTER_VER##*.}"
# Xcode 27's build tools reject the app that older Flutter versions produce
# ("lipo -verify_arch" fails); Flutter 3.47 fixed that.
if [ "$XCODE_MAJOR" -ge 27 ] 2>/dev/null; then
  if [ "${F_MAJOR:-0}" -lt 3 ] || { [ "${F_MAJOR:-0}" -eq 3 ] && [ "${F_MINOR:-0}" -lt 47 ]; }; then
    die "Xcode $XCODE_MAJOR needs Flutter 3.47 or newer; you have Flutter ${FLUTTER_VER:-unknown}. Run:  flutter upgrade"
  fi
fi

# --- CocoaPods -------------------------------------------------------------
command -v pod >/dev/null || die "CocoaPods is not installed. Run:  brew install cocoapods"

# --- Where the sandbox is --------------------------------------------------
DEFINES=(--dart-define=USE_FIREBASE_EMULATOR=true)
LAN_IP=""
if [ "$IPHONE" = 1 ]; then
  for iface in en0 en1 en2; do
    LAN_IP="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
    [ -n "$LAN_IP" ] && break
  done
  [ -n "$LAN_IP" ] || die "could not find this Mac's Wi-Fi address. Join a Wi-Fi network (the iPhone must be on the same one) and try again."
  DEFINES+=(--dart-define=EMULATOR_HOST="$LAN_IP")
fi

# --- Build setup -----------------------------------------------------------
echo "==> flutter pub get"
flutter pub get
echo "==> pod install"
(cd ios && pod install)
echo "==> telling Xcode to build the sandbox version"
flutter build ios --config-only --no-codesign "${DEFINES[@]}"

echo
echo "Ready (Xcode $XCODE_MAJOR, Flutter ${FLUTTER_VER:-?})."
echo
echo "Next:"
echo "  1. In another terminal:  ./tool/emulator/start.sh$([ "$IPHONE" = 1 ] && echo ' --lan')"
echo "     wait for 'All emulators ready!', then in a third terminal:  ./tool/emulator/seed.sh"
if [ "$IPHONE" = 1 ]; then
  echo "  2. In Xcode: Runner -> Signing & Capabilities -> Team -> your Apple ID,"
  echo "     choose your iPhone at the top, press Run."
  echo "     The app will look for the sandbox at $LAN_IP."
else
  echo "  2. In Xcode choose an iPhone Simulator at the top and press Run."
fi
echo "  3. Sign in: TEACH001 / password123 (teacher) or STU002 / password123 (student)."

if [ "$OPEN" = 1 ]; then
  open ios/Runner.xcworkspace
fi
