import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';

// Provider for user's personal leave requests and leadership pending approvals
final leaveDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  final api = CxApiClient();
  try {
    final res = await api.dio.get('/api/mobile/leave');
    if (res.data != null && res.data['ok'] == true) {
      return Map<String, dynamic>.from(res.data);
    }
  } catch (_) {}
  return {};
});

// Provider for full admin leave dashboard
final adminLeaveListProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) async {
    final api = CxApiClient();
    try {
      final res = await api.dio.get('/api/admin/leave');
      if (res.data != null && res.data['ok'] == true) {
        return Map<String, dynamic>.from(res.data);
      }
    } catch (_) {}
    return {};
  },
);

class LeaveScreen extends ConsumerStatefulWidget {
  const LeaveScreen({super.key});

  @override
  ConsumerState<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends ConsumerState<LeaveScreen> {
  int _currentTab = 0; // 0: Pending/My Leave, 1: Approved, 2: Declined
  bool _isSubmitting = false;
  String? _actionLoadingId;

  bool _isLeadershipRole(String? role) {
    if (role == null) return false;
    final r = role.toUpperCase();
    return [
      'FOUNDER',
      'CO_FOUNDER',
      'CEO',
      'CTO',
      'HR',
      'OWNER',
      'ADMIN',
    ].contains(r);
  }

  // --- APPROVE LEAVE ACTION ---
  Future<void> _approveLeave(String leaveId, String applicantName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CxColors.cardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'APPROVE LEAVE REQUEST',
          style: GoogleFonts.orbitron(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Grant official leave approval for $applicantName? The applicant will be notified immediately.',
          style: GoogleFonts.inter(fontSize: 13, color: CxColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.orbitron(
                fontSize: 12,
                color: CxColors.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'APPROVE',
              style: GoogleFonts.orbitron(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _actionLoadingId = leaveId);
    final api = CxApiClient();
    try {
      final res = await api.dio.post(
        '/api/admin/leave/$leaveId/approve',
        data: {'notes': 'Approved via CodeXa Mobile'},
      );
      if (res.data != null && res.data['ok'] == true) {
        ref.invalidate(leaveDataProvider);
        ref.invalidate(adminLeaveListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Leave request for $applicantName approved.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final msg =
            res.data?['error']?['message'] ?? 'Failed to approve leave.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: CxColors.brightRed),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving leave: $e'),
            backgroundColor: CxColors.brightRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoadingId = null);
    }
  }

  // --- REJECT LEAVE ACTION ---
  Future<void> _rejectLeave(String leaveId, String applicantName) async {
    final reasonController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CxColors.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: CxSpacing.lg,
          right: CxSpacing.lg,
          top: CxSpacing.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + CxSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'DECLINE LEAVE REQUEST',
              style: GoogleFonts.orbitron(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: CxColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Provide an official reason for declining leave for $applicantName. This will be dispatched to the applicant.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: CxColors.textSecondary,
              ),
            ),
            const SizedBox(height: CxSpacing.md),
            CxTextField(
              label: 'REASON FOR DECLINE',
              hint: 'e.g., Critical sprint deliverable, Insufficient notice...',
              controller: reasonController,
              maxLines: 3,
            ),
            const SizedBox(height: CxSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: CxColors.borderDefault),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'CANCEL',
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        color: CxColors.textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (reasonController.text.trim().isEmpty) return;
                      Navigator.pop(ctx, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CxColors.brightRed,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'CONFIRM DECLINE',
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) return;

    setState(() => _actionLoadingId = leaveId);
    final api = CxApiClient();
    try {
      final res = await api.dio.post(
        '/api/admin/leave/$leaveId/reject',
        data: {'reason': reason},
      );
      if (res.data != null && res.data['ok'] == true) {
        ref.invalidate(leaveDataProvider);
        ref.invalidate(adminLeaveListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Leave request for $applicantName declined.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        final msg =
            res.data?['error']?['message'] ?? 'Failed to decline leave.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: CxColors.brightRed),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining leave: $e'),
            backgroundColor: CxColors.brightRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoadingId = null);
    }
  }

  // --- APPLY LEAVE BOTTOM SHEET ---
  void _openRequestLeaveSheet() {
    final reasonController = TextEditingController();
    DateTime startDate = DateTime.now().add(const Duration(days: 1));
    DateTime endDate = DateTime.now().add(const Duration(days: 1));
    String leaveType = 'CASUAL';

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
                'APPLY FOR LEAVE',
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: CxColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Formal leave requests are routed to Founder & HR for review.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: CxColors.textSecondary,
                ),
              ),
              const SizedBox(height: CxSpacing.md),

              // Leave Type Selector
              Text(
                'LEAVE TYPE',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  color: CxColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['CASUAL', 'SICK', 'EMERGENCY', 'ACADEMIC'].map((
                    t,
                  ) {
                    final isSel = leaveType == t;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          t,
                          style: GoogleFonts.orbitron(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: isSel,
                        selectedColor: CxColors.brightRed,
                        backgroundColor: CxColors.secondaryDark,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : CxColors.textSecondary,
                        ),
                        onSelected: (val) {
                          if (val) setSheetState(() => leaveType = t);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: CxSpacing.md),

              // Date Selectors
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: CxColors.borderDefault),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 90),
                          ),
                        );
                        if (picked != null) {
                          setSheetState(() {
                            startDate = picked;
                            if (endDate.isBefore(startDate)) {
                              endDate = startDate;
                            }
                          });
                        }
                      },
                      child: Column(
                        children: [
                          Text(
                            'START DATE',
                            style: GoogleFonts.orbitron(
                              fontSize: 9,
                              color: CxColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${startDate.day}/${startDate.month}/${startDate.year}',
                            style: GoogleFonts.inter(
                              color: CxColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: CxSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: CxColors.borderDefault),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate,
                          firstDate: startDate,
                          lastDate: DateTime.now().add(
                            const Duration(days: 90),
                          ),
                        );
                        if (picked != null) {
                          setSheetState(() => endDate = picked);
                        }
                      },
                      child: Column(
                        children: [
                          Text(
                            'END DATE',
                            style: GoogleFonts.orbitron(
                              fontSize: 9,
                              color: CxColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${endDate.day}/${endDate.month}/${endDate.year}',
                            style: GoogleFonts.inter(
                              color: CxColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CxSpacing.md),

              CxTextField(
                label: 'REASON & DETAILS',
                hint: 'Provide reason for leave (medical, academic exam, personal)...',
                controller: reasonController,
                maxLines: 3,
              ),
              const SizedBox(height: CxSpacing.lg),

              CxButton(
                label: 'SUBMIT LEAVE REQUEST',
                isLoading: _isSubmitting,
                onPressed: () async {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please provide a reason for leave.'),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  setState(() => _isSubmitting = true);
                  final api = CxApiClient();
                  try {
                    final res = await api.dio.post(
                      '/api/mobile/leave',
                      data: {
                        'startDate': startDate.toIso8601String(),
                        'endDate': endDate.toIso8601String(),
                        'leaveType': leaveType,
                        'reason': reason,
                      },
                    );
                    if (res.data != null && res.data['ok'] == true) {
                      ref.invalidate(leaveDataProvider);
                      ref.invalidate(adminLeaveListProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Leave request submitted to leadership for review.',
                            ),
                            backgroundColor: CxColors.success,
                          ),
                        );
                      }
                    } else {
                      final msg =
                          res.data?['error']?['message'] ??
                          'Failed to submit leave request.';
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: CxColors.brightRed,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Submission error: $e'),
                          backgroundColor: CxColors.brightRed,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isSubmitting = false);
                  }
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
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isLeadership = _isLeadershipRole(user?.role);

    final leaveDataAsync = ref.watch(leaveDataProvider);

    return Scaffold(
      backgroundColor: CxColors.background,
      appBar: CxAppBar(
        title: isLeadership ? 'LEAVE APPROVALS' : 'LEAVE REQUESTS',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CxColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: CxColors.brightRed),
            tooltip: 'Apply for Leave',
            onPressed: _openRequestLeaveSheet,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: CxColors.brightRed,
        backgroundColor: CxColors.cardElevated,
        onRefresh: () async {
          ref.invalidate(leaveDataProvider);
          if (isLeadership) ref.invalidate(adminLeaveListProvider);
        },
        child: leaveDataAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: CxColors.brightRed),
          ),
          error: (_, __) => const CxEmptyState(
            icon: Icons.event_busy,
            title: 'LEAVE SYSTEM',
            message: 'Unable to load leave records from Core backend.',
          ),
          data: (data) {
            final myLeaves = (data['leaveRequests'] as List<dynamic>?) ?? [];
            final pendingApprovals =
                (data['pendingApprovals'] as List<dynamic>?) ?? [];
            final stats = data['leadershipStats'] as Map<String, dynamic>?;

            if (isLeadership) {
              return _buildLeadershipView(pendingApprovals, myLeaves, stats);
            } else {
              return _buildApplicantView(myLeaves);
            }
          },
        ),
      ),
    );
  }

  // =========================================================================
  // LEADERSHIP / FOUNDER / CO-FOUNDER APPROVAL DASHBOARD VIEW
  // =========================================================================
  Widget _buildLeadershipView(
    List<dynamic> pendingApprovals,
    List<dynamic> myLeaves,
    Map<String, dynamic>? stats,
  ) {
    final pendingCount = stats?['pendingCount'] ?? pendingApprovals.length;
    final approvedCount = stats?['approvedCount'] ?? 0;
    final totalCount = stats?['totalCount'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(CxSpacing.lg),
      children: [
        // Summary Cards
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CxColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amberAccent.withAlpha(80)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PENDING',
                      style: GoogleFonts.orbitron(
                        fontSize: 10,
                        color: CxColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$pendingCount',
                      style: GoogleFonts.orbitron(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.amberAccent,
                      ),
                    ),
                    Text(
                      'Awaiting review',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: CxColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CxColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent.withAlpha(80)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'APPROVED',
                      style: GoogleFonts.orbitron(
                        fontSize: 10,
                        color: CxColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$approvedCount',
                      style: GoogleFonts.orbitron(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                    Text(
                      'Granted leaves',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: CxColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CxColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CxColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL',
                      style: GoogleFonts.orbitron(
                        fontSize: 10,
                        color: CxColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalCount',
                      style: GoogleFonts.orbitron(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'All applications',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: CxColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Tabs
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _currentTab = 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _currentTab == 0
                        ? CxColors.brightRed
                        : CxColors.secondaryDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'PENDING (${pendingApprovals.length})',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _currentTab = 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _currentTab == 1
                        ? CxColors.brightRed
                        : CxColors.secondaryDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'MY LEAVE (${myLeaves.length})',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (_currentTab == 0) ...[
          // PENDING APPROVALS LIST
          if (pendingApprovals.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CxColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CxColors.borderSubtle),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.greenAccent,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ALL CAUGHT UP',
                    style: GoogleFonts.orbitron(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No pending leave applications awaiting review.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: CxColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ...pendingApprovals.map(
              (req) =>
                  _buildPendingApprovalCard(Map<String, dynamic>.from(req)),
            ),
        ] else ...[
          // MY LEAVE LIST
          if (myLeaves.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CxColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CxColors.borderSubtle),
              ),
              child: Text(
                'No personal leave requests submitted yet.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: CxColors.textSecondary,
                ),
              ),
            )
          else
            ...myLeaves.map(
              (l) => _buildPersonalLeaveCard(Map<String, dynamic>.from(l)),
            ),
        ],
      ],
    );
  }

  Widget _buildPendingApprovalCard(Map<String, dynamic> req) {
    final leaveId = req['id'] ?? '';
    final applicant = req['user'] as Map<String, dynamic>? ?? {};
    final applicantName =
        applicant['fullName'] ?? applicant['username'] ?? 'Team Member';
    final role = applicant['role'] ?? 'INTERN';
    final emp = applicant['employmentProfile'] as Map<String, dynamic>? ?? {};
    final empId = emp['employeeId'] ?? 'CXA-INT-2026';
    final domain = emp['internshipDomain'] ?? role;
    final photoUrl = applicant['profileMediaUrl'];

    final leaveType = req['leaveType'] ?? 'CASUAL';
    final reason = req['reason'] ?? '';
    final start = (req['startDate'] ?? '').toString().split('T')[0];
    final end = (req['endDate'] ?? '').toString().split('T')[0];

    final isProcessing = _actionLoadingId == leaveId;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CxColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amberAccent.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Applicant Header
          Row(
            children: [
              CxAvatar(name: applicantName, imageUrl: photoUrl, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      applicantName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: CxColors.textPrimary,
                      ),
                    ),
                    Text(
                      '$empId • $domain',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: CxColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  leaveType,
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.amberAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date Range
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: CxColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: CxColors.brightRed,
                ),
                const SizedBox(width: 6),
                Text(
                  '$start  →  $end',
                  style: GoogleFonts.orbitron(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: CxColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Reason
          Text(
            '"$reason"',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white70,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _rejectLeave(leaveId, applicantName),
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: CxColors.brightRed,
                  ),
                  label: Text(
                    'DECLINE',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: CxColors.brightRed,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: CxColors.brightRed),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _approveLeave(leaveId, applicantName),
                  icon: isProcessing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check, size: 16, color: Colors.white),
                  label: Text(
                    'APPROVE',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // APPLICANT (INTERN / EMPLOYEE) VIEW
  // =========================================================================
  Widget _buildApplicantView(List<dynamic> myLeaves) {
    final approvedCount = myLeaves
        .where((l) => l['status'] == 'APPROVED')
        .length;
    final pendingCount = myLeaves.where((l) => l['status'] == 'PENDING').length;

    return ListView(
      padding: const EdgeInsets.all(CxSpacing.lg),
      children: [
        // Summary & Apply Button
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CxColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CxColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'APPROVED',
                      style: GoogleFonts.orbitron(
                        fontSize: 10,
                        color: CxColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$approvedCount',
                      style: GoogleFonts.orbitron(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                    Text(
                      'Days approved',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: CxColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CxColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CxColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PENDING',
                      style: GoogleFonts.orbitron(
                        fontSize: 10,
                        color: CxColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$pendingCount',
                      style: GoogleFonts.orbitron(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.amberAccent,
                      ),
                    ),
                    Text(
                      'Under review',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: CxColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        CxButton(
          label: 'APPLY FOR LEAVE',
          icon: Icons.add_circle_outline,
          onPressed: _openRequestLeaveSheet,
        ),
        const SizedBox(height: 24),

        Text(
          'YOUR LEAVE HISTORY (${myLeaves.length})',
          style: GoogleFonts.orbitron(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: CxColors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),

        if (myLeaves.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: CxColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CxColors.borderSubtle),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.event_available,
                  color: CxColors.textMuted,
                  size: 36,
                ),
                const SizedBox(height: 10),
                Text(
                  'NO LEAVE REQUESTS',
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You have not submitted any leave applications.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: CxColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ...myLeaves.map(
            (l) => _buildPersonalLeaveCard(Map<String, dynamic>.from(l)),
          ),
      ],
    );
  }

  Widget _buildPersonalLeaveCard(Map<String, dynamic> l) {
    final status = l['status'] ?? 'PENDING';
    final reason = l['reason'] ?? '';
    final type = l['leaveType'] ?? 'CASUAL';
    final start = (l['startDate'] ?? '').toString().split('T')[0];
    final end = (l['endDate'] ?? '').toString().split('T')[0];
    final notes = l['reviewNotes'];

    Color statusColor = Colors.amberAccent;
    if (status == 'APPROVED') statusColor = Colors.greenAccent;
    if (status == 'REJECTED') statusColor = CxColors.brightRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CxColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CxColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                type.toUpperCase(),
                style: GoogleFonts.orbitron(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: CxColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withAlpha(100)),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$start  →  $end',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: CxColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            reason,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
          ),
          if (notes != null && notes.toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CxColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: CxColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Note: $notes',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: CxColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
