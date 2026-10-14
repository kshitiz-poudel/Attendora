import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/app_colors.dart';
import 'core/design/theme_controller.dart';
import 'core/notification_listener.dart';
import 'core/router.dart';
import 'core/theme.dart';

class AttendoraApp extends ConsumerWidget {
  const AttendoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final theme = buildAttendoraTheme();
    final themeMode = ref.watch(themeModeProvider);

    // Watch the notification listener to activate it
    ref.watch(notificationListenerProvider);

    return MaterialApp.router(
      title: 'Attendora',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _AppScrollBehavior(),
      theme: theme.light,
      darkTheme: theme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        // Keep the Android system bars in step with the resolved theme.
        final isDark = resolveIsDark(themeMode, context);
        final colors = isDark ? AppColors.dark : AppColors.light;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: colors.canvas,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: _SandboxBanner(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // No glow on web; clean minimal scroll like shadcn sites
    return child;
  }
}

/// A corner ribbon shown only when running against the local Firebase
/// emulators, so nobody mistakes fake test data for the real system. (The
/// "emulator mode" banner Firebase draws itself exists only on the web.)
class _SandboxBanner extends StatelessWidget {
  const _SandboxBanner({required this.child});

  final Widget child;

  static const bool _enabled = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return child;
    return Banner(
      message: 'SANDBOX',
      location: BannerLocation.topEnd,
      color: const Color(0xFFB45309),
      child: child,
    );
  }
}
