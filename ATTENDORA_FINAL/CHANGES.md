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

## 8. iOS — deferred

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
