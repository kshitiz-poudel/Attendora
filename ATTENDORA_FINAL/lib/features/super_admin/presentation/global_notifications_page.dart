import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/glass_text_field.dart';
import '../../shared/widgets/glass_dropdown.dart';
import '../../dashboard/providers.dart';
import '../services/global_notification_service.dart';
import 'super_admin_shell.dart';
import '../../../core/design/app_colors.dart';

class GlobalNotificationsPage extends ConsumerStatefulWidget {
  const GlobalNotificationsPage({super.key});

  @override
  ConsumerState<GlobalNotificationsPage> createState() =>
      _GlobalNotificationsPageState();
}

class _GlobalNotificationsPageState
    extends ConsumerState<GlobalNotificationsPage> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _targetRole = 'all'; // all, student, teacher, admin
  String? _selectedInstitution;
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      await ref
          .read(globalNotificationServiceProvider)
          .sendGlobalNotification(
            title: _titleController.text.trim(),
            message: _messageController.text.trim(),
            targetRole: _targetRole,
            institutionId: _selectedInstitution,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Broadcast sent successfully!'),
            backgroundColor: context.c.success,
          ),
        );
        _titleController.clear();
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: context.c.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SuperAdminShell(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Global Broadcast',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: context.c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Send notifications to all users or specific groups.',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: context.c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FadeInUp(
              child: GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compose Message',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Target Selection
                    Text(
                      'Target Audience',
                      style: GoogleFonts.outfit(color: context.c.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _TargetChip(
                            label: 'All Users',
                            selected: _targetRole == 'all',
                            onTap: () => setState(() => _targetRole = 'all'),
                          ),
                          const SizedBox(width: 12),
                          _TargetChip(
                            label: 'Students',
                            selected: _targetRole == 'student',
                            onTap: () =>
                                setState(() => _targetRole = 'student'),
                          ),
                          const SizedBox(width: 12),
                          _TargetChip(
                            label: 'Teachers',
                            selected: _targetRole == 'teacher',
                            onTap: () =>
                                setState(() => _targetRole = 'teacher'),
                          ),
                          const SizedBox(width: 12),
                          _TargetChip(
                            label: 'Admins',
                            selected: _targetRole == 'admin',
                            onTap: () => setState(() => _targetRole = 'admin'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Institution Selection
                    Text(
                      'Institution (Optional)',
                      style: GoogleFonts.outfit(color: context.c.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    ref
                        .watch(activeInstitutionsProvider)
                        .when(
                          data: (institutions) => GlassDropdown<String>(
                            value: _selectedInstitution,
                            hint: 'All Institutions',
                            icon: Icon(
                              Icons.business,
                              color: context.c.textTertiary,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All Institutions'),
                              ),
                              ...institutions.map(
                                (inst) => DropdownMenuItem(
                                  value: inst['code'],
                                  child: Text(inst['name'] ?? inst['code']),
                                ),
                              ),
                            ],
                            onChanged: (val) =>
                                setState(() => _selectedInstitution = val),
                          ),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (_, __) => const SizedBox(),
                        ),
                    const SizedBox(height: 24),

                    GlassTextField(
                      controller: _titleController,
                      label: 'Title',
                      hintText: 'e.g., System Maintenance',
                      prefixIcon: Icons.title,
                    ),
                    const SizedBox(height: 16),
                    GlassTextField(
                      controller: _messageController,
                      label: 'Message',
                      hintText: 'Enter your message here...',
                      prefixIcon: Icons.message,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.c.textPrimary,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(_sending ? 'Sending...' : 'Send Broadcast'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.c.accent,
                          foregroundColor: context.c.textPrimary,
                          textStyle: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
          ],
        ),
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TargetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? context.c.accent
              : context.c.textPrimary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? context.c.accent
                : context.c.textPrimary.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: selected ? context.c.textPrimary : context.c.textSecondary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
