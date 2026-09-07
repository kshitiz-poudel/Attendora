# Attendora fixes applied

- Added a safer Firestore web configuration: persistence disabled and forced long-polling.
- Reworked the Teacher Approvals page to use one stable Firestore listener and derive pending/approved lists locally.
- Made approval writes merge-safe and recorded `approvedAt`.
- Added compatibility for demo users using either `teacher` or `faculty` as the role.
- Added geo-attendance sequencing so exit cannot be recorded before entry and duplicate daily evidence is rejected.
- Added coordinate/radius validation and save error handling to geofence settings.

Run `flutter clean && flutter pub get && flutter run -d chrome`.
