import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';

class ClassDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> classData;

  const ClassDetailsScreen({super.key, required this.classData});

  @override
  State<ClassDetailsScreen> createState() => _ClassDetailsScreenState();
}

class _ClassDetailsScreenState extends State<ClassDetailsScreen> {
  final _questionController = TextEditingController();

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _joinMeeting(String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No meeting link configured for this class.'),
        ),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.classData['title'] ?? 'Class Session';
    final topic = widget.classData['topic'] ?? '';
    final instructor = widget.classData['instructor_name'] ?? 'Instructor';
    final startTime = widget.classData['start_time'] ?? '';
    final endTime = widget.classData['end_time'] ?? '';
    final status = widget.classData['status'] ?? 'UPCOMING';
    final objectives = widget.classData['learning_objectives'] ?? '';
    final meetingLink = widget.classData['meeting_link'];

    List<dynamic> subtopics = [];
    if (widget.classData['subtopics'] is List) {
      subtopics = widget.classData['subtopics'];
    }

    List<dynamic> resources = [];
    if (widget.classData['resources'] is List) {
      resources = widget.classData['resources'];
    }

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
          'SCHEDULED CLASS',
          style: GoogleFonts.orbitron(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(CxSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: status == 'LIVE'
                    ? Colors.green.withAlpha(50)
                    : CxColors.brightRed.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: status == 'LIVE' ? Colors.green : CxColors.brightRed,
                ),
              ),
              child: Text(
                status.toUpperCase(),
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: status == 'LIVE'
                      ? Colors.greenAccent
                      : CxColors.brightRed,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Class Title
            Text(
              title,
              style: GoogleFonts.orbitron(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            // Instructor & Time
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 16,
                  color: CxColors.brightRed,
                ),
                const SizedBox(width: 6),
                Text(
                  instructor,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: CxColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: CxColors.brightRed,
                ),
                const SizedBox(width: 6),
                Text(
                  '$startTime - $endTime',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: CxColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Join Meeting Button
            if (meetingLink != null && meetingLink.toString().isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton.icon(
                  onPressed: () => _joinMeeting(meetingLink),
                  icon: const Icon(
                    Icons.video_call_rounded,
                    color: Colors.white,
                  ),
                  label: Text(
                    'JOIN CLASS MEETING',
                    style: GoogleFonts.orbitron(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CxColors.brightRed,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            // Topic Card
            CxCard(
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
                        'TODAY\'S TOPIC',
                        style: GoogleFonts.orbitron(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    topic,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CxColors.textPrimary,
                    ),
                  ),
                  if (subtopics.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Subtopics covered:',
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
            const SizedBox(height: 16),

            // Learning Objectives
            if (objectives.isNotEmpty) ...[
              CxCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.track_changes,
                          size: 16,
                          color: Colors.amberAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'LEARNING OBJECTIVES',
                          style: GoogleFonts.orbitron(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      objectives,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Resources
            if (resources.isNotEmpty) ...[
              CxCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.attachment,
                          size: 16,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'CLASS RESOURCES',
                          style: GoogleFonts.orbitron(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...resources.map((res) {
                      final resTitle = res['title'] ?? 'Material';
                      final resUrl = res['url'] ?? '';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.description_outlined,
                          color: Colors.white70,
                          size: 20,
                        ),
                        title: Text(
                          resTitle,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.open_in_new,
                          size: 14,
                          color: CxColors.textMuted,
                        ),
                        onTap: () => _joinMeeting(resUrl),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
