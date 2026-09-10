import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/error_handler.dart';
import '../../auth/providers.dart';
import 'empty_state.dart';
import 'glass_card.dart';
import 'shimmer_loading.dart';

// Provider for low attendance alerts - connected to real Firestore data
import 'package:async/async.dart';
import '../../../core/design/app_colors.dart';

// Provider for alerts - connected to real Firestore data via Streams
final lowAttendanceAlertsProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final auth = ref.watch(authControllerProvider);
  final code = auth.institutionCode;
  final isSuperAdmin = auth.isSuperAdmin;

  // Safety check for institution code
  if (!isSuperAdmin && (code == null || code.isEmpty)) {
    return Stream.value([]);
  }

  // 1. Pending Teachers Stream
  // AVOID COMPOSITE INDEX (role + approved + institutionCode)
  // Query by institutionCode (if exists) or role, filter rest in memory.
  Query<Map<String, dynamic>> pendingQ = FirebaseFirestore.instance.collection(
    'users',
  );

  if (!isSuperAdmin && code != null) {
    pendingQ = pendingQ.where('institutionCode', isEqualTo: code);
  } else {
    pendingQ = pendingQ.where('role', isEqualTo: 'teacher');
  }

  // 2. New Institutions Stream (Super Admin only, or empty for others)
  Query<Map<String, dynamic>> institutionsQ = FirebaseFirestore.instance
      .collection('institutions')
      // Removed orderBy('createdAt') to avoid Web SDK crash on mixed types
      .limit(50); 

  // 3. Students Stream (for low attendance check)
  // AVOID COMPOSITE INDEX (role + institutionCode)
  Query<Map<String, dynamic>> studentsQ = FirebaseFirestore.instance.collection(
    'users',
  );

  if (!isSuperAdmin && code != null) {
    studentsQ = studentsQ.where('institutionCode', isEqualTo: code);
  } else {
    studentsQ = studentsQ.where('role', isEqualTo: 'student').limit(20);
  }

  // 4. Recent Sessions Stream (for attendance calculation context)
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

  // SESSION QUERY: Avoid composite index (institutionCode + createdAt).
  // Query by institutionCode only (auto-index), then filter by date in memory.
  Query<Map<String, dynamic>> sessionsQ = FirebaseFirestore.instance.collection(
    'sessions',
  );

  if (!isSuperAdmin && code != null) {
    sessionsQ = sessionsQ.where('institutionCode', isEqualTo: code);
  } else {
    // Fetch limited sessions to avoid massive reads, filter createdAt in memory
    sessionsQ = sessionsQ.limit(100);
  }

  // Combine streams
  return StreamZip([
    pendingQ.snapshots(),
    institutionsQ.snapshots(),
    studentsQ.snapshots(),
    sessionsQ.snapshots(),
  ]).asyncMap((results) async {
    final pendingSnap = results[0];
    final institutionsSnap = results[1];
    final studentsSnap = results[2];
    final sessionsSnap = results[3];

    final alerts = <Map<String, dynamic>>[];

    // Process Pending Teachers
    for (final doc in pendingSnap.docs) {
      final data = doc.data();
      // In-memory filter: Must be teacher and not approved
      if (data['role'] != 'teacher' || data['approved'] == true) continue;

      alerts.add({
        'type': 'pending_approval',
        'teacherName': data['displayName'] ?? 'Unknown',
        'teacherId': doc.id,
        'severity': 'info',
      });
    }

    // Process New Institutions (only show if recently created)
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    for (final doc in institutionsSnap.docs) {
      final data = doc.data();
      // In-memory filter: Must be Active
      if (data['status'] != 'Active') continue;

      final rawCreatedAt = data['createdAt'];
      DateTime? createdAt;
      if (rawCreatedAt is Timestamp) {
        createdAt = rawCreatedAt.toDate();
      } else if (rawCreatedAt is String) {
        createdAt = DateTime.tryParse(rawCreatedAt);
      }
      
      if (createdAt != null && createdAt.isAfter(sevenDaysAgo)) {
        alerts.add({
          'type': 'new_institution',
          'institutionName': doc.data()['name'] ?? 'Unknown',
          'institutionCode': doc.data()['code'] ?? doc.id,
          'severity': 'info',
        });
      }
    }

    // Process Low Attendance
    // Filter sessions for last 30 days in memory (if not done by query)
    final recentSessions = sessionsSnap.docs.where((doc) {
      final rawCreatedAt = doc.data()['createdAt'];
      DateTime? createdAt;
      if (rawCreatedAt is Timestamp) {
        createdAt = rawCreatedAt.toDate();
      } else if (rawCreatedAt is String) {
        createdAt = DateTime.tryParse(rawCreatedAt);
      }
      return createdAt != null && createdAt.isAfter(thirtyDaysAgo);
    }).toList();

    final totalSessions = recentSessions.length;

    if (totalSessions > 0 && studentsSnap.docs.isNotEmpty) {
      // SESSION-BASED ATTENDANCE FETCH
      // Avoid collectionGroup index. Fetch attendance for each recent session.

      final attendanceByStudent = <String, int>{};

      // We limit to checking the last 20 sessions to avoid excessive reads
      final sessionsToCheck = recentSessions.toList()
        ..sort((a, b) {
          final aRaw = a.data()['createdAt'];
          final bRaw = b.data()['createdAt'];
          
          DateTime? aDate;
          if (aRaw is Timestamp) aDate = aRaw.toDate();
          else if (aRaw is String) aDate = DateTime.tryParse(aRaw);

          DateTime? bDate;
          if (bRaw is Timestamp) bDate = bRaw.toDate();
          else if (bRaw is String) bDate = DateTime.tryParse(bRaw);

          if (aDate == null || bDate == null) return 0;
          return bDate.compareTo(aDate);
        });

      final limitedSessions = sessionsToCheck.take(20).toList();

      final attendanceFutures = limitedSessions.map(
        (sessionDoc) => sessionDoc.reference.collection('attendance').get(),
      );

      final attendanceSnaps = await Future.wait(attendanceFutures);

      for (final attSnap in attendanceSnaps) {
        for (final doc in attSnap.docs) {
          final data = doc.data();
          if (data['status'] != 'present') continue;

          final uid = data['uid'] as String?;
          if (uid != null) {
            attendanceByStudent[uid] = (attendanceByStudent[uid] ?? 0) + 1;
          }
        }
      }

      for (final studentDoc in studentsSnap.docs) {
        final studentData = studentDoc.data();

        // In-memory filter: Must be student
        if (studentData['role'] != 'student') continue;

        // Check if student joined more than 30 days ago
        final rawJoinedAt = studentData['createdAt'];
        DateTime? joinedAt;
        if (rawJoinedAt is Timestamp) joinedAt = rawJoinedAt.toDate();
        else if (rawJoinedAt is String) joinedAt = DateTime.tryParse(rawJoinedAt);
        if (joinedAt == null || joinedAt.isAfter(thirtyDaysAgo)) continue;

        final attendedCount = attendanceByStudent[studentDoc.id] ?? 0;
        // Calculate percentage based on the sessions we actually checked (limitedSessions)
        final denominator = limitedSessions.length;

        if (denominator == 0) continue;

        final attendancePercentage = (attendedCount / denominator * 100).clamp(
          0.0,
          100.0,
        );

        // Only alert if attendance is below 50%
        if (attendancePercentage < 50) {
          alerts.add({
            'type': 'low_attendance',
            'studentName': studentData['displayName'] ?? 'Unknown',
            'studentId':
                studentData['idNumber'] ??
                studentData['rollNumber'] ??
                studentDoc.id,
            'percentage': attendancePercentage,
            'severity': 'critical', // Always critical if < 50%
          });
        }
      }
    }

    return alerts;
  });
});

class AlertsCard extends ConsumerWidget {
  const AlertsCard({super.key});

  IconData _getAlertIcon(String type) {
    switch (type) {
      case 'low_attendance':
        return Icons.warning_amber_rounded;
      case 'pending_approval':
        return Icons.approval;
      case 'new_institution':
        return Icons.corporate_fare;
      default:
        return Icons.info_outline;
    }
  }

  Color _getSeverityColor(BuildContext context, String severity) {
    switch (severity) {
      case 'critical':
        return context.c.danger;
      case 'warning':
        return context.c.warning;
      case 'info':
        return context.c.primary;
      default:
        return context.c.textTertiary;
    }
  }

  String _getAlertMessage(Map<String, dynamic> alert) {
    final type = alert['type'] as String;
    switch (type) {
      case 'low_attendance':
        final name = alert['studentName'] as String;
        final percentage = (alert['percentage'] as double).toStringAsFixed(0);
        return '$name has low attendance ($percentage%)';
      case 'pending_approval':
        final name = alert['teacherName'] as String;
        return 'Teacher $name pending approval';
      case 'new_institution':
        final name = alert['institutionName'] as String;
        return 'New institution added: $name';
      default:
        return 'New alert';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(lowAttendanceAlertsProvider);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [context.c.warning, Color(0xFFF97316)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.notifications_active,
                  color: context.c.textPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Alerts & Reminders',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.c.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.c.danger,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: alertsAsync.when(
                  data: (alerts) => Text(
                    '${alerts.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.c.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  loading: () => SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(context.c.textPrimary),
                    ),
                  ),
                  error: (_, __) => Text(
                    '0',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.c.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          alertsAsync.when(
            data: (alerts) {
              if (alerts.isEmpty) {
                return EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'All Clear!',
                  subtitle: 'No alerts or warnings at this time',
                  color: context.c.success,
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: alerts.length > 5 ? 5 : alerts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final alert = alerts[index];
                  final severity = alert['severity'] as String;
                  final type = alert['type'] as String;
                  final color = _getSeverityColor(context, severity);
                  final icon = _getAlertIcon(type);
                  final message = _getAlertMessage(alert);

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: context.c.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: context.c.textTertiary,
                          ),
                          iconSize: 14,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => const ShimmerListTile(),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: ErrorHandler.buildErrorWidget(
                  e,
                  customMessage: 'Unable to load alerts',
                ),
              ),
            ),
          ),
          if (alertsAsync.hasValue && alertsAsync.value!.length > 5) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () {},
                child: const Text('View All Alerts'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
