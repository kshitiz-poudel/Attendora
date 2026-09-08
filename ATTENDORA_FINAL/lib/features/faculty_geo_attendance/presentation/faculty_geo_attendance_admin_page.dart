import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../auth/providers.dart';
import '../../dashboard/presentation/admin_shell.dart';
import '../../shared/widgets/background_pattern.dart';
import '../../shared/widgets/glass_card.dart';
import '../models/geo_attendance_models.dart';
import '../providers/faculty_geo_attendance_providers.dart';

class FacultyGeoAttendanceAdminPage extends ConsumerStatefulWidget {
  const FacultyGeoAttendanceAdminPage({super.key});
  @override
  ConsumerState<FacultyGeoAttendanceAdminPage> createState() =>
      _FacultyGeoAttendanceAdminPageState();
}

class _FacultyGeoAttendanceAdminPageState
    extends ConsumerState<FacultyGeoAttendanceAdminPage> {
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _radius = TextEditingController(text: '150');
  bool _enabled = true;
  bool _saving = false;
  bool _loaded = false;
  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    _radius.dispose();
    super.dispose();
  }

  void _populate(GeoAttendanceSettings? s) {
    if (_loaded || s == null) return;
    _lat.text = s.latitude.toString();
    _lng.text = s.longitude.toString();
    _radius.text = s.radiusMeters.round().toString();
    _enabled = s.enabled;
    _loaded = true;
  }

  Future<void> _useCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception(
          'Location services are disabled. Please enable location services and try again.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required.');
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _lat.text = p.latitude.toStringAsFixed(6);
        _lng.text = p.longitude.toStringAsFixed(6);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _save(String code) async {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    final radius = double.tryParse(_radius.text.trim());
    if (lat == null ||
        lng == null ||
        radius == null ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180 ||
        radius < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter valid coordinates and a radius of at least 20 metres.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(facultyGeoAttendanceServiceProvider)
          .saveSettings(
            code,
            GeoAttendanceSettings(
              latitude: lat,
              longitude: lng,
              radiusMeters: radius,
              enabled: _enabled,
            ),
          );
      _loaded = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geo-attendance settings saved successfully.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to save settings: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = ref.watch(authControllerProvider).institutionCode;
    if (code == null || code.isEmpty) {
      return const AdminShell(
        child: Center(child: Text('Institution information is unavailable.')),
      );
    }
    final settings = ref.watch(geoAttendanceSettingsProvider(code));
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final records = ref
        .read(facultyGeoAttendanceServiceProvider)
        .watchTodayAttendance(code, date);
    return AdminShell(
      child: BackgroundPattern(
        child: ListView(
          children: [
            Text(
              'Faculty Geo-Attendance',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure the campus geofence and monitor verified faculty entry and exit records.',
            ),
            const SizedBox(height: 24),
            settings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Settings error: $e'),
              data: (s) {
                _populate(s);
                return _SettingsCard(
                  lat: _lat,
                  lng: _lng,
                  radius: _radius,
                  enabled: _enabled,
                  onEnabled: (v) => setState(() => _enabled = v),
                  onUseLocation: _useCurrentLocation,
                  onSave: _saving ? null : () => _save(code),
                  saving: _saving,
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              "Today's verified activity",
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: records,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Unable to load records: ${snapshot.error}');
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const GlassCard(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No faculty geo-attendance has been recorded today.',
                    ),
                  );
                }
                return Column(
                  children: docs
                      .map((d) => _RecordCard(data: d.data()))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.lat,
    required this.lng,
    required this.radius,
    required this.enabled,
    required this.onEnabled,
    required this.onUseLocation,
    required this.onSave,
    required this.saving,
  });
  final TextEditingController lat, lng, radius;
  final bool enabled, saving;
  final ValueChanged<bool> onEnabled;
  final VoidCallback onUseLocation;
  final VoidCallback? onSave;
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.tealAccent),
            const SizedBox(width: 10),
            Text(
              'Campus Geofence Settings',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Switch(value: enabled, onChanged: onEnabled),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          enabled
              ? 'Faculty geo-attendance is enabled.'
              : 'Faculty geo-attendance is disabled.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                controller: lat,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Campus latitude',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 260,
              child: TextField(
                controller: lng,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Campus longitude',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 200,
              child: TextField(
                controller: radius,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Allowed radius (m)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: onUseLocation,
              icon: const Icon(Icons.my_location),
              label: const Text('Use my current location'),
            ),
            FilledButton.icon(
              onPressed: onSave,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(saving ? 'Saving...' : 'Save settings'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Recommended workflow: set the campus center from a verified location and use a radius large enough to accommodate normal GPS accuracy.',
          style: TextStyle(color: Colors.white60),
        ),
      ],
    ),
  );
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.data});
  final Map<String, dynamic> data;
  String _time(dynamic v) {
    if (v is Map && v['timestamp'] is Timestamp) {
      return DateFormat('hh:mm a')
          .format((v['timestamp'] as Timestamp).toDate());
    }
    return 'Pending sync';
  }

  String _distance(dynamic v) {
    if (v is Map && v['distanceFromCampus'] is num) {
      return '${(v['distanceFromCampus'] as num).round()} m';
    }
    return '--';
  }

  void _photo(BuildContext context, dynamic event, String title) {
    if (event is! Map || event['photoUrl'] is! String) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Image.network(
                  event['photoUrl'] as String,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inData = data['checkIn'];
    final outData = data['checkOut'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              child: Text(
                (data['facultyName'] as String? ?? 'F').isNotEmpty
                    ? (data['facultyName'] as String)[0].toUpperCase()
                    : 'F',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['facultyName'] as String? ?? 'Faculty',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _Tag(
                        icon: Icons.login,
                        label: 'Entry: ${_time(inData)} • ${_distance(inData)}',
                      ),
                      _Tag(
                        icon: Icons.logout,
                        label:
                            'Exit: ${_time(outData)} • ${_distance(outData)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (inData is Map && inData['photoUrl'] != null)
                        OutlinedButton.icon(
                          onPressed: () => _photo(
                            context,
                            inData,
                            'Entry verification photo',
                          ),
                          icon: const Icon(Icons.photo_outlined, size: 16),
                          label: const Text('Entry photo'),
                        ),
                      if (outData is Map && outData['photoUrl'] != null)
                        OutlinedButton.icon(
                          onPressed: () => _photo(
                            context,
                            outData,
                            'Exit verification photo',
                          ),
                          icon: const Icon(Icons.photo_outlined, size: 16),
                          label: const Text('Exit photo'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.verified_rounded,
              color: (inData != null) ? Colors.greenAccent : Colors.white30,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: Colors.tealAccent),
      const SizedBox(width: 5),
      Text(label),
    ],
  );
}
