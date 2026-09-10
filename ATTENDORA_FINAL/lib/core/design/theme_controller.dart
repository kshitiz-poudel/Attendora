import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted light / dark / system preference.
///
/// The stored value survives restarts and is restored before the first frame
/// paints (see `main.dart`), so the app never flashes the wrong theme.
class ThemeModeController extends Notifier<ThemeMode> {
  static const _prefsKey = 'attendora.themeMode';

  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      final restored = _decode(stored);
      if (restored != null) state = restored;
    } catch (_) {
      // A missing or unreadable preference store just means we keep the
      // system default; never block startup on it.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (_) {
      // Preference persistence is best-effort; the in-memory choice still
      // applies for this session.
    }
  }

  /// Cycles system -> light -> dark -> system, for a single-tap toggle button.
  Future<void> cycle() async {
    switch (state) {
      case ThemeMode.system:
        await setMode(ThemeMode.light);
      case ThemeMode.light:
        await setMode(ThemeMode.dark);
      case ThemeMode.dark:
        await setMode(ThemeMode.system);
    }
  }

  static ThemeMode? _decode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

/// True when the *resolved* theme is dark, accounting for `ThemeMode.system`.
bool resolveIsDark(ThemeMode mode, BuildContext context) {
  switch (mode) {
    case ThemeMode.light:
      return false;
    case ThemeMode.dark:
      return true;
    case ThemeMode.system:
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }
}
