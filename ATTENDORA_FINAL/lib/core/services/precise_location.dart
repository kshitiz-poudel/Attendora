import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Thrown when attendance needs a precise location and the person has not
/// allowed one. The message is written to be shown to them as-is.
class PreciseLocationException implements Exception {
  const PreciseLocationException(this.message);
  final String message;

  // Deliberately the bare message: call sites show `e.toString()` and some
  // strip a leading "Exception: ", so this reads well either way.
  @override
  String toString() => message;
}

/// The two platform calls this needs, behind an interface so the decision
/// logic can be tested without a phone.
abstract class LocationAccuracyGateway {
  /// Only iPhones have a user-selectable "approximate location" mode.
  bool get hasApproximateMode;
  Future<LocationAccuracyStatus> currentStatus();
  Future<LocationAccuracyStatus> requestTemporaryFullAccuracy(String purposeKey);
}

class _GeolocatorGateway implements LocationAccuracyGateway {
  const _GeolocatorGateway();

  @override
  bool get hasApproximateMode =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<LocationAccuracyStatus> currentStatus() =>
      Geolocator.getLocationAccuracy();

  @override
  Future<LocationAccuracyStatus> requestTemporaryFullAccuracy(
    String purposeKey,
  ) => Geolocator.requestTemporaryFullAccuracy(purposeKey: purposeKey);
}

/// Must match a key in Info.plist's NSLocationTemporaryUsageDescriptionDictionary,
/// which holds the text iOS shows in the one-time "Allow Precise Location" prompt.
const String kPreciseLocationPurposeKey = 'AttendancePrecise';

/// Makes sure the next location reading is a *precise* one.
///
/// Since iOS 14 a person can grant an app only "Approximate Location", which
/// is accurate to roughly a kilometre or more. Attendance is checked against a
/// radius of tens of metres, so an approximate reading would reject a student
/// who is sitting in the classroom (and, worse, make the failure look like a
/// distance problem rather than a permission one). Android and the web have no
/// such mode, so this does nothing there.
///
/// When the reading is approximate it asks iOS for temporary full accuracy,
/// which shows a one-off system prompt. If that is declined it throws a
/// [PreciseLocationException] telling the person where to switch it on.
Future<void> ensurePreciseLocation({
  LocationAccuracyGateway gateway = const _GeolocatorGateway(),
}) async {
  if (!gateway.hasApproximateMode) return;

  var status = await gateway.currentStatus();
  if (status != LocationAccuracyStatus.reduced) return;

  try {
    status = await gateway.requestTemporaryFullAccuracy(
      kPreciseLocationPurposeKey,
    );
  } catch (e) {
    debugPrint('requestTemporaryFullAccuracy failed: $e');
  }

  if (status == LocationAccuracyStatus.reduced) {
    throw const PreciseLocationException(
      'Precise Location is turned off for Attendora, so your distance cannot '
      'be checked. Open Settings > Privacy & Security > Location Services > '
      'Attendora and turn on Precise Location.',
    );
  }
}
