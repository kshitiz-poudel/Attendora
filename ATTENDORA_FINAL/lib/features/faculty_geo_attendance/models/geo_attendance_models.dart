import 'package:cloud_firestore/cloud_firestore.dart';

class GeoAttendanceSettings {
  const GeoAttendanceSettings({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.enabled = true,
  });

  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool enabled;

  factory GeoAttendanceSettings.fromMap(Map<String, dynamic> map) {
    return GeoAttendanceSettings(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      radiusMeters: (map['radiusMeters'] as num?)?.toDouble() ?? 150,
      enabled: map['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
    'enabled': enabled,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class FacultyGeoAttendance {
  const FacultyGeoAttendance({
    required this.id,
    required this.facultyId,
    required this.date,
    this.checkIn,
    this.checkOut,
  });

  final String id;
  final String facultyId;
  final String date;
  final GeoAttendanceEvent? checkIn;
  final GeoAttendanceEvent? checkOut;

  factory FacultyGeoAttendance.fromMap(String id, Map<String, dynamic> map) {
    GeoAttendanceEvent? parse(String key) {
      final value = map[key];
      if (value is Map<String, dynamic>) {
        return GeoAttendanceEvent.fromMap(value);
      }
      return null;
    }

    return FacultyGeoAttendance(
      id: id,
      facultyId: map['facultyId'] as String? ?? '',
      date: map['date'] as String? ?? '',
      checkIn: parse('checkIn'),
      checkOut: parse('checkOut'),
    );
  }
}

class GeoAttendanceEvent {
  const GeoAttendanceEvent({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.distanceFromCampus,
    required this.photoUrl,
  });

  final DateTime? timestamp;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double distanceFromCampus;
  final String? photoUrl;

  factory GeoAttendanceEvent.fromMap(Map<String, dynamic> map) {
    final ts = map['timestamp'];
    return GeoAttendanceEvent(
      timestamp: ts is Timestamp ? ts.toDate() : null,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0,
      distanceFromCampus: (map['distanceFromCampus'] as num?)?.toDouble() ?? 0,
      photoUrl: map['photoUrl'] as String?,
    );
  }
}
