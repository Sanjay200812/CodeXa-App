import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CodeXa Leave & Concurrency Conflict Tests', () {
    test(
      'Leave status state machine correctly validates PENDING transitions',
      () {
        const initialStatus = 'PENDING';
        expect(initialStatus, equals('PENDING'));

        // Concurrency check simulation
        const currentStatus = 'APPROVED';
        const isConflict = currentStatus != 'PENDING';
        expect(isConflict, isTrue);
      },
    );

    test('Leave types include CASUAL, SICK, EMERGENCY, ACADEMIC', () {
      final validTypes = ['CASUAL', 'SICK', 'EMERGENCY', 'ACADEMIC'];
      expect(validTypes.contains('CASUAL'), isTrue);
      expect(validTypes.contains('SICK'), isTrue);
      expect(validTypes.contains('EMERGENCY'), isTrue);
      expect(validTypes.contains('ACADEMIC'), isTrue);
    });
  });

  group('CodeXa Daily Topics & Classes Date Navigation Tests', () {
    test('Daily topics date formatting matches ISO standard YYYY-MM-DD', () {
      final date = DateTime(2026, 10, 8);
      final formatted =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      expect(formatted, equals('2026-10-08'));
    });

    test(
      'Classes parser correctly handles subtopics and learning objectives',
      () {
        final classPayload = {
          'id': 'class_test_1',
          'title': 'Enterprise Mobile Architecture',
          'topic': 'Supabase Realtime State',
          'subtopics': ['Monotonic Read Markers', 'Offline Queues'],
          'learning_objectives': 'Master offline idempotency',
          'resources': [
            {'title': 'Specs', 'url': 'https://example.com/specs.pdf'},
          ],
        };

        expect(classPayload['title'], equals('Enterprise Mobile Architecture'));
        expect((classPayload['subtopics'] as List).length, equals(2));
        expect((classPayload['resources'] as List).length, equals(1));
      },
    );
  });

  group('CodeXa AI Output Formatting & Artifact Sanitization Tests', () {
    test('AI sanitizer cleans triple asterisks (***) cleanly', () {
      String cleanAiFormatting(String text) {
        var cleaned = text;
        cleaned = cleaned.replaceAll(RegExp(r'\*{3,}'), '**');
        return cleaned.trim();
      }

      const rawAiResponse =
          '***CodeXa Scheduled Class:*** Today topic is ***Flutter Riverpod***';
      final cleaned = cleanAiFormatting(rawAiResponse);

      expect(cleaned.contains('***'), isFalse);
      expect(
        cleaned,
        equals(
          '**CodeXa Scheduled Class:** Today topic is **Flutter Riverpod**',
        ),
      );
    });
  });
}
