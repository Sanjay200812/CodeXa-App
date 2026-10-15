import '../stories/stories_tray.dart';
import '../assistant/ai_chat_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/models.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/cx_update_service.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static bool _hasPromptedUpdateThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptUpdate(ref.read(codeXaUpdateProvider));
    });
  }

  void _checkAndPromptUpdate(CodeXaUpdateState updateState) {
    if (_hasPromptedUpdateThisSession || !mounted) return;
    if (updateState.status == UpdateState.updateAvailable ||
        updateState.status == UpdateState.updateRequired) {
      _hasPromptedUpdateThisSession = true;
      _showUpdatePromptDialog(context, updateState);
    }
  }

  void _showUpdatePromptDialog(BuildContext context, CodeXaUpdateState updateState) {
    final info = updateState.updateInfo;
    final latestVer = info?.latestVersion ?? '1.0.5';
    final latestCode = info?.latestVersionCode ?? 105;
    final isMandatory = updateState.isMandatory;
    final releaseNotes = info?.releaseNotes ??
        'Official CodeXa Mobile Production Release v$latestVer with high-definition showcase, in-app store, and live features.';

    showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (dialogCtx) {
        return PopScope(
          canPop: !isMandatory,
          child: Dialog(
            backgroundColor: const Color(0xFF0F0F0F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: CxColors.borderDefault),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Icon & Title
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: CxColors.crimson.withAlpha(40),
                          shape: BoxShape.circle,
                          border: Border.all(color: CxColors.borderActive),
                        ),
                        child: const Icon(
                          Icons.system_update_rounded,
                          color: CxColors.brightRed,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMandatory ? 'CRITICAL UPDATE' : 'UPDATE AVAILABLE',
                              style: GoogleFonts.orbitron(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: isMandatory ? CxColors.crimson : Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'CodeXa Mobile v$latestVer (Build $latestCode)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: CxColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Release Notes Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: CxColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, color: CxColors.brightRed, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              "What's New:",
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          releaseNotes,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: CxColors.textSecondary,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Action Buttons
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(dialogCtx).pop();
                      context.push('/store');
                    },
                    icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                    label: Text(
                      'UPDATE NOW',
                      style: GoogleFonts.orbitron(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CxColors.brightRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      shadowColor: const Color(0x60FF1E3C),
                    ),
                  ),
                  if (!isMandatory) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: Text(
                        'Later',
                        style: GoogleFonts.inter(
                          color: CxColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for async update notification
    ref.listen<CodeXaUpdateState>(codeXaUpdateProvider, (previous, next) {
      _checkAndPromptUpdate(next);
    });

    final bootstrapAsync = ref.watch(bootstrapProvider);
    final attendanceState = ref.watch(attendanceProvider);

    return RefreshIndicator(
      color: CxColors.brightRed,
      backgroundColor: CxColors.cardElevated,
      onRefresh: () async {
        ref.invalidate(bootstrapProvider);
      },
      child: bootstrapAsync.when(
        loading: () => const _HomeLoadingView(),
        error: (err, stack) =>
            _HomeErrorView(onRetry: () => ref.invalidate(bootstrapProvider)),
        data: (data) {
          if (data == null) {
            return const _HomeLoadingView();
          }
          return _HomeContentView(data: data, attendanceState: attendanceState);
        },
      ),
    );
  }
}

class _HomeContentView extends ConsumerWidget {
  final BootstrapModel data;
  final AttendanceState attendanceState;

  const _HomeContentView({required this.data, required this.attendanceState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = data.user;
    final role = data.role.toUpperCase();
    final attendance = data.attendance;
    final internship = data.internship;
    final payment = data.payment;
    final metrics = data.operationalMetrics;
    final activeProjects = data.activeProjects;

    final isLeadership = [
      'FOUNDER',
      'CO_FOUNDER',
      'CEO',
      'CTO',
      'HR',
      'COO',
    ].contains(role);

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: CxSpacing.lg,
        vertical: CxSpacing.md,
      ),
      children: [
        // 1. Role-Aware Greeting Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, ${user.fullName.split(' ').first}',
                    style: GoogleFonts.orbitron(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: CxColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: CxColors.crimson.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: CxColors.brightRed.withOpacity(0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          role,
                          style: GoogleFonts.orbitron(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: CxColors.brightRed,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        user.designation ??
                            user.department ??
                            'CodeXa Workspace',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: CxColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: CxSpacing.md),

        // 1.5 24-Hour Stories Tray
        const StoriesTray(),
        const SizedBox(height: CxSpacing.md),

        // 1.8 CodeXa Store Update Notification Banner
        Consumer(
          builder: (context, ref, _) {
            final updateState = ref.watch(codeXaUpdateProvider);
            final status = updateState.status;
            final isAvail = status == UpdateState.updateAvailable ||
                status == UpdateState.updateRequired ||
                status == UpdateState.downloading ||
                status == UpdateState.readyToInstall;
            if (!isAvail) return const SizedBox.shrink();

            final info = updateState.updateInfo;
            final ver = info?.latestVersion ?? 'Latest';
            final isMandatory = updateState.isMandatory;

            return Padding(
              padding: const EdgeInsets.only(bottom: CxSpacing.md),
              child: InkWell(
                onTap: () => context.push('/store'),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMandatory ? CxColors.crimson.withAlpha(35) : CxColors.cardElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isMandatory ? CxColors.crimson : CxColors.brightRed.withAlpha(90),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: CxColors.crimson.withAlpha(50),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isMandatory ? Icons.warning_rounded : Icons.system_update_alt_rounded,
                          color: CxColors.brightRed,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMandatory ? 'CRITICAL UPDATE REQUIRED' : 'UPDATE AVAILABLE (v$ver)',
                              style: GoogleFonts.orbitron(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: isMandatory ? CxColors.crimson : CxColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tap to open CodeXa Store and update in place.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: CxColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: CxColors.brightRed),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // 2. Global Announcement if active
        if (data.announcement != null &&
            data.announcement!['enabled'] == true) ...[
          _buildAnnouncementBanner(data.announcement!),
          const SizedBox(height: CxSpacing.lg),
        ],

        // 3. ROLE-SPECIFIC SECTIONS
        if (isLeadership && metrics != null) ...[
          _buildLeadershipDashboard(context, role, metrics, activeProjects),
        ] else if (role == 'INTERN') ...[
          _buildInternDashboard(
            context,
            ref,
            attendance,
            internship,
            payment,
            activeProjects,
          ),
        ] else ...[
          _buildEmployeeDashboard(context, ref, attendance, activeProjects),
        ],

        const SizedBox(height: CxSpacing.lg),

        // 3.5 Ask AI Card
        InkWell(
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const CodexaAiScreen())),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: CxColors.cardElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CxColors.brightRed.withOpacity(0.35)),
              boxShadow: CxShadows.subtle,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: CxColors.brightRed,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ASK CODEXA AI',
                        style: GoogleFonts.orbitron(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: CxColors.brightRed,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Summarize tasks, draft standup updates & workspace Q&A',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: CxColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: CxColors.textMuted,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: CxSpacing.md),

        // 4. Quick Action Shortcuts
        Row(
          children: [
            _buildActionTile(context, Icons.auto_awesome, 'Ask AI', '/ai'),
            const SizedBox(width: CxSpacing.sm),
            _buildActionTile(
              context,
              Icons.people_outline,
              'Directory',
              '/people',
            ),
            const SizedBox(width: CxSpacing.sm),
            _buildActionTile(context, Icons.event_note, 'Leave', '/leave'),
            const SizedBox(width: CxSpacing.sm),
            _buildActionTile(
              context,
              Icons.receipt_long,
              'Payments',
              '/payments',
            ),
            const SizedBox(width: CxSpacing.sm),
            _buildActionTile(
              context,
              Icons.folder_shared_outlined,
              'Docs',
              '/documents',
            ),
          ],
        ),
        const SizedBox(height: CxSpacing.xl),
      ],
    );
  }

  // --- LEADERSHIP DASHBOARD ---
  Widget _buildLeadershipDashboard(
    BuildContext context,
    String role,
    OperationalMetricsModel metrics,
    List<ProjectItemModel> projects,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              role == 'FOUNDER' || role == 'CO_FOUNDER'
                  ? 'ORGANIZATION PULSE'
                  : role == 'CTO'
                  ? 'TECHNICAL OVERVIEW'
                  : role == 'HR'
                  ? 'STAFF & ATTENDANCE PULSE'
                  : 'EXECUTIVE OVERVIEW',
              style: GoogleFonts.orbitron(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: CxColors.textSecondary,
                letterSpacing: 1.0,
              ),
            ),
            const CxStatusChip(label: 'LIVE', isSmall: true),
          ],
        ),
        const SizedBox(height: CxSpacing.sm),

        // Operational Metrics Grid
        Row(
          children: [
            _buildMetricTile(
              'EMPLOYEES',
              '${metrics.activeEmployees}',
              Icons.badge_outlined,
              CxColors.success,
            ),
            const SizedBox(width: CxSpacing.md),
            _buildMetricTile(
              'INTERNS',
              '${metrics.activeInterns}',
              Icons.school_outlined,
              const Color(0xFFF77F00),
            ),
          ],
        ),
        const SizedBox(height: CxSpacing.md),
        Row(
          children: [
            _buildMetricTile(
              'TODAY PRESENT',
              '${metrics.todayPresentCount}',
              Icons.how_to_reg_outlined,
              CxColors.brightRed,
            ),
            const SizedBox(width: CxSpacing.md),
            _buildMetricTile(
              'PENDING LEAVE',
              '${metrics.pendingLeaveCount}',
              Icons.pending_actions_outlined,
              CxColors.warning,
            ),
          ],
        ),
        const SizedBox(height: CxSpacing.lg),

        // Company Projects Overview
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ACTIVE COMPANY PROJECTS',
              style: GoogleFonts.orbitron(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: CxColors.textSecondary,
                letterSpacing: 1.0,
              ),
            ),
            GestureDetector(
              onTap: () => context.go('/projects'),
              child: Text(
                'View All (${metrics.totalProjectsCount})',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: CxColors.brightRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: CxSpacing.sm),
        if (projects.isEmpty)
          const CxEmptyState(
            icon: Icons.folder_open,
            title: 'NO ACTIVE PROJECTS',
            message: 'No active client or internal projects found.',
          )
        else
          ...projects.take(3).map((p) => _buildProjectCard(context, p)),
      ],
    );
  }

  // --- INTERN DASHBOARD ---
  Widget _buildInternDashboard(
    BuildContext context,
    WidgetRef ref,
    AttendanceStateModel attendance,
    InternshipModel? internship,
    PaymentInfoModel? payment,
    List<ProjectItemModel> projects,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A) Pre-Start or Active Attendance
        _buildAttendancePriorityCard(context, ref, attendance, internship),
        const SizedBox(height: CxSpacing.lg),

        // B) Internship Service Fee Alert (if due)
        if (payment != null &&
            payment.status != 'APPROVED' &&
            payment.status != 'SUCCESSFUL') ...[
          CxCard(
            isActive: true,
            onTap: () => context.push('/payments'),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: CxColors.crimson.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: CxColors.brightRed.withOpacity(0.5),
                    ),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: CxColors.brightRed,
                    size: 22,
                  ),
                ),
                const SizedBox(width: CxSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INTERNSHIP SERVICE BILL DUE',
                        style: GoogleFonts.orbitron(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: CxColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Official Smart ID Card & Dev Stack (₹450)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: CxColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                CxButton(
                  label: 'PAY ₹450',
                  width: 90,
                  height: 36,
                  onPressed: () => context.push('/payments'),
                ),
              ],
            ),
          ),
          const SizedBox(height: CxSpacing.lg),
        ],

        // C) Internship Domain & Mentor Card
        if (internship != null) ...[
          CxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'INTERNSHIP PROGRAM',
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: CxColors.textSecondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    CxStatusChip(label: internship.status, isSmall: true),
                  ],
                ),
                const SizedBox(height: CxSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Domain',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: CxColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            internship.domain,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: CxColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mentor',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: CxColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            internship.mentorName,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: CxColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: CxSpacing.lg),
        ],

        // D) Assigned Project
        Text(
          'ASSIGNED PROJECT',
          style: GoogleFonts.orbitron(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: CxColors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: CxSpacing.sm),
        if (projects.isEmpty)
          const CxEmptyState(
            icon: Icons.assignment_outlined,
            title: 'NO ASSIGNED PROJECTS',
            message: 'You have not been assigned to a project yet. Projects will appear here once assigned by your mentor.',
          )
        else
          ...projects.take(2).map((p) => _buildProjectCard(context, p)),
      ],
    );
  }

  // --- EMPLOYEE DASHBOARD ---
  Widget _buildEmployeeDashboard(
    BuildContext context,
    WidgetRef ref,
    AttendanceStateModel attendance,
    List<ProjectItemModel> projects,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAttendancePriorityCard(context, ref, attendance, null),
        const SizedBox(height: CxSpacing.lg),

        Text(
          'ASSIGNED PROJECTS',
          style: GoogleFonts.orbitron(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: CxColors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: CxSpacing.sm),
        if (projects.isEmpty)
          const CxEmptyState(
            icon: Icons.folder_open,
            title: 'NO ASSIGNED PROJECTS',
            message: 'No assigned projects. Check back once projects are provisioned.',
          )
        else
          ...projects.take(2).map((p) => _buildProjectCard(context, p)),
      ],
    );
  }

  // --- ATTENDANCE PRIORITY CARD ---
  Widget _buildAttendancePriorityCard(
    BuildContext context,
    WidgetRef ref,
    AttendanceStateModel attendance,
    InternshipModel? internship,
  ) {
    // 1. Mandatory Pre-Start Rule for Intern
    if (attendance.isPreStart ||
        attendance.lifecycleStatus == 'PRE_START' ||
        attendance.lifecycleStatus == 'COMING_SOON') {
      final startDateFormatted = internship?.startDate != null
          ? _formatDate(internship!.startDate!)
          : 'To be scheduled';

      return CxCard(
        backgroundColor: const Color(0xFF141208),
        borderColor: CxColors.warning.withOpacity(0.4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CxColors.warning.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: CxColors.warning),
              ),
              child: const Icon(
                Icons.access_time_filled,
                color: CxColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: CxSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'ATTENDANCE',
                        style: GoogleFonts.orbitron(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: CxColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const CxStatusChip(label: 'COMING SOON', isSmall: true),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Starts: $startDateFormatted (${internship?.daysUntilStart ?? 0} days left)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: CxColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 2. Attendance Marked
    if (attendance.todayRecord != null || attendanceState.markedSuccess) {
      return CxCard(
        isActive: true,
        backgroundColor: const Color(0xFF0C1A11),
        borderColor: CxColors.success.withOpacity(0.4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: CxColors.success.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: CxColors.success),
              ),
              child: const Icon(Icons.check, color: CxColors.success, size: 22),
            ),
            const SizedBox(width: CxSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ATTENDANCE MARKED',
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: CxColors.success,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Today: PRESENT • Verified',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: CxColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const CxStatusChip(label: 'PRESENT', isSmall: true),
          ],
        ),
      );
    }

    // 3. Check-In Window Active
    if (attendance.canMark && attendance.currentWindow != null) {
      return CxCard(
        isActive: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: CxColors.brightRed,
                        shape: BoxShape.circle,
                        boxShadow: CxShadows.neonGlow,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'WINDOW ACTIVE',
                      style: GoogleFonts.orbitron(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: CxColors.brightRed,
                      ),
                    ),
                  ],
                ),
                const CxStatusChip(label: 'OPEN', isSmall: true),
              ],
            ),
            const SizedBox(height: CxSpacing.sm),
            Text(
              'Mark your presence before today\'s window closes.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: CxColors.textSecondary,
              ),
            ),
            const SizedBox(height: CxSpacing.md),
            CxButton(
              label: 'MARK PRESENT',
              isLoading: attendanceState.isMarking,
              onPressed: attendanceState.isMarking
                  ? null
                  : () async {
                      final ok = await ref
                          .read(attendanceProvider.notifier)
                          .markPresent();
                      if (context.mounted && ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Attendance marked successfully!'),
                            backgroundColor: CxColors.success,
                          ),
                        );
                      }
                    },
            ),
          ],
        ),
      );
    }

    // 4. Closed / Inactive
    return CxCard(
      onTap: () => context.go('/attendance'),
      child: Row(
        children: [
          const Icon(Icons.lock_clock, color: CxColors.textMuted, size: 22),
          const SizedBox(width: CxSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ATTENDANCE WINDOW CLOSED',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CxColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Next check-in window will open as scheduled.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: CxColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const CxStatusChip(label: 'CLOSED', isSmall: true),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    String label,
    String value,
    IconData icon,
    Color accentColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CxColors.card,
          borderRadius: BorderRadius.circular(CxSpacing.cardRadius),
          border: Border.all(color: CxColors.borderDefault),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: GoogleFonts.orbitron(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: CxColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                Icon(icon, size: 16, color: accentColor),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.orbitron(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, ProjectItemModel project) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CxSpacing.sm),
      child: CxCard(
        onTap: () => context.go('/projects'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    project.title,
                    style: GoogleFonts.orbitron(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: CxColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                CxStatusChip(label: project.status, isSmall: true),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              project.shortDesc ?? project.category,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: CxColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: CxSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Role: ${project.myRole}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: CxColors.textMuted,
                  ),
                ),
                Text(
                  '${project.progressPercentage.toInt()}%',
                  style: GoogleFonts.orbitron(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: CxColors.brightRed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementBanner(Map<String, dynamic> ann) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CxColors.cardElevated,
        borderRadius: BorderRadius.circular(CxSpacing.cardRadius),
        border: Border.all(color: CxColors.brightRed.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign, color: CxColors.brightRed, size: 24),
          const SizedBox(width: CxSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ann['title'] ?? 'Announcement',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CxColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ann['message'] ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: CxColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context,
    IconData icon,
    String label,
    String route,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () => context.push(route),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: CxColors.card,
            borderRadius: BorderRadius.circular(CxSpacing.buttonRadius),
            border: Border.all(color: CxColors.borderDefault),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: CxColors.brightRed),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: CxColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return isoString;
    }
  }
}

class _HomeLoadingView extends StatelessWidget {
  const _HomeLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(CxSpacing.lg),
      children: const [
        CxLoadingSkeleton(width: 180, height: 24),
        SizedBox(height: CxSpacing.sm),
        CxLoadingSkeleton(width: 120, height: 16),
        SizedBox(height: CxSpacing.xl),
        CxLoadingSkeleton(
          width: double.infinity,
          height: 140,
          borderRadius: 18,
        ),
        SizedBox(height: CxSpacing.lg),
        Row(
          children: [
            Expanded(
              child: CxLoadingSkeleton(
                width: double.infinity,
                height: 100,
                borderRadius: 18,
              ),
            ),
            SizedBox(width: CxSpacing.md),
            Expanded(
              child: CxLoadingSkeleton(
                width: double.infinity,
                height: 100,
                borderRadius: 18,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HomeErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _HomeErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return CxEmptyState(
      icon: Icons.cloud_off,
      title: 'CONNECTION ERROR',
      message: 'Could not synchronize with CodeXa core servers.',
      action: CxButton(label: 'RETRY SYNC', width: 160, onPressed: onRetry),
    );
  }
}
