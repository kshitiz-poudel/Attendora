import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_colors.dart';
import 'shimmer_loading.dart';

/// Renders an [AsyncValue] with a consistent loading skeleton, error card and
/// empty state, so no screen paints a "real looking" result from data that has
/// not arrived yet.
///
/// Prefer this over `asyncValue.when(...)` with an ad-hoc spinner: it keeps a
/// stale value visible during a background refresh (avoiding a flash back to
/// the skeleton), and gives errors a retry affordance.
class AsyncSection<T> extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.value,
    required this.builder,
    this.skeleton,
    this.onRetry,
    this.isEmpty,
    this.emptyBuilder,
    this.errorTitle = 'Could not load this section',
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) builder;

  /// Shown while the first load is in flight. Defaults to a shimmering list.
  final Widget? skeleton;

  /// When provided, an error state offers a retry button.
  final VoidCallback? onRetry;

  /// Optional emptiness test; when it returns true [emptyBuilder] is used.
  final bool Function(T data)? isEmpty;
  final WidgetBuilder? emptyBuilder;

  final String errorTitle;

  @override
  Widget build(BuildContext context) {
    // A refresh that already has data keeps rendering that data; only the
    // very first load shows the skeleton.
    if (value.hasValue && !value.hasError) {
      final data = value.requireValue;
      if (isEmpty != null && isEmpty!(data) && emptyBuilder != null) {
        return emptyBuilder!(context);
      }
      return builder(context, data);
    }

    if (value.hasError) {
      return _ErrorCard(
        title: errorTitle,
        message: _describe(value.error),
        onRetry: onRetry,
      );
    }

    return skeleton ?? const SkeletonList();
  }

  static String _describe(Object? error) {
    if (error == null) return 'Unknown error.';
    final text = error.toString();
    return text.startsWith('Exception: ')
        ? text.substring('Exception: '.length)
        : text;
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.title, required this.message, this.onRetry});

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.dangerSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.danger.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: c.danger, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: c.textSecondary, fontSize: 13)),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shimmering placeholder rows, sized like a typical list.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 4});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      isLoading: true,
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Skeleton(width: 44, height: 44, borderRadius: 22),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(width: double.infinity, height: 14),
                        SizedBox(height: 8),
                        Skeleton(width: 120, height: 11),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Shimmering placeholder for a grid of metric tiles.
class SkeletonCardGrid extends StatelessWidget {
  const SkeletonCardGrid({
    super.key,
    this.count = 4,
    this.columns = 2,
    this.tileHeight = 110,
  });

  final int count;
  final int columns;
  final double tileHeight;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      isLoading: true,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: tileHeight,
        ),
        itemBuilder: (_, __) => const Skeleton(borderRadius: 16),
      ),
    );
  }
}

/// Single-line shimmering placeholder, for inline values inside a card.
class SkeletonText extends StatelessWidget {
  const SkeletonText({super.key, this.width = 80, this.height = 14});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      isLoading: true,
      child: Skeleton(width: width, height: height, borderRadius: 6),
    );
  }
}
