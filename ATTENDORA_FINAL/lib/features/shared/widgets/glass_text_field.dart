import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/design/app_colors.dart';

class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.keyboardType,
    this.focusNode,
    this.hintText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final bool readOnly;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.c.textPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.c.textPrimary.withValues(alpha: 0.1)),
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        readOnly: readOnly,
        maxLines: maxLines,
        validator: validator,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: GoogleFonts.outfit(color: context.c.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.outfit(color: context.c.textSecondary),
          hintText: hintText,
          hintStyle: GoogleFonts.outfit(color: context.c.textTertiary),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: context.c.textSecondary, size: 20)
              : null,
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }
}
