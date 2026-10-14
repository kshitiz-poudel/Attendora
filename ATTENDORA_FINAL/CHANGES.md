# Attendora — fixes and features

Work delivered against the requested items, what needs deploying, and what is
still open.

---

## Deploy checklist — read before shipping

Two changes are **not** live until you deploy them, and the app depends on
both:

```bash
firebase deploy --only firestore:rules,storage
```

1. **`firestore.rules`** — closes several privilege-escalation holes and adds
   server-side QR verification. Until deployed, any signed-in user can still
   set `approved: true` / `admin: true` on their own account.
2. **`storage.rules`** — restricts selfie uploads to the faculty member the
   photo is about.

Then rebuild and publish the web + Android artefacts:

```bash
flutter pub get
./scripts/build_mobile.sh android      # APK -> build/web/downloads/attendora.apk
firebase deploy --only hosting
```

---

## 1. Admin cannot approve faculty — fixed

Four separate defects, all of which had to go:

- **The approval never reached the running session.** `AuthController`'s live
  user-document listener watched only `forceLogoutAt` and role changes, so
  flipping `approved` had no effect until the teacher fully signed out and
  back in. It now syncs approval, institution and group changes into the live
  session, and `/teacher/pending` redirects out the moment approval lands.
- **Admins were being signed out.** The role-change guard compared the raw
  Firestore role against the *effective* (admin-flag-aware) role, so any admin
  whose document still said `role: 'teacher'` was force-signed-out on every
  snapshot. It now compares like with like.
- **Legacy accounts were unapprovable.** The rules matched the admin's
  institution against the target's, so a teacher document written without an
  `institutionCode` produced a hard `permission-denied`.
  `FacultyApprovalService` now backfills the code, and the rules permit that
  specific claim.
- **Rejection failed for everyone but the super admin.** Rejecting deletes the
  account, but `allow delete` was `isSuperAdmin()` only.

Approval logic had been copy-pasted into five widgets with drifting write
shapes; everything now routes through
`lib/features/dashboard/services/faculty_approval_service.dart`. The pending
list also used `approved == false`, which hid legacy documents that have no
such field, while the dashboard badge used `!= true` — so the two disagreed.

### Security holes found and closed along the way

These were not in the brief, but they undermine the approval feature itself:

| Hole | Was | Now |
| --- | --- | --- |
| Self-approval | any user could write `approved: true` on their own document | privileged fields are admin-only |
| Self-promotion | `admin: true` / `isSuperAdmin: true` writable by the user | blocked on both create and update |
| Signup escalation | `allow create` let anyone self-create as an admin | unprivileged self-signup only |
| Device lock | students could clear their own `registeredDeviceId` | bindable once; changes are an admin action |
| Roll-number lock | `id_index` was `write: if isAuthenticated()`, enforcing none of the uniqueness it documented | create-once, owner-release |
| Selfie privacy | `faculty_geo_attendance` readable by every authenticated user, students included | faculty member and their institution admins only |

## 2. Lab groups — extended

`ClassGroup` already carried a `type` of `Lecture` or `Lab`, and the create
dialog could set it, but the detail dialog could only *list* members — there
was no way to assign anyone. Added `GroupMemberManager` (search, assign,
remove, members-first ordering) for both students and faculty.

The important part is data integrity: `assignStudent` only updated the group's
`studentUids` array, while subject resolution reads the student's own
`lectureGroup` / `labGroup` field. An assigned student therefore appeared in
the group but saw none of its subjects. Both sides are now written in one
batch, and removal clears the pointer only if it still refers to that group.

## 3. UI rendering before data arrives — fixed

Twenty-two call sites did `ref.watch(dep).asData?.value ?? []`, which turns
"still loading" into "empty". Providers built that way emitted a complete,
plausible-looking result computed from nothing — every subject at 0%, empty
tables, zeroed counters — and then snapped to the real values.

- Added `AsyncValue` combinators (`lib/core/utils/async_combine.dart`) so a
  derived provider stays loading until *every* input resolves and surfaces the
  first error.
- Converted the student subject/stats and attendance-history providers, and
  fixed the pass-through providers that were collapsing a loading dependency
  into an empty list.
- Added `AsyncSection` plus content-shaped shimmer skeletons for consistent
  loading and error states with a retry affordance.

## 4. Mobile app distribution

The APK download existed but was buried inside the QR generate and scan pages.
`AppDownloadCard` now appears at the top of both the Teacher and Student
portals, renders only on the web build, and reports a clear message if the APK
has not been published yet.

Mobile layout fixes found by testing at 375px: the auth pages stacked 24 + 32px
of fixed padding, clipping the institution dropdown and the Google button.

## 5. Dynamic QR — now actually secure

The old "dynamic" code was `"<sessionId>:<slot>"` where
`slot = epochMillis / 5000`. **There was no secret.** Anyone who learned a
session id could regenerate a valid code indefinitely from anywhere, and the
freshness check ran only on the scanning device — the security rules never saw
the token at all.

The signed scheme:

- `ATTNDRA1:<sessionId>:<slot>:<token>`, with 32 bytes of cryptographic
  randomness per rotation.
- The teacher's device publishes a new secret every 5 s to
  `sessions/{id}/secure/qr`. Students have **no read access** to that path, but
  `get()` inside a security rule still resolves it — so the server verifies the
  token without ever exposing it.
- The rules accept only the current or immediately previous token, so a
  screenshot or forwarded photo stops working within one rotation.
- Only the owning teacher or an admin may publish a secret.
- Ending a session deletes it, so no displayed code outlives the session.

### Grace period, and how to end it

Sessions created by this build carry `requireSignedQr: true`. Sessions from
older builds omit the flag and keep accepting unsigned codes, so installs that
have not updated keep working. **Once your users have updated**, end the grace
period by changing one default in `firestore.rules`:

```javascript
function sessionRequiresSignedQr(sessionId) {
  return sessionData(sessionId).get('requireSignedQr', true) == true;
  //                                                  ^^^^ was false
}
```

## 6. Teacher self-attendance — hardened

The selfie + geofence flow already existed and is reachable from the teacher
portal ("My Geo-Attendance"). One manipulation gap closed: the GPS fix was
taken *before* the camera opened, so a teacher could pass the geofence check on
campus and then walk away to take the photo. A second fix is now taken after
capture, and that is the one recorded and validated.

## 7. Attendance metadata for admins — delivered

The admin photo dialog showed the image alone. `AttendanceEvidenceDialog` now
shows the selfie together with the exact capture date and time, GPS
coordinates (copyable, with a Maps link), location accuracy, distance from
campus, and a clear entry/exit designation.

## 8. iOS — prepared (see Round 3)

Deferred at your direction. For the record, the blockers are:
`firebase_options.dart` throws `UnsupportedError` for iOS, there is no
`GoogleService-Info.plist`, the deployment target is 12.0 (Firebase needs 15+),
and registering an iOS app requires Firebase console access to
`attendora-a0fc5`.

## Theming

There was no light mode: `buildAttendoraTheme()` returned the dark `ThemeData`
for *both* slots and the app pinned `ThemeMode.light`.

- `AppColors` — a `ThemeExtension` of semantic tokens (canvas, surface, text
  ramp, status colours), read via `context.c`.
- Full light and dark `ThemeData` generated from one palette definition.
- Persisted light / dark / system preference, with a switcher in all four
  portal shells and the desktop sidebar.
- ~1,400 colour literals converted across 76 files; `FluentColors` references
  in screens went 104 → 0.

Deliberately left as literals: the pre-theme crash screen, `PdfColors` in the
export generators, decorative category tints, and the QR code's white backing
(scanners need that contrast).

---

## Verification

**Firestore rules — 29 assertions, all passing.** See `test/rules/README.md`.

```bash
cd test/rules
npx firebase emulators:exec --only firestore --project attendora-rules-test \
  "node firestore_rules_test.mjs && node qr_rules_test.mjs"
```

Requires JDK 21+. These are not vacuous: **11 of them fail against the original
rules**, which is what confirmed each vulnerability above was real.

**Static analysis:** `flutter analyze` — 0 errors (15 pre-existing lint infos).

**Build:** `flutter build web --release` succeeds.

**Manual:** the built web app was driven in a browser and checked in light and
dark, at desktop and 375px. That is what caught the contrast and clipping
regressions the analyzer could not see.

### Not verified

- **No end-to-end run against live Firebase.** Rules are proven in the
  emulator; the client changes are not exercised against the real backend.
  Worth a staging pass on the approval flow and one live QR session.
- **No Android build.** `flutter build apk` was never run here — no Android
  SDK on this machine.
- **Faculty coordinates are still client-supplied.** With no Cloud Functions,
  the rules cannot verify a GPS fix, so a modified client could submit false
  coordinates. The selfie is the compensating control. Closing this properly
  needs a Cloud Function or App Check.
- **`getDownloadURL()` tokens bypass storage rules.** Anyone holding a photo
  URL can fetch it. The Firestore document is the real access boundary and is
  now restricted; to make the objects themselves private, store the storage
  path instead of a download URL.

---

## Round 2 — field testing and the requirements list

### Group creation crash (reported against production)

Creating a Lab group failed with `FIRESTORE INTERNAL ASSERTION FAILED:
Unexpected state (ID: b815)`. Three things were going on:

1. **Real errors were being thrown away.** `ErrorHandler.showErrorSnackBar`
   discarded the actual exception whenever a custom message was passed, which
   is every call site, so every failure showed the same generic banner. It now
   always logs the raw error and shows the Firebase error code (or exception
   text) under the friendly message.
2. **The assertion is a documented Firestore Web SDK bug** in listener
   bookkeeping (firebase-js-sdk#9985, #8305), intermittent across versions
   10.5 to 12.14. A safe non-breaking upgrade does not exist (the fix path is a
   major bump, cloud_firestore 5.x to 6.x), so group writes now go through
   `withFirestoreRetry`, which retries once on that exact signature only.
3. **I had enabled Firestore persistence by accident.** Wiring in the emulator
   flag flipped `persistenceEnabled` from `false` to `true`. Reverted and
   documented in `main.dart`.

Create/Edit Group and Approve/Reject/Revoke now disable and show a spinner
while their write is in flight.

### Requirements list

| Requirement | Status |
| --- | --- |
| APK from a Google Drive link | New. Set it under System Settings; see `APK_DOWNLOAD_SETUP.md` |
| Teacher generates QR per class | Already existed (class + subject picker on Start Session) |
| Attendance only within a radius the teacher sets | Already existed (Radius field; checked on the student's phone) |
| Teacher marks own attendance with a selfie, college behind them | Existed; added pre-capture instructions and a retake preview |
| Teacher sees every student's attendance | Already existed (Students page, per subject) |
| Detain below 75% | Changed from 60% to 75%; one shared constant now drives both portals |
| "You are detained" notification to the student | New. Sent atomically with the detention |
| Student sees their attendance % | Already existed (dashboard, subjects, analytics) |
| Syncs with the existing Firebase | Same project `attendora-a0fc5`; no migration |

**Detention is a flag plus a notification.** It shows on the student's subject
page and bell and fires an on-device alert while the app is running. It does
not currently stop a detained student from scanning in, and a push
notification when the app is closed needs a Cloud Function, which this project
does not have.

### Security rules were incomplete

Four collections the app uses had no rule at all, so Firestore would have
denied them: `detentions`, `global_notifications`, `subject_catalog` and
`users/{uid}/notification_states`. Rules are now written for each, with 21 new
emulator assertions (50 in total, all passing). **Do this before deploying
`firestore.rules`**, or the Detain button, broadcasts and notification
read-state would have stopped working.

### Found while testing, fixed

- The Download button first opened the old relative `downloads/attendora.apk`
  because the setting had not loaded yet. It now waits for the setting.
- Tested end to end against the emulators with fake accounts: detain a student at
  50%, no button for a student at 100%, the student receives the notification
  and sees the detained notice. See `tool/emulator/README.md` to reproduce.

---

## Round 3 — iPhone

The iOS project is prepared to run on an iPhone plugged into a Mac; see
`IOS_FIREBASE_SETUP.md`. It was first prepared on a Mac with only the command
line tools; it has since been **built with Xcode 27 and run on the iPhone
Simulator** (see "iPhone, verified on the Simulator" below). It has not been run
on a physical iPhone.

What was wrong, and is fixed:

- Xcode deployment target was **12.0**; the Firebase iOS SDK needs 13.0. First
  set to 13.0; Xcode 27 turned out to require **15.0**, which it now is (Podfile,
  project and the engine's `AppFrameworkInfo.plist`).
- Bundle ID `com.example.attendora` is routinely rejected for signing; changed
  to `com.attendora.attendance`, and `scripts/ios_setup.sh` realigns it to
  whatever ID the downloaded plist was made for.
- Firebase had no iOS configuration, and a missing one would have left a blank
  screen. It is now generated from `GoogleService-Info.plist` by the script
  (no Xcode drag-and-drop), and an unconfigured build shows a setup screen.
- `Info.plist` lacked permission texts for photos and Face ID, and its camera
  and location texts only mentioned teachers; reworded and added.
- The "You are detained" alert used Android-only display settings and the app
  was not the notification centre's delegate, so iOS would have dropped it
  while the app was open. Fixed both.
- App start-up waited on a push token that was only ever logged; on an iPhone
  without push this can stall launch. Now fetched in the background.
- **Approximate location.** iOS lets a person grant only a ~1 km location,
  which fails a tens-of-metres attendance check and looks like a distance
  problem. A new `ensurePreciseLocation()` asks iOS for precise location where
  attendance reads the phone's position (scan, session start, faculty
  geo-attendance, campus setup) and explains how to enable it if declined.
  Android and web are unaffected. 8 unit tests.
- Found by testing `ios_setup.sh`: `plutil` prints its error to stdout, so a
  missing key was read as a real value (and a junk file as a valid plist).
  Fixed and every failure case re-tested.

Push notifications are deliberately **not** enabled: the capability cannot be
signed with a free Apple ID and there is no server sending pushes.

### Running the iPhone app without access to the real Firebase project

Someone who is handed the source cannot add an iOS app to a Firebase project
they do not own, so the real-project route is not available to them. The app
can now run in Xcode (Simulator or a real iPhone) against the local emulators
with a placeholder Firebase configuration, used **only** when
`--dart-define=USE_FIREBASE_EMULATOR=true` and no real iOS config exists.
It is accepted because the Firebase iOS SDK only checks that the app id has the
form `1:<number>:ios:<hex>` (read from FirebaseCore's `FIRApp.m`: the hash "cannot
be validated" on the client; an Android or web id would be rejected). A normal
build with no config still shows the setup screen rather than using the
placeholder. 8 unit tests pin this down.

Also: `EMULATOR_HOST` lets a real phone reach emulators on the computer; the
iOS plist allows local networking for that; and an orange SANDBOX ribbon shows
whenever the emulator flag is on (Firebase's own "emulator mode" banner exists
only on the web, so iOS and Android had no indication at all). The engine
framework's minimum iOS (`AppFrameworkInfo.plist`) now agrees with the app's.

See `IOS_FIREBASE_SETUP.md`, Option A.

**Sandbox start-up bug, found by following the instructions literally.** The
first version told people to run the Firebase CLI in `tool/emulator`, whose
`firebase.json` pointed at `../../firestore.rules`. The CLI refuses rules files
outside the project folder, so step 1 failed for anyone who tried it
("... is outside of project directory"); it had only worked in testing because
the rules had been copied in by hand. Replaced with `tool/emulator/start.sh` and
`seed.sh`, which copy the real rules in, check Node and Java versions with a
clear message, refuse to seed if the emulators are not running, and work from
any folder. Verified from a clean copy: emulators start, seeding installs its
own dependency, the fake accounts sign in, seeding is repeatable, and old Java
and not-started cases print a clear error.

**`start.sh` could exit without a word.** Found while setting up the iOS
Simulator on this Mac: under `bash`, the first `java` on the path was an
Intel-only JDK that macOS can no longer run ("Bad CPU type in executable"), and
the script's version probe failed under `set -e`, ending the script silently.
It now tolerates a failing probe, falls back to `/usr/libexec/java_home -v 21+`
to find a working JDK (it recovered automatically here), and otherwise prints
which Java it found and why it cannot be used. Each case was exercised: working
Java, broken Java with and without the system lookup, and a too-old Java.

### iPhone, verified on the Simulator

Built with Xcode 27.0 and Flutter 3.47.7 and run on an iPhone 17 Simulator
against the sandbox. Walked through as the teacher (sign in, student list,
Detain the 50% student) and then as that student (native "You are detained"
banner, in-app notice, attendance alert showing 50.0%). The app stayed signed in
across a restart. Every item below was found by actually running it:

- **Flutter 3.38 cannot build for Xcode 27** (`lipo -verify_arch` rejects the
  app). Flutter 3.47 fixes it. `scripts/ios_sandbox.sh` refuses the combination
  with a one-line fix instead of failing deep in a build.
- **Deployment target 13.0 -> 15.0** (Xcode 27 refuses anything older).
- **UIScene life cycle.** iOS 26+ SDKs require it; without it the app starts as
  a blank white screen. Added `SceneDelegate.swift`, the scene manifest in
  `Info.plist`, and moved plugin registration to Flutter's engine callback.
- **Sandbox placeholder Firebase options were rejected twice**: the Installations
  API key must be exactly 39 characters starting with `A` (a crash at launch),
  and the options need a `storageBucket` or `FirebaseStorage.instance` throws
  `no-bucket` and aborts start-up. Both are now covered by unit tests.
- **Start-up waited on the notification permission pop-up.** On a fresh
  install the app stayed blank white until the pop-up was answered, which looks
  like a crash. Notification set-up now runs in the background and the pop-up
  appears over the login screen.
- **Detain button squashed the student row on a phone.** It sat in the same row
  as the name and attendance, leaving the text one letter wide ("RIGHT
  OVERFLOWED BY 92 PIXELS"). Moved under the details; "Remove detention" scales
  to fit instead of wrapping. This was a real bug in the Android app too, from
  the detain feature; rebuild the APK to get the fix.
- **CocoaPods needs a UTF-8 terminal** (`pod install` crashes under the plain
  "C" locale); `ios_sandbox.sh` sets it.

For handing the project to someone else: `scripts/ios_sandbox.sh` (checks tools,
fetches dependencies, makes Xcode build the sandbox, opens the project, `--iphone`
for a real phone) and `tool/emulator/start.sh --lan` (emulators reachable from a
phone on the same Wi-Fi). `flutter build ios --config-only` also tries to sign
for a device and fails on a Mac with no certificate, so the script passes
`--no-codesign`. The Xcode-workspace build (`xcodebuild -workspace
ios/Runner.xcworkspace -scheme Runner`, which is what Run does) succeeded and
the resulting app was the one used for the walk-through.

The hand-over was also tested from a clean copy: the committed zip unpacked into
an empty folder, `scripts/ios_sandbox.sh` and an `xcodebuild` of the workspace
succeeded there, `start.sh --lan` plus `seed.sh` served the emulators on the Mac's
network address, and a `--iphone` build (that address baked in) signed in on the
Simulator through it, so iOS allows plain HTTP to the Mac's local address.

Not verified: a physical iPhone (signing, the Local Network prompt, the phone
actually reaching the Mac over Wi-Fi), the camera (QR scan, selfie) and location
accuracy.

