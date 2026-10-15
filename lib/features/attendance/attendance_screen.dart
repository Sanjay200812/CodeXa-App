import '../classes/class_details_screen.dart';
import '../classes/daily_topics_screen.dart';
import '../assignments/assignments_screen.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';

// Provider for dedicated attendance endpoint
final classesEndpointProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
      final api = CxApiClient();
      try {
        final res = await api.dio.get('/api/mobile/classes');
        if (res.data != null && res.data['ok'] == true) {
          return Map<String, dynamic>.from(res.data);
        }
      } catch (_) {}
      return {};
    });

final attendanceEndpointProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
      final api = CxApiClient();
      try {
        final res = await api.dio.get('/api/mobile/attendance');
        if (res.data != null && res.data['ok'] == true) {
          return Map<String, dynamic>.from(res.data);
        }
      } catch (_) {}
      return {};
    });

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  bool _isMarking = false;
  bool _isControllingWindow = false;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      }
    });
  }

  String _formatSeconds(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _openWindowDialog(BuildContext context) async {
    int selectedDuration = 30;

    await showModalBottomSheet(
      context: context,
      backgroundColor: CxColors.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OPEN ATTENDANCE WINDOW',
                style: GoogleFonts.orbitron(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: CxColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select duration for team & intern check-in slot. A push notification will be broadcast to eligible members.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: CxColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [15, 30, 45, 60].map((dur) {
                  final isSelected = selectedDuration == dur;
                  return InkWell(
                    onTap: () => setSheetState(() => selectedDuration = dur),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? CxColors.crimson
                            : CxColors.secondaryDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? CxColors.accent
                              : CxColors.borderSubtle,
                        ),
                      ),
                      child: Text(
                        '$dur MIN',
                        style: GoogleFonts.orbitron(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              CxButton(
                label: 'BROADCAST & OPEN WINDOW',
                icon: Icons.notifications_active_outlined,
                isLoading: _isControllingWindow,
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _controlWindow('OPEN', duration: selectedDuration);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _controlWindow(String action, {int duration = 30}) async {
    setState(() => _isControllingWindow = true);
    final api = CxApiClient();
    try {
      final res = await api.dio.post(
        '/api/mobile/attendance/window',
        data: {'action': action, 'durationMinutes': duration},
      );
      if (res.data != null && res.data['ok'] == true) {
        ref.invalidate(attendanceEndpointProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res.data['message'] ?? 'Attendance window updated.',
              ),
              backgroundColor: CxColors.crimson,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res.data?['error']?['message'] ??
                    'Failed to update attendance window.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Network error updating attendance window.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isControllingWindow = false);
    }
  }

  Future<void> _markSelfAttendance() async {
    setState(() => _isMarking = true);
    final api = CxApiClient();
    try {
      final res = await api.dio.post('/api/mobile/attendance/mark');
      if (res.data != null && res.data['ok'] == true) {
        ref.invalidate(attendanceEndpointProvider);
        ref.invalidate(bootstrapProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance marked PRESENT successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res.data?['error']?['message'] ?? 'Could not mark attendance.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error communicating with CodeXa attendance service.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMarking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attAsync = ref.watch(attendanceEndpointProvider);

    return Scaffold(
      backgroundColor: CxColors.background,
      appBar: AppBar(
        backgroundColor: CxColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: CxColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'ATTENDANCE',
          style: GoogleFonts.orbitron(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: CxColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: CxColors.textSecondary,
            ),
            onPressed: () => ref.invalidate(attendanceEndpointProvider),
          ),
        ],
      ),
      body: attAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: CxColors.crimson),
        ),
        error: (_, __) => _buildErrorState(),
        data: (data) {
          if (data.isEmpty) return _buildErrorState();

          final isManagement = data['isManagement'] == true;
          if (isManagement) {
            return _buildManagementView(data);
          } else {
            return _buildParticipantView(data);
          }
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: CxColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'COULD NOT SYNC ATTENDANCE',
              style: GoogleFonts.orbitron(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: CxColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to load attendance lifecycle data from server.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: CxColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CxButton(
              label: 'RETRY',
              width: 140,
              onPressed: () => ref.invalidate(attendanceEndpointProvider),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // LEADERSHIP / FOUNDER ATTENDANCE DASHBOARD
  // =========================================================================
  Widget _buildManagementView(Map<String, dynamic> data) {
    final window = data['window'] as Map<String, dynamic>?;
    final isWindowOpen = window != null && window['status'] == 'ACTIVE';
    final remaining = (window?['remainingSeconds'] ?? 0) as int;
    if (_remainingSeconds == 0 && remaining > 0) {
      _remainingSeconds = remaining;
    }

    final metrics = data['metrics'] as Map<String, dynamic>? ?? {};
    final totalEligible = metrics['totalEligible'] ?? 0;
    final presentCount = metrics['presentCount'] ?? 0;
    final lateCount = metrics['lateCount'] ?? 0;
    final leaveCount = metrics['leaveCount'] ?? 0;
    final notMarked = metrics['notMarkedCount'] ?? 0;

    final todayRecords = (data['todayRecords'] as List<dynamic>?) ?? [];
    final calendar = (data['calendar'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      color: CxColors.crimson,
      backgroundColor: CxColors.cardElevated,
      onRefresh: () async => ref.invalidate(attendanceEndpointProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Control Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CxColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isWindowOpen
                    ? CxColors.crimson.withAlpha(160)
                    : CxColors.borderSubtle,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isWindowOpen
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isWindowOpen
                              ? 'ATTENDANCE WINDOW OPEN'
                              : 'ATTENDANCE WINDOW CLOSED',
                          style: GoogleFonts.orbitron(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: isWindowOpen
                                ? Colors.greenAccent
                                : CxColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (isWindowOpen && _remainingSeconds > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: CxColors.crimson.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: CxColors.crimson),
                        ),
                        child: Text(
                          _formatSeconds(_remainingSeconds),
                          style: GoogleFonts.orbitron(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: CxColors.accent,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  isWindowOpen
                      ? 'Active check-in window open for team members and interns. You may close or extend the slot.'
                      : 'No attendance window is currently open for check-ins. Tap below to broadcast and open check-in.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: CxColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                if (isWindowOpen)
                  CxButton(
                    label: 'CLOSE ATTENDANCE WINDOW',
                    icon: Icons.cancel_outlined,
                    backgroundColor: CxColors.secondaryDark,
                    isLoading: _isControllingWindow,
                    onPressed: () => _controlWindow('CLOSE'),
                  )
                else
                  CxButton(
                    label: 'OPEN ATTENDANCE WINDOW',
                    icon: Icons.door_sliding_outlined,
                    isLoading: _isControllingWindow,
                    onPressed: () => _openWindowDialog(context),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 2. Metrics Grid
          Text(
            'TODAY\'S ATTENDANCE SUMMARY',
            style: GoogleFonts.orbitron(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: CxColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'ELIGIBLE',
                  '$totalEligible',
                  CxColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  'PRESENT',
                  '$presentCount',
                  Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  'LATE',
                  '$lateCount',
                  Colors.orangeAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'ON LEAVE',
                  '$leaveCount',
                  Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  'NOT MARKED',
                  '$notMarked',
                  Colors.redAccent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 3. Month Attendance Calendar
          Text(
            'MONTH OVERVIEW',
            style: GoogleFonts.orbitron(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: CxColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CxColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CxColors.borderSubtle),
            ),
            child: calendar.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No past records for this month yet.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: CxColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: calendar.take(7).map((c) {
                      final d = c['date'] ?? '';
                      final p = c['present'] ?? 0;
                      final l = c['late'] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              d,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: CxColors.textPrimary,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '$p Present',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (l > 0) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '$l Late',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.orangeAccent,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),

          const SizedBox(height: 24),

          // 4. Today Attendees List
          Text(
            'TODAY\'S CHECK-INS (${todayRecords.length})',
            style: GoogleFonts.orbitron(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: CxColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          if (todayRecords.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CxColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CxColors.borderSubtle),
              ),
              child: Text(
                'No check-ins recorded today yet.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: CxColors.textSecondary,
                ),
              ),
            )
          else
            ...todayRecords.map(
              (r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: CxColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CxColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    CxAvatar(
                      name: r['name']?.toString() ?? 'Colleague',
                      imageUrl:
                          r['profileMediaUrl']?.toString() ??
                          r['avatarUrl']?.toString(),
                      radius: 16,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r['name'] ?? 'Colleague',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: CxColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${r['role'] ?? ''} • ${r['employeeId'] ?? ''}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: CxColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: r['status'] == 'PRESENT'
                            ? Colors.green.withAlpha(30)
                            : Colors.orange.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: r['status'] == 'PRESENT'
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                      child: Text(
                        r['status'] ?? 'PRESENT',
                        style: GoogleFonts.orbitron(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: r['status'] == 'PRESENT'
                              ? Colors.greenAccent
                              : Colors.orangeAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: CxColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CxColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.orbitron(
              fontSize: 9,
              color: CxColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.orbitron(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // PARTICIPANT (INTERN / EMPLOYEE) ATTENDANCE VIEW
  // =========================================================================
  Widget _buildParticipantView(Map<String, dynamic> data) {
    final state = data['state'] ?? 'NOT_OPENED';
    final message = data['message'] ?? '';
    final startDate = data['startDate'];
    final daysUntilStart = data['daysUntilStart'] ?? 0;
    final stats = data['stats'] as Map<String, dynamic>? ?? {};
    final history = (data['history'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      color: CxColors.crimson,
      backgroundColor: CxColors.cardElevated,
      onRefresh: () async => ref.invalidate(attendanceEndpointProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Lifecycle State Banner
          if (state == 'BEFORE_START')
            _buildBeforeStartCard(startDate, daysUntilStart)
          else if (state == 'OPEN')
            _buildOpenCard()
          else if (state == 'MARKED')
            _buildMarkedCard(data['myRecord'])
          else if (state == 'CLOSED')
            _buildClosedCard()
          else if (state == 'COMPLETED')
            _buildCompletedCard()
          else
            _buildNotOpenedCard(message),

          const SizedBox(height: 24),

          // 2. Personal Attendance Stats
          if (state != 'BEFORE_START') ...[
            Text(
              'ATTENDANCE STATISTICS',
              style: GoogleFonts.orbitron(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: CxColors.textSecondary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'PRESENT',
                    '${stats['presentCount'] ?? 0}',
                    Colors.greenAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'LATE',
                    '${stats['lateCount'] ?? 0}',
                    Colors.orangeAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'LEAVE',
                    '${stats['leaveCount'] ?? 0}',
                    Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'RATE',
                    '${stats['percentage'] ?? 100}%',
                    CxColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // 3. Monthly Attendance Calendar Grid
          if (state != 'BEFORE_START') ...[
            _buildMonthlyCalendar(history),
            const SizedBox(height: 20),
          ],

          // 4. Daily Topics Hero Card
          _buildDailyTopicsHeroCard(),
          const SizedBox(height: 20),

          // 5. Quick Link to Assignments
          _buildAssignmentsCard(),
          const SizedBox(height: 24),

          // 6. Scheduled Classes Section (Below Attendance)
          _buildScheduledClassesSection(),
        ],
      ),
    );
  }

  Widget _buildBeforeStartCard(String? startDate, int daysUntilStart) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CxColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CxColors.borderSubtle),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: CxColors.secondaryDark,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amberAccent.withAlpha(100)),
            ),
            child: const Icon(
              Icons.access_time_rounded,
              color: Colors.amberAccent,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'COMING SOON',
            style: GoogleFonts.orbitron(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: CxColors.textPrimary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Attendance will become available when your internship begins.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: CxColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: CxColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CxColors.borderSubtle),
            ),
            child: Column(
              children: [
                Text(
                  'INTERNSHIP START DATE',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    color: CxColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  startDate != null
                      ? startDate.split('T')[0]
                      : 'Scheduled by CodeXa',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: CxColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Starts in $daysUntilStart days',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: CxColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CxColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CxColors.crimson, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ATTENDANCE OPEN',
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.greenAccent,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'The daily check-in window is open. Mark yourself present before the slot concludes.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: CxColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          CxButton(
            label: 'MARK PRESENT',
            icon: Icons.check_circle_outline,
            isLoading: _isMarking,
            onPressed: _markSelfAttendance,
          ),
        ],
      ),
    );
  }

  Widget _buildMarkedCard(Map<String, dynamic>? record) {
    final status = record?['status'] ?? 'PRESENT';
    final timeStr =
        record?['checkInTime']?.toString().split('T')[1].split('.')[0] ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CxColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.greenAccent.withAlpha(120),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.verified_rounded,
            size: 48,
            color: Colors.greenAccent,
          ),
          const SizedBox(height: 12),
          Text(
            'ATTENDANCE MARKED $status',
            style: GoogleFonts.orbitron(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.greenAccent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Recorded today at $timeStr. You are all set for today.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: CxColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildClosedCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CxColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CxColors.borderSubtle),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.lock_clock_outlined,
            size: 44,
            color: Colors.orangeAccent,
          ),
          const SizedBox(height: 12),
          Text(
            'ATTENDANCE CLOSED',
            style: GoogleFonts.orbitron(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.orangeAccent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Today\'s attendance window has ended. Check-ins are no longer accepted for this slot.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: CxColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotOpenedCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CxColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CxColors.borderSubtle),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_busy_outlined,
            size: 44,
            color: CxColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'ATTENDANCE NOT OPENED',
            style: GoogleFonts.orbitron(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: CxColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message.isNotEmpty ? message : 'Attendance window is not open right now. You will receive a notification when leadership opens check-ins.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: CxColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CxColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withAlpha(120)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.military_tech_outlined,
            size: 48,
            color: Colors.blueAccent,
          ),
          const SizedBox(height: 12),
          Text(
            'INTERNSHIP COMPLETED',
            style: GoogleFonts.orbitron(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your internship term has concluded. Final attendance percentage is archived below.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: CxColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // MONTHLY ATTENDANCE CALENDAR & DAY DETAILS
  // =========================================================================
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: CxColors.textSecondary),
        ),
      ],
    );
  }

  void _showDayAttendanceDetail(String dateStr, Map<String, dynamic>? record) {
    final status = record?['status'] ?? 'NOT MARKED';
    final time = record?['markedAt'] ?? record?['time'] ?? 'N/A';

    Color statusColor = Colors.grey;
    if (status == 'PRESENT') statusColor = Colors.greenAccent;
    if (status == 'LATE') statusColor = Colors.orangeAccent;
    if (status == 'LEAVE') statusColor = Colors.blueAccent;
    if (status == 'ABSENT') statusColor = CxColors.brightRed;

    showModalBottomSheet(
      context: context,
      backgroundColor: CxColors.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ATTENDANCE RECORD',
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
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
            const SizedBox(height: 12),
            Text(
              'Date: $dateStr',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: CxColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Timestamp: $time',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: CxColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            CxButton(label: 'CLOSE', onPressed: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyCalendar(List<dynamic> history) {
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(now).toUpperCase();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstWeekday = DateTime(
      now.year,
      now.month,
      1,
    ).weekday; // 1 = Mon, 7 = Sun

    final historyMap = <String, Map<String, dynamic>>{};
    for (final h in history) {
      if (h is Map) {
        final dStr = (h['date'] ?? '').toString();
        historyMap[dStr] = Map<String, dynamic>.from(h);
      }
    }

    final totalCells = (firstWeekday - 1) + daysInMonth;
    final rowsCount = (totalCells / 7).ceil();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CxColors.cardElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CxColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month,
                    size: 16,
                    color: CxColors.brightRed,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ATTENDANCE CALENDAR',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Text(
                monthName,
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: CxColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
              return SizedBox(
                width: 36,
                child: Center(
                  child: Text(
                    day,
                    style: GoogleFonts.orbitron(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: CxColors.textMuted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          ...List.generate(rowsCount, (rowIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (colIndex) {
                  final cellIndex = rowIndex * 7 + colIndex;
                  final dayNumber = cellIndex - (firstWeekday - 1) + 1;

                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return const SizedBox(width: 36, height: 36);
                  }

                  final cellDate = DateTime(now.year, now.month, dayNumber);
                  final cellDateStr = DateFormat('yyyy-MM-dd').format(cellDate);
                  final record = historyMap[cellDateStr];
                  final status = record?['status']?.toString().toUpperCase();
                  final isToday = dayNumber == now.day;

                  Color dotColor = Colors.transparent;
                  if (status == 'PRESENT') dotColor = Colors.greenAccent;
                  if (status == 'LATE') dotColor = Colors.orangeAccent;
                  if (status == 'LEAVE') dotColor = Colors.blueAccent;
                  if (status == 'ABSENT') dotColor = CxColors.brightRed;

                  return GestureDetector(
                    onTap: () => _showDayAttendanceDetail(cellDateStr, record),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isToday ? CxColors.secondaryDark : CxColors.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isToday
                              ? CxColors.brightRed
                              : CxColors.borderSubtle,
                          width: isToday ? 1.5 : 0.8,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNumber',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isToday
                                  ? Colors.white
                                  : CxColors.textPrimary,
                            ),
                          ),
                          if (dotColor != Colors.transparent)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                              ),
                            )
                          else
                            const SizedBox(height: 5),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            );
          }),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem('Present', Colors.greenAccent),
              _buildLegendItem('Late', Colors.orangeAccent),
              _buildLegendItem('Leave', Colors.blueAccent),
              _buildLegendItem('Absent', CxColors.brightRed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTopicsHeroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CxColors.cardElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CxColors.brightRed.withAlpha(80)),
        gradient: LinearGradient(
          colors: [CxColors.cardElevated, CxColors.brightRed.withAlpha(30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.date_range,
                    color: CxColors.brightRed,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'DAILY TOPICS & SYLLABUS',
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CxColors.brightRed.withAlpha(40),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'INTERACTIVE',
                  style: GoogleFonts.orbitron(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: CxColors.brightRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Explore scheduled classes, main topics, subtopics, documents, and meeting links with the horizontal date selector.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: CxColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          CxButton(
            label: 'BROWSE DAILY TOPICS',
            icon: Icons.calendar_today,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DailyTopicsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CxColors.cardElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CxColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CxColors.brightRed.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.assignment_turned_in_outlined,
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
                  'PROJECT ASSIGNMENTS',
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Submit text & code repo assignments',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: CxColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AssignmentsScreen()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: CxColors.brightRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: Text(
              'VIEW',
              style: GoogleFonts.orbitron(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledClassesSection() {
    final classesAsync = ref.watch(classesEndpointProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.school_outlined,
                  size: 16,
                  color: CxColors.brightRed,
                ),
                const SizedBox(width: 8),
                Text(
                  'SCHEDULED CLASSES',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: CxColors.textPrimary,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(
                Icons.refresh,
                size: 16,
                color: CxColors.textSecondary,
              ),
              onPressed: () => ref.invalidate(classesEndpointProvider),
            ),
          ],
        ),
        const SizedBox(height: 12),
        classesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: CxColors.brightRed),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (classesData) {
            final todayList = (classesData['today'] as List<dynamic>?) ?? [];
            final upcomingList =
                (classesData['upcoming'] as List<dynamic>?) ?? [];

            if (todayList.isEmpty && upcomingList.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CxColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: CxColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_available,
                      color: CxColors.textSecondary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No classes scheduled for today. Check upcoming sessions soon.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: CxColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                ...todayList.map(
                  (c) => _buildClassCard(
                    Map<String, dynamic>.from(c),
                    isToday: true,
                  ),
                ),
                if (upcomingList.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...upcomingList
                      .take(3)
                      .map(
                        (c) => _buildClassCard(
                          Map<String, dynamic>.from(c),
                          isToday: false,
                        ),
                      ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildClassCard(Map<String, dynamic> c, {required bool isToday}) {
    final title = c['title'] ?? 'Class Session';
    final topic = c['topic'] ?? '';
    final instructor = c['instructor_name'] ?? 'CodeXa Instructor';
    final startTime = c['start_time'] ?? '';
    final endTime = c['end_time'] ?? '';
    final status = c['status'] ?? 'UPCOMING';
    final date = c['class_date'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CxColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? CxColors.brightRed.withAlpha(80)
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isToday
                      ? CxColors.brightRed.withAlpha(30)
                      : Colors.blueGrey.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isToday ? 'TODAY\'S CLASS' : 'UPCOMING ($date)',
                  style: GoogleFonts.orbitron(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isToday ? CxColors.brightRed : Colors.blueGrey,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: status == 'LIVE'
                      ? Colors.green.withAlpha(40)
                      : Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: status == 'LIVE'
                        ? Colors.greenAccent
                        : Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.orbitron(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            topic,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 14,
                color: CxColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                instructor,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: CxColors.textMuted,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.access_time,
                size: 14,
                color: CxColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                '$startTime - $endTime',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: CxColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClassDetailsScreen(classData: c),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: CxColors.borderSubtle),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'VIEW TOPICS & JOIN',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: CxColors.brightRed,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
