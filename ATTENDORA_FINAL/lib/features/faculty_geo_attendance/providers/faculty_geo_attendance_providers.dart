import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/geo_attendance_models.dart';
import '../services/faculty_geo_attendance_service.dart';

final facultyGeoAttendanceServiceProvider =
    Provider<FacultyGeoAttendanceService>(
      (ref) => FacultyGeoAttendanceService(),
    );

final geoAttendanceSettingsProvider =
    StreamProvider.family<GeoAttendanceSettings?, String>(
      (ref, institutionCode) => ref
          .read(facultyGeoAttendanceServiceProvider)
          .watchSettings(institutionCode),
    );
