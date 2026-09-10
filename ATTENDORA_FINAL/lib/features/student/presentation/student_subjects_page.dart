import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/error_handler.dart';

import 'package:attendora/core/responsive_utils.dart';
import 'package:attendora/features/student/presentation/student_shell.dart';
import 'package:attendora/features/student/providers.dart';

import '../../shared/widgets/background_pattern.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/glass_text_field.dart';
import '../../shared/widgets/async_section.dart';
import '../../../core/design/app_colors.dart';

class StudentSubjectsPage extends ConsumerStatefulWidget {
  const StudentSubjectsPage({super.key});

  @override
  ConsumerState<StudentSubjectsPage> createState() =>
      _StudentSubjectsPageState();
}

class _StudentSubjectsPageState extends ConsumerState<StudentSubjectsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(studentSubjectsWithStatsProvider);

    return StudentShell(
      child: BackgroundPattern(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            subjectsAsync.when(
              data: (subjects) {
                // Filter subjects based on search query
                final filteredSubjects = subjects.where((subject) {
                  final name = (subject['name'] as String? ?? '').toLowerCase();
                  final code = (subject['code'] as String? ?? '').toLowerCase();
                  final query = _searchQuery.toLowerCase();
                  return name.contains(query) || code.contains(query);
                }).toList();

                if (filteredSubjects.isEmpty) {
                  return FadeInUp(
                    duration: const Duration(milliseconds: 500),
                    child: GlassCard(
                      padding: const EdgeInsets.all(48),
                      child: EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No Subjects Found',
                        subtitle: _searchQuery.isEmpty
                            ? 'You are not enrolled in any subjects yet'
                            : 'No subjects match "$_searchQuery"',
                        color: context.c.textTertiary,
                      ),
                    ),
                  );
                }

                return Column(
                  children: filteredSubjects.map((subject) {
                    return _StudentSubjectCard(subject: subject);
                  }).toList(),
                );
              },
              // Content-shaped placeholder: the page keeps its layout while
              // subjects, attendance and sessions finish loading, instead of
              // briefly showing every subject at 0%.
              loading: () => const SkeletonList(rows: 5),
              error: (error, _) => Center(
                child: GlassCard(
                  padding: const EdgeInsets.all(32),
                  child: ErrorHandler.buildErrorWidget(
                    error,
                    customMessage: 'Unable to load subjects',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isMobile = context.isMobile;

    return FadeInDown(
      duration: const Duration(milliseconds: 400),
      child: GlassCard(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.c.accent.withValues(alpha: 0.2),
                        context.c.accent.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.library_books_rounded,
                    color: context.c.accent,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Subjects',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: context.c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View your enrolled subjects and attendance',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: context.c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GlassTextField(
              controller: _searchController,
              label: 'Search',
              onChanged: (value) => setState(() => _searchQuery = value),
              hintText: 'Search subjects...',
              prefixIcon: Icons.search,
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentSubjectCard extends StatefulWidget {
  final Map<String, dynamic> subject;

  const _StudentSubjectCard({required this.subject});

  @override
  State<_StudentSubjectCard> createState() => _StudentSubjectCardState();
}

class _StudentSubjectCardState extends State<_StudentSubjectCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    final name = subject['name'] as String? ?? 'Unknown Subject';
    final code = subject['code'] as String? ?? '';
    final type = subject['type'] as String? ?? 'Lecture';
    final stats = subject['stats'] as Map<String, dynamic>?;
    final percentage = stats != null ? (stats['percentage'] as double) : 0.0;
    final attended = stats != null ? (stats['attended'] as int) : 0;
    final total = stats != null ? (stats['total'] as int) : 0;

    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                  bottom: Radius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.c.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.class_,
                          color: context.c.accent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: context.c.textPrimary,
                              ),
                            ),
                            if (code.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '$code • $type',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: context.c.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Attendance Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getAttendanceColor(percentage)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getAttendanceColor(percentage)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _getAttendanceColor(percentage),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: context.c.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),

              // Detained Banner
              if (subject['detained'] == true)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.c.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: context.c.danger.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.block_rounded,
                        color: context.c.danger,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You have been detained from this course.',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.c.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Expanded Details
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Column(
                  children: [
                    Divider(
                      height: 1,
                      color: context.c.textPrimary.withValues(alpha: 0.1),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attendance Details',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Responsive Stats Layout
                          LayoutBuilder(
                            builder: (context, constraints) {
                              // If width is small (mobile), use Column or Wrap
                              // The card padding is 24, so available width is screen width - 48 (outer) - 48 (inner) approx
                              // A safe breakpoint for 3 cards side-by-side is around 400-500px
                              final isNarrow = constraints.maxWidth < 500;

                              if (isNarrow) {
                                return Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _StatCard(
                                            label: 'Attended',
                                            value: '$attended',
                                            icon: Icons.check_circle_outline,
                                            color: context.c.success,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _StatCard(
                                            label: 'Total',
                                            value: '$total',
                                            icon: Icons.calendar_today_outlined,
                                            color: context.c.info,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: _StatCard(
                                        label: 'Missed',
                                        value: '${total - attended}',
                                        icon: Icons.cancel_outlined,
                                        color: context.c.danger,
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                return Row(
                                  children: [
                                    Expanded(
                                      child: _StatCard(
                                        label: 'Attended',
                                        value: '$attended',
                                        icon: Icons.check_circle_outline,
                                        color: context.c.success,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _StatCard(
                                        label: 'Total Sessions',
                                        value: '$total',
                                        icon: Icons.calendar_today_outlined,
                                        color: context.c.info,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _StatCard(
                                        label: 'Missed',
                                        value: '${total - attended}',
                                        icon: Icons.cancel_outlined,
                                        color: context.c.danger,
                                      ),
                                    ),
                                  ],
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                          // Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: total > 0 ? attended / total : 0,
                              minHeight: 8,
                              backgroundColor: context.c.textPrimary.withValues(
                                alpha: 0.1,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getAttendanceColor(percentage),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getAttendanceColor(double percentage) {
    if (percentage >= 75) return context.c.accent;
    if (percentage >= 60) return context.c.warning;
    return context.c.danger;
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.c.textPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.c.textPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.c.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 12, color: context.c.textTertiary),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: color.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.c.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: context.c.textTertiary),
          ),
        ],
      ),
    );
  }
}
