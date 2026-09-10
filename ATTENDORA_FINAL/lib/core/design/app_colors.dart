import 'package:flutter/material.dart';

/// Semantic colour tokens for Attendora.
///
/// Every screen should resolve colours through this extension rather than
/// hardcoding literals, so a single palette definition drives both light and
/// dark mode. Access it with `context.c` (see [AppColorsX]).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.canvas,
    required this.canvasGradientTop,
    required this.canvasGradientBottom,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceRaised,
    required this.glassFill,
    required this.glassBorder,
    required this.dotPattern,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textInverse,
    required this.primary,
    required this.primaryHover,
    required this.onPrimary,
    required this.primarySubtle,
    required this.accent,
    required this.onAccent,
    required this.accentSubtle,
    required this.success,
    required this.successSubtle,
    required this.warning,
    required this.warningSubtle,
    required this.danger,
    required this.dangerSubtle,
    required this.info,
    required this.infoSubtle,
    required this.overlay,
    required this.shadow,
    required this.skeletonBase,
    required this.skeletonHighlight,
  });

  final Brightness brightness;

  /// Page background and the gradient used by [BackgroundPattern].
  final Color canvas;
  final Color canvasGradientTop;
  final Color canvasGradientBottom;

  /// Card / panel fills.
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceRaised;

  /// Frosted-glass card fill and hairline.
  final Color glassFill;
  final Color glassBorder;
  final Color dotPattern;

  final Color border;
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Text that sits on a filled brand-coloured surface.
  final Color textInverse;

  final Color primary;
  final Color primaryHover;
  final Color onPrimary;
  final Color primarySubtle;

  final Color accent;
  final Color onAccent;
  final Color accentSubtle;

  final Color success;
  final Color successSubtle;
  final Color warning;
  final Color warningSubtle;
  final Color danger;
  final Color dangerSubtle;
  final Color info;
  final Color infoSubtle;

  /// Scrim behind modals.
  final Color overlay;
  final Color shadow;

  final Color skeletonBase;
  final Color skeletonHighlight;

  bool get isDark => brightness == Brightness.dark;

  /// Foreground that reads correctly on top of [surface].
  Color get onSurface => textPrimary;

  /// A status colour resolved from an attendance/approval status string.
  Color statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'present':
      case 'approved':
      case 'active':
      case 'checkin':
      case 'entry':
        return success;
      case 'late':
      case 'pending':
        return warning;
      case 'absent':
      case 'rejected':
      case 'revoked':
        return danger;
      case 'checkout':
      case 'exit':
        return info;
      default:
        return textSecondary;
    }
  }

  Color statusSubtle(String? status) {
    final base = statusColor(status);
    return base.withValues(alpha: isDark ? 0.18 : 0.12);
  }

  static const AppColors light = AppColors(
    brightness: Brightness.light,
    canvas: Color(0xFFF6F8FC),
    canvasGradientTop: Color(0xFFFFFFFF),
    canvasGradientBottom: Color(0xFFEEF2F9),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1F5F9),
    surfaceRaised: Color(0xFFFFFFFF),
    glassFill: Color(0xF2FFFFFF),
    glassBorder: Color(0x140F172A),
    dotPattern: Color(0x140F172A),
    border: Color(0xFFE2E8F0),
    borderStrong: Color(0xFFCBD5E1),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textTertiary: Color(0xFF94A3B8),
    textInverse: Color(0xFFFFFFFF),
    primary: Color(0xFF2F6FED),
    primaryHover: Color(0xFF1D4ED8),
    onPrimary: Color(0xFFFFFFFF),
    primarySubtle: Color(0xFFE6EEFE),
    accent: Color(0xFF0E9F71),
    onAccent: Color(0xFFFFFFFF),
    accentSubtle: Color(0xFFD8F5EA),
    success: Color(0xFF0E9F71),
    successSubtle: Color(0xFFD8F5EA),
    warning: Color(0xFFB45309),
    warningSubtle: Color(0xFFFDF0DC),
    danger: Color(0xFFDC2626),
    dangerSubtle: Color(0xFFFCE7E7),
    info: Color(0xFF2F6FED),
    infoSubtle: Color(0xFFE6EEFE),
    overlay: Color(0x660F172A),
    shadow: Color(0x1A0F172A),
    skeletonBase: Color(0xFFE2E8F0),
    skeletonHighlight: Color(0xFFF8FAFC),
  );

  static const AppColors dark = AppColors(
    brightness: Brightness.dark,
    canvas: Color(0xFF0B1121),
    canvasGradientTop: Color(0xFF111A31),
    canvasGradientBottom: Color(0xFF080D19),
    surface: Color(0xFF151A2D),
    surfaceMuted: Color(0xFF1E293B),
    surfaceRaised: Color(0xFF1E2438),
    glassFill: Color(0x991E293B),
    glassBorder: Color(0x14FFFFFF),
    dotPattern: Color(0x0DFFFFFF),
    border: Color(0xFF283449),
    borderStrong: Color(0xFF3A4A63),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textTertiary: Color(0xFF64748B),
    textInverse: Color(0xFF0F172A),
    primary: Color(0xFF4C8DFF),
    primaryHover: Color(0xFF6BA3FF),
    onPrimary: Color(0xFF06122B),
    primarySubtle: Color(0x334C8DFF),
    accent: Color(0xFF10B981),
    onAccent: Color(0xFF03231A),
    accentSubtle: Color(0x3310B981),
    success: Color(0xFF10B981),
    successSubtle: Color(0x3310B981),
    warning: Color(0xFFF59E0B),
    warningSubtle: Color(0x33F59E0B),
    danger: Color(0xFFF87171),
    dangerSubtle: Color(0x33F87171),
    info: Color(0xFF4C8DFF),
    infoSubtle: Color(0x334C8DFF),
    overlay: Color(0xA6020617),
    shadow: Color(0x66000000),
    skeletonBase: Color(0xFF1E293B),
    skeletonHighlight: Color(0xFF2C3A52),
  );

  @override
  AppColors copyWith({
    Brightness? brightness,
    Color? canvas,
    Color? canvasGradientTop,
    Color? canvasGradientBottom,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceRaised,
    Color? glassFill,
    Color? glassBorder,
    Color? dotPattern,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textInverse,
    Color? primary,
    Color? primaryHover,
    Color? onPrimary,
    Color? primarySubtle,
    Color? accent,
    Color? onAccent,
    Color? accentSubtle,
    Color? success,
    Color? successSubtle,
    Color? warning,
    Color? warningSubtle,
    Color? danger,
    Color? dangerSubtle,
    Color? info,
    Color? infoSubtle,
    Color? overlay,
    Color? shadow,
    Color? skeletonBase,
    Color? skeletonHighlight,
  }) {
    return AppColors(
      brightness: brightness ?? this.brightness,
      canvas: canvas ?? this.canvas,
      canvasGradientTop: canvasGradientTop ?? this.canvasGradientTop,
      canvasGradientBottom: canvasGradientBottom ?? this.canvasGradientBottom,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
      dotPattern: dotPattern ?? this.dotPattern,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textInverse: textInverse ?? this.textInverse,
      primary: primary ?? this.primary,
      primaryHover: primaryHover ?? this.primaryHover,
      onPrimary: onPrimary ?? this.onPrimary,
      primarySubtle: primarySubtle ?? this.primarySubtle,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      success: success ?? this.success,
      successSubtle: successSubtle ?? this.successSubtle,
      warning: warning ?? this.warning,
      warningSubtle: warningSubtle ?? this.warningSubtle,
      danger: danger ?? this.danger,
      dangerSubtle: dangerSubtle ?? this.dangerSubtle,
      info: info ?? this.info,
      infoSubtle: infoSubtle ?? this.infoSubtle,
      overlay: overlay ?? this.overlay,
      shadow: shadow ?? this.shadow,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      canvas: c(canvas, other.canvas),
      canvasGradientTop: c(canvasGradientTop, other.canvasGradientTop),
      canvasGradientBottom: c(
        canvasGradientBottom,
        other.canvasGradientBottom,
      ),
      surface: c(surface, other.surface),
      surfaceMuted: c(surfaceMuted, other.surfaceMuted),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      glassFill: c(glassFill, other.glassFill),
      glassBorder: c(glassBorder, other.glassBorder),
      dotPattern: c(dotPattern, other.dotPattern),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      textInverse: c(textInverse, other.textInverse),
      primary: c(primary, other.primary),
      primaryHover: c(primaryHover, other.primaryHover),
      onPrimary: c(onPrimary, other.onPrimary),
      primarySubtle: c(primarySubtle, other.primarySubtle),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      accentSubtle: c(accentSubtle, other.accentSubtle),
      success: c(success, other.success),
      successSubtle: c(successSubtle, other.successSubtle),
      warning: c(warning, other.warning),
      warningSubtle: c(warningSubtle, other.warningSubtle),
      danger: c(danger, other.danger),
      dangerSubtle: c(dangerSubtle, other.dangerSubtle),
      info: c(info, other.info),
      infoSubtle: c(infoSubtle, other.infoSubtle),
      overlay: c(overlay, other.overlay),
      shadow: c(shadow, other.shadow),
      skeletonBase: c(skeletonBase, other.skeletonBase),
      skeletonHighlight: c(skeletonHighlight, other.skeletonHighlight),
    );
  }
}

/// `context.c.textPrimary` — the canonical way to read a colour token.
extension AppColorsX on BuildContext {
  AppColors get c =>
      Theme.of(this).extension<AppColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColors.dark
          : AppColors.light);

  bool get isDarkMode => c.isDark;
}
