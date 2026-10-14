import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design/app_colors.dart';

/// Guided capture of the faculty entry/exit selfie.
///
/// The requirement is a selfie with the college visible behind the teacher, so
/// that the photo itself shows where it was taken. A phone camera cannot
/// verify that on its own, so the flow does the two things that make it
/// likely and checkable:
///
///  1. tells the teacher what the photo must show *before* the camera opens,
///     rather than after a rejected submission, and
///  2. shows the captured photo back to them with a Retake option, so a shot
///     with the building cut off or the teacher's face filling the frame is
///     caught while they are still standing in the right place.
///
/// The photo is always taken live from the front camera (never picked from a
/// gallery), and the admin sees it together with its timestamp and GPS fix.
///
/// Returns the JPEG bytes, or null if the teacher cancelled.
Future<Uint8List?> captureCampusSelfie(
  BuildContext context, {
  required bool isEntry,
}) async {
  final proceed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final c = dialogContext.c;
      Widget tip(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: c.accent),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      );
      return AlertDialog(
        title: Text(isEntry ? 'Entry photo' : 'Exit photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Take a selfie that shows the college behind you:'),
            const SizedBox(height: 14),
            tip(
              Icons.apartment_rounded,
              'Stand so the college building, gate or name board is clearly '
              'visible in the background.',
            ),
            tip(
              Icons.face_rounded,
              'Keep your face visible, but not so close that the building is '
              'hidden.',
            ),
            tip(
              Icons.wb_sunny_outlined,
              'Make sure there is enough light to see both.',
            ),
            tip(
              Icons.schedule_rounded,
              'The photo is saved with the exact time and your location.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.photo_camera_front_rounded, size: 18),
            label: const Text('Open camera'),
          ),
        ],
      );
    },
  );
  if (proceed != true || !context.mounted) return null;

  final picker = ImagePicker();
  while (true) {
    final shot = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (shot == null) return null;
    final bytes = await shot.readAsBytes();
    if (!context.mounted) return null;

    final decision = await showDialog<_PreviewChoice>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Is the college visible?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(bytes, fit: BoxFit.contain, height: 320),
              ),
              const SizedBox(height: 12),
              const Text(
                'Check that the college can be seen behind you. If not, '
                'retake the photo.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _PreviewChoice.cancel),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, _PreviewChoice.retake),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retake'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, _PreviewChoice.use),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Use this photo'),
          ),
        ],
      ),
    );

    switch (decision) {
      case _PreviewChoice.use:
        return bytes;
      case _PreviewChoice.retake:
        continue;
      case _PreviewChoice.cancel:
      case null:
        return null;
    }
  }
}

enum _PreviewChoice { use, retake, cancel }
