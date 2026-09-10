import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';

import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/background_pattern.dart';
import '../../student/providers.dart';
import 'student_shell.dart';
import '../../../core/responsive_utils.dart';
import '../../../core/design/app_colors.dart';

class StudentAnalyticsPage extends ConsumerWidget {
  const StudentAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = context.isMobile;

    return StudentShell(
      child: BackgroundPattern(
        child: ListView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          children: [
            FadeInDown(
              duration: const Duration(milliseconds: 600),
              child: Text(
                'Analytics',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: context.c.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeInDown(
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 100),
              child: Text(
                'Track your attendance trends over time.',
                style: GoogleFonts.outfit(fontSize: 16, color: context.c.textSecondary),
              ),
            ),
            const SizedBox(height: 32),

            // Trend Chart
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 200),
              child: const _AttendanceTrendChart(),
            ),

            const SizedBox(height: 24),

            // Subject Performance Breakdown
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 300),
              child: const _SubjectPerformanceList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceTrendChart extends ConsumerWidget {
  const _AttendanceTrendChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We need historical data. For now, we'll derive it from the attendance list.
    // In a real app, you might want a dedicated endpoint for aggregated history.
    final attendanceAsync = ref.watch(studentAttendanceStreamProvider);

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance Trend (Last 6 Months)',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.c.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: attendanceAsync.when(
              data: (records) {
                if (records.isEmpty) {
                  return Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(color: context.c.textTertiary),
                    ),
                  );
                }

                // Group by month
                final now = DateTime.now();
                final Map<int, List<bool>> monthlyStats = {};

                // Initialize last 6 months
                for (int i = 5; i >= 0; i--) {
                  final monthDate = DateTime(now.year, now.month - i, 1);
                  // Use a key like 202311 for Nov 2023
                  final key = monthDate.year * 100 + monthDate.month;
                  monthlyStats[key] = [];
                }

                for (final record in records) {
                  final date = record.timestamp;
                  final key = date.year * 100 + date.month;
                  if (monthlyStats.containsKey(key)) {
                    monthlyStats[key]!.add(record.result == 'Present');
                  }
                }

                // Convert to spots
                final spots = <FlSpot>[];
                int index = 0;
                final sortedKeys = monthlyStats.keys.toList()..sort();

                for (final key in sortedKeys) {
                  final stats = monthlyStats[key]!;
                  double percentage = 0;
                  if (stats.isNotEmpty) {
                    final present = stats.where((p) => p).length;
                    percentage = (present / stats.length) * 100;
                  }
                  spots.add(FlSpot(index.toDouble(), percentage));
                  index++;
                }

                return LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 20,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: context.c.textPrimary.withValues(alpha: 0.1),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final intVal = value.toInt();
                            if (intVal < 0 || intVal >= sortedKeys.length) {
                              return const Text('');
                            }

                            final key = sortedKeys[intVal];
                            final year = key ~/ 100;
                            final month = key % 100;
                            final date = DateTime(year, month);

                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('MMM').format(date),
                                style: TextStyle(
                                  color: context.c.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 20,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}%',
                              style: TextStyle(
                                color: context.c.textTertiary,
                                fontSize: 12,
                              ),
                            );
                          },
                          reservedSize: 40,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 5,
                    minY: 0,
                    maxY: 100,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        gradient: LinearGradient(
                          colors: [context.c.accent, context.c.primary],
                        ),
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              context.c.accent.withValues(alpha: 0.3),
                              context.c.primary.withValues(alpha: 0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Error: $e',
                  style: TextStyle(color: context.c.danger),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectPerformanceList extends ConsumerWidget {
  const _SubjectPerformanceList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(studentSubjectsWithStatsProvider);

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subject Performance',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.c.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          subjectsAsync.when(
            data: (subjects) {
              if (subjects.isEmpty) {
                return Text(
                  'No subjects found.',
                  style: TextStyle(color: context.c.textTertiary),
                );
              }

              return Column(
                children: subjects.map((subject) {
                  final stats = subject['stats'] as Map<String, dynamic>?;
                  final percentage = stats?['percentage'] as double? ?? 0.0;
                  final total = stats?['total'] as int? ?? 0;
                  final attended = stats?['attended'] as int? ?? 0;

                  Color progressColor = context.c.accent; // Green
                  if (percentage < 75) {
                    progressColor = context.c.danger; // Red
                  } else if (percentage < 85) {
                    progressColor = context.c.warning; // Orange
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                subject['name'] ?? 'Unknown',
                                style: TextStyle(
                                  color: context.c.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: progressColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: total > 0 ? percentage / 100 : 0,
                            backgroundColor: context.c.textPrimary.withValues(
                              alpha: 0.1,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progressColor,
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$attended / $total sessions attended',
                          style: TextStyle(
                            color: context.c.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              'Error loading subjects: $e',
              style: TextStyle(color: context.c.danger),
            ),
          ),
        ],
      ),
    );
  }
}
