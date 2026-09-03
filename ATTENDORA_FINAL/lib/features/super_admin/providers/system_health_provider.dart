import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SystemStatus { healthy, degraded, down }

enum ServerLoad { low, medium, high }

/// Monitors the application's Firestore connection.
///
/// Attendora is a Firebase-based application, so a successful Firestore
/// realtime snapshot is treated as a healthy system connection. This avoids
/// repeatedly forcing one-shot server reads, which could incorrectly mark the
/// system as down even while the application's other Firestore streams are
/// working normally.
final systemHealthProvider = StreamProvider<SystemStatus>((ref) {
  return FirebaseFirestore.instance
      .collection('institutions')
      .limit(1)
      .snapshots()
      .map<SystemStatus>((_) => SystemStatus.healthy)
      .handleError((Object error, StackTrace stackTrace) {
        // Log the problem without converting every transient Firestore error
        // into a permanent "server down" status.
        // ignore: avoid_print
        print('System health stream error: $error');
      });
});

/// Estimates application load from the number of active attendance sessions.
/// Sessions are stored in Attendora's top-level `sessions` collection.
final serverLoadProvider = StreamProvider<ServerLoad>((ref) {
  return FirebaseFirestore.instance
      .collection('sessions')
      .where('active', isEqualTo: true)
      .snapshots()
      .map<ServerLoad>((snapshot) {
        final count = snapshot.docs.length;

        if (count < 10) return ServerLoad.low;
        if (count < 50) return ServerLoad.medium;
        return ServerLoad.high;
      });
});
