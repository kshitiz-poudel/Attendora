#!/usr/bin/env bash
#
# Adds the fake accounts and a small class to the running emulators.
# Run start.sh first, in another terminal.
#
#   ./tool/emulator/seed.sh

set -euo pipefail
cd "$(dirname "$0")"

die() { echo "error: $*" >&2; exit 1; }
command -v node >/dev/null || die "Node.js is not installed."

# The emulators must already be up, or seeding would just hang.
if ! curl -s -o /dev/null --max-time 3 http://127.0.0.1:8180/; then
  die "the emulators are not running. Start them first:  ./tool/emulator/start.sh"
fi

if [ ! -d node_modules/firebase-admin ]; then
  echo "Installing firebase-admin (one time)..."
  [ -f package.json ] || echo '{"private": true}' > package.json
  npm install --no-audit --no-fund firebase-admin
fi

node seed.mjs
