import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'teacher_shell.dart';
import '../../auth/providers.dart';
import '../providers.dart';
import '../../../core/subject_export_generator.dart';
import '../../shared/services/file_download_helper.dart';
import '../../../core/design/app_colors.dart';

class TeacherExportsPage extends ConsumerStatefulWidget {
  const TeacherExportsPage({super.key});

  @override
  ConsumerState<TeacherExportsPage> createState() => _TeacherExportsPageState();
}

class _TeacherExportsPageState extends ConsumerState<TeacherExportsPage> {
  final Set<String> _exportingSubjects = {};

  Future<void> _exportSubjectPDF(Map<String, dynamic> subject) async {
    final subjectId = subject['id'] as String;
    setState(() => _exportingSubjects.add('$subjectId-pdf'));

    try {
      final auth = ref.read(authControllerProvider);
      final bytes = await SubjectExportGenerator.generateSubjectPDF(
        subjectName: subject['name'] ?? 'Subject',
        groupName: subject['group'] ?? subject['groupName'] ?? '',
        subjectId: subjectId,
        institutionCode: auth.institutionCode ?? '',
      );

      await downloadFile(
        filename: '${subject['name']}_${subject['group'] ?? ''}_report.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF downloaded successfully'),
            backgroundColor: context.c.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting PDF: $e'),
            backgroundColor: context.c.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exportingSubjects.remove('$subjectId-pdf'));
      }
    }
  }

  Future<void> _exportSubjectExcel(Map<String, dynamic> subject) async {
    final subjectId = subject['id'] as String;
    setState(() => _exportingSubjects.add('$subjectId-excel'));

    try {
      final auth = ref.read(authControllerProvider);
      final bytes = await SubjectExportGenerator.generateSubjectExcel(
        subjectName: subject['name'] ?? 'Subject',
        groupName: subject['group'] ?? subject['groupName'] ?? '',
        subjectId: subjectId,
        institutionCode: auth.institutionCode ?? '',
      );

      if (bytes != null) {
        await downloadFile(
          filename: '${subject['name']}_${subject['group'] ?? ''}_report.xlsx',
          bytes: bytes,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excel downloaded successfully'),
              backgroundColor: context.c.accent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting Excel: $e'),
            backgroundColor: context.c.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exportingSubjects.remove('$subjectId-excel'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncSubjects = ref.watch(teacherSubjectsProvider);

    return TeacherShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dashboard-style Header
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [context.c.accent, context.c.primary],
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.c.textPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.download_rounded,
                    color: context.c.textPrimary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export Reports',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: context.c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Download comprehensive attendance reports for your subjects',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: context.c.textPrimary.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Subjects Grid
          Expanded(
            child: asyncSubjects.when(
              data: (subjects) {
                if (subjects.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No subjects assigned',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Subjects will appear here once assigned to you',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: subjects.length,
                  itemBuilder: (context, index) {
                    final subject = subjects[index];
                    return _SubjectExportCard(
                      subject: subject,
                      onExportPDF: () => _exportSubjectPDF(subject),
                      onExportExcel: () => _exportSubjectExcel(subject),
                      isExportingPDF: _exportingSubjects.contains(
                        '${subject['id']}-pdf',
                      ),
                      isExportingExcel: _exportingSubjects.contains(
                        '${subject['id']}-excel',
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: context.c.danger,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading subjects',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: context.c.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectExportCard extends StatelessWidget {
  final Map<String, dynamic> subject;
  final VoidCallback onExportPDF;
  final VoidCallback onExportExcel;
  final bool isExportingPDF;
  final bool isExportingExcel;

  const _SubjectExportCard({
    required this.subject,
    required this.onExportPDF,
    required this.onExportExcel,
    required this.isExportingPDF,
    required this.isExportingExcel,
  });

  @override
  Widget build(BuildContext context) {
    final subjectName = subject['name'] as String? ?? 'Subject';
    final groupName =
        subject['group'] as String? ?? subject['groupName'] as String? ?? '';
    final type = subject['type'] as String? ?? '';

    final colors = [
      context.c.accent,
      context.c.primary,
      context.c.accent,
      context.c.warning,
      const Color(0xFFEC4899),
    ];
    final color = colors[subjectName.length % colors.length];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.book_rounded, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subjectName,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (groupName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.groups_rounded,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                groupName,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (type.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  type,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const Spacer(),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isExportingPDF ? null : onExportPDF,
                    icon: isExportingPDF
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf, size: 18),
                    label: Text('PDF', style: GoogleFonts.outfit(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: context.c.danger,
                      foregroundColor: context.c.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isExportingExcel ? null : onExportExcel,
                    icon: isExportingExcel
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.table_chart, size: 18),
                    label: Text(
                      'Excel',
                      style: GoogleFonts.outfit(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: context.c.accent,
                      foregroundColor: context.c.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
