import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';

final documentsListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final api = CxApiClient();
      try {
        final res = await api.dio.get('/api/mobile/documents');
        if (res.data != null && res.data['ok'] == true) {
          return (res.data['documents'] as List<dynamic>?)
                  ?.map((d) => Map<String, dynamic>.from(d))
                  .toList() ??
              [];
        }
      } catch (_) {}
      return [];
    });

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsListProvider);

    return Scaffold(
      backgroundColor: CxColors.background,
      appBar: CxAppBar(
        title: 'DOCUMENTS',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CxColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        color: CxColors.brightRed,
        backgroundColor: CxColors.cardElevated,
        onRefresh: () async => ref.invalidate(documentsListProvider),
        child: docsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: CxColors.brightRed),
          ),
          error: (_, __) => const CxEmptyState(
            icon: Icons.folder_open,
            title: 'DOCUMENTS',
            message: 'Unable to load company documents.',
          ),
          data: (docs) {
            if (docs.isEmpty) {
              return const CxEmptyState(
                icon: Icons.description_outlined,
                title: 'NO DOCUMENTS AVAILABLE',
                message: 'You have no assigned offer letters, certificates, or agreements yet.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(CxSpacing.lg),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: CxSpacing.sm),
              itemBuilder: (context, index) {
                final d = docs[index];
                final title = d['title'] ?? 'Document';
                final type = (d['documentType'] ?? 'AGREEMENT')
                    .toString()
                    .replaceAll('_', ' ');

                return CxCard(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: CxColors.secondaryDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: CxColors.borderSubtle),
                        ),
                        child: const Icon(
                          Icons.file_present,
                          color: CxColors.brightRed,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: CxSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: CxColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              type,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: CxColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CxButton(
                        label: 'VIEW',
                        width: 70,
                        height: 36,
                        isSecondary: true,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Opening secure document: $title'),
                              backgroundColor: CxColors.cardElevated,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
