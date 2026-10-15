import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';

class CoworkerProfileScreen extends ConsumerWidget {
  final String username;

  const CoworkerProfileScreen({super.key, required this.username});

  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'FOUNDER':
      case 'CO_FOUNDER':
        return CxColors.brightRed;
      case 'CEO':
      case 'CTO':
      case 'COO':
        return const Color(0xFF9D4EDD);
      case 'HR':
        return const Color(0xFF00B4D8);
      case 'EMPLOYEE':
        return CxColors.success;
      case 'INTERN':
      default:
        return const Color(0xFFF77F00);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(coworkerProfileProvider(username));

    return Scaffold(
      backgroundColor: CxColors.background,
      appBar: CxAppBar(
        title: '@${username.toUpperCase()}',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CxColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        color: CxColors.brightRed,
        backgroundColor: CxColors.cardElevated,
        onRefresh: () async {
          ref.invalidate(coworkerProfileProvider(username));
        },
        child: profileAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(CxSpacing.lg),
            children: const [
              Center(
                child: CxLoadingSkeleton(
                  width: 80,
                  height: 80,
                  borderRadius: 40,
                ),
              ),
              SizedBox(height: CxSpacing.md),
              Center(child: CxLoadingSkeleton(width: 160, height: 20)),
              SizedBox(height: CxSpacing.sm),
              Center(child: CxLoadingSkeleton(width: 100, height: 16)),
              SizedBox(height: CxSpacing.xl),
              CxLoadingSkeleton(
                width: double.infinity,
                height: 120,
                borderRadius: 16,
              ),
            ],
          ),
          error: (e, _) => CxEmptyState(
            icon: Icons.person_off_outlined,
            title: 'PROFILE UNAVAILABLE',
            message: 'Could not load profile for @$username.',
            action: CxButton(
              label: 'RETRY',
              width: 140,
              onPressed: () =>
                  ref.invalidate(coworkerProfileProvider(username)),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return const CxEmptyState(
                icon: Icons.person_off_outlined,
                title: 'USER NOT FOUND',
                message:
                    'This user account does not exist or has been deactivated.',
              );
            }

            final fullName = profile['fullName'] ?? username;
            final role = (profile['role'] ?? 'EMPLOYEE')
                .toString()
                .toUpperCase();
            final designation =
                profile['designation'] ??
                profile['department'] ??
                'Team Member';
            final department = profile['department'];
            final employeeId = profile['employeeId'];
            final bio = profile['bio'];
            final skills =
                (profile['skills'] as List<dynamic>?)
                    ?.map((s) => s.toString())
                    .toList() ??
                [];
            final projects = (profile['projects'] as List<dynamic>?) ?? [];
            final avatarUrl = profile['profileMediaUrl'];
            final roleColor = _getRoleColor(role);

            return ListView(
              padding: const EdgeInsets.all(CxSpacing.lg),
              children: [
                // Profile Header Card
                CxCard(
                  child: Column(
                    children: [
                      CxAvatar(name: fullName, imageUrl: avatarUrl, radius: 42),
                      const SizedBox(height: CxSpacing.md),
                      Text(
                        fullName,
                        style: GoogleFonts.orbitron(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: CxColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@$username',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: CxColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: CxSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: roleColor.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          role,
                          style: GoogleFonts.orbitron(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: roleColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: CxSpacing.md),
                      Text(
                        designation,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: CxColors.textSecondary,
                        ),
                      ),
                      if (department != null && department != designation) ...[
                        const SizedBox(height: 2),
                        Text(
                          department,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: CxColors.textMuted,
                          ),
                        ),
                      ],
                      if (employeeId != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'ID: $employeeId',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: CxColors.textMuted,
                          ),
                        ),
                      ],
                      const SizedBox(height: CxSpacing.lg),

                      // Direct Message Button
                      CxButton(
                        label: 'SEND MESSAGE',
                        icon: Icons.chat_bubble_outline,
                        onPressed: () => context.go('/messages'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CxSpacing.lg),

                // Internship Details Card (for Interns)
                if (role == 'INTERN') ...[
                  CxCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                              'INTERNSHIP DETAILS',
                              style: GoogleFonts.orbitron(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: CxColors.textPrimary,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: CxSpacing.md),
                        _buildRow('Intern ID', employeeId ?? 'CXA-INT-2026'),
                        const Divider(color: CxColors.borderSubtle, height: 16),
                        _buildRow(
                          'Domain',
                          (profile['internshipDomain'] ??
                                  department ??
                                  'Software Engineering')
                              .toString(),
                        ),
                        const Divider(color: CxColors.borderSubtle, height: 16),
                        _buildRow(
                          'Duration',
                          (profile['internshipDuration'] ?? '3 Months')
                              .toString(),
                        ),
                        if (profile['startDate'] != null) ...[
                          const Divider(
                            color: CxColors.borderSubtle,
                            height: 16,
                          ),
                          _buildRow(
                            'Start Date',
                            profile['startDate'].toString().split('T').first,
                          ),
                        ],
                        if (profile['endDate'] != null) ...[
                          const Divider(
                            color: CxColors.borderSubtle,
                            height: 16,
                          ),
                          _buildRow(
                            'End Date',
                            profile['endDate'].toString().split('T').first,
                          ),
                        ],
                        const Divider(color: CxColors.borderSubtle, height: 16),
                        _buildRow(
                          'Mentor / Lead',
                          (profile['mentorName'] ?? 'Shaik Ashu (Founder)')
                              .toString(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CxSpacing.lg),
                ],

                // Internship Details Card (for Interns)
                if (role == 'INTERN') ...[
                  CxCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                              'INTERNSHIP DETAILS',
                              style: GoogleFonts.orbitron(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: CxColors.textPrimary,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: CxSpacing.md),
                        _buildRow('Intern ID', employeeId ?? 'CXA-INT-2026'),
                        const Divider(color: CxColors.borderSubtle, height: 16),
                        _buildRow(
                          'Domain',
                          (profile['internshipDomain'] ??
                                  department ??
                                  'Software Engineering')
                              .toString(),
                        ),
                        const Divider(color: CxColors.borderSubtle, height: 16),
                        _buildRow(
                          'Duration',
                          (profile['internshipDuration'] ?? '3 Months')
                              .toString(),
                        ),
                        if (profile['startDate'] != null) ...[
                          const Divider(
                            color: CxColors.borderSubtle,
                            height: 16,
                          ),
                          _buildRow(
                            'Start Date',
                            profile['startDate'].toString().split('T').first,
                          ),
                        ],
                        if (profile['endDate'] != null) ...[
                          const Divider(
                            color: CxColors.borderSubtle,
                            height: 16,
                          ),
                          _buildRow(
                            'End Date',
                            profile['endDate'].toString().split('T').first,
                          ),
                        ],
                        const Divider(color: CxColors.borderSubtle, height: 16),
                        _buildRow(
                          'Mentor / Lead',
                          (profile['mentorName'] ?? 'Shaik Ashu (Founder)')
                              .toString(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CxSpacing.lg),
                ],

                // Bio / About
                if (bio != null && bio.toString().trim().isNotEmpty) ...[
                  CxCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ABOUT',
                          style: GoogleFonts.orbitron(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: CxColors.textPrimary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: CxSpacing.sm),
                        Text(
                          bio,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: CxColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CxSpacing.lg),
                ],

                // Skills
                if (skills.isNotEmpty) ...[
                  CxCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SKILLS & EXPERTISE',
                          style: GoogleFonts.orbitron(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: CxColors.textPrimary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: CxSpacing.md),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: skills.map((s) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: CxColors.secondaryDark,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: CxColors.borderSubtle,
                                ),
                              ),
                              child: Text(
                                s,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: CxColors.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CxSpacing.lg),
                ],

                // Assigned Projects
                if (projects.isNotEmpty) ...[
                  CxCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PROJECTS',
                          style: GoogleFonts.orbitron(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: CxColors.textPrimary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: CxSpacing.md),
                        ...projects.map((p) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.folder_outlined,
                                  size: 16,
                                  color: CxColors.brightRed,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    p['title'] ?? '',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: CxColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (p['status'] != null)
                                  CxStatusChip(
                                    label: p['status'],
                                    isSmall: true,
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: CxColors.textSecondary),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: CxColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
