import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:codexa_mobile/main.dart';

void main() {
  testWidgets('CodeXa Mobile App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CodeXaMobileApp()));

    // Initial pump renders root widgets
    await tester.pump();
    expect(find.byType(CodeXaMobileApp), findsOneWidget);

    // Allow splash timers to elapse cleanly
    await tester.pump(const Duration(milliseconds: 1500));
  });
}
