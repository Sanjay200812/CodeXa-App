import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';

final assignmentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final api = CxApiClient();
      try {
        final res = await api.dio.get('/api/mobile/assignments');
        if (res.data != null && res.data['ok'] == true) {
          return (res.data['assignments'] as List<dynamic>?)
                  ?.map((a) => Map<String, dynamic>.from(a))
                  .toList() ??
              [];
        }
      } catch (_) {}
      return [];
    });

class AssignmentsScreen extends ConsumerStatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  ConsumerState<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends ConsumerState<AssignmentsScreen> {
  void _openSubmitModal(Map<String, dynamic> assignment) {
    final submissionType = assignment['submission_type'] ?? 'BOTH';
    final textController = TextEditingController(
      text: assignment['text_content'] ?? '',
    );
    final repoController = TextEditingController(
      text: assignment['repository_url'] ?? '',
    );
    final branchController = TextEditingController(
      text: assignment['branch'] ?? 'main',
    );
    final notesController = TextEditingController();
    String activeType = submissionType == 'REPOSITORY' ? 'REPOSITORY' : 'TEXT';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CxColors.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SUBMIT ASSIGNMENT',
                      style: GoogleFonts.orbitron(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text(
                  assignment['title'] ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CxColors.brightRed,
                  ),
                ),
                const SizedBox(height: 16),

                // Format selector if BOTH allowed
                if (submissionType == 'BOTH') ...[
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Text Submission'),
                        selected: activeType == 'TEXT',
                        selectedColor: CxColors.brightRed,
                        onSelected: (val) =>
                            setModalState(() => activeType = 'TEXT'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Repository Submission'),
                        selected: activeType == 'REPOSITORY',
                        selectedColor: CxColors.brightRed,
                        onSelected: (val) =>
                            setModalState(() => activeType = 'REPOSITORY'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                if (activeType == 'TEXT') ...[
                  CxTextField(
                    label: 'WRITTEN RESPONSE / EXPLANATION',
                    hint: 'Type your comprehensive assignment response...',
                    controller: textController,
                    maxLines: 6,
                  ),
                ] else ...[
                  CxTextField(
                    label: 'REPOSITORY URL (GITHUB / GITLAB)',
                    hint: 'https://github.com/your-username/codexa-task',
                    controller: repoController,
                  ),
                  const SizedBox(height: 12),
                  CxTextField(
                    label: 'BRANCH',
                    hint: 'main',
                    controller: branchController,
                  ),
                ],
                const SizedBox(height: 12),
                CxTextField(
                  label: 'ADDITIONAL NOTES (OPTIONAL)',
                  hint: 'Any notes for the reviewer...',
                  controller: notesController,
                  maxLines: 2,
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: CxButton(
                    label: isSubmitting ? 'SUBMITTING...' : 'SUBMIT ASSIGNMENT',
                    icon: Icons.check_circle_outline,
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final text = textController.text.trim();
                            final repo = repoController.text.trim();

                            if (activeType == 'TEXT' && text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter your text response.',
                                  ),
                                ),
                              );
                              return;
                            }
                            if (activeType == 'REPOSITORY' && repo.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter your repository URL.',
                                  ),
                                ),
                              );
                              return;
                            }

                            setModalState(() => isSubmitting = true);
                            final api = CxApiClient();

                            try {
                              final res = await api.dio.post(
                                '/api/mobile/assignments/${assignment['id']}/submit',
                                data: {
                                  'submissionType': activeType,
                                  'textContent': text,
                                  'repositoryUrl': repo,
                                  'branch': branchController.text.trim(),
                                  'notes': notesController.text.trim(),
                                },
                              );

                              if (res.data != null && res.data['ok'] == true) {
                                ref.invalidate(assignmentsProvider);
                                if (ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Assignment submitted successfully!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } else {
                                throw Exception(
                                  res.data?['error']?['message'] ?? 'Failed',
                                );
                              }
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Submission failed: ${e.toString()}',
                                    ),
                                    backgroundColor: CxColors.brightRed,
                                  ),
                                );
                              }
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assignmentsAsync = ref.watch(assignmentsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'PROJECT ASSIGNMENTS',
          style: GoogleFonts.orbitron(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: assignmentsAsync.when(
        data: (assignments) {
          if (assignments.isEmpty) {
            return const Center(
              child: CxEmptyState(
                icon: Icons.assignment_outlined,
                title: 'NO ASSIGNMENTS DUE',
                message: 'You have no pending assignments at this time.',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(CxSpacing.lg),
            itemCount: assignments.length,
            itemBuilder: (ctx, idx) {
              final asg = assignments[idx];
              final title = asg['title'] ?? 'Assignment';
              final desc = asg['description'] ?? '';
              final dueDate =
                  asg['due_date']?.toString().split('T').first ?? '';
              final submissionStatus = asg['user_submission_status'];
              final grade = asg['grade'];
              final feedback = asg['feedback'];
              final reviewer = asg['reviewer_name'];

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CxColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: submissionStatus == 'APPROVED'
                        ? Colors.green.withAlpha(100)
                        : CxColors.borderSubtle,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: CxColors.brightRed.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            asg['domain'] ?? 'General',
                            style: GoogleFonts.orbitron(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: CxColors.brightRed,
                            ),
                          ),
                        ),
                        if (submissionStatus != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: submissionStatus == 'APPROVED'
                                  ? Colors.green.withAlpha(40)
                                  : Colors.orange.withAlpha(40),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              submissionStatus,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: submissionStatus == 'APPROVED'
                                    ? Colors.greenAccent
                                    : Colors.orangeAccent,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: GoogleFonts.orbitron(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: CxColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Due: $dueDate',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: CxColors.textMuted,
                          ),
                        ),
                      ],
                    ),

                    // Review Feedback if available
                    if (feedback != null && feedback.toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CxColors.cardElevated,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reviewer Feedback ($reviewer):',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              feedback,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                            if (grade != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Grade: $grade',
                                style: GoogleFonts.orbitron(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.greenAccent,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: CxButton(
                        label: submissionStatus == null
                            ? 'SUBMIT WORK'
                            : 'RESUBMIT REVISION',
                        icon: Icons.upload_file,
                        onPressed: () => _openSubmitModal(asg),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: CxColors.brightRed),
        ),
        error: (_, __) => const Center(
          child: Text(
            'Failed to load assignments',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
