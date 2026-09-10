import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';

/// Page canvas: a soft vertical gradient plus a subtle dot grid.
class BackgroundPattern extends StatelessWidget {
  final Widget child;

  const BackgroundPattern({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [c.canvasGradientTop, c.canvasGradientBottom],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: DotGridPainter(color: c.dotPattern, spacing: 30),
          ),
        ),
        child,
      ],
    );
  }
}

class DotGridPainter extends CustomPainter {
  final Color color;
  final double spacing;

  DotGridPainter({required this.color, required this.spacing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotGridPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.spacing != spacing;
}
