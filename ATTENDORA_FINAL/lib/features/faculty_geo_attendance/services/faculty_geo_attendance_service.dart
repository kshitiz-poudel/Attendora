import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import '../models/geo_attendance_models.dart';

class FacultyGeoAttendanceService {
  FacultyGeoAttendanceService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> _settingsRef(String institutionCode) =>
      _firestore.collection('geo_attendance_settings').doc(institutionCode);

  Future<GeoAttendanceSettings?> getSettings(String institutionCode) async {
    final snapshot = await _settingsRef(institutionCode).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return GeoAttendanceSettings.fromMap(snapshot.data()!);
  }

  Stream<GeoAttendanceSettings?> watchSettings(String institutionCode) =>
      _settingsRef(institutionCode).snapshots().map((snapshot) =>
          snapshot.exists && snapshot.data() != null
              ? GeoAttendanceSettings.fromMap(snapshot.data()!)
              : null);

  Future<void> saveSettings(String institutionCode, GeoAttendanceSettings settings) async {
    await _settingsRef(institutionCode).set(settings.toMap(), SetOptions(merge: true));
  }

  Future<Position> getVerifiedCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location services are disabled. Please enable GPS and try again.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required to mark faculty attendance.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  double distanceFromCampus(Position position, GeoAttendanceSettings settings) =>
      Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        settings.latitude,
        settings.longitude,
      );

  Future<String> uploadEvidence({
    required String facultyId,
    required String date,
    required String type,
    required Uint8List bytes,
  }) async {
    final ref = _storage.ref(
      'faculty_geo_attendance/$facultyId/$date/${type}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<void> submitAttendance({
    required String facultyId,
    required String facultyName,
    required String institutionCode,
    required String type,
    required Position position,
    required double distance,
    required String photoUrl,
  }) async {
    if (type != 'checkIn' && type != 'checkOut') {
      throw ArgumentError.value(type, 'type', 'Must be checkIn or checkOut');
    }
    final now = DateTime.now();
    final date = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final docId = '${institutionCode}_${facultyId}_$date';
    final field = type == 'checkIn' ? 'checkIn' : 'checkOut';
    final ref = _firestore.collection('faculty_geo_attendance').doc(docId);
    final existing = await ref.get();
    final existingData = existing.data();

    if (type == 'checkOut' && (existingData == null || existingData['checkIn'] == null)) {
      throw Exception('Please mark entry attendance before marking exit.');
    }
    if (existingData != null && existingData[field] != null) {
      throw Exception(type == 'checkIn'
          ? 'Entry attendance has already been recorded for today.'
          : 'Exit attendance has already been recorded for today.');
    }

    final event = {
      'timestamp': FieldValue.serverTimestamp(),
      'clientCapturedAt': now.toIso8601String(),
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'distanceFromCampus': distance,
      'photoUrl': photoUrl,
    };

    await ref.set({
      'facultyId': facultyId,
      'facultyName': facultyName,
      'institutionCode': institutionCode,
      'date': date,
      field: event,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTodayAttendance(String institutionCode, String date) =>
      _firestore
          .collection('faculty_geo_attendance')
          .where('institutionCode', isEqualTo: institutionCode)
          .where('date', isEqualTo: date)
          .snapshots();
}
