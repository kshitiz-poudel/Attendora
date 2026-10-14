# Attendora APK download

The Download button on the Teacher and Student portals opens a link you
control, so the APK can live on Google Drive instead of being deployed with the
website.

## 1. Build the APK

```bash
flutter pub get
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk
```

(`./scripts/build_mobile.sh android` does the same and also builds the web app.)
The Android Gradle file currently signs with the debug key; configure a private
release keystore before wider distribution, and never commit the keystore.

## 2. Put it on Google Drive

1. Upload `app-release.apk` to Google Drive.
2. Share -> General access -> **Anyone with the link** (Viewer).
3. Copy the link. It looks like
   `https://drive.google.com/file/d/<ID>/view?usp=sharing`.

## 3. Tell the app where it is

Sign in as the super admin -> **System Settings** -> **Android App Download
Link** -> paste the link -> **Save Link**.

Both portals pick it up immediately, no rebuild or redeploy. Drive share links
are converted to a direct download (`drive.google.com/uc?export=download&id=...`)
so the button starts the download rather than opening a preview page.

If you would rather bake the link in, either pass
`--dart-define=APK_URL=<link>` at build time or set `kBundledAndroidApkUrl` in
`lib/core/config/app_links.dart`. The setting in System Settings wins when both
exist. With nothing configured, the button falls back to `downloads/attendora.apk`
beside the web build.

## Notes

- Only http(s) links are accepted; anything else is ignored.
- Android asks the person to allow installs from their browser the first time.
- Drive can show a "can't scan for viruses" page for files over 100 MB.
