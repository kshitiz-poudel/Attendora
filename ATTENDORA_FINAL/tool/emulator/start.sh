#!/usr/bin/env bash
#
# Starts the local Firebase emulators (Auth, Firestore, Storage) with the
# project's real security rules. Leave it running; use seed.sh in another
# terminal to add the fake accounts.
#
#   ./tool/emulator/start.sh          # for the Simulator, web, Android emulator
#   ./tool/emulator/start.sh --lan    # also reachable from a real iPhone/phone
#                                     # on the same Wi-Fi (fake data only)
#
# Needs: Node 20+ and a working JDK 21+.

set -euo pipefail
cd "$(dirname "$0")"

LAN=0
for arg in "$@"; do
  case "$arg" in
    --lan) LAN=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "error: unknown option '$arg' (try --lan)" >&2; exit 1 ;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }

command -v node >/dev/null || die "Node.js is not installed. Install Node 20+ (brew install node)."

# Every probe below is allowed to fail: with `set -e` an unguarded failing
# command would end the script without printing anything, which is the worst
# possible failure for someone following the steps.
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
[ "$NODE_MAJOR" -ge 20 ] || die "Node 20+ is required; you have $(node -v 2>/dev/null || echo 'none')."

# Major version of the Java at $1 ("0" when it will not run at all - for
# example an Intel-only JDK on a Mac that can no longer run Intel programs
# reports "Bad CPU type in executable").
java_major() {
  local out
  out="$("$1" -version 2>&1 || true)"
  printf '%s' "$out" | sed -n 's/.*version "\([0-9]*\).*/\1/p' | head -1
}

JAVA_FOUND_MAJOR=""
JAVA_FOUND_PATH=""

# 1. The Java that is first on PATH, if it works and is new enough.
if command -v java >/dev/null 2>&1; then
  JAVA_FOUND_PATH="$(command -v java)"
  JAVA_FOUND_MAJOR="$(java_major java)"
fi

# 2. Otherwise, on a Mac, ask the system for a JDK 21 or newer. This finds a
#    good JDK even when an older or broken one comes first on PATH.
if [ "${JAVA_FOUND_MAJOR:-0}" -lt 21 ] 2>/dev/null || [ -z "$JAVA_FOUND_MAJOR" ]; then
  JAVA_HOME_TOOL="${JAVA_HOME_TOOL:-/usr/libexec/java_home}"
  if [ -x "$JAVA_HOME_TOOL" ]; then
    CANDIDATE="$("$JAVA_HOME_TOOL" -v 21+ 2>/dev/null || true)"
    if [ -n "$CANDIDATE" ] && [ -x "$CANDIDATE/bin/java" ]; then
      M="$(java_major "$CANDIDATE/bin/java")"
      if [ "${M:-0}" -ge 21 ] 2>/dev/null; then
        export JAVA_HOME="$CANDIDATE"
        export PATH="$CANDIDATE/bin:$PATH"
        JAVA_FOUND_MAJOR="$M"
        JAVA_FOUND_PATH="$CANDIDATE/bin/java"
        echo "Using Java $M from $CANDIDATE"
      fi
    fi
  fi
fi

if [ -z "$JAVA_FOUND_MAJOR" ] || [ "$JAVA_FOUND_MAJOR" -lt 21 ]; then
  if [ -z "$JAVA_FOUND_PATH" ]; then
    die "Java is not installed. Install JDK 21+ (brew install openjdk@21), then follow the PATH note brew prints."
  elif [ -z "$JAVA_FOUND_MAJOR" ]; then
    die "the Java at $JAVA_FOUND_PATH does not run on this Mac, and no JDK 21+ was found. Install one: brew install openjdk@21"
  else
    die "JDK 21+ is required; the Java at $JAVA_FOUND_PATH is version $JAVA_FOUND_MAJOR. Install a newer one: brew install openjdk@21"
  fi
fi

# The Firebase CLI refuses rules files that live outside this folder, so the
# emulators run against copies of the real ones, refreshed on every start.
cp ../../firestore.rules ./firestore.rules
cp ../../storage.rules ./storage.rules

CONFIG=firebase.json
if [ "$LAN" = 1 ]; then
  # The emulators normally listen on this Mac only. A phone needs them on the
  # network, so write a copy of the config that listens on every interface.
  node -e '
    const c = JSON.parse(require("fs").readFileSync("firebase.json", "utf8"));
    for (const k of ["auth", "firestore", "storage"]) c.emulators[k].host = "0.0.0.0";
    require("fs").writeFileSync("firebase.lan.json", JSON.stringify(c, null, 2));
  '
  CONFIG=firebase.lan.json

  # This Mac'"'"'s address on the Wi-Fi (Ethernet is en0 on some Macs, Wi-Fi en0/en1).
  LAN_IP=""
  for iface in en0 en1 en2; do
    LAN_IP="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
    [ -n "$LAN_IP" ] && break
  done
  [ -n "$LAN_IP" ] || die "could not find this Mac's Wi-Fi address. Join a Wi-Fi network, or run 'ipconfig getifaddr en0' yourself."

  echo "----------------------------------------------------------------------"
  echo "LAN mode: the emulators are open to everyone on this network."
  echo "They only hold fake data, but use a network you trust."
  echo
  echo "On the iPhone (same Wi-Fi as this Mac), run the app with:"
  echo "  flutter run --release -d <your iPhone> \\"
  echo "    --dart-define=USE_FIREBASE_EMULATOR=true \\"
  echo "    --dart-define=EMULATOR_HOST=$LAN_IP"
  echo "----------------------------------------------------------------------"
fi

# Used by the test that checks the messages above; never set it normally.
if [ -n "${START_DRY_RUN:-}" ]; then
  echo "OK: would start the emulators with Java $JAVA_FOUND_MAJOR ($JAVA_FOUND_PATH)"
  exit 0
fi

echo "Starting the emulators. Leave this window open. Ctrl+C stops them."
exec npx --yes firebase-tools emulators:start --config "$CONFIG" --only auth,firestore,storage --project attendora-local
