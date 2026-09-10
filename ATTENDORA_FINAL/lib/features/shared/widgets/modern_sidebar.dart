import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/app_colors.dart';
import 'theme_toggle_button.dart';

/// Modern sidebar widget with improved Material Design 3 styling
class ModernSidebar extends StatelessWidget {
  const ModernSidebar({
    super.key,
    required this.items,
    required this.currentPath,
    this.header,
    this.footer,
  });

  final List<SidebarItem> items;
  final String currentPath;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.c.canvas, context.c.surface],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            if (header != null) header! else const _DefaultHeader(),

            const SizedBox(height: 8),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final item in items)
                    if (item.isDivider)
                      const _SidebarDivider()
                    else if (item.isHeader)
                      _SidebarHeader(label: item.label!)
                    else
                      _SidebarNavItem(
                        item: item,
                        isSelected: _isSelected(currentPath, item.path),
                        onTap: () => _handleNavigation(context, item),
                      ),
                ],
              ),
            ),

            // Theme switcher, pinned above the footer so it is reachable on
            // desktop layouts where there is no app bar.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ThemeToggleButton(showLabel: true),
              ),
            ),

            // Footer
            if (footer != null)
              Padding(padding: const EdgeInsets.all(12), child: footer!),
          ],
        ),
      ),
    );
  }

  bool _isSelected(String currentPath, String? itemPath) {
    if (itemPath == null) return false;
    if (currentPath == itemPath) return true;
    // Check if current path starts with item path (for nested routes)
    if (itemPath != '/' && currentPath.startsWith(itemPath)) return true;
    return false;
  }

  void _handleNavigation(BuildContext context, SidebarItem item) {
    if (item.onTap != null) {
      item.onTap!();
    } else if (item.path != null) {
      context.go(item.path!);
    }
  }
}

class _DefaultHeader extends StatelessWidget {
  const _DefaultHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.c.accent, context.c.success],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: context.c.accent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.qr_code_2_rounded,
              color: context.c.textPrimary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ATTENDORA',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: context.c.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Smart Attendance',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.c.textTertiary,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  const _SidebarNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final SidebarItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final color = isSelected ? context.c.textPrimary : context.c.textSecondary;
    final iconColor = isSelected
        ? context.c.accent
        : context.c.textTertiary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      context.c.accent.withValues(alpha: 0.15),
                      context.c.success.withValues(alpha: 0.1),
                    ],
                  )
                : _isHovered
                ? LinearGradient(
                    colors: [
                      context.c.textPrimary.withValues(alpha: 0.05),
                      context.c.textPrimary.withValues(alpha: 0.02),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: context.c.accent.withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.c.accent.withValues(alpha: 0.2)
                            : _isHovered
                            ? context.c.textPrimary.withValues(alpha: 0.05)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(widget.item.icon, size: 20, color: iconColor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.item.label!,
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    if (widget.item.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.c.danger,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.item.badge!,
                          style: TextStyle(
                            color: context.c.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (isSelected)
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.c.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              context.c.border.withValues(alpha: 0.5),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: context.c.textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

/// Model class for sidebar items
class SidebarItem {
  final String? label;
  final IconData? icon;
  final String? path;
  final VoidCallback? onTap;
  final String? badge;
  final bool isDivider;
  final bool isHeader;

  const SidebarItem({
    this.label,
    this.icon,
    this.path,
    this.onTap,
    this.badge,
    this.isDivider = false,
    this.isHeader = false,
  });

  factory SidebarItem.divider() => const SidebarItem(isDivider: true);

  factory SidebarItem.header(String label) =>
      SidebarItem(label: label, isHeader: true);
}
