import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';

final projectsListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final api = CxApiClient();
      try {
        final res = await api.dio.get('/api/mobile/projects');
        if (res.data != null && res.data['ok'] == true) {
          return (res.data['projects'] as List<dynamic>?)
                  ?.map((p) => Map<String, dynamic>.from(p))
                  .toList() ??
              [];
        }
      } catch (_) {}
      return [];
    });

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openProjectDetail(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> project,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CxColors.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => _ProjectDetailContent(
          project: project,
          scrollController: scrollController,
          onUpdateTapped: () {
            Navigator.pop(ctx);
            _openProjectUpdateSheet(context, ref, project);
          },
        ),
      ),
    );
  }

  void _openProjectUpdateSheet(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> project,
  ) {
    final completedController = TextEditingController();
    final workingController = TextEditingController();
    final blockersController = TextEditingController();
    double progressVal =
        (project['progressPercentage'] as num?)?.toDouble() ?? 75.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CxColors.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: CxSpacing.lg,
            right: CxSpacing.lg,
            top: CxSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + CxSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'SUBMIT PROJECT UPDATE',
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: CxColors.textPrimary,
                ),
              ),
              const SizedBox(height: CxSpacing.md),
              CxTextField(
                label: 'COMPLETED WORK',
                hint: 'What did you accomplish today?',
                controller: completedController,
              ),
              const SizedBox(height: CxSpacing.md),
              CxTextField(
                label: 'CURRENTLY WORKING ON',
                hint: 'e.g. API Integration or UI polish',
                controller: workingController,
              ),
              const SizedBox(height: CxSpacing.md),
              CxTextField(
                label: 'BLOCKERS',
                hint: 'None or specify obstacles',
                controller: blockersController,
              ),
              const SizedBox(height: CxSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PROGRESS: ${progressVal.toInt()}%',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: CxColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Slider(
                value: progressVal,
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: CxColors.brightRed,
                inactiveColor: CxColors.secondaryDark,
                onChanged: (val) => setSheetState(() => progressVal = val),
              ),
              const SizedBox(height: CxSpacing.lg),
              CxButton(
                label: 'SUBMIT UPDATE',
                onPressed: () async {
                  final completed = completedController.text.trim();
                  if (completed.isEmpty) return;

                  Navigator.pop(ctx);
                  final api = CxApiClient();
                  try {
                    await api.dio.post(
                      '/api/mobile/projects',
                      data: {
                        'projectId': project['id'],
                        'completedWork': completed,
                        'currentWork': workingController.text.trim(),
                        'blockers': blockersController.text.trim(),
                        'progress': progressVal.toInt(),
                      },
                    );
                    ref.invalidate(projectsListProvider);
                    ref.invalidate(myWorkProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Project progress update submitted!'),
                          backgroundColor: CxColors.success,
                        ),
                      );
                    }
                  } catch (_) {}
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CxColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: CxColors.cardElevated,
          child: TabBar(
            controller: _tabController,
            indicatorColor: CxColors.brightRed,
            indicatorWeight: 2.5,
            labelColor: CxColors.brightRed,
            unselectedLabelColor: CxColors.textSecondary,
            labelStyle: GoogleFonts.orbitron(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
            unselectedLabelStyle: GoogleFonts.orbitron(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: 'PROJECTS'),
              Tab(text: 'MY WORK'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildProjectsTab(context), _buildMyWorkTab(context)],
      ),
    );
  }

  Widget _buildProjectsTab(BuildContext context) {
    final projectsAsync = ref.watch(projectsListProvider);

    return RefreshIndicator(
      color: CxColors.brightRed,
      backgroundColor: CxColors.cardElevated,
      onRefresh: () async => ref.invalidate(projectsListProvider),
      child: projectsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: CxColors.brightRed),
        ),
        error: (err, _) => CxEmptyState(
          icon: Icons.folder_open,
          title: 'PROJECTS UNAVAILABLE',
          message: 'Could not load project assignments.',
          action: CxButton(
            label: 'RETRY',
            width: 120,
            onPressed: () => ref.invalidate(projectsListProvider),
          ),
        ),
        data: (projects) {
          if (projects.isEmpty) {
            return const CxEmptyState(
              icon: Icons.folder_open,
              title: 'NO ASSIGNED PROJECTS',
              message: 'You will see projects here once management assigns you to a workspace.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(CxSpacing.lg),
            itemCount: projects.length,
            separatorBuilder: (_, __) => const SizedBox(height: CxSpacing.md),
            itemBuilder: (context, index) {
              final p = projects[index];
              final title = p['title'] ?? 'CodeXa Project';
              final status = p['status'] ?? 'Active';
              final myRole = p['myRole'] ?? 'Contributor';
              final progress =
                  (p['progressPercentage'] as num?)?.toDouble() ?? 75.0;
              final desc =
                  p['shortDesc'] ??
                  p['overview'] ??
                  'Production development pipeline';

              return CxCard(
                onTap: () => _openProjectDetail(context, ref, p),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.orbitron(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: CxColors.textPrimary,
                            ),
                          ),
                        ),
                        CxStatusChip(label: status.toUpperCase()),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Role: $myRole',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CxColors.brightRed,
                      ),
                    ),
                    const SizedBox(height: CxSpacing.sm),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: CxColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: CxSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress / 100,
                              backgroundColor: CxColors.secondaryDark,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                CxColors.brightRed,
                              ),
                              minHeight: 5,
                            ),
                          ),
                        ),
                        const SizedBox(width: CxSpacing.md),
                        Text(
                          '${progress.toInt()}%',
                          style: GoogleFonts.orbitron(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: CxColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMyWorkTab(BuildContext context) {
    final workAsync = ref.watch(myWorkProvider);

    return RefreshIndicator(
      color: CxColors.brightRed,
      backgroundColor: CxColors.cardElevated,
      onRefresh: () async => ref.invalidate(myWorkProvider),
      child: workAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: CxColors.brightRed),
        ),
        error: (err, _) => CxEmptyState(
          icon: Icons.task_alt,
          title: 'MY WORK UNAVAILABLE',
          message: 'Could not load your active tasks.',
          action: CxButton(
            label: 'RETRY',
            width: 120,
            onPressed: () => ref.invalidate(myWorkProvider),
          ),
        ),
        data: (tasks) {
          if (tasks.isEmpty) {
            return const CxEmptyState(
              icon: Icons.task_alt,
              title: 'NO ACTIVE TASKS',
              message: 'You have no pending tasks in your assigned sprint pipelines.',
            );
          }

          final inProgress = tasks
              .where((t) => t.status == 'IN_PROGRESS')
              .toList();
          final todo = tasks.where((t) => t.status == 'TODO').toList();
          final done = tasks.where((t) => t.status == 'DONE').toList();

          return ListView(
            padding: const EdgeInsets.all(CxSpacing.lg),
            children: [
              if (inProgress.isNotEmpty) ...[
                _buildSectionHeader(
                  'IN PROGRESS',
                  inProgress.length,
                  CxColors.brightRed,
                ),
                const SizedBox(height: 8),
                ...inProgress.map((t) => _buildTaskCard(t)),
                const SizedBox(height: CxSpacing.lg),
              ],
              if (todo.isNotEmpty) ...[
                _buildSectionHeader('TO DO', todo.length, CxColors.warning),
                const SizedBox(height: 8),
                ...todo.map((t) => _buildTaskCard(t)),
                const SizedBox(height: CxSpacing.lg),
              ],
              if (done.isNotEmpty) ...[
                _buildSectionHeader('COMPLETED', done.length, CxColors.success),
                const SizedBox(height: 8),
                ...done.map((t) => _buildTaskCard(t)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.orbitron(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(MyWorkTaskModel task) {
    final isDone = task.status == 'DONE';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDone ? CxColors.textMuted : CxColors.textPrimary,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                CxStatusChip(label: task.status, isSmall: true),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              task.projectTitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: CxColors.brightRed,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: CxColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProjectDetailContent extends StatelessWidget {
  final Map<String, dynamic> project;
  final ScrollController scrollController;
  final VoidCallback onUpdateTapped;

  const _ProjectDetailContent({
    required this.project,
    required this.scrollController,
    required this.onUpdateTapped,
  });

  @override
  Widget build(BuildContext context) {
    final title = project['title'] ?? 'Project';
    final status = project['status'] ?? 'Active';
    final overview =
        project['overview'] ?? project['shortDesc'] ?? 'No overview available.';
    final stack = (project['techStack'] as List<dynamic>?) ?? [];
    final collaborators = (project['collaborators'] as List<dynamic>?) ?? [];

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(CxSpacing.lg),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.orbitron(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: CxColors.textPrimary,
                ),
              ),
            ),
            CxStatusChip(label: status.toUpperCase()),
          ],
        ),
        const SizedBox(height: CxSpacing.md),
        Text(
          'OVERVIEW',
          style: GoogleFonts.orbitron(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: CxColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          overview,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: CxColors.textPrimary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: CxSpacing.lg),

        if (stack.isNotEmpty) ...[
          Text(
            'TECH STACK',
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: CxColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: stack
                .map(
                  (s) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: CxColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: CxColors.borderSubtle),
                    ),
                    child: Text(
                      s.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: CxColors.textSecondary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: CxSpacing.lg),
        ],

        if (collaborators.isNotEmpty) ...[
          Text(
            'PROJECT TEAM',
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: CxColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          ...collaborators.map(
            (c) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CxAvatar(name: c['name'] ?? 'Team Member', radius: 14),
                  const SizedBox(width: 8),
                  Text(
                    c['name'] ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: CxColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${c['roleTitle'] ?? 'Contributor'})',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: CxColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: CxSpacing.xl),
        ],

        CxButton(label: 'SUBMIT PROGRESS UPDATE', onPressed: onUpdateTapped),
      ],
    );
  }
}
