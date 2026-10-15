import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';
import '../assignments/assignments_screen.dart';

// Provider for classes on a selected date
final classesForDateProvider = FutureProvider.family
    .autoDispose<List<Map<String, dynamic>>, String>((ref, dateStr) async {
      final api = CxApiClient();
      try {
        final res = await api.dio.get(
          '/api/mobile/classes/by-date',
          queryParameters: {'date': dateStr},
        );
        if (res.data != null && res.data['ok'] == true) {
          final list = res.data['classes'] as List<dynamic>?;
          return list?.map((c) => Map<String, dynamic>.from(c)).toList() ?? [];
        }
      } catch (_) {}
      return [];
    });

class DailyTopicsScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;

  const DailyTopicsScreen({super.key, this.initialDate});

  @override
  ConsumerState<DailyTopicsScreen> createState() => _DailyTopicsScreenState();
}

class _DailyTopicsScreenState extends ConsumerState<DailyTopicsScreen> {
  late DateTime _selectedDate;
  late DateTime _currentWeekStart;
  final ScrollController _dateStripController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    // Normalize to beginning of week (Monday)
    final weekday = _selectedDate.weekday; // 1 = Mon, 7 = Sun
    _currentWeekStart = _selectedDate.subtract(Duration(days: weekday - 1));
  }

  @override
  void dispose() {
    _dateStripController.dispose();
    super.dispose();
  }

  void _previousWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
      _selectedDate = _currentWeekStart;
    });
  }

  void _nextWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
      _selectedDate = _currentWeekStart;
    });
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = now;
      _currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
    });
  }

  String _formatDateYMD(DateTime d) {
    return DateFormat('yyyy-MM-dd').format(d);
  }

  Future<void> _launchResource(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // --- FOUNDER / CO-FOUNDER CREATE CLASS MODAL ---
  void _openCreateClassSheet() {
    final titleCtrl = TextEditingController();
    final topicCtrl = TextEditingController();
    final subtopicsCtrl = TextEditingController();
    final startTimeCtrl = TextEditingController(text: '11:00 AM');
    final endTimeCtrl = TextEditingController(text: '12:30 PM');
    final meetingLinkCtrl = TextEditingController();
    final objectivesCtrl = TextEditingController();
    String domain = 'All Domains';

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SCHEDULE CLASS / TOPIC',
                      style: GoogleFonts.orbitron(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: CxColors.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text(
                  'Date: ${DateFormat('EEE, MMM dd, yyyy').format(_selectedDate)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: CxColors.brightRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                CxTextField(
                  label: 'CLASS TITLE',
                  hint: 'e.g., Enterprise Architecture & API Design',
                  controller: titleCtrl,
                ),
                const SizedBox(height: 12),
                CxTextField(
                  label: 'MAIN TOPIC',
                  hint: 'e.g., Supabase Realtime & PostgreSQL Pooling',
                  controller: topicCtrl,
                ),
                const SizedBox(height: 12),
                CxTextField(
                  label: 'SUBTOPICS (COMMA-SEPARATED)',
                  hint: 'e.g., State Replay, Monotonic IDs, Offline Queues',
                  controller: subtopicsCtrl,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CxTextField(
                        label: 'START TIME',
                        hint: '11:00 AM',
                        controller: startTimeCtrl,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CxTextField(
                        label: 'END TIME',
                        hint: '12:30 PM',
                        controller: endTimeCtrl,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CxTextField(
                  label: 'MEETING LINK (OPTIONAL)',
                  hint: 'https://meet.google.com/xyz',
                  controller: meetingLinkCtrl,
                ),
                const SizedBox(height: 12),
                CxTextField(
                  label: 'LEARNING OBJECTIVES',
                  hint: 'What interns will learn...',
                  controller: objectivesCtrl,
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                CxButton(
                  label: 'PUBLISH TO ALL APKS',
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    final topic = topicCtrl.text.trim();
                    if (title.isEmpty || topic.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Title and Main Topic are required.'),
                        ),
                      );
                      return;
                    }

                    final subtopics = subtopicsCtrl.text
                        .split(',')
                        .map((s) => s.trim())
                        .filter((s) => s.isNotEmpty)
                        .toList();

                    Navigator.pop(ctx);
                    final api = CxApiClient();
                    try {
                      final dateStr = _formatDateYMD(_selectedDate);
                      final res = await api.dio.post(
                        '/api/mobile/classes',
                        data: {
                          'title': title,
                          'topic': topic,
                          'subtopics': subtopics,
                          'classDate': dateStr,
                          'startTime': startTimeCtrl.text.trim(),
                          'endTime': endTimeCtrl.text.trim(),
                          'domain': domain,
                          'meetingLink': meetingLinkCtrl.text.trim(),
                          'learningObjectives': objectivesCtrl.text.trim(),
                        },
                      );

                      if (res.data != null && res.data['ok'] == true) {
                        ref.invalidate(classesForDateProvider(dateStr));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Class published and synchronized across all APKs!',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to publish class: $e'),
                            backgroundColor: CxColors.brightRed,
                          ),
                        );
                      }
                    }
                  },
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
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final role = user?.role.toUpperCase();
    final isLeadership = [
      'FOUNDER',
      'CO_FOUNDER',
      'CEO',
      'CTO',
      'HR',
      'OWNER',
      'ADMIN',
    ].contains(role);

    final selectedDateStr = _formatDateYMD(_selectedDate);
    final classesAsync = ref.watch(classesForDateProvider(selectedDateStr));

    // Generate dates for current strip (14 days: 2 weeks)
    final stripDays = List.generate(
      14,
      (i) => _currentWeekStart.add(Duration(days: i)),
    );

    return Scaffold(
      backgroundColor: CxColors.background,
      appBar: CxAppBar(
        title: 'DAILY TOPICS',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CxColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.today, color: CxColors.textPrimary),
            tooltip: 'Jump to Today',
            onPressed: _jumpToToday,
          ),
          if (isLeadership)
            IconButton(
              icon: const Icon(Icons.add, color: CxColors.brightRed),
              tooltip: 'Schedule Class',
              onPressed: _openCreateClassSheet,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── TOP DATE / DAY SELECTOR STRIP ──
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              color: CxColors.cardElevated,
              border: Border(bottom: BorderSide(color: CxColors.borderSubtle)),
            ),
            child: Column(
              children: [
                // Month & Year header with week navigation
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            size: 16,
                            color: CxColors.brightRed,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMMM yyyy')
                                .format(_selectedDate)
                                .toUpperCase(),
                            style: GoogleFonts.orbitron(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _previousWeek,
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _nextWeek,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Horizontal Day Strip
                SizedBox(
                  height: 64,
                  child: ListView.builder(
                    controller: _dateStripController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: stripDays.length,
                    itemBuilder: (context, index) {
                      final dayDate = stripDays[index];
                      final isSelected =
                          _formatDateYMD(dayDate) == selectedDateStr;
                      final isToday =
                          _formatDateYMD(dayDate) ==
                          _formatDateYMD(DateTime.now());

                      final weekdayStr = DateFormat('EEE')
                          .format(dayDate)
                          .toUpperCase();
                      final dayNumStr = DateFormat('dd').format(dayDate);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDate = dayDate;
                          });
                        },
                        child: Container(
                          width: 58,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? CxColors.brightRed
                                : (isToday
                                      ? CxColors.secondaryDark
                                      : CxColors.card),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? CxColors.brightRed
                                  : (isToday
                                        ? CxColors.accent.withAlpha(120)
                                        : CxColors.borderSubtle),
                              width: isSelected || isToday ? 1.5 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: CxColors.brightRed.withAlpha(80),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                weekdayStr,
                                style: GoogleFonts.orbitron(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : (isToday
                                            ? CxColors.accent
                                            : CxColors.textSecondary),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dayNumStr,
                                style: GoogleFonts.orbitron(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── SELECTED DATE BANNER ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: CxColors.card,
            child: Row(
              children: [
                const Icon(Icons.event, size: 16, color: CxColors.textMuted),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, MMMM dd, yyyy')
                      .format(_selectedDate)
                      .toUpperCase(),
                  style: GoogleFonts.orbitron(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: CxColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (_formatDateYMD(_selectedDate) ==
                    _formatDateYMD(DateTime.now()))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(40),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'TODAY',
                      style: GoogleFonts.orbitron(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── TOPIC DETAILS / CLASSES FOR SELECTED DATE ──
          Expanded(
            child: RefreshIndicator(
              color: CxColors.brightRed,
              onRefresh: () async =>
                  ref.invalidate(classesForDateProvider(selectedDateStr)),
              child: classesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: CxColors.brightRed),
                ),
                error: (_, __) => const CxEmptyState(
                  icon: Icons.error_outline,
                  title: 'TOPICS NOT FOUND',
                  message: 'Unable to load syllabus for this date.',
                ),
                data: (classes) {
                  if (classes.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 48),
                        CxEmptyState(
                          icon: Icons.event_available,
                          title: 'NO TOPICS SCHEDULED',
                          message:
                              'No classes or curriculum topics recorded for ${DateFormat('MMMM dd').format(_selectedDate)}.',
                          action: isLeadership
                              ? CxButton(
                                  label: 'SCHEDULE TOPIC',
                                  width: 180,
                                  onPressed: _openCreateClassSheet,
                                )
                              : null,
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: classes.length,
                    itemBuilder: (context, index) {
                      final c = classes[index];
                      return _buildDetailedClassTopicCard(c);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedClassTopicCard(Map<String, dynamic> c) {
    final title = c['title'] ?? 'Class Session';
    final topic = c['topic'] ?? '';
    final instructor = c['instructor_name'] ?? 'Instructor';
    final startTime = c['start_time'] ?? '';
    final endTime = c['end_time'] ?? '';
    final status = c['status'] ?? 'UPCOMING';
    final meetingLink = c['meeting_link'];
    final objectives = c['learning_objectives'];

    List<dynamic> subtopics = [];
    if (c['subtopics'] is List) {
      subtopics = c['subtopics'];
    }

    List<dynamic> resources = [];
    if (c['resources'] is List) {
      resources = c['resources'];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CxColors.cardElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CxColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: status == 'LIVE'
                      ? Colors.green.withAlpha(40)
                      : CxColors.brightRed.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.orbitron(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: status == 'LIVE'
                        ? Colors.greenAccent
                        : CxColors.brightRed,
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 14,
                    color: CxColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$startTime - $endTime',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: CxColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            title,
            style: GoogleFonts.orbitron(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),

          // Instructor
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 14,
                color: CxColors.brightRed,
              ),
              const SizedBox(width: 6),
              Text(
                'Instructor: $instructor',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: CxColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Topic Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CxColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CxColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      size: 16,
                      color: CxColors.brightRed,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CORE TOPIC',
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  topic,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: CxColors.textPrimary,
                  ),
                ),
                if (subtopics.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Subtopics Covered:',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: CxColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...subtopics.map(
                    (sub) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(color: CxColors.brightRed),
                          ),
                          Expanded(
                            child: Text(
                              sub.toString(),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Objectives
          if (objectives != null && objectives.toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CxColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.track_changes,
                        size: 14,
                        color: Colors.amberAccent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'OBJECTIVES',
                        style: GoogleFonts.orbitron(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.amberAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    objectives.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Resources
          if (resources.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'RESOURCES & ATTACHMENTS',
              style: GoogleFonts.orbitron(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: CxColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            ...resources.map((res) {
              final rTitle = res['title'] ?? 'Document';
              final rUrl = res['url'] ?? '';
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.file_present_outlined,
                  color: Colors.blueAccent,
                  size: 20,
                ),
                title: Text(
                  rTitle,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                ),
                trailing: const Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: CxColors.textMuted,
                ),
                onTap: () => _launchResource(rUrl),
              );
            }),
          ],

          const SizedBox(height: 16),

          // Actions: Join Meeting + Assignments
          Row(
            children: [
              if (meetingLink != null && meetingLink.toString().isNotEmpty)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _launchResource(meetingLink),
                    icon: const Icon(
                      Icons.video_call,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      'JOIN CLASS',
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CxColors.brightRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              if (meetingLink != null && meetingLink.toString().isNotEmpty)
                const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AssignmentsScreen(),
                    ),
                  ),
                  icon: const Icon(
                    Icons.assignment_outlined,
                    size: 16,
                    color: CxColors.textPrimary,
                  ),
                  label: Text(
                    'ASSIGNMENTS',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: CxColors.borderSubtle),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension IterableExtension<T> on Iterable<T> {
  Iterable<T> filter(bool Function(T element) test) => where(test);
}
