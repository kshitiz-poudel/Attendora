import 'package:flutter/material.dart';

import '../../shared/widgets/safe_avatar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/responsive_utils.dart';
import '../../../core/services/email_service.dart';
import '../../../core/constants/email_constants.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../shared/widgets/empty_state.dart';
import '../../auth/providers.dart';
import '../../shared/providers.dart';
import '../services/faculty_approval_service.dart';
import 'admin_shell.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/background_pattern.dart';
import '../../shared/widgets/glass_text_field.dart';
import '../../../core/design/app_colors.dart';

// A single stable listener is used for the complete teacher directory.  The
// pending/approved lists are derived in memory. This avoids rapidly adding and
// removing multiple Firestore watch targets when an approval changes a document.
final teacherDirectoryProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final auth = ref.watch(authControllerProvider);
  Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
    'users',
  );

  if (!auth.isSuperAdmin &&
      auth.institutionCode != null &&
      auth.institutionCode!.isNotEmpty) {
    query = query.where('institutionCode', isEqualTo: auth.institutionCode);
  }

  return query.snapshots().map((snap) {
    final teachers = snap.docs
        .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
        .where((data) {
          final role = (data['role'] as String? ?? '').toLowerCase();
          // Support legacy demo accounts created with either role name.
          return role == 'teacher' || role == 'faculty';
        })
        .toList();

    teachers.sort((a, b) {
      final aName = (a['displayName'] as String? ?? '').toLowerCase();
      final bName = (b['displayName'] as String? ?? '').toLowerCase();
      return aName.compareTo(bName);
    });
    return teachers;
  });
});

final pendingTeachersProvider =
    Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
      return ref
          .watch(teacherDirectoryProvider)
          .whenData(
            (teachers) => teachers
                .where((teacher) => teacher['approved'] != true)
                .toList(),
          );
    });

final approvedTeachersProvider =
    Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
      return ref
          .watch(teacherDirectoryProvider)
          .whenData(
            (teachers) => teachers
                .where((teacher) => teacher['approved'] == true)
                .toList(),
          );
    });

class AdminTeacherApprovalPage extends ConsumerStatefulWidget {
  const AdminTeacherApprovalPage({super.key});

  @override
  ConsumerState<AdminTeacherApprovalPage> createState() =>
      _AdminTeacherApprovalPageState();
}

class _AdminTeacherApprovalPageState
    extends ConsumerState<AdminTeacherApprovalPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  // Guards against a duplicate approve/reject/revoke firing from a second
  // click while the first write is still in flight against a slow
  // connection - without this, "nothing happened" reads as an invitation to
  // click again.
  final Set<String> _pendingActions = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      child: BackgroundPattern(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              FadeInDown(
                duration: const Duration(milliseconds: 500),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < Breakpoints.mobile;

                    if (isMobile) {
                      // Mobile: Stack vertically
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Teacher Approvals',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: context.c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Review and approve requests',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: context.c.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GlassTextField(
                            controller: _searchController,
                            label: 'Search',
                            onChanged: (value) =>
                                setState(() => _searchQuery = value),
                            hintText: 'Search teachers...',
                            prefixIcon: Icons.search,
                          ),
                        ],
                      );
                    }

                    // Desktop: Row layout
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Teacher Approvals',
                                style: GoogleFonts.outfit(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: context.c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Review and approve teacher registration requests',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  color: context.c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 300,
                          child: GlassTextField(
                            controller: _searchController,
                            label: 'Search',
                            onChanged: (value) =>
                                setState(() => _searchQuery = value),
                            hintText: 'Search teachers...',
                            prefixIcon: Icons.search,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Stats Cards
              FadeInUp(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 100),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.hourglass_empty,
                        title: 'Pending',
                        count:
                            ref.watch(pendingTeachersProvider).value?.length ??
                            0,
                        color: context.c.warning,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.check_circle,
                        title: 'Approved',
                        count:
                            ref.watch(approvedTeachersProvider).value?.length ??
                            0,
                        color: context.c.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: context.c.accent,
                labelColor: context.c.textPrimary,
                unselectedLabelColor: context.c.textTertiary,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Pending Approval'),
                  Tab(text: 'Approved Teachers'),
                ],
              ),
              const SizedBox(height: 16),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildPendingTab(), _buildApprovedTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.toString(),
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 14, color: context.c.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    final teachersAsync = ref.watch(pendingTeachersProvider);

    return teachersAsync.when(
      data: (teachers) {
        if (teachers.isEmpty) {
          return Center(
            child: EmptyState(
              icon: Icons.check_circle_outline,
              title: 'No Pending Approvals',
              subtitle:
                  'All teacher registration requests have been processed.',
              color: context.c.textTertiary,
            ),
          );
        }

        // Filter by search query
        final filteredTeachers = teachers.where((teacher) {
          if (_searchQuery.isEmpty) return true;
          final name = (teacher['displayName'] as String?) ?? '';
          final email = (teacher['email'] as String?) ?? '';
          final id = (teacher['idNumber'] as String?) ?? '';
          return name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              id.contains(_searchQuery);
        }).toList();

        if (filteredTeachers.isEmpty) {
          return Center(
            child: EmptyState(
              icon: Icons.search_off,
              title: 'No Results',
              subtitle: 'No teachers match "$_searchQuery"',
              color: context.c.textTertiary,
            ),
          );
        }

        return FadeInUp(
          duration: const Duration(milliseconds: 500),
          child: ListView.separated(
            itemCount: filteredTeachers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final teacher = filteredTeachers[index];
              final teacherId = teacher['id'] as String;
              // null disables the button (Flutter's normal onPressed:null
              // behaviour) while a previous action for this teacher is
              // still in flight, instead of allowing a second click to fire
              // a duplicate approve/reject.
              final busy = _pendingActions.contains(teacherId);
              return _TeacherCard(
                teacher: teacher,
                isPending: true,
                isBusy: busy,
                onApprove: busy
                    ? null
                    : () => _approveTeacher(
                        teacherId,
                        teacher['email'] as String?,
                        teacher['displayName'] as String?,
                      ),
                onReject: busy
                    ? null
                    : () => _rejectTeacher(
                        teacherId,
                        teacher['email'] as String?,
                        teacher['displayName'] as String?,
                      ),
              );
            },
          ),
        );
      },
      loading: () =>
          Center(child: CircularProgressIndicator(color: context.c.textPrimary)),
      error: (e, st) => Center(
        child: Text(
          'Error loading teachers: $e',
          style: GoogleFonts.outfit(color: context.c.danger),
        ),
      ),
    );
  }

  Widget _buildApprovedTab() {
    final teachersAsync = ref.watch(approvedTeachersProvider);

    return teachersAsync.when(
      data: (teachers) {
        if (teachers.isEmpty) {
          return Center(
            child: EmptyState(
              icon: Icons.person_off,
              title: 'No Approved Teachers',
              subtitle: 'No teachers have been approved yet.',
              color: context.c.textTertiary,
            ),
          );
        }

        // Filter by search query
        final filteredTeachers = teachers.where((teacher) {
          if (_searchQuery.isEmpty) return true;
          final name = (teacher['displayName'] as String?) ?? '';
          final email = (teacher['email'] as String?) ?? '';
          final id = (teacher['idNumber'] as String?) ?? '';
          return name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              id.contains(_searchQuery);
        }).toList();

        if (filteredTeachers.isEmpty) {
          return Center(
            child: EmptyState(
              icon: Icons.search_off,
              title: 'No Results',
              subtitle: 'No teachers match "$_searchQuery"',
              color: context.c.textTertiary,
            ),
          );
        }

        return FadeInUp(
          duration: const Duration(milliseconds: 500),
          child: ListView.separated(
            itemCount: filteredTeachers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final teacher = filteredTeachers[index];
              final teacherId = teacher['id'] as String;
              final busy = _pendingActions.contains(teacherId);
              return _TeacherCard(
                teacher: teacher,
                isPending: false,
                isBusy: busy,
                onRevoke: busy
                    ? null
                    : () => _revokeApproval(
                        teacherId,
                        teacher['email'] as String?,
                        teacher['displayName'] as String?,
                      ),
              );
            },
          ),
        );
      },
      loading: () =>
          Center(child: CircularProgressIndicator(color: context.c.textPrimary)),
      error: (e, st) => Center(
        child: Text(
          'Error loading teachers: $e',
          style: GoogleFonts.outfit(color: context.c.danger),
        ),
      ),
    );
  }

  Future<void> _approveTeacher(
    String teacherId,
    String? email,
    String? name,
  ) async {
    if (!_pendingActions.add(teacherId)) return;
    setState(() {});
    try {
      await ref
          .read(facultyApprovalServiceProvider)
          .approve(
            teacherId: teacherId,
            adminInstitutionCode: ref
                .read(authControllerProvider)
                .institutionCode,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Teacher approved successfully'),
            backgroundColor: context.c.success,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Send Email
        if (email != null && email.isNotEmpty) {
          if (EmailConstants.serviceId == 'YOUR_SERVICE_ID') {
            // Fallback to mailto if not configured
            final Uri emailLaunchUri = Uri(
              scheme: 'mailto',
              path: email,
              query: _encodeQueryParameters(<String, String>{
                'subject': 'Teacher Account Approved - Attendora',
                'body':
                    'Dear ${name ?? 'Teacher'},\n\nYour teacher account has been approved. You can now log in to the Attendora dashboard at https://attendora.pages.dev/\n\nBest regards,\nAdmin Team',
              }),
            );
            if (await canLaunchUrl(emailLaunchUri)) {
              await launchUrl(emailLaunchUri);
            }
          } else {
            // Use EmailJS
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sending email notification...')),
              );
            }
            await EmailService.sendEmail(
              templateId: EmailConstants.approvalTemplateId,
              templateParams: {
                'to_name': name ?? 'Teacher',
                'to_email': email,
                'message': 'Your teacher account has been approved. You can now log in.',
                'email': email,
                'action_url': 'https://attendora.pages.dev/',
              },
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error approving teacher: $e')));
      }
    } finally {
      _pendingActions.remove(teacherId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _rejectTeacher(
    String teacherId,
    String? email,
    String? name,
  ) async {
    if (_pendingActions.contains(teacherId)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.c.surface,
        title: Text(
          'Reject Teacher Application',
          style: GoogleFonts.outfit(color: context.c.textPrimary),
        ),
        content: Text(
          'Are you sure you want to reject this application? The user will be deleted from the system.',
          style: GoogleFonts.outfit(color: context.c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: context.c.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.c.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Reject',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _pendingActions.add(teacherId);
      setState(() {});
      try {
        // Remove the teacher from any class groups they were added to
        // during signup, before deleting their profile.
        final classGroupRepo = ref.read(classGroupRepositoryProvider);
        await classGroupRepo.removeUserFromAllGroups(teacherId);

        // Fetch idNumber before deleting so we can clean up the id_index lock.
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(teacherId)
            .get();
        final idNumber = userSnap.data()?['idNumber'] as String?;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(teacherId)
            .delete();

        // Free up the roll number so the applicant can sign up again.
        if (idNumber != null && idNumber.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('id_index')
              .doc(idNumber)
              .delete();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Teacher application rejected'),
              backgroundColor: context.c.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Send Email
          if (email != null && email.isNotEmpty) {
            if (EmailConstants.serviceId == 'YOUR_SERVICE_ID') {
              // Fallback
              final Uri emailLaunchUri = Uri(
                scheme: 'mailto',
                path: email,
                query: _encodeQueryParameters(<String, String>{
                  'subject': 'Teacher Application Update - Attendora',
                  'body':
                      'Dear ${name ?? 'Applicant'},\n\nWe regret to inform you that your teacher application has been rejected.\n\nBest regards,\nAdmin Team',
                }),
              );
              if (await canLaunchUrl(emailLaunchUri)) {
                await launchUrl(emailLaunchUri);
              }
            } else {
              // EmailJS
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sending email notification...'),
                  ),
                );
              }
              await EmailService.sendEmail(
                templateId: EmailConstants.rejectionTemplateId,
                templateParams: {
                  'to_name': name ?? 'Applicant',
                  'to_email': email,
                  'message': 'Your teacher application has been rejected.',
                  'email': email,
                  'support_url': '#', // Make button unclickable/no-op
                },
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error rejecting teacher: $e')),
          );
        }
      } finally {
        _pendingActions.remove(teacherId);
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _revokeApproval(
    String teacherId,
    String? email,
    String? name,
  ) async {
    if (_pendingActions.contains(teacherId)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.c.surface,
        title: Text(
          'Revoke Approval',
          style: GoogleFonts.outfit(color: context.c.textPrimary),
        ),
        content: Text(
          'Are you sure you want to revoke approval for this teacher? They will no longer be able to access the system.',
          style: GoogleFonts.outfit(color: context.c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: context.c.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.c.warning),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Revoke',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _pendingActions.add(teacherId);
      setState(() {});
      try {
        await ref
            .read(facultyApprovalServiceProvider)
            .revoke(
              teacherId: teacherId,
              adminInstitutionCode: ref
                  .read(authControllerProvider)
                  .institutionCode,
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Teacher approval revoked'),
              backgroundColor: context.c.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Send Email
          if (email != null && email.isNotEmpty) {
            if (EmailConstants.serviceId == 'YOUR_SERVICE_ID') {
              // Fallback
              final Uri emailLaunchUri = Uri(
                scheme: 'mailto',
                path: email,
                query: _encodeQueryParameters(<String, String>{
                  'subject': 'Account Access Revoked - Attendora',
                  'body':
                      'Dear ${name ?? 'Teacher'},\n\nYour teacher account approval has been revoked. You can no longer access the system.\n\nBest regards,\nAdmin Team',
                }),
              );
              if (await canLaunchUrl(emailLaunchUri)) {
                await launchUrl(emailLaunchUri);
              }
            } else {
              // EmailJS
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sending email notification...'),
                  ),
                );
              }
              await EmailService.sendEmail(
                templateId: EmailConstants.rejectionTemplateId, // Reusing rejection template for revocation
                templateParams: {
                  'to_name': name ?? 'Teacher',
                  'to_email': email,
                  'message': 'Your account approval has been revoked.',
                  'email': email,
                },
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error revoking approval: $e')),
          );
        }
      } finally {
        _pendingActions.remove(teacherId);
        if (mounted) setState(() {});
      }
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }
}

class _TeacherCard extends ConsumerWidget {
  const _TeacherCard({
    required this.teacher,
    required this.isPending,
    this.isBusy = false,
    this.onApprove,
    this.onReject,
    this.onRevoke,
  });

  final Map<String, dynamic> teacher;
  final bool isPending;
  /// True while an approve/reject/revoke for this teacher is in flight.
  /// Callbacks are already null in that state (disabling the buttons); this
  /// additionally swaps the action icon for a spinner so a slow write still
  /// reads as "working" instead of "did nothing".
  final bool isBusy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onRevoke;

  /// A small inline spinner matching [size], swapped in for the action icon
  /// while [isBusy] is true.
  Widget _spinner(double size, Color color) => SizedBox(
    width: size,
    height: size,
    child: CircularProgressIndicator(strokeWidth: 2, color: color),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = teacher['displayName'] as String? ?? 'Unknown';
    final email = teacher['email'] as String? ?? '';
    final idNumber =
        teacher['idNumber'] as String? ??
        teacher['rollNumber'] as String? ??
        'N/A';
    final institutionCode = teacher['institutionCode'] as String? ?? '';
    final createdAt =
        teacher['createdAt']; // Keep as dynamic to handle Timestamp
    final isMobile = context.isMobile;

    return GlassCard(
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // Avatar
                    SafeAvatar(
                      imageUrl: null, // Teacher approval usually doesn't have photoUrl yet, or check if it does
                      name: name,
                      radius: 24,
                      backgroundColor: isPending
                          ? Colors.orange.withValues(alpha: 0.2)
                          : Colors.green.withValues(alpha: 0.2),
                      fallbackIcon: isPending
                          ? Icons.hourglass_empty
                          : Icons.check_circle,
                      foregroundColor: isPending
                          ? context.c.warning
                          : context.c.success,
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: context.c.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.email,
                                size: 14,
                                color: context.c.textTertiary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  email,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: context.c.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Additional Info
                Row(
                  children: [
                    Icon(Icons.badge, size: 14, color: context.c.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      'ID: $idNumber',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: context.c.textSecondary,
                      ),
                    ),
                    if (institutionCode.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.school, size: 14, color: context.c.textTertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildInstitutionText(context, ref, institutionCode),
                      ),
                    ],
                  ],
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: context.c.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        'Registered: ${_formatDate(createdAt)}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: context.c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isPending) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onReject,
                          icon: isBusy
                              ? _spinner(18, context.c.danger)
                              : const Icon(Icons.close, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.c.danger,
                            side: BorderSide(
                              color: Colors.red.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onApprove,
                          icon: isBusy
                              ? _spinner(18, Colors.white)
                              : const Icon(Icons.check, size: 18),
                          label: const Text('Approve'),
                          style: FilledButton.styleFrom(
                            backgroundColor: context.c.success,
                          ),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onRevoke,
                          icon: isBusy
                              ? _spinner(18, context.c.warning)
                              : const Icon(Icons.block, size: 18),
                          label: const Text('Revoke'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.c.warning,
                            side: BorderSide(
                              color: Colors.orange.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            )
          : Row(
              children: [
                // Avatar
                SafeAvatar(
                  imageUrl: null,
                  name: name,
                  radius: 28,
                  backgroundColor: isPending
                      ? Colors.orange.withValues(alpha: 0.2)
                      : Colors.green.withValues(alpha: 0.2),
                  fallbackIcon: isPending
                      ? Icons.hourglass_empty
                      : Icons.check_circle,
                  foregroundColor: isPending
                      ? context.c.warning
                      : context.c.success,
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: context.c.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.email, size: 14, color: context.c.textTertiary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              email,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: context.c.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.badge, size: 14, color: context.c.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            'ID: $idNumber',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: context.c.textSecondary,
                            ),
                          ),
                          if (institutionCode.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.school, size: 14, color: context.c.textTertiary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: _buildInstitutionText(context, 
                                ref,
                                institutionCode,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: context.c.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Registered: ${_formatDate(createdAt)}',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: context.c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Actions
                if (isPending) ...[
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: onReject,
                    icon: isBusy
                        ? _spinner(20, context.c.danger)
                        : Icon(Icons.close, color: context.c.danger),
                    tooltip: 'Reject',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onApprove,
                    icon: isBusy
                        ? _spinner(20, context.c.success)
                        : Icon(Icons.check, color: context.c.success),
                    tooltip: 'Approve',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green.withValues(alpha: 0.1),
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: onRevoke,
                    icon: isBusy
                        ? _spinner(20, context.c.warning)
                        : Icon(Icons.block, color: context.c.warning),
                    tooltip: 'Revoke Approval',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.orange.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildInstitutionText(BuildContext context, WidgetRef ref, String code) {
    // We could fetch institution name here if we had a provider for it
    // For now just show code
    return Text(
      'Inst: $code',
      style: GoogleFonts.outfit(fontSize: 13, color: context.c.textSecondary),
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      final dt = date.toDate();
      return '${dt.day}/${dt.month}/${dt.year}';
    }
    return '';
  }
}
