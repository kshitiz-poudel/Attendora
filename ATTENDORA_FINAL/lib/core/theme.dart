import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design/app_colors.dart';

class AttendoraTheme {
  AttendoraTheme({required this.light, required this.dark});

  final ThemeData light;
  final ThemeData dark;
}

/// Builds the real light and dark themes. Both are generated from the same
/// [AppColors] token set so the two modes stay in lockstep.
AttendoraTheme buildAttendoraTheme() => AttendoraTheme(
  light: _buildTheme(AppColors.light),
  dark: _buildTheme(AppColors.dark),
);

ThemeData _buildTheme(AppColors c) {
  final isDark = c.isDark;
  final base = isDark
      ? ThemeData.dark(useMaterial3: true)
      : ThemeData.light(useMaterial3: true);

  final baseTextTheme = GoogleFonts.outfitTextTheme(base.textTheme);
  final textTheme = baseTextTheme
      .apply(bodyColor: c.textPrimary, displayColor: c.textPrimary)
      .copyWith(
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: c.textSecondary),
        bodySmall: baseTextTheme.bodySmall?.copyWith(color: c.textSecondary),
        labelSmall: baseTextTheme.labelSmall?.copyWith(color: c.textTertiary),
      );

  final colorScheme = ColorScheme(
    brightness: c.brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    primaryContainer: c.primarySubtle,
    onPrimaryContainer: c.textPrimary,
    secondary: c.accent,
    onSecondary: c.onAccent,
    secondaryContainer: c.accentSubtle,
    onSecondaryContainer: c.textPrimary,
    tertiary: c.info,
    onTertiary: c.onPrimary,
    error: c.danger,
    onError: c.textInverse,
    errorContainer: c.dangerSubtle,
    onErrorContainer: c.textPrimary,
    surface: c.surface,
    onSurface: c.textPrimary,
    surfaceContainerHighest: c.surfaceMuted,
    onSurfaceVariant: c.textSecondary,
    outline: c.border,
    outlineVariant: c.borderStrong,
    shadow: c.shadow,
    scrim: c.overlay,
    inverseSurface: c.textPrimary,
    onInverseSurface: c.canvas,
    inversePrimary: c.primaryHover,
  );

  return base.copyWith(
    brightness: c.brightness,
    scaffoldBackgroundColor: c.canvas,
    canvasColor: c.canvas,
    colorScheme: colorScheme,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[c],
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: c.textSecondary),
    primaryIconTheme: IconThemeData(color: c.textPrimary),
    appBarTheme: AppBarTheme(
      backgroundColor: c.canvas,
      foregroundColor: c.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.outfit(
        color: c.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: c.textPrimary),
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.border, width: 1),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.border),
      ),
      titleTextStyle: GoogleFonts.outfit(
        color: c.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: GoogleFonts.outfit(
        color: c.textSecondary,
        fontSize: 14,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      textStyle: GoogleFonts.outfit(color: c.textPrimary, fontSize: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.border),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: GoogleFonts.outfit(color: c.textPrimary, fontSize: 14),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceMuted,
      hintStyle: TextStyle(color: c.textTertiary),
      labelStyle: TextStyle(color: c.textSecondary),
      floatingLabelStyle: TextStyle(color: c.primary),
      prefixIconColor: c.textTertiary,
      suffixIconColor: c.textTertiary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.danger, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        disabledBackgroundColor: c.surfaceMuted,
        disabledForegroundColor: c.textTertiary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.textPrimary,
        side: BorderSide(color: c.borderStrong),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primary,
        textStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surfaceMuted,
      side: BorderSide(color: c.border),
      labelStyle: GoogleFonts.outfit(color: c.textPrimary, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: c.primary,
      unselectedLabelColor: c.textSecondary,
      indicatorColor: c.primary,
      dividerColor: c.border,
      labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.surfaceRaised,
      contentTextStyle: GoogleFonts.outfit(color: c.textPrimary),
      actionTextColor: c.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      textStyle: GoogleFonts.outfit(color: c.textPrimary, fontSize: 12),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.textTertiary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.primary : c.surfaceMuted,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.primary : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(c.onPrimary),
      side: BorderSide(color: c.borderStrong, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.primary : c.borderStrong,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.primary,
      linearTrackColor: c.surfaceMuted,
      circularTrackColor: c.surfaceMuted,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.textSecondary,
      textColor: c.textPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.primarySubtle,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.outfit(fontSize: 12, color: c.textSecondary),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: c.surface,
      selectedIconTheme: IconThemeData(color: c.primary),
      unselectedIconTheme: IconThemeData(color: c.textSecondary),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: c.canvas,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
