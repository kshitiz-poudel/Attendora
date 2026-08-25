# Security Notes

## GitHub Secret Scanning Alert: "Google API Key"

GitHub's secret scanner flags the Firebase Web API key present in:
- `lib/firebase_options.dart`
- `web/firebase-messaging-sw.js`

**This is expected and not a critical vulnerability.** Firebase Web API keys
are not authentication secrets — they identify which Firebase project a
client is talking to. They do not grant access to data on their own.
Google's own FlutterFire tooling generates `firebase_options.dart` to be
committed to source control by default.

Actual access control for this project is enforced by `firestore.rules`,
which requires authentication and role checks (`isSuperAdmin`,
`isInstitutionAdmin`, `isTeacher`) for all sensitive reads/writes.

### Recommended hardening (optional, done once per project)

To reduce misuse of the key (e.g. quota abuse from other origins), restrict
it in Google Cloud Console:

1. Go to [console.cloud.google.com](https://console.cloud.google.com) →
   select the `attendiify` project.
2. Navigate to **APIs & Services → Credentials**.
3. Click the key starting `AIzaSyBMS5TGBrhbeg0ywkHr...`.
4. Under **Application restrictions**, choose **Websites** and add your
   Firebase Hosting domain(s), e.g. `attendiify.web.app/*` and
   `attendiify.firebaseapp.com/*` (add `localhost` too if you test locally).
5. Under **API restrictions**, restrict the key to only the Firebase APIs
   actually used (Identity Toolkit, Firebase Installations, Cloud Firestore,
   FCM Registration, etc.).
6. Save.

This does not require rotating the key or rewriting git history — the key
can remain as-is in the source tree.

### Dismissing the GitHub alert

When resolving the alert on GitHub, choose **"False positive"** or
**"Used in tests"** is not accurate — instead select **"Revoked"** only if
you actually restrict/rotate the key, or leave it open with a comment
linking to this file if you choose not to restrict it immediately.
