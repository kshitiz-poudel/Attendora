import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 1. Real-time Active Sessions Count
final activeSessionsCountProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('sessions')
      .where('active', isEqualTo: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.length,
      ); // snapshot.count is not available in stream directly
});

// 2. Real-time Today's Sessions Count
final todaySessionsCountProvider = StreamProvider.autoDispose<int>((ref) {
  // Disabled where('createdAt') due to Firestore Web SDK crash on mixed types
  return Stream.value(0);
});

// 3. Total Counts (Future - refreshed on load)
final totalStatsProvider =
    FutureProvider.autoDispose<({int students, int sessions})>((ref) async {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'student')
            .count()
            .get(),
        FirebaseFirestore.instance.collection('sessions').count().get(),
      ]);

      return (students: results[0].count ?? 0, sessions: results[1].count ?? 0);
    });

// 4. Attendance Stats (Future - Expensive)
final attendanceStatsProvider =
    FutureProvider.autoDispose<({int totalRecords, double avgPerSession})>((
      ref,
    ) async {
      final totalSessionsSnap = await FirebaseFirestore.instance
          .collection('sessions')
          .count()
          .get();
      final totalSessions = totalSessionsSnap.count ?? 0;

      if (totalSessions == 0) return (totalRecords: 0, avgPerSession: 0.0);

      // Estimate based on recent 10 sessions to avoid reading ALL sessions
      final recentSessions = await FirebaseFirestore.instance
          .collection('sessions')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      int sampleAttendance = 0;
      for (final doc in recentSessions.docs) {
        final count =
            (await doc.reference.collection('attendance').count().get())
                .count ??
            0;
        sampleAttendance += count;
      }

      if (recentSessions.docs.isEmpty) {
        return (totalRecords: 0, avgPerSession: 0.0);
      }

      final avg = sampleAttendance / recentSessions.docs.length;
      final estimatedTotal = (avg * totalSessions).round();

      return (totalRecords: estimatedTotal, avgPerSession: avg);
    });

// 5. Recent Activity Stream (Optimized)
final recentActivityProvider = StreamProvider.autoDispose<List<ActivityItem>>((
  ref,
) {
  // Disabled orderBy('createdAt') due to Firestore Web SDK crash on mixed types
  return Stream.value([]);
});

DateTime? _parseTimestamp(dynamic timestamp) {
  if (timestamp == null) return null;
  if (timestamp is Timestamp) return timestamp.toDate();
  if (timestamp is DateTime) return timestamp;
  return null;
}

class ActivityItem {
  final String id;
  final String teacherName;
  final String subject;
  final int attendanceCount;
  final DateTime? timestamp;
  final bool isActive;

  ActivityItem({
    required this.id,
    required this.teacherName,
    required this.subject,
    required this.attendanceCount,
    this.timestamp,
    required this.isActive,
  });
}
