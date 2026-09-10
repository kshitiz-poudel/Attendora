import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/design/app_colors.dart';

class GlassDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  final String hint;
  final Widget? icon;

  const GlassDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: context.c.textPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.c.textPrimary.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          hint: Row(
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 12)],
              Text(hint, style: GoogleFonts.outfit(color: context.c.textTertiary)),
            ],
          ),
          dropdownColor: context.c.surface,
          style: GoogleFonts.outfit(color: context.c.textPrimary),
          icon: Icon(Icons.arrow_drop_down, color: context.c.textTertiary),
          isExpanded: true,
        ),
      ),
    );
  }
}
