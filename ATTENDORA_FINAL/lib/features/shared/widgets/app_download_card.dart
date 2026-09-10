import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/app_colors.dart';

/// Where the Android build is published. `scripts/build_mobile.sh android`
/// writes the APK to `build/web/downloads/attendora.apk`, so this resolves
/// against whatever origin the portal is served from.
Uri get androidApkUri => Uri.base.resolve('downloads/attendora.apk');

Future<bool> launchAndroidApk() async {
  try {
    return await launchUrl(androidApkUri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Promotes the mobile app from the teacher and student portals.
///
/// Only meaningful on the web build — inside the installed app there is
/// nothing to download, so it renders nothing there.
class AppDownloadCard extends StatelessWidget {
  const AppDownloadCard({
    super.key,
    required this.audience,
    this.compact = false,
  });

  /// 'teacher' or 'student'; changes the supporting copy only.
  final String audience;
  final bool compact;

  bool get _isTeacher => audience == 'teacher';

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    final c = context.c;
    final headline = _isTeacher
        ? 'Run sessions from your phone'
        : 'Mark attendance from your phone';
    final body = _isTeacher
        ? 'Generate rotating QR codes, take attendance and record your own '
              'campus entry and exit with the Attendora mobile app.'
        : 'Scanning attendance QR codes needs a camera, so it is only '
              'available in the Attendora mobile app.';

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.primary.withValues(alpha: c.isDark ? 0.22 : 0.10),
            c.accent.withValues(alpha: c.isDark ? 0.16 : 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.primary.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.phone_iphone_rounded,
                  color: c.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  headline,
                  style: GoogleFonts.outfit(
                    color: c.textPrimary,
                    fontSize: compact ? 15 : 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: GoogleFonts.outfit(
              color: c.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () async {
                  final ok = await launchAndroidApk();
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'The Android build is not published yet. '
                          'Please contact your administrator.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.android_rounded, size: 18),
                label: const Text('Download for Android'),
              ),
              Tooltip(
                message: 'The iOS build is not available yet',
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.apple_rounded, size: 18),
                  label: const Text('iOS — coming soon'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 13, color: c.textTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Android may ask you to allow installs from your browser.',
                  style: GoogleFonts.outfit(
                    color: c.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Slim app-bar action pointing at the same download.
class AppDownloadButton extends StatelessWidget {
  const AppDownloadButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Get the mobile app',
      onPressed: () async {
        final ok = await launchAndroidApk();
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('The Android build is not published yet.')),
          );
        }
      },
      icon: const Icon(Icons.download_for_offline_outlined),
    );
  }
}
