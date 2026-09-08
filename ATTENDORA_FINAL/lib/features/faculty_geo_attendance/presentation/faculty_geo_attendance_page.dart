import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../auth/providers.dart';
import '../../teacher/presentation/teacher_shell.dart';
import '../../shared/widgets/background_pattern.dart';
import '../../shared/widgets/glass_card.dart';
import '../models/geo_attendance_models.dart';
import '../providers/faculty_geo_attendance_providers.dart';

class FacultyGeoAttendancePage extends ConsumerStatefulWidget {
  const FacultyGeoAttendancePage({super.key});

  @override
  ConsumerState<FacultyGeoAttendancePage> createState() =>
      _FacultyGeoAttendancePageState();
}

class _FacultyGeoAttendancePageState
    extends ConsumerState<FacultyGeoAttendancePage> {
  bool _busy = false;
  String? _message;

  Future<void> _mark(String type, GeoAttendanceSettings settings) async {
    final auth = ref.read(authControllerProvider);
    final code = auth.institutionCode;
    final uid = auth.uid;
    if (uid == null || code == null || code.isEmpty) {
      setState(
        () => _message = 'Your institution information is missing. Please contact the administrator.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final service = ref.read(facultyGeoAttendanceServiceProvider);
      final position = await service.getVerifiedCurrentPosition();
      final distance = service.distanceFromCampus(position, settings);
      if (distance > settings.radiusMeters) {
        throw Exception(
          'You are ${distance.round()} m from the campus location. Attendance is allowed only within ${settings.radiusMeters.round()} m.',
        );
      }

      final image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (image == null) {
        setState(
          () => _message =
              'Attendance was cancelled because no live photo was captured.',
        );
        return;
      }
      final bytes = await image.readAsBytes();
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final photoUrl = await service.uploadEvidence(
        facultyId: uid,
        date: date,
        type: type,
        bytes: bytes,
      );
      await service.submitAttendance(
        facultyId: uid,
        facultyName: auth.displayName ?? 'Faculty',
        institutionCode: code,
        type: type,
        position: position,
        distance: distance,
        photoUrl: photoUrl,
      );
      if (mounted) {
        setState(
          () => _message = type == 'checkIn'
              ? 'Entry attendance verified and recorded successfully.'
              : 'Exit attendance verified and recorded successfully.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final code = auth.institutionCode;
    if (code == null || code.isEmpty) {
      return const TeacherShell(
        child: Center(child: Text('Institution setup is required.')),
      );
    }
    final settingsAsync = ref.watch(geoAttendanceSettingsProvider(code));
    return TeacherShell(
      child: BackgroundPattern(
        child: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Unable to load attendance settings: $error')),
          data: (settings) {
            if (settings == null) return _NotConfigured();
            if (!settings.enabled) return _Disabled();
            return ListView(
              children: [
                _Header(settings: settings),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 760;
                    final cards = [
                      _ActionCard(
                        icon: Icons.login_rounded,
                        title: 'Mark Entry',
                        subtitle: 'Verify GPS location and capture a live campus photo.',
                        action: () => _mark('checkIn', settings),
                        busy: _busy,
                        label: 'Check In',
                      ),
                      _ActionCard(
                        icon: Icons.logout_rounded,
                        title: 'Mark Exit',
                        subtitle: 'Verify your location and capture a live photo before leaving.',
                        action: () => _mark('checkOut', settings),
                        busy: _busy,
                        label: 'Check Out',
                      ),
                    ];
                    return wide
                        ? Row(
                            children: [
                              Expanded(child: cards[0]),
                              const SizedBox(width: 20),
                              Expanded(child: cards[1]),
                            ],
                          )
                        : Column(
                            children: [
                              cards[0],
                              const SizedBox(height: 16),
                              cards[1],
                            ],
                          );
                  },
                ),
                const SizedBox(height: 24),
                if (_busy)
                  const GlassCard(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Verifying GPS, capturing evidence and securely recording attendance...',
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _message!.contains('successfully')
                              ? Icons.verified_rounded
                              : Icons.info_outline,
                          color: _message!.contains('successfully')
                              ? Colors.greenAccent
                              : Colors.orangeAccent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_message!)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const _PrivacyNote(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.settings});
  final GeoAttendanceSettings settings;
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(28),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: .18),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.location_on_rounded,
            color: Color(0xFF34D399),
            size: 32,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Faculty Geo-Attendance',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Attendance is verified through your real-time location and a live camera capture.',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _Chip(
                    icon: Icons.shield_outlined,
                    label: 'Geofence: ${settings.radiusMeters.round()} m',
                  ),
                  const _Chip(
                    icon: Icons.camera_alt_outlined,
                    label: 'Live photo required',
                  ),
                  const _Chip(
                    icon: Icons.schedule_outlined,
                    label: 'Server timestamp',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.tealAccent),
        const SizedBox(width: 6),
        Text(label),
      ],
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.busy,
    required this.label,
  });
  final IconData icon;
  final String title, subtitle, label;
  final VoidCallback action;
  final bool busy;
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 36, color: Colors.tealAccent),
        const SizedBox(height: 18),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(subtitle),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy ? null : action,
            icon: Icon(icon),
            label: Text(label),
          ),
        ),
      ],
    ),
  );
}

class _NotConfigured extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: GlassCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 48,
            color: Colors.orangeAccent,
          ),
          const SizedBox(height: 16),
          const Text('Geo-attendance is not configured yet.'),
          const SizedBox(height: 8),
          Text(
            'Please ask your institution administrator to configure the campus geofence.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}

class _Disabled extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
    child: GlassCard(
      padding: EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 48,
            color: Colors.orangeAccent,
          ),
          SizedBox(height: 16),
          Text(
            'Faculty geo-attendance is currently disabled by the administrator.',
          ),
        ],
      ),
    ),
  );
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(18),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.privacy_tip_outlined, color: Colors.lightBlueAccent),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Privacy design: Attendora checks your location only when you explicitly mark entry or exit. It does not continuously track faculty location in the background.',
          ),
        ),
      ],
    ),
  );
}
