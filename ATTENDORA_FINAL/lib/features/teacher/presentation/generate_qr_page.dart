import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/error_handler.dart';
import '../../teacher/providers.dart';
import '../../teacher/presentation/teacher_subjects_page.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/background_pattern.dart';
import '../../shared/widgets/glass_text_field.dart';
import 'widgets/rotating_qr_view.dart';
import '../../../core/design/app_colors.dart';

class _WebStep extends StatelessWidget {
  const _WebStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.c.accent,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(
              color: context.c.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: GoogleFonts.outfit(color: context.c.textSecondary)),
        ),
      ],
    );
  }
}

class GenerateQrPage extends ConsumerStatefulWidget {
  const GenerateQrPage({
    super.key,
    this.initialSubject,
    this.initialDuration,
    this.initialRadius,
    this.scheduledSessionId,
  });

  final String? initialSubject;
  final int? initialDuration;
  final double? initialRadius;
  final String? scheduledSessionId;

  @override
  ConsumerState<GenerateQrPage> createState() => _GenerateQrPageState();
}

class _GenerateQrPageState extends ConsumerState<GenerateQrPage> {
  String? _selectedSubject;
  late final TextEditingController _durationController;
  late final TextEditingController _radiusController;
  String? _error;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.initialSubject;
    _durationController = TextEditingController(
      text: (widget.initialDuration ?? 10).toString(),
    );
    _radiusController = TextEditingController(
      text: (widget.initialRadius ?? 50).toString(),
    );
  }

  @override
  void dispose() {
    _durationController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Uri get _androidDownloadUri => Uri.base.resolve('downloads/attendora.apk');

  Future<void> _downloadAndroidApp() async {
    final launched = await launchUrl(
      _androidDownloadUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      setState(() {
        _error =
            'Unable to open the Android download link. Please try again later.';
      });
    }
  }

  Future<void> _startSession() async {
    setState(() {
      _error = null;
      _requesting = true;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _error = 'Location services are disabled.');
        return;
      }
      if (!kIsWeb) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          setState(() => _error = 'Location permission denied.');
          return;
        }
      }

      final LocationSettings locationSettings = kIsWeb
          ? const LocationSettings(accuracy: LocationAccuracy.high)
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 100,
            );

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      bool bypassLocation = false;

      // Check accuracy
      if (pos.accuracy > 100) {
        if (mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: context.c.surface,
              title: Text(
                'Weak Location Signal',
                style: GoogleFonts.outfit(color: context.c.textPrimary),
              ),
              content: Text(
                'Your location accuracy is poor (${pos.accuracy.toStringAsFixed(0)} meters). '
                'This usually happens on desktops without GPS/Wi-Fi.\n\n'
                'Students will likely fail the location check.\n'
                'Do you want to proceed and BYPASS location checks for this session?',
                style: GoogleFonts.outfit(color: context.c.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.c.accent,
                  ),
                  child: const Text('Proceed & Bypass'),
                ),
              ],
            ),
          );

          if (proceed != true) {
            setState(() => _requesting = false);
            return;
          }
          bypassLocation = true;
        }
      }

      final duration = Duration(
        minutes: int.tryParse(_durationController.text) ?? 10,
      );
      final radius = double.tryParse(_radiusController.text) ?? 50;
      final subjectStr = _selectedSubject;
      String? subjectName;
      String? groupName;

      if (subjectStr != null) {
        final match = RegExp(r'^(.+) \((.+)\)$').firstMatch(subjectStr);
        if (match != null) {
          subjectName = match.group(1)?.trim();
          groupName = match.group(2)?.trim();
        } else {
          subjectName = subjectStr;
        }
      }

      await ref
          .read(activeSessionProvider.notifier)
          .startSession(
            latitude: pos.latitude,
            longitude: pos.longitude,
            duration: duration,
            radiusMeters: radius,
            subject: subjectName,
            group: groupName,
            bypassLocation: bypassLocation,
            scheduledSessionId: widget.scheduledSessionId,
          );
    } on ConflictingSessionException catch (e) {
      if (mounted) {
        setState(() => _requesting = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: context.c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.c.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: context.c.warning,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Session Already Running',
                    style: GoogleFonts.outfit(
                      color: context.c.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Currently, the session of ${e.subjectName} is running for ${e.group}.',
                  style: GoogleFonts.outfit(
                    color: context.c.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.c.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.c.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        color: context.c.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Started by: ${e.teacherName}',
                          style: GoogleFonts.outfit(
                            color: context.c.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You cannot start a new session for this group until the current session ends.',
                  style: GoogleFonts.outfit(
                    color: context.c.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: context.c.warning,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Understood'),
              ),
            ],
          ),
        );
      }
      return;
    } catch (e) {
      setState(() => _error = 'Failed to get location: $e');
    } finally {
      if (mounted) {
        setState(() => _requesting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeSessionProvider);
    final controller = ref.read(activeSessionProvider.notifier);
    final timeLeft = controller.timeLeft();
    final code = controller.currentDynamicCode();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Start Session',
          style: GoogleFonts.outfit(color: context.c.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.c.textPrimary),
      ),
      body: BackgroundPattern(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: 80,
                bottom: 24,
                left: 24,
                right: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 104,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: active == null
                        ? GlassCard(
                            padding: const EdgeInsets.all(32),
                            child: kIsWeb
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: context.c.accent
                                              .withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.phone_iphone_rounded,
                                          size: 64,
                                          color: context.c.success,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        'Start securely from the attendora mobile app',
                                        style: GoogleFonts.outfit(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: context.c.textPrimary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'The mobile app uses your phone GPS for a more reliable attendance session. Android and iPhone builds use the same Firebase project and the same teacher account.',
                                        style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          height: 1.5,
                                          color: context.c.textSecondary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 52,
                                        child: ElevatedButton.icon(
                                          onPressed: _downloadAndroidApp,
                                          icon: const Icon(
                                            Icons.android_rounded,
                                          ),
                                          label: Text(
                                            'Download attendora for Android',
                                            style: GoogleFonts.outfit(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: context.c.accent,
                                            foregroundColor: context.c.textPrimary,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: context.c.textPrimary.withValues(
                                            alpha: 0.04,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: context.c.textPrimary.withValues(
                                              alpha: 0.10,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.phone_iphone_rounded,
                                              color: context.c.textSecondary,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                'iPhone version: install through the official iOS distribution link when it is published.',
                                                style: GoogleFonts.outfit(
                                                  color: context.c.textSecondary,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: context.c.textPrimary.withValues(
                                            alpha: 0.05,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: context.c.textPrimary.withValues(
                                              alpha: 0.10,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            _WebStep(
                                              number: '1',
                                              text: 'Open attendora on your Android phone or iPhone.',
                                            ),
                                            const SizedBox(height: 12),
                                            _WebStep(
                                              number: '2',
                                              text: 'Sign in with this same teacher account.',
                                            ),
                                            const SizedBox(height: 12),
                                            _WebStep(
                                              number: '3',
                                              text: 'Start the session and keep this page open.',
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'The active session and QR code will synchronize automatically through Firebase.',
                                        style: GoogleFonts.outfit(
                                          color: context.c.success,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  context.c.accent,
                                                  Color(0xFF7C3AED),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.qr_code_2_rounded,
                                              color: context.c.textPrimary,
                                              size: 28,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Create a secure attendance session',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: context.c.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'GPS is captured from your phone before the QR session starts',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 14,
                                                    color: context.c.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      _buildMobileSafetyStrip(),
                                      const SizedBox(height: 24),
                                      _buildSubjectDropdown(context, ref),
                                      const SizedBox(height: 24),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: GlassTextField(
                                              controller: _durationController,
                                              label: 'Duration (min)',
                                              prefixIcon: Icons.timer_outlined,
                                              keyboardType:
                                                  TextInputType.number,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: GlassTextField(
                                              controller: _radiusController,
                                              label: 'Radius (m)',
                                              prefixIcon:
                                                  Icons.location_on_outlined,
                                              keyboardType:
                                                  TextInputType.number,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 32),
                                      SizedBox(
                                        height: 50,
                                        child: ElevatedButton.icon(
                                          onPressed: _requesting
                                              ? null
                                              : _startSession,
                                          icon: _requesting
                                              ? SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: context.c.textPrimary,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.play_arrow_rounded,
                                                ),
                                          label: Text(
                                            _requesting
                                                ? 'Starting Session...'
                                                : 'Start Session',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: context.c.accent,
                                            foregroundColor: context.c.textPrimary,
                                            textStyle: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_error != null) ...[
                                        const SizedBox(height: 24),
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: context.c.danger
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: context.c.danger
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.error_outline,
                                                color: context.c.danger,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  _error!,
                                                  style: GoogleFonts.outfit(
                                                    color: context.c.danger,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GlassCard(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            context.c.accent,
                                            context.c.success,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            color: context.c.textPrimary,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Session Active',
                                                style: GoogleFonts.outfit(
                                                  color: context.c.textPrimary,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (timeLeft != null)
                                                Text(
                                                  'Expires in ${timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(timeLeft.inSeconds.remainder(60)).toString().padLeft(2, '0')}',
                                                  style: GoogleFonts.outfit(
                                                    color: context.c.textPrimary,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    if (code != null)
                                      RotatingQrView(
                                        data: code,
                                        isSecured: active.isSecured,
                                      ),
                                    const SizedBox(height: 32),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: context.c.textPrimary.withValues(
                                          alpha: 0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 16,
                                        runSpacing: 8,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.location_on,
                                                size: 16,
                                                color: context.c.accent,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Lat: ${active.latitude.toStringAsFixed(5)}, Lng: ${active.longitude.toStringAsFixed(5)}',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 13,
                                                  color: context.c.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.radar,
                                                size: 16,
                                                color: context.c.accent,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Radius: ${active.radiusMeters.toStringAsFixed(0)} m',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 13,
                                                  color: context.c.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 50,
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => ref
                                      .read(activeSessionProvider.notifier)
                                      .endSession(),
                                  icon: const Icon(Icons.stop_circle_outlined),
                                  label: const Text('End Session'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: context.c.textPrimary,
                                    side: BorderSide(
                                      color: context.c.textPrimary.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                    textStyle: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileSafetyStrip() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.c.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.c.accent.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: context.c.success),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Live GPS verification is performed before your session begins.',
              style: TextStyle(color: context.c.textSecondary, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectDropdown(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);

    return subjectsAsync.when(
      data: (groupedSubjects) {
        final allSubjects = <Map<String, dynamic>>[];
        for (final typeGroups in groupedSubjects.values) {
          for (final subjects in typeGroups.values) {
            allSubjects.addAll(subjects);
          }
        }

        if (allSubjects.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.c.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.c.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: context.c.warning,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Subjects Added',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          color: context.c.warning,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Please add subjects in the Subjects page first',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: context.c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: context.c.textPrimary.withValues(alpha: 0.05),
            border: Border.all(color: context.c.textPrimary.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedSubject,
              dropdownColor: context.c.surface,
              style: GoogleFonts.outfit(color: context.c.textPrimary, fontSize: 16),
              icon: Icon(Icons.arrow_drop_down, color: context.c.textSecondary),
              hint: Row(
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 20,
                    color: context.c.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Select Subject',
                    style: GoogleFonts.outfit(color: context.c.textSecondary),
                  ),
                ],
              ),
              items: allSubjects.map((subject) {
                final name = subject['name'] ?? 'Untitled';
                final group = subject['group'] ?? 'No Group';
                final type = subject['type'] ?? 'Lecture';
                final displayText = '$name ($group)';

                final isLab = type == 'Lab';
                final typeColor = isLab
                    ? context.c.accent
                    : context.c.primary;
                final typeIcon = isLab
                    ? Icons.science_outlined
                    : Icons.school_outlined;

                return DropdownMenuItem<String>(
                  value: displayText,
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(typeIcon, color: typeColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayText,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: context.c.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                type,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: typeColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSubject = value;
                });
              },
            ),
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.c.textPrimary.withValues(alpha: 0.05),
          border: Border.all(color: context.c.textPrimary.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.c.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading subjects...',
              style: GoogleFonts.outfit(color: context.c.textSecondary),
            ),
          ],
        ),
      ),
      error: (error, _) => ErrorHandler.buildErrorWidget(
        error,
        customMessage: 'Unable to load subjects',
      ),
    );
  }
}
