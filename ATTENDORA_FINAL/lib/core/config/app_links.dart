import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/super_admin/services/system_settings_service.dart';

/// Where the Android app is downloaded from.
///
/// The APK is hosted on Google Drive (or any file host) rather than served
/// from the web build, so the link has to be configurable without a rebuild.
/// Resolution order, first non-empty wins:
///
///  1. `androidApkUrl` in the Firestore `system_settings/config` document -
///     editable by a super admin under System Settings. This is the one to
///     use: change it and every portal picks it up immediately.
///  2. `--dart-define=APK_URL=...` at build time.
///  3. [kBundledAndroidApkUrl] below, for people who would rather commit it.
///  4. `downloads/attendora.apk` beside the web build (what
///     `scripts/build_mobile.sh` produces), the original behaviour.
const String kBundledAndroidApkUrl = '';

const String _definedApkUrl = String.fromEnvironment('APK_URL');

/// Normalises a pasted link into something a browser can fetch.
///
/// Google Drive share links open a preview page rather than starting a
/// download, which is not what a "Download" button should do:
///
///   https://drive.google.com/file/d/ID/view?usp=sharing
///   https://drive.google.com/open?id=ID
///
/// become `https://drive.google.com/uc?export=download&id=ID`. Anything else
/// is passed through untouched. Returns null for text that is not an
/// http(s) URL, so a stray value (or a `javascript:` string someone managed
/// to write into settings) can never be launched.
Uri? normalizeDownloadUrl(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasScheme) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  if (uri.host.isEmpty) return null;

  if (uri.host == 'drive.google.com') {
    final fileMatch = RegExp(r'/file/d/([A-Za-z0-9_-]+)').firstMatch(uri.path);
    final id = fileMatch?.group(1) ?? uri.queryParameters['id'];
    if (id != null && id.isNotEmpty) {
      return Uri.https('drive.google.com', '/uc', {
        'export': 'download',
        'id': id,
      });
    }
  }
  return uri;
}

/// The Android download link, following the resolution order above.
final androidApkUriProvider = Provider<Uri>((ref) {
  final settings = ref.watch(systemSettingsStreamProvider).asData?.value;
  final configured = (settings?['androidApkUrl'] as String?) ?? '';

  for (final candidate in [configured, _definedApkUrl, kBundledAndroidApkUrl]) {
    final uri = normalizeDownloadUrl(candidate);
    if (uri != null) return uri;
  }
  return Uri.base.resolve('downloads/attendora.apk');
});

/// True once a real hosted link has been configured (as opposed to the
/// relative fallback, which only works if the APK was deployed with the web
/// build).
final androidApkConfiguredProvider = Provider<bool>((ref) {
  final settings = ref.watch(systemSettingsStreamProvider).asData?.value;
  final configured = (settings?['androidApkUrl'] as String?) ?? '';
  return [configured, _definedApkUrl, kBundledAndroidApkUrl]
      .any((c) => normalizeDownloadUrl(c) != null);
});

/// The Android link to open *right now*.
///
/// Reading [androidApkUriProvider] directly at click time is not enough: the
/// settings document arrives asynchronously, so a click shortly after the page
/// loads would still see "no setting yet" and open the relative fallback
/// instead of the configured Drive link. This waits (briefly) for the first
/// settings snapshot before resolving, and falls back rather than hanging if
/// the settings cannot be read.
Future<Uri> resolveAndroidApkUri(WidgetRef ref) async {
  try {
    await ref
        .read(systemSettingsStreamProvider.future)
        .timeout(const Duration(seconds: 4));
  } catch (_) {
    // Offline or settings unreadable: use whatever resolution gives.
  }
  return ref.read(androidApkUriProvider);
}
