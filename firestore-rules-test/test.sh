#!/usr/bin/env bash
# Starts the Firestore emulator, runs run-tests.mjs against it, shuts the
# emulator down again. This exists instead of `firebase emulators:exec`
# because the standalone firebase CLI binary runs its exec script under a
# bundled Node 18 + minimal shell, which can't load ESM and breaks npm —
# backgrounding the emulator and using the system Node avoids all of that.
set -euo pipefail
cd "$(dirname "$0")"

# The emulator needs the repo's firebase.json for context; rules themselves
# are loaded explicitly by run-tests.mjs so edits to ../firestore.rules are
# always what get tested.
(cd .. && firebase emulators:start --only firestore --project greyvetro-rules-test) &
EMULATOR_PID=$!
cleanup() {
  kill "$EMULATOR_PID" 2>/dev/null || true
  # The CLI's java child sometimes outlives it — make sure the port is freed.
  lsof -ti:8080 | xargs kill 2>/dev/null || true
}
trap cleanup EXIT

for _ in $(seq 1 60); do
  curl -s http://127.0.0.1:8080 >/dev/null 2>&1 && break
  sleep 1
done

FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node run-tests.mjs
