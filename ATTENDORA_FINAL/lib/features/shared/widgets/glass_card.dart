import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';

/// Frosted panel used as the primary content container across the app.
/// Colours resolve from the active theme so it reads correctly in both modes.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: width,
            height: height,
            padding: padding ?? const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: c.glassFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.glassBorder, width: 1),
              boxShadow: c.isDark
                  ? null
                  : [
                      BoxShadow(
                        color: c.shadow,
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
