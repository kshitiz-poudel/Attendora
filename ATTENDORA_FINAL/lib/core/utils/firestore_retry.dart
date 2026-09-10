import 'dart:async';

import 'package:flutter/foundation.dart';

/// Retries a Firestore operation once when it fails with the Firestore Web
/// SDK's own internal-assertion class of error.
///
/// `FIRESTORE INTERNAL ASSERTION FAILED: Unexpected state (ID: ...)` is a
/// real, documented bug in the Firestore JS SDK's `WatchChangeAggregator`
/// (stale acknowledgments arriving during listener creation/recreation - see
/// firebase/firebase-js-sdk#9985, #8305, #7717, #5303) that Firebase's own
/// engineers describe as intermittent and hard to reproduce, still occurring
/// across SDK releases from 10.5 through 12.14 at time of writing. It is not
/// caused by anything wrong with the write itself - a page with many
/// concurrent listeners (which every dashboard screen in this app has) is
/// exactly the shape of app that triggers it. Firebase has never shipped a
/// complete fix, so the practical mitigation - used widely in the community
/// threads on this bug - is what this does: catch it specifically and retry
/// the same operation once, since the SDK's internal state has almost always
/// recovered by the second attempt.
///
/// This must never mask a real failure: only the exact "INTERNAL ASSERTION
/// FAILED" signature is caught. Every other error (permission-denied,
/// network, validation, ...) passes straight through on the first try.
Future<T> withFirestoreRetry<T>(
  Future<T> Function() operation, {
  int maxRetries = 1,
  Duration delay = const Duration(milliseconds: 400),
}) async {
  var attempt = 0;
  while (true) {
    try {
      return await operation();
    } catch (e) {
      final isInternalAssertion = e
          .toString()
          .toUpperCase()
          .contains('INTERNAL ASSERTION FAILED');
      if (!isInternalAssertion || attempt >= maxRetries) rethrow;
      attempt++;
      debugPrint(
        'withFirestoreRetry: retrying after Firestore internal-assertion '
        'error (attempt $attempt/$maxRetries): $e',
      );
      await Future.delayed(delay);
    }
  }
}
