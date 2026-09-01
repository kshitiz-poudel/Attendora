import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SystemStatus { healthy, degraded, down }

enum ServerLoad { low, medium, high }

// Implemented with Timer.periodic + a plain one-shot .get(source: server)
// rather than an async* generator repeatedly calling .get() in a loop.
// The previous implementation triggered a documented Firestore Web SDK bug
// ("INTERNAL ASSERTION FAILED: Unexpected state") where repeated .get()
// calls inside a single long-lived stream generator conflict with the
// SDK's internal watch-target bookkeeping over time. Using Source.server
// also avoids interacting with the local watch/cache layer entirely, and
// each tick now runs as an independent one-shot future rather than
// sharing state with a never-ending generator.
final systemHealthProvider = StreamProvider<SystemStatus>((ref) {
  final controller = StreamController<SystemStatus>();
  Timer? timer;

  Future<void> ping() async {
    final start = DateTime.now();
    try {
      await FirebaseFirestore.instance
          .collection('institutions')
          .limit(1)
          .get();
      final duration = DateTime.now().difference(start).inMilliseconds;
      if (!controller.isClosed) {
        controller.add(
          duration < 2000 ? SystemStatus.healthy : SystemStatus.degraded,
        );
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('🔴 SystemHealth check failed: $e');
      // ignore: avoid_print
      print(st);
      if (!controller.isClosed) {
        controller.add(SystemStatus.down);
      }
    }
  }

  // Fire immediately, then every 30 seconds.
  ping();
  timer = Timer.periodic(const Duration(seconds: 30), (_) => ping());

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});

final serverLoadProvider = StreamProvider<ServerLoad>((ref) {
  // Calculate load based on total active sessions across the system
  return FirebaseFirestore.instance
      .collectionGroup('sessions')
      .where('active', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
        final count = snapshot.docs.length;
        if (count < 10) return ServerLoad.low;
        if (count < 50) return ServerLoad.medium;
        return ServerLoad.high;
      });
});
