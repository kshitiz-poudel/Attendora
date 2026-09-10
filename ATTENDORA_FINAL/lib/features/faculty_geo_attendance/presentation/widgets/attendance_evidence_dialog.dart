import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/app_colors.dart';

/// Full verification record for one faculty entry or exit.
///
/// Requirement is that an administrator reviewing attendance can see the
/// selfie together with exactly when and where it was taken and whether it
/// was an entry or an exit — so this shows the photo alongside the captured
/// timestamp, GPS fix, accuracy and distance from campus, rather than the
/// image alone.
class AttendanceEvidenceDialog extends StatelessWidget {
  const AttendanceEvidenceDialog({
    super.key,
    required this.event,
    required this.type,
    required this.facultyName,
    this.date,
  });

  /// The `checkIn` / `checkOut` map from a `faculty_geo_attendance` document.
  final Map<String, dynamic> event;

  /// 'checkIn' or 'checkOut'.
  final String type;
  final String facultyName;
  final String? date;

  bool get _isEntry => type == 'checkIn';

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> event,
    required String type,
    required String facultyName,
    String? date,
  }) => showDialog(
    context: context,
    builder: (_) => AttendanceEvidenceDialog(
      event: event,
      type: type,
      facultyName: facultyName,
      date: date,
    ),
  );

  DateTime? get _capturedAt {
    final ts = event['timestamp'];
    if (ts is Timestamp) return ts.toDate();
    // Written by the device at capture time; the server timestamp is
    // authoritative but this survives an offline queue.
    final client = event['clientCapturedAt'];
    if (client is String) return DateTime.tryParse(client);
    return null;
  }

  double? get _latitude => (event['latitude'] as num?)?.toDouble();
  double? get _longitude => (event['longitude'] as num?)?.toDouble();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final captured = _capturedAt;
    final lat = _latitude;
    final lng = _longitude;
    final accuracy = (event['accuracy'] as num?)?.toDouble();
    final distance = (event['distanceFromCampus'] as num?)?.toDouble();
    final photoUrl = event['photoUrl'] as String?;
    final statusColor = _isEntry ? c.success : c.info;

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isEntry ? Icons.login_rounded : Icons.logout_rounded,
                          size: 15,
                          color: statusColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isEntry ? 'Entry' : 'Exit',
                          style: GoogleFonts.outfit(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      facultyName,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: c.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: photoUrl == null || photoUrl.isEmpty
                          ? Container(
                              height: 220,
                              color: c.surfaceMuted,
                              alignment: Alignment.center,
                              child: Text(
                                'No photo captured',
                                style: GoogleFonts.outfit(
                                  color: c.textTertiary,
                                ),
                              ),
                            )
                          : Image.network(
                              photoUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) =>
                                  progress == null
                                  ? child
                                  : Container(
                                      height: 220,
                                      color: c.surfaceMuted,
                                      alignment: Alignment.center,
                                      child: CircularProgressIndicator(
                                        value:
                                            progress.expectedTotalBytes == null
                                            ? null
                                            : progress
                                                      .cumulativeBytesLoaded /
                                                  progress.expectedTotalBytes!,
                                      ),
                                    ),
                              errorBuilder: (_, __, ___) => Container(
                                height: 220,
                                color: c.surfaceMuted,
                                alignment: Alignment.center,
                                child: Text(
                                  'Photo could not be loaded',
                                  style: GoogleFonts.outfit(color: c.danger),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                    _MetaRow(
                      icon: Icons.event_rounded,
                      label: 'Date',
                      value: captured != null
                          ? DateFormat('EEEE, d MMMM y').format(captured)
                          : (date ?? 'Not recorded'),
                    ),
                    _MetaRow(
                      icon: Icons.schedule_rounded,
                      label: 'Time captured',
                      value: captured != null
                          ? DateFormat('hh:mm:ss a').format(captured)
                          : 'Pending sync',
                    ),
                    _MetaRow(
                      icon: Icons.my_location_rounded,
                      label: 'GPS coordinates',
                      value: lat != null && lng != null
                          ? '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'
                          : 'Not recorded',
                      onCopy: lat != null && lng != null
                          ? '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'
                          : null,
                    ),
                    if (accuracy != null)
                      _MetaRow(
                        icon: Icons.gps_fixed_rounded,
                        label: 'Location accuracy',
                        value: '±${accuracy.round()} m',
                      ),
                    if (distance != null)
                      _MetaRow(
                        icon: Icons.social_distance_rounded,
                        label: 'Distance from campus',
                        value: '${distance.round()} m',
                      ),
                    if (lat != null && lng != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(
                            'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                          );
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: const Icon(Icons.map_rounded, size: 18),
                        label: const Text('Open location in Maps'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  final IconData icon;
  final String label;
  final String value;

  /// When set, a copy button places this text on the clipboard.
  final String? onCopy;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: c.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: GoogleFonts.outfit(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              tooltip: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: onCopy!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
            ),
        ],
      ),
    );
  }
}
