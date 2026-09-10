import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/theme_controller.dart';

/// Compact light/dark/system switcher for app bars and settings rows.
///
/// Tapping cycles system -> light -> dark; long-pressing opens an explicit
/// picker so the current choice is always discoverable.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key, this.showLabel = false});

  /// When true the button renders the mode name next to the icon.
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final c = context.c;

    final icon = switch (mode) {
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
      ThemeMode.system => Icons.brightness_auto_rounded,
    };
    final label = switch (mode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    };

    return Tooltip(
      message: 'Theme: $label (tap to change, hold to pick)',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => ref.read(themeModeProvider.notifier).cycle(),
        onLongPress: () => _showPicker(context, ref, mode),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: showLabel ? 14 : 10,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => RotationTransition(
                  turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  icon,
                  key: ValueKey(mode),
                  size: 18,
                  color: c.textPrimary,
                ),
              ),
              if (showLabel) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPicker(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in const {
              ThemeMode.system: ('Use system setting', Icons.brightness_auto_rounded),
              ThemeMode.light: ('Light', Icons.light_mode_rounded),
              ThemeMode.dark: ('Dark', Icons.dark_mode_rounded),
            }.entries)
              ListTile(
                leading: Icon(entry.value.$2),
                title: Text(entry.value.$1),
                trailing: current == entry.key
                    ? Icon(Icons.check_rounded, color: sheetContext.c.primary)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(entry.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) {
      await ref.read(themeModeProvider.notifier).setMode(selected);
    }
  }
}

/// Segmented light/dark/system control for settings pages.
class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final c = context.c;

    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto_rounded, size: 18),
          label: Text('System'),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode_rounded, size: 18),
          label: Text('Light'),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode_rounded, size: 18),
          label: Text('Dark'),
        ),
      ],
      selected: {mode},
      showSelectedIcon: false,
      onSelectionChanged: (selection) =>
          ref.read(themeModeProvider.notifier).setMode(selection.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.primarySubtle
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.primary
              : c.textSecondary,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: c.border)),
      ),
    );
  }
}
