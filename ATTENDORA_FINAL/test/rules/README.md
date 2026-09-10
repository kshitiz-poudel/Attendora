# Firestore security-rules tests

These run against the Firestore emulator and cover the access-control
behaviour the app depends on: faculty approval, tenant isolation, privilege
escalation, the roll-number uniqueness lock, and rotating-QR verification.

## Requirements

- JDK 21 or newer (the emulator refuses older runtimes)
- `npm install -D firebase-tools @firebase/rules-unit-testing firebase`

## Run

```bash
cd test/rules
npx firebase emulators:exec --only firestore --project attendora-rules-test \
  "node firestore_rules_test.mjs && node qr_rules_test.mjs"
```

Both suites exit non-zero on failure, so they can gate CI.

## What they pin down

`firestore_rules_test.mjs`
- an institution admin can approve, revoke and reject faculty in their tenant,
  including legacy accounts stored without an `institutionCode`
- an admin from another institution cannot
- no user can grant themselves `approved`, `admin` or `isSuperAdmin`
- the student device lock cannot be reset by the student
- `id_index` entries cannot be hijacked

`qr_rules_test.mjs`
- students cannot read the rotating secret at `sessions/{id}/secure/qr`
- attendance is rejected without a token, with a forged token, or with a
  stale one; accepted for the current and immediately previous token
- sessions without `requireSignedQr` still accept unsigned writes, which is
  the grace period for clients that have not updated yet
- only the owning teacher or an admin can publish a secret
