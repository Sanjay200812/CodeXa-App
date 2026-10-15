import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/models.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';

class PeopleSearchScreen extends ConsumerStatefulWidget {
  const PeopleSearchScreen({super.key});

  @override
  ConsumerState<PeopleSearchScreen> createState() => _PeopleSearchScreenState();
}

class _PeopleSearchScreenState extends ConsumerState<PeopleSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<String> _roleFilters = [
    'ALL',
    'EMPLOYEES',
    'INTERNS',
    'MANAGEMENT',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onFilterChanged(String role) {
    ref
        .read(peopleFilterProvider.notifier)
        .update((s) => s.copyWith(role: role));
  }

  void _onQueryChanged(String query) {
    ref
        .read(peopleFilterProvider.notifier)
        .update((s) => s.copyWith(query: query));
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(peopleFilterProvider);
    final peopleAsync = ref.watch(peopleListProvider);

    return Scaffold(
      backgroundColor: CxColors.background,
      appBar: CxAppBar(
        title: 'TEAM DIRECTORY',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CxColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.fromLTRB(
              CxSpacing.lg,
              CxSpacing.sm,
              CxSpacing.lg,
              CxSpacing.md,
            ),
            decoration: const BoxDecoration(
              color: CxColors.background,
              border: Border(
                bottom: BorderSide(color: CxColors.borderSubtle, width: 1),
              ),
            ),
            child: Column(
              children: [
                // Search Input Field
                Container(
                  decoration: BoxDecoration(
                    color: CxColors.card,
                    borderRadius: BorderRadius.circular(CxSpacing.inputRadius),
                    border: Border.all(color: CxColors.borderDefault),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onQueryChanged,
                    style: GoogleFonts.inter(
                      color: CxColors.textPrimary,
                      fontSize: 14,
                    ),
                    cursorColor: CxColors.brightRed,
                    decoration: InputDecoration(
                      hintText: 'Search by name, ID, domain, skills...',
                      hintStyle: GoogleFonts.inter(
                        color: CxColors.textMuted,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: CxColors.textSecondary,
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: CxColors.textSecondary,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _onQueryChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: CxSpacing.sm),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _roleFilters.map((r) {
                      final isSelected = filter.role == r;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            r,
                            style: GoogleFonts.orbitron(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : CxColors.textSecondary,
                              letterSpacing: 0.8,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: CxColors.crimson,
                          backgroundColor: CxColors.cardElevated,
                          side: BorderSide(
                            color: isSelected
                                ? CxColors.brightRed
                                : CxColors.borderSubtle,
                            width: 1,
                          ),
                          onSelected: (_) => _onFilterChanged(r),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // People List
          Expanded(
            child: RefreshIndicator(
              color: CxColors.brightRed,
              backgroundColor: CxColors.cardElevated,
              onRefresh: () async {
                ref.invalidate(peopleListProvider);
              },
              child: peopleAsync.when(
                loading: () => ListView.separated(
                  padding: const EdgeInsets.all(CxSpacing.lg),
                  itemCount: 6,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: CxSpacing.md),
                  itemBuilder: (_, __) => const CxLoadingSkeleton(
                    width: double.infinity,
                    height: 90,
                    borderRadius: 14,
                  ),
                ),
                error: (e, _) => CxEmptyState(
                  icon: Icons.error_outline,
                  title: 'DIRECTORY ERROR',
                  message: 'Could not load team directory from server.',
                  action: CxButton(
                    label: 'RETRY',
                    width: 140,
                    onPressed: () => ref.invalidate(peopleListProvider),
                  ),
                ),
                data: (people) {
                  if (people.isEmpty) {
                    return const CxEmptyState(
                      icon: Icons.person_search_outlined,
                      title: 'NO PEOPLE FOUND',
                      message: 'No team members matched your search criteria.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(CxSpacing.lg),
                    itemCount: people.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: CxSpacing.md),
                    itemBuilder: (context, index) {
                      final person = people[index];
                      return _PeopleCard(person: person);
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
}

class _PeopleCard extends StatelessWidget {
  final PeopleModel person;

  const _PeopleCard({required this.person});

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
  Widget build(BuildContext context) {
    final roleColor = _getRoleColor(person.role);

    return CxCard(
      onTap: () => context.push('/profile/${person.username}'),
      padding: const EdgeInsets.all(CxSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CxAvatar(
                name: person.fullName,
                imageUrl: person.profileMediaUrl,
                radius: 24,
              ),
              const SizedBox(width: CxSpacing.md),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            person.fullName,
                            style: GoogleFonts.orbitron(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: CxColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: roleColor.withOpacity(0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            person.role,
                            style: GoogleFonts.orbitron(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: roleColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      person.designation ??
                          person.department ??
                          '@${person.username}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: CxColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (person.employeeId != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${person.employeeId}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: CxColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: CxColors.brightRed,
                    ),
                    tooltip: 'Message',
                    onPressed: () => context.go('/messages'),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: CxColors.textMuted,
                  ),
                ],
              ),
            ],
          ),

          // Skills Chips
          if (person.skills.isNotEmpty) ...[
            const SizedBox(height: CxSpacing.sm),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: person.skills.take(4).map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: CxColors.secondaryDark,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: CxColors.borderSubtle,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    s,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: CxColors.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
