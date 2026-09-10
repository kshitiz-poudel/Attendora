import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/design/app_colors.dart';
import '../../../shared/models/class_group.dart';
import '../../../shared/providers.dart';
import '../admin_class_groups_page.dart' show allStudentsProvider, allTeachersProvider;
import '../../../shared/widgets/async_section.dart';

/// Add/remove members of a class group (lecture or lab).
///
/// The repository keeps the group's membership array and the member's own
/// `lectureGroup` / `labGroup` field in step, so assigning here is what makes
/// the group's subjects actually appear for that student.
class GroupMemberManager extends ConsumerStatefulWidget {
  const GroupMemberManager({
    super.key,
    required this.group,
    required this.role,
  });

  final ClassGroup group;

  /// 'student' or 'teacher'.
  final String role;

  @override
  ConsumerState<GroupMemberManager> createState() => _GroupMemberManagerState();
}

class _GroupMemberManagerState extends ConsumerState<GroupMemberManager> {
  final _searchController = TextEditingController();
  String _query = '';
  final Set<String> _busy = {};

  bool get _isStudent => widget.role == 'student';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _memberUids =>
      _isStudent ? widget.group.studentUids : widget.group.teacherUids;

  Future<void> _toggle(String uid, bool isMember) async {
    setState(() => _busy.add(uid));
    final repo = ref.read(classGroupRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (isMember) {
        if (_isStudent) {
          await repo.removeStudent(groupId: widget.group.id, studentUid: uid);
        } else {
          await repo.removeTeacher(groupId: widget.group.id, teacherUid: uid);
        }
      } else {
        if (_isStudent) {
          await repo.assignStudent(groupId: widget.group.id, studentUid: uid);
        } else {
          await repo.assignTeacher(groupId: widget.group.id, teacherUid: uid);
        }
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update membership: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final peopleAsync = _isStudent
        ? ref.watch(allStudentsProvider)
        : ref.watch(allTeachersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: _isStudent
                ? 'Search students by name, roll number or email'
                : 'Search faculty by name or email',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: AsyncSection<List<Map<String, dynamic>>>(
            value: peopleAsync,
            skeleton: const SkeletonList(rows: 5),
            builder: (context, people) {
              // Only offer people from the same institution as the group.
              final scoped = people.where((p) {
                final code = p['institutionCode'] as String?;
                return widget.group.institutionCode == null ||
                    code == null ||
                    code == widget.group.institutionCode;
              }).toList();

              final filtered = scoped.where((p) {
                if (_query.isEmpty) return true;
                final haystack = [
                  p['displayName'],
                  p['email'],
                  p['idNumber'],
                  p['rollNumber'],
                ].whereType<String>().join(' ').toLowerCase();
                return haystack.contains(_query);
              }).toList();

              // Current members first, so the assigned set is obvious.
              filtered.sort((a, b) {
                final aIn = _memberUids.contains(a['id']) ? 0 : 1;
                final bIn = _memberUids.contains(b['id']) ? 0 : 1;
                if (aIn != bIn) return aIn.compareTo(bIn);
                return (a['displayName'] as String? ?? '').toLowerCase().compareTo(
                  (b['displayName'] as String? ?? '').toLowerCase(),
                );
              });

              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    _query.isEmpty
                        ? 'No ${_isStudent ? 'students' : 'faculty'} in this institution yet'
                        : 'No matches for "$_query"',
                    style: GoogleFonts.outfit(color: c.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: c.border),
                itemBuilder: (context, i) {
                  final person = filtered[i];
                  final uid = person['id'] as String;
                  final isMember = _memberUids.contains(uid);
                  final isBusy = _busy.contains(uid);
                  final subtitle = [
                    person['idNumber'] ?? person['rollNumber'],
                    person['email'],
                  ].whereType<String>().where((e) => e.isNotEmpty).join('  ·  ');

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: CircleAvatar(
                      backgroundColor: isMember
                          ? c.accentSubtle
                          : c.surfaceMuted,
                      child: Icon(
                        _isStudent
                            ? Icons.person_rounded
                            : Icons.school_rounded,
                        size: 18,
                        color: isMember ? c.accent : c.textTertiary,
                      ),
                    ),
                    title: Text(
                      person['displayName'] as String? ?? 'Unnamed',
                      style: GoogleFonts.outfit(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: subtitle.isEmpty
                        ? null
                        : Text(
                            subtitle,
                            style: GoogleFonts.outfit(
                              color: c.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                    trailing: isBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : isMember
                        ? OutlinedButton.icon(
                            onPressed: () => _toggle(uid, true),
                            icon: const Icon(Icons.remove_rounded, size: 16),
                            label: const Text('Remove'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: c.danger,
                              side: BorderSide(color: c.danger),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          )
                        : FilledButton.icon(
                            onPressed: () => _toggle(uid, false),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Assign'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
