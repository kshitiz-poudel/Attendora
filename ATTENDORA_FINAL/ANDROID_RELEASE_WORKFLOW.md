# Attendora Android release workflow

This source package contains the latest project code. Build a fresh APK from this package before uploading it to the public download link.

```bash
chmod +x scripts/build_mobile.sh
./scripts/build_mobile.sh android
```

The current APK is produced at:

`build/releases/attendora-latest.apk`

After testing it, upload this newly built APK to Google Drive and replace the Android download URL in `lib/features/teacher/presentation/generate_qr_page.dart` if Drive gives the file a new ID.

Do not label an older APK as the current Attendora release.
