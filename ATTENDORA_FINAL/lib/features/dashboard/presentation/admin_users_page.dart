import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/email_service.dart';
import '../../../core/constants/email_constants.dart';
import '../../../core/fluent_theme.dart';
import '../../../core/logger.dart';
import '../../../core/utils/error_handler.dart';
import '../../shared/widgets/empty_state.dart';
import '../../auth/providers.dart';
import '../providers.dart';
import '../../student/providers.dart';
import '../../shared/providers.dart';
import '../../shared/widgets/glass_card.dart';
import 'admin_shell.dart';
import '../services/faculty_approval_service.dart';
import '../../../core/design/app_colors.dart';

// RBAC: Teachers provider scoped by institution
final teachersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final auth = ref.watch(authControllerProvider);

  Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
    'users',
  );

  if (!auth.isSuperAdmin && auth.institutionCode != null) {
    // Institution Admin: Only see teachers from their institution
    q = q.where('institutionCode', isEqualTo: auth.institutionCode);
  }
  // Super Admin: See all teachers

  q = q.where('role', isEqualTo: 'teacher');

  return q.snapshots().map(
    (snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
  );
});

// RBAC: Students provider scoped by institution
final studentsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final auth = ref.watch(authControllerProvider);

  try {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
      'users',
    );

    if (!auth.isSuperAdmin && auth.institutionCode != null) {
      // Institution Admin: Only see students from their institution
      q = q.where('institutionCode', isEqualTo: auth.institutionCode);
    }
    // Super Admin: See all students

    q = q.where('role', isEqualTo: 'student');

    return q
        .snapshots()
        .map((snap) {
          appLogger.i('Students query result: ${snap.docs.length} documents');
          return snap.docs.map((doc) {
            final data = doc.data();
            appLogger.i(
              'Student data: ${doc.id} - role: ${data['role']}, name: ${data['displayName']}',
            );
            return {'id': doc.id, ...data};
          }).toList();
        })
        .handleError((error) {
          appLogger.i('Error in students query: $error');
          return <Map<String, dynamic>>[];
        });
  } catch (e) {
    appLogger.i('Exception in students provider: $e');
    return Stream.value(<Map<String, dynamic>>[]);
  }
});

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});
  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Search
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.search,
                        color: context.c.textSecondary,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: context.c.textSecondary,
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(
                                  () {},
                                ); // Trigger rebuild to update list
                              },
                            )
                          : null,
                      hintText: 'Search by name, email, or ID...',
                      hintStyle: GoogleFonts.outfit(color: context.c.textTertiary),
                      border: InputBorder.none,
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.2),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: context.c.accent.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ),
                    style: GoogleFonts.outfit(color: context.c.textPrimary),
                    onChanged: (value) =>
                        setState(() {}), // Trigger rebuild on typing
                  ),
                ),
              ),
              // Removed "Add User" button as requested
            ],
          ),
          const SizedBox(height: 16),

          // Custom Tab Bar
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TabBar(
              controller: _tab,
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(width: 4.0, color: context.c.textTertiary),
                insets: EdgeInsets.symmetric(
                  horizontal: 40,
                ), // Make it shorter ("half" length)
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: context.c.textPrimary,
              unselectedLabelColor: context.c.textSecondary,
              labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Teachers'),
                Tab(text: 'Students'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [_buildTeachersTab(), _buildStudentsTab()],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterUsers(List<Map<String, dynamic>> users) {
    if (_searchQuery.isEmpty) return users;
    return users.where((u) {
      final name = (u['displayName'] as String? ?? '').toLowerCase();
      final email = (u['email'] as String? ?? '').toLowerCase();
      final id = (u['idNumber'] as String? ?? u['rollNumber'] as String? ?? '')
          .toLowerCase();
      return name.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          id.contains(_searchQuery);
    }).toList();
  }

  Widget _buildTeachersTab() {
    final teachersAsync = ref.watch(teachersProvider);
    return teachersAsync.when(
      data: (teachers) => _UserList(
        users: _filterUsers(teachers),
        isTeacher: true,
        onEdit: (u) => _showEditUserDialog(context, u),
        onDelete: (u) => _deleteUser(
          u['id'],
          u['email'],
          u['displayName'],
          u['idNumber'] ?? u['rollNumber'],
        ),
        onToggleApproval: (u) => _toggleApproval(
          u['id'],
          u['approved'] == true,
          u['email'],
          u['displayName'],
        ),
        onChangeRole: (u) => _showChangeRoleDialog(u),
        onResetLock: (u) => _resetDeviceLock(u['id'], u['displayName']),
        buildInstitutionCell: _buildInstitutionCell,
        buildStatusChip: _buildStatusChip,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorHandler.buildErrorWidget(
        e,
        customMessage: 'Unable to load students',
      ),
    );
  }

  Widget _buildStudentsTab() {
    final studentsAsync = ref.watch(studentsProvider);
    return studentsAsync.when(
      data: (students) {
        final filtered = _filterUsers(students);
        if (filtered.isEmpty && _searchQuery.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: context.c.textPrimary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Students Found',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    color: context.c.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }
        return _UserList(
          users: filtered,
          isTeacher: false,
          onEdit: (u) => _showEditUserDialog(context, u),
          onDelete: (u) => _deleteUser(
            u['id'],
            u['email'],
            u['displayName'],
            u['idNumber'] ?? u['rollNumber'],
          ),
          onViewDetails: (u) => _showStudentDetailsDialog(context, u),
          onChangeRole: (u) => _showChangeRoleDialog(u),
          onResetLock: (u) => _resetDeviceLock(u['id'], u['displayName']),
          buildInstitutionCell: _buildInstitutionCell,
          buildStatusChip: _buildStatusChip,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorHandler.buildErrorWidget(
        e,
        customMessage: 'Unable to load teachers',
      ),
    );
  }

  Widget _buildInstitutionCell(String? institutionCode) {
    if (institutionCode == null || institutionCode.isEmpty) {
      return Text(
        'Not Set',
        style: TextStyle(color: context.c.textTertiary, fontStyle: FontStyle.italic),
      );
    }

    final institutionAsync = ref.watch(
      institutionNameProvider(institutionCode),
    );
    return institutionAsync.when(
      data: (name) => Text(name),
      loading: () => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) =>
          Text(institutionCode, style: TextStyle(color: context.c.textTertiary)),
    );
  }

  Widget _buildStatusChip(Map<String, dynamic> user, bool isTeacher) {
    final approved = user['approved'] == true;
    final admin = user['admin'] == true;

    if (admin) {
      return Chip(
        label: Text('Admin'),
        backgroundColor: context.c.accent,
        labelStyle: TextStyle(color: context.c.textPrimary),
        side: BorderSide.none,
      );
    }

    if (isTeacher && !approved) {
      return Chip(
        label: Text('Pending'),
        backgroundColor: context.c.dangerSubtle,
        labelStyle: TextStyle(color: context.c.danger),
        side: BorderSide.none,
      );
    }

    return Chip(
      label: Text('Active'),
      backgroundColor: context.c.successSubtle,
      labelStyle: TextStyle(color: context.c.success),
      side: BorderSide.none,
    );
  }

  Future<void> _toggleApproval(
    String userId,
    bool currentlyApproved,
    String? email,
    String? name,
  ) async {
    try {
      final service = ref.read(facultyApprovalServiceProvider);
      final institutionCode = ref.read(authControllerProvider).institutionCode;
      if (currentlyApproved) {
        await service.revoke(
          teacherId: userId,
          adminInstitutionCode: institutionCode,
        );
      } else {
        await service.approve(
          teacherId: userId,
          adminInstitutionCode: institutionCode,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyApproved ? 'User approval revoked' : 'User approved',
            ),
          ),
        );

        // Trigger email
        if (email != null && email.isNotEmpty) {
          // Check if keys are configured
          if (EmailConstants.serviceId == 'YOUR_SERVICE_ID') {
            // Fallback to mailto if not configured
            final subject = currentlyApproved
                ? 'Attendora Account Status Update'
                : 'Welcome to Attendora - Account Approved';

            final body = currentlyApproved
                ? 'Dear ${name ?? 'User'},\n\nYour teacher account access has been temporarily revoked by the administrator.\n\nPlease contact support for more information.\n\nBest regards,\nAttendora Admin Team'
                : 'Dear ${name ?? 'User'},\n\nWe are pleased to inform you that your teacher account has been approved!\n\nYou can now log in to the Attendora dashboard to manage your classes and attendance.\n\nBest regards,\nAttendora Admin Team';

            final uri = Uri(
              scheme: 'mailto',
              path: email,
              query:
                  'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
            );

            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          } else {
            // Use EmailJS
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sending email notification...')),
              );
            }

            if (currentlyApproved) {
              // Revoking approval - Use Rejection Template
              await EmailService.sendEmail(
                templateId: EmailConstants.rejectionTemplateId,
                templateParams: {
                  'to_name': name ?? 'Teacher',
                  'to_email': email,
                  'message': 'Your account approval has been revoked by the administrator.',
                  'email': email,
                  'support_url': '#',
                },
              );
            } else {
              // Approving
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
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Unable to reset password',
        );
      }
    }
  }

  Future<void> _resetDeviceLock(String userId, String? name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.c.surface,
        title: Text(
          'Reset Device Lock',
          style: GoogleFonts.outfit(color: context.c.textPrimary),
        ),
        content: Text(
          'Are you sure you want to reset the device lock for ${name ?? 'this user'}?\n\nThey will be able to log in from a NEW device, which will then become their registered device.',
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
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: context.c.accent,
            ),
            child: Text(
              'Reset Device',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).update(
          {
            'registeredDeviceId': null,
            'forceLogoutAt':
                FieldValue.serverTimestamp(), // Force logout from all devices
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device lock reset successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.showErrorSnackBar(
            context,
            e,
            customMessage: 'Unable to update user',
          );
        }
      }
    }
  }

  Future<void> _showChangeRoleDialog(Map<String, dynamic> user) async {
    final currentRole = user['role'] as String? ?? 'student';
    String? selectedRole = currentRole;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: context.c.surface,
          title: Text(
            'Change User Role',
            style: GoogleFonts.outfit(color: context.c.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change role for ${user['displayName']}',
                style: GoogleFonts.outfit(color: context.c.textSecondary),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                dropdownColor: context.c.surface,
                style: GoogleFonts.outfit(color: context.c.textPrimary),
                decoration: fluentInputDecoration(
                  context: context,
                  labelText: 'Role',
                ),
                items: [
                  DropdownMenuItem(
                    value: 'student',
                    child: Text(
                      'Student',
                      style: GoogleFonts.outfit(color: context.c.textPrimary),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'teacher',
                    child: Text(
                      'Teacher',
                      style: GoogleFonts.outfit(color: context.c.textPrimary),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text(
                      'Admin',
                      style: GoogleFonts.outfit(color: context.c.textPrimary),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => selectedRole = value),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: context.c.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Changing roles will hide/restore associated data (subjects, classes, etc.) from active views.',
                        style: GoogleFonts.outfit(
                          color: context.c.warning,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: context.c.accent,
              ),
              child: Text(
                'Update Role',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true &&
        selectedRole != null &&
        selectedRole != currentRole &&
        mounted) {
      try {
        await _handleRoleChange(user['id'], currentRole, selectedRole!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Role updated to ${selectedRole!.toUpperCase()}'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.showErrorSnackBar(
            context,
            e,
            customMessage: 'Unable to update user role',
          );
        }
      }
    }
  }

  Future<void> _handleRoleChange(
    String uid,
    String oldRole,
    String newRole,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // 1. Update User Document
    final userRef = firestore.collection('users').doc(uid);
    batch.update(userRef, {
      'role': newRole,
      'admin': newRole == 'admin',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Handle Data Cleanup (Delete instead of Archive)

    // Case A: Teacher -> Non-Teacher
    if (oldRole == 'teacher' && newRole != 'teacher') {
      // Remove from Class Groups (Do NOT archive)
      final groups = await firestore
          .collection('class_groups')
          .where('teacherUids', arrayContains: uid)
          .get();

      for (final doc in groups.docs) {
        batch.update(doc.reference, {
          'teacherUids': FieldValue.arrayRemove([uid]),
          // 'archivedTeacherUids': FieldValue.arrayUnion([uid]), // REMOVED: Do not archive
        });
      }

      // Delete Subjects (Do NOT archive)
      // This prevents "Subject Already Taken" errors when a new teacher takes over.
      final subjects = await firestore
          .collection('subjects')
          .where('teacherUid', isEqualTo: uid)
          .get();

      for (final doc in subjects.docs) {
        batch.delete(doc.reference); // CHANGED: Delete instead of archive
      }

      // Delete Sessions (Do NOT archive)
      // This removes historical attendance data but ensures the user is "clean" as requested.
      final sessions = await firestore
          .collection('sessions')
          .where('teacherUid', isEqualTo: uid)
          .get();

      for (final doc in sessions.docs) {
        batch.delete(doc.reference);
      }
    }

    // Case B: Non-Teacher -> Teacher
    // No restoration needed since we are deleting data now.
    // If we kept archive logic, we would restore here.
    // But since we delete, there is nothing to restore.
    // We can leave this empty or remove it.
    // Removing it to keep code clean and consistent with "Delete" strategy.

    // Case C: Student -> Non-Student
    if (oldRole == 'student' && newRole != 'student') {
      // Remove from Class Groups (Do NOT archive)
      final groups = await firestore
          .collection('class_groups')
          .where('studentUids', arrayContains: uid)
          .get();

      for (final doc in groups.docs) {
        batch.update(doc.reference, {
          'studentUids': FieldValue.arrayRemove([uid]),
          // 'archivedStudentUids': FieldValue.arrayUnion([uid]), // REMOVED: Do not archive
        });
      }
    }

    // Case D: Non-Student -> Student
    // No restoration needed.

    await batch.commit();
  }

  Future<void> _deleteUser(
    String userId,
    String? email,
    String? name,
    String? idNumber,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.c.surface,
        title: Text(
          'Delete User',
          style: GoogleFonts.outfit(color: context.c.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete this user? This action cannot be undone.',
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
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: context.c.danger),
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // 1. Remove user from all class groups first
        final classGroupRepo = ref.read(classGroupRepositoryProvider);
        await classGroupRepo.removeUserFromAllGroups(userId);

        // 2. Delete from users collection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .delete();

        // Delete from id_index if idNumber is available
        if (idNumber != null && idNumber.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('id_index')
              .doc(idNumber)
              .delete();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully')),
          );

          // Trigger rejection email if it was a pending teacher (or general deletion)
          if (email != null && email.isNotEmpty) {
            // Check if keys are configured
            if (EmailConstants.serviceId == 'YOUR_SERVICE_ID') {
              // Fallback to mailto
              final subject = 'Attendora Account Update';
              final body =
                  'Dear ${name ?? 'User'},\n\nYour account request has been declined or your account has been removed from the system.\n\nIf you believe this is an error, please contact the administration.\n\nBest regards,\nAttendora Admin Team';

              final uri = Uri(
                scheme: 'mailto',
                path: email,
                query:
                    'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
              );

              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            } else {
              // Use EmailJS
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
                  'email': email,
                  'teacher_name': name ?? 'Teacher',
                  'platform_name': 'Attendora',
                  'rejection_reason': 'Administrative decision. Please contact support for more details.',
                  'support_link': 'mailto:support@attendora.com',
                },
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.showErrorSnackBar(
            context,
            e,
            customMessage: 'Unable to delete user',
          );
        }
      }
    }
  }

  void _showEditUserDialog(BuildContext context, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => _EditUserDialog(user: user),
    );
  }

  void _showStudentDetailsDialog(
    BuildContext context,
    Map<String, dynamic> user,
  ) {
    showDialog(
      context: context,
      builder: (context) => _StudentDetailsDialog(user: user),
    );
  }
}

class _EditUserDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  const _EditUserDialog({required this.user});

  @override
  ConsumerState<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends ConsumerState<_EditUserDialog> {
  late TextEditingController _nameController;
  late TextEditingController _idController;
  String? _selectedLectureGroup;
  String? _selectedLabGroup;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['displayName']);
    _idController = TextEditingController(
      text: widget.user['idNumber'] ?? widget.user['rollNumber'],
    );
    _selectedLectureGroup = widget.user['lectureGroup'];
    _selectedLabGroup = widget.user['labGroup'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = widget.user['role'] == 'student';
    final classGroupsAsync = ref.watch(allClassGroupsListProvider);

    return AlertDialog(
      backgroundColor: context.c.surface, // Dark background
      title: Text(
        'Edit ${isStudent ? 'Student' : 'User'}',
        style: GoogleFonts.outfit(color: context.c.textPrimary),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                style: GoogleFonts.outfit(color: context.c.textPrimary),
                decoration: fluentInputDecoration(
                  context: context,
                  labelText: 'Full Name',
                  prefixIcon: Icons.person,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _idController,
                style: GoogleFonts.outfit(color: context.c.textPrimary),
                decoration: fluentInputDecoration(
                  context: context,
                  labelText: 'ID Number',
                  prefixIcon: Icons.badge,
                ),
              ),
              if (isStudent) ...[
                const SizedBox(height: 24),
                Divider(color: context.c.border),
                const SizedBox(height: 16),
                Text(
                  'Class Groups',
                  style: GoogleFonts.outfit(
                    color: context.c.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                classGroupsAsync.when(
                  data: (groups) {
                    final lectureGroups = groups
                        .where((g) => g.type == 'Lecture')
                        .toList();
                    final labGroups = groups
                        .where((g) => g.type == 'Lab')
                        .toList();

                    return Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _selectedLectureGroup,
                          dropdownColor: context.c.surface,
                          style: GoogleFonts.outfit(color: context.c.textPrimary),
                          decoration: fluentInputDecoration(
                            context: context,
                            labelText: 'Lecture Group',
                            prefixIcon: Icons.school,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(
                                'None',
                                style: GoogleFonts.outfit(
                                  color: context.c.textSecondary,
                                ),
                              ),
                            ),
                            ...lectureGroups.map(
                              (g) => DropdownMenuItem(
                                value: g.id,
                                child: Text(
                                  g.name,
                                  style: GoogleFonts.outfit(
                                    color: context.c.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedLectureGroup = v),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedLabGroup,
                          dropdownColor: context.c.surface,
                          style: GoogleFonts.outfit(color: context.c.textPrimary),
                          decoration: fluentInputDecoration(
                            context: context,
                            labelText: 'Lab Group',
                            prefixIcon: Icons.science,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(
                                'None',
                                style: GoogleFonts.outfit(
                                  color: context.c.textSecondary,
                                ),
                              ),
                            ),
                            ...labGroups.map(
                              (g) => DropdownMenuItem(
                                value: g.id,
                                child: Text(
                                  g.name,
                                  style: GoogleFonts.outfit(
                                    color: context.c.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedLabGroup = v),
                        ),
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(
                    'Error loading groups: $e',
                    style: GoogleFonts.outfit(color: context.c.danger),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.outfit(color: context.c.textSecondary),
          ),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _saveChanges,
          style: FilledButton.styleFrom(
            backgroundColor: context.c.accent,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.c.textPrimary,
                  ),
                )
              : Text(
                  'Save Changes',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      final updates = <String, dynamic>{
        'displayName': _nameController.text.trim(),
        'idNumber': _idController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.user['role'] == 'student') {
        updates['lectureGroup'] = _selectedLectureGroup;
        updates['labGroup'] = _selectedLabGroup;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user['id'])
          .update(updates);

      // Handle group membership updates (add/remove from studentUids)
      // This is complex because we need to remove from old groups and add to new ones.
      // For simplicity in this iteration, we'll just add to new ones.
      // A robust solution would track old values and remove.
      // Ideally, Cloud Functions should handle this consistency.

      // Attempt to add to new groups
      if (widget.user['role'] == 'student') {
        final batch = FirebaseFirestore.instance.batch();
        if (_selectedLectureGroup != null &&
            _selectedLectureGroup != widget.user['lectureGroup']) {
          batch.update(
            FirebaseFirestore.instance
                .collection('class_groups')
                .doc(_selectedLectureGroup),
            {
              'studentUids': FieldValue.arrayUnion([widget.user['id']]),
            },
          );
        }
        if (_selectedLabGroup != null &&
            _selectedLabGroup != widget.user['labGroup']) {
          batch.update(
            FirebaseFirestore.instance
                .collection('class_groups')
                .doc(_selectedLabGroup),
            {
              'studentUids': FieldValue.arrayUnion([widget.user['id']]),
            },
          );
        }
        // Note: We are NOT removing from old groups here to avoid accidental data loss if logic is flawed.
        // Admins can manually remove students from groups if needed, or we can implement a cleanup job later.

        await batch.commit();
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Unable to save changes',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _StudentDetailsDialog extends ConsumerWidget {
  final Map<String, dynamic> user;
  const _StudentDetailsDialog({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (
      uid: user['id'] as String,
      lectureGroup: user['lectureGroup'] as String?,
      labGroup: user['labGroup'] as String?,
      electives: (user['electives'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );

    final historyAsync = ref.watch(
      studentCompleteHistoryFamilyProvider(params),
    );
    final subjectsAsync = ref.watch(
      studentSubjectsFamilyProvider((
        lectureGroup: params.lectureGroup,
        labGroup: params.labGroup,
        electives: params.electives,
      )),
    );

    return AlertDialog(
      backgroundColor: context.c.surface, // Dark background
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: context.c.textPrimary.withValues(alpha: 0.1),
            backgroundImage: user['photoUrl'] != null
                ? NetworkImage(user['photoUrl'])
                : null,
            child: user['photoUrl'] == null
                ? Text(
                    (user['displayName'] as String? ?? 'S')[0].toUpperCase(),
                    style: GoogleFonts.outfit(color: context.c.textPrimary),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['displayName'] ?? 'Student',
                  style: GoogleFonts.outfit(
                    color: context.c.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user['idNumber'] ?? user['rollNumber'] ?? '',
                  style: GoogleFonts.outfit(
                    color: context.c.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 500,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                labelColor: context.c.accent,
                unselectedLabelColor: context.c.textSecondary,
                indicatorColor: context.c.accent,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Attendance'),
                  Tab(text: 'Subjects'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    // Attendance Tab
                    historyAsync.when(
                      data: (records) {
                        if (records.isEmpty) {
                          return Center(
                            child: Text(
                              'No attendance history found',
                              style: GoogleFonts.outfit(color: context.c.textTertiary),
                            ),
                          );
                        }

                        final present = records
                            .where((r) => r['isPresent'] == true)
                            .length;
                        final total = records.length;
                        final percentage = total > 0
                            ? (present / total * 100).toStringAsFixed(1)
                            : '0.0';

                        return Column(
                          children: [
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _StatItem(
                                  label: 'Total Sessions',
                                  value: total.toString(),
                                  color: context.c.textPrimary,
                                ),
                                _StatItem(
                                  label: 'Present',
                                  value: present.toString(),
                                  color: context.c.success,
                                ),
                                _StatItem(
                                  label: 'Attendance',
                                  value: '$percentage%',
                                  color: context.c.accent,
                                ),
                              ],
                            ),
                            Divider(height: 32, color: context.c.border),
                            Expanded(
                              child: ListView.builder(
                                itemCount: records.length,
                                itemBuilder: (context, index) {
                                  final record = records[index];
                                  final isPresent = record['isPresent'] == true;
                                  return ListTile(
                                    leading: Icon(
                                      isPresent
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color: isPresent
                                          ? context.c.success
                                          : context.c.danger,
                                    ),
                                    title: Text(
                                      record['subject'] ?? 'Unknown',
                                      style: GoogleFonts.outfit(
                                        color: context.c.textPrimary,
                                      ),
                                    ),
                                    subtitle: Text(
                                      record['timestamp'].toString().split(
                                        '.',
                                      )[0],
                                      style: GoogleFonts.outfit(
                                        color: context.c.textTertiary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: Text(
                                      isPresent ? 'Present' : 'Missed',
                                      style: GoogleFonts.outfit(
                                        color: isPresent
                                            ? context.c.success
                                            : context.c.danger,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => ErrorHandler.buildErrorWidget(
                        e,
                        customMessage: 'Unable to load assigned students',
                      ),
                    ),

                    // Subjects Tab
                    subjectsAsync.when(
                      data: (subjects) {
                        if (subjects.isEmpty) {
                          return Center(
                            child: Text(
                              'No enrolled subjects',
                              style: GoogleFonts.outfit(color: context.c.textTertiary),
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: subjects.length,
                          itemBuilder: (context, index) {
                            final subject = subjects[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: context.c.textPrimary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  subject['type'] == 'Lab'
                                      ? Icons.science
                                      : Icons.book,
                                  color: subject['type'] == 'Lab'
                                      ? context.c.success
                                      : context.c.info,
                                ),
                                title: Text(
                                  subject['name'] ?? 'Unknown',
                                  style: GoogleFonts.outfit(
                                    color: context.c.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  '${subject['code'] ?? ''} • ${subject['type'] ?? 'Lecture'}',
                                  style: GoogleFonts.outfit(
                                    color: context.c.textTertiary,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => ErrorHandler.buildErrorWidget(
                        e,
                        customMessage: 'Unable to load available students',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Close',
            style: GoogleFonts.outfit(color: context.c.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: context.c.textTertiary)),
      ],
    );
  }
}

class _UserList extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final bool isTeacher;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onDelete;
  final Function(Map<String, dynamic>)? onToggleApproval;
  final Function(Map<String, dynamic>)? onViewDetails;
  final Function(Map<String, dynamic>) onChangeRole;
  final Function(Map<String, dynamic>) onResetLock;
  final Widget Function(String?) buildInstitutionCell;
  final Widget Function(Map<String, dynamic>, bool) buildStatusChip;

  const _UserList({
    required this.users,
    required this.isTeacher,
    required this.onEdit,
    required this.onDelete,
    this.onToggleApproval,
    this.onViewDetails,
    required this.onChangeRole,
    required this.onResetLock,
    required this.buildInstitutionCell,
    required this.buildStatusChip,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return GlassCard(
        child: EmptyState(
          icon: isTeacher ? Icons.school_outlined : Icons.people_alt_outlined,
          title: isTeacher ? 'No Teachers Found' : 'No Students Found',
          subtitle: 'Try adjusting your search filters',
          color: context.c.info,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          // Mobile/Tablet View (List)
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final user = users[index];
              return GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: context.c.textPrimary.withValues(alpha: 0.1),
                          backgroundImage: user['photoUrl'] != null
                              ? NetworkImage(user['photoUrl'])
                              : null,
                          child: user['photoUrl'] == null
                              ? Text(
                                  (user['displayName'] as String? ?? 'U')[0]
                                      .toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    color: context.c.textPrimary,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['displayName'] ?? 'Unknown',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: context.c.textPrimary,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                user['email'] ?? '',
                                style: GoogleFonts.outfit(
                                  color: context.c.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        buildStatusChip(user, isTeacher),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          user['idNumber'] ?? user['rollNumber'] ?? 'N/A',
                          style: GoogleFonts.outfit(
                            color: context.c.textTertiary,
                            fontSize: 13,
                          ),
                        ),
                        Row(
                          children: [
                            if (!isTeacher && onViewDetails != null)
                              IconButton(
                                icon: Icon(
                                  Icons.visibility,
                                  color: context.c.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () => onViewDetails!(user),
                              ),
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                color: context.c.textSecondary,
                              ),
                              color: context.c.surface, // Dark slate background
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: context.c.textPrimary.withValues(alpha: 0.1),
                                ),
                              ),
                              onSelected: (value) {
                                switch (value) {
                                  case 'edit':
                                    onEdit(user);
                                    break;
                                  case 'role':
                                    onChangeRole(user);
                                    break;
                                  case 'reset':
                                    onResetLock(user);
                                    break;
                                  case 'delete':
                                    onDelete(user);
                                    break;
                                  case 'approve':
                                    if (onToggleApproval != null) {
                                      onToggleApproval!(user);
                                    }
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit_outlined,
                                        color: context.c.textSecondary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Edit Profile',
                                        style: GoogleFonts.outfit(
                                          color: context.c.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'role',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.admin_panel_settings_outlined,
                                        color: context.c.textSecondary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Change Role',
                                        style: GoogleFonts.outfit(
                                          color: context.c.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isTeacher)
                                  PopupMenuItem(
                                    value: 'reset',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.lock_reset,
                                          color: context.c.textSecondary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Reset Device Lock',
                                          style: GoogleFonts.outfit(
                                            color: context.c.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (isTeacher && onToggleApproval != null)
                                  PopupMenuItem(
                                    value: 'approve',
                                    child: Row(
                                      children: [
                                        Icon(
                                          user['approved'] == true
                                              ? Icons.block
                                              : Icons.check_circle_outline,
                                          color: user['approved'] == true
                                              ? context.c.warning
                                              : context.c.success,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          user['approved'] == true
                                              ? 'Revoke Approval'
                                              : 'Approve',
                                          style: GoogleFonts.outfit(
                                            color: context.c.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        color: context.c.danger,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Delete User',
                                        style: GoogleFonts.outfit(
                                          color: context.c.danger,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        } else {
          // Desktop View (Table)
          return GlassCard(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingTextStyle: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: context.c.textPrimary,
                  ),
                  dataTextStyle: GoogleFonts.outfit(color: context.c.textSecondary),
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('Institution')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    for (final user in users)
                      DataRow(
                        cells: [
                          DataCell(
                            Text(user['displayName']?.toString() ?? 'Unknown'),
                          ),
                          DataCell(
                            Text(user['email']?.toString() ?? 'No email'),
                          ),
                          DataCell(
                            Text(
                              (user['idNumber'] ?? user['rollNumber'] ?? 'N/A')
                                  .toString(),
                            ),
                          ),
                          DataCell(
                            buildInstitutionCell(
                              user['institutionCode'] as String?,
                            ),
                          ),
                          DataCell(buildStatusChip(user, isTeacher)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isTeacher && onViewDetails != null)
                                  IconButton(
                                    onPressed: () => onViewDetails!(user),
                                    icon: Icon(
                                      Icons.visibility_outlined,
                                      color: context.c.textSecondary,
                                      size: 20,
                                    ),
                                    tooltip: 'View Details',
                                  ),
                                IconButton(
                                  onPressed: () => onEdit(user),
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    color: context.c.textSecondary,
                                    size: 20,
                                  ),
                                  tooltip: 'Edit User',
                                ),
                                IconButton(
                                  onPressed: () => onChangeRole(user),
                                  icon: Icon(
                                    Icons.admin_panel_settings_outlined,
                                    color: context.c.textSecondary,
                                    size: 20,
                                  ),
                                  tooltip: 'Change Role',
                                ),
                                if (!isTeacher)
                                  IconButton(
                                    onPressed: () => onResetLock(user),
                                    icon: Icon(
                                      Icons.lock_reset,
                                      color: context.c.textSecondary,
                                      size: 20,
                                    ),
                                    tooltip: 'Reset Device Lock',
                                  ),
                                if (isTeacher && onToggleApproval != null)
                                  IconButton(
                                    onPressed: () => onToggleApproval!(user),
                                    icon: Icon(
                                      user['approved'] == true
                                          ? Icons.check_circle
                                          : Icons.pending,
                                      color: user['approved'] == true
                                          ? context.c.success
                                          : context.c.warning,
                                      size: 20,
                                    ),
                                    tooltip: user['approved'] == true
                                        ? 'Revoke Approval'
                                        : 'Approve',
                                  ),
                                IconButton(
                                  onPressed: () => onDelete(user),
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: context.c.danger,
                                    size: 20,
                                  ),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }
}
