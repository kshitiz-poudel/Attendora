import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/design/app_colors.dart';
import '../../../attendance/qr_token.dart';

/// The scannable code, with a ring that drains over each rotation interval so
/// the room can see the code is live rather than a static image.
///
/// The QR itself is always drawn on white with dark modules: scanners need
/// that contrast, so this element deliberately does not follow the theme.
class RotatingQrView extends StatefulWidget {
  const RotatingQrView({
    super.key,
    required this.data,
    required this.isSecured,
    this.size = 260,
  });

  final String data;

  /// False until the first rotation has been published; the code is briefly
  /// unsigned in that window.
  final bool isSecured;
  final double size;

  @override
  State<RotatingQrView> createState() => _RotatingQrViewState();
}

class _RotatingQrViewState extends State<RotatingQrView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: QrPayload.rotationInterval,
    )..repeat();
  }

  @override
  void didUpdateWidget(RotatingQrView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Restart the sweep whenever a new code lands so the ring stays in step
    // with the actual rotation rather than free-running.
    if (oldWidget.data != widget.data) {
      _controller.forward(from: 0);
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ringSize = widget.size + 40;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: ringSize,
          height: ringSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => SizedBox(
                  width: ringSize,
                  height: ringSize,
                  child: CircularProgressIndicator(
                    value: 1.0 - _controller.value,
                    strokeWidth: 5,
                    backgroundColor: c.border,
                    valueColor: AlwaysStoppedAnimation(
                      widget.isSecured ? c.success : c.warning,
                    ),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: Container(
                  key: ValueKey(widget.data),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    // Fixed white: QR contrast must not follow the theme.
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: c.shadow,
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: widget.data,
                    size: widget.size,
                    backgroundColor: Colors.white,
                    // Denser payload than the legacy scheme; let the library
                    // pick a version that fits rather than overflowing.
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.isSecured
                  ? Icons.verified_user_rounded
                  : Icons.hourglass_top_rounded,
              size: 16,
              color: widget.isSecured ? c.success : c.warning,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.isSecured
                    ? 'Secured code — rotates every '
                          '${QrPayload.rotationInterval.inSeconds}s'
                    : 'Securing session…',
                style: GoogleFonts.outfit(
                  color: c.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Screenshots stop working within seconds',
          style: GoogleFonts.outfit(color: c.textTertiary, fontSize: 11),
        ),
      ],
    );
  }
}
