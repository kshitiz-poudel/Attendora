# Local sandbox (Firebase emulators + fake accounts)

Run the whole app against local emulators with fake data, so you can click
through teacher, student and admin flows without touching production. It works
on the web, the iPhone Simulator, a real iPhone and Android.

You need **Node 20+** and **JDK 21+** (`brew install node openjdk@21`; Homebrew
prints a line about adding Java to your PATH - do what it says, then open a new
terminal). All commands below are run from the `ATTENDORA_FINAL` folder.

## 1. Start the emulators  (terminal 1)

```bash
./tool/emulator/start.sh
```

The first run downloads the Firebase tools (a minute or two). Wait for
`All emulators ready!`, then **leave this window open**. Ctrl+C stops them.

## 2. Add the fake accounts  (terminal 2)

```bash
./tool/emulator/seed.sh
```

This creates one teacher and three students (100%, 50% and 0% attendance in one
subject). It is safe to run again. Everything is wiped when you stop the
emulators, so run it again after restarting them.

| Sign in with ID | Password | Who |
| --- | --- | --- |
| `TEACH001` | `password123` | Teacher |
| `STU001` | `password123` | Student at 100% |
| `STU002` | `password123` | Student at 50% - the one to detain |
| `STU003` | `password123` | Student at 0% |

## 3. Run the app against them  (terminal 3)

```bash
flutter pub get
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true
```

For the iPhone Simulator or a real iPhone see `IOS_FIREBASE_SETUP.md` (Option A).
A phone on your Wi-Fi needs the emulators reachable from the network:
`./tool/emulator/start.sh --lan` does that and prints the address to use.

## Warnings you can ignore

- `Unexpected rules runtime error: WARNING: A terminally deprecated method in
  sun.misc.Unsafe` (newer Java versions complaining about the emulator's code).
- `MetadataLookupWarning ... ETIMEDOUT / ENOTFOUND` when seeding (the Admin SDK
  looking for a Google Cloud server that is not there on your laptop).

Neither stops anything from working. `All emulators ready!` and
`seeded: TEACH001 ...` are the lines that matter.

## Notes

- `--dart-define=USE_FIREBASE_EMULATOR=true` is off by default, so normal and
  production builds never connect to an emulator. An orange **SANDBOX** ribbon
  shows in the corner of the app when it is on.
- The app looks for the emulators on `localhost` (on `10.0.2.2` for the Android
  emulator). A real phone cannot reach that: pass your computer's address with
  `--dart-define=EMULATOR_HOST=192.168.x.x`, and make the emulators listen on
  the network by adding `"host": "0.0.0.0"` to each entry in `firebase.json`
  (this exposes them to your Wi-Fi, so use a network you trust).
- `start.sh` copies the project's real `firestore.rules` and `storage.rules`
  into this folder each time (the Firebase CLI refuses rules files outside the
  project folder), so you always test against the current rules.
- Seeding uses the Admin SDK, which bypasses security rules, so the real rules
  stay loaded while you test as a normal user.
- The Auth emulator is single-project (`attendora-local`); Firestore is keyed
  by the app's real project id, which `seed.mjs` already accounts for.
- Student accounts are locked to the first device they sign in from. If you
  clear browser storage and a student can no longer sign in, use the teacher
  account, or restart the emulators and seed again.
