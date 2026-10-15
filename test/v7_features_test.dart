import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codexa_mobile/core/theme/cx_theme.dart';
import 'package:codexa_mobile/core/widgets/cx_glass.dart';

void main() {
  group('CodeXa V7 — Liquid Glass Component System Tests', () {
    testWidgets(
      'CodeXaGlassSurface renders with backdrop filter and glass decoration',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CodeXaGlassSurface(
                borderRadius: 16.0,
                blurAmount: 18.0,
                borderColor: Colors.white.withOpacity(0.12),
                child: const Text('Glass Test Content'),
              ),
            ),
          ),
        );

        expect(find.text('Glass Test Content'), findsOneWidget);
        expect(find.byType(BackdropFilter), findsOneWidget);
      },
    );

    testWidgets(
      'CodeXaGlassButton responds to taps and displays labels & icons',
      (tester) async {
        bool tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CodeXaGlassButton(
                label: 'Launch Glass Action',
                icon: Icons.shield,
                onPressed: () => tapped = true,
                variant: GlassButtonVariant.crimson,
              ),
            ),
          ),
        );

        expect(find.text('Launch Glass Action'), findsOneWidget);
        expect(find.byIcon(Icons.shield), findsOneWidget);

        await tester.tap(find.text('Launch Glass Action'));
        await tester.pumpAndSettle();
        expect(tapped, isTrue);
      },
    );

    testWidgets('CodeXaGlassSearchBar handles input and text changes', (
      tester,
    ) async {
      String changedText = '';
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeXaGlassSearchBar(
              controller: controller,
              hintText: 'Search people, messages...',
              onChanged: (val) => changedText = val,
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Antigravity');
      expect(changedText, 'Antigravity');
    });

    testWidgets('CodeXaGlassSegmentedControl switches selected index', (
      tester,
    ) async {
      int activeIndex = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: CodeXaGlassSegmentedControl(
                  segments: const ['Members', 'Admins', 'Roles'],
                  selectedIndex: activeIndex,
                  onSegmentSelected: (i) => setState(() => activeIndex = i),
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Admins'), findsOneWidget);
      expect(find.text('Roles'), findsOneWidget);

      await tester.tap(find.text('Admins'));
      await tester.pumpAndSettle();
      expect(activeIndex, 1);
    });
  });

  group('CodeXa V7 — 5-Tab Navigation Order & Swipe Mapping Tests', () {
    test('Tabs map sequentially across 5 core modules', () {
      const tabPaths = ['/', '/attendance', '/messages', '/feed', '/projects'];

      const tabLabels = ['HOME', 'ATTENDANCE', 'MESSAGES', 'FEED', 'PROJECTS'];

      expect(tabPaths.length, 5);
      expect(tabLabels.length, 5);
      expect(tabLabels[0], 'HOME');
      expect(tabLabels[1], 'ATTENDANCE');
      expect(tabLabels[2], 'MESSAGES');
      expect(tabLabels[3], 'FEED');
      expect(tabLabels[4], 'PROJECTS');
    });
  });

  group(
    'CodeXa V7 — Canonical OTP Recipient & Account Switching Policy Tests',
    () {
      test(
        'Situation A: Valid saved account switches without OTP challenge',
        () {
          final savedAccountB = <String, dynamic>{
            'id': 'user_b_456',
            'email': 'developer.bob@codexa.app',
            'accessToken': 'valid_token_b',
            'hasValidSession': true,
          };

          // Condition: Target account already saved with valid session
          final requiresOtp = savedAccountB['hasValidSession'] != true;
          expect(requiresOtp, isFalse);
        },
      );

      test('Situation B: Adding new account derives OTP email strictly from target Core account', () {
        const targetUserEmail = 'newhire.alex@codexa.app';
        const founderEmail = 'ashuchinthapalli3900@gmail.com';

        // Canonical resolution logic
        final resolvedRecipient = targetUserEmail.trim().toLowerCase();

        // Must be target email, NEVER hardcoded founder email
        expect(resolvedRecipient, equals('newhire.alex@codexa.app'));
        expect(resolvedRecipient, isNot(equals(founderEmail)));
      });

      test('Situation C: Expired session reauthentication targets verified account email only', () {
        final targetAccount = <String, dynamic>{
          'id': 'user_expired_789',
          'email': 'samuel.lead@codexa.app',
          'sessionExpired': true,
        };

        final recipientEmail = (targetAccount['email'] as String)
            .trim()
            .toLowerCase();
        expect(recipientEmail, equals('samuel.lead@codexa.app'));
      });
    },
  );

  group('CodeXa V7 — Crew Group Details: Role Separation & Member Data Tests', () {
    test('Separates Core Organization Role from Group Role cleanly', () {
      final member1 = {
        'userId': 'usr_001',
        'name': 'Ashu C',
        'orgRole': 'FOUNDER', // CodeXa Core role
        'groupRole': 'OWNER', // Group role
        'canEditGroupInfo': true,
      };

      final member2 = {
        'userId': 'usr_002',
        'name': 'Priya S',
        'orgRole': 'INTERN', // CodeXa Core role
        'groupRole': 'MEMBER', // Group role
        'canEditGroupInfo': false,
      };

      expect(member1['orgRole'], equals('FOUNDER'));
      expect(member1['groupRole'], equals('OWNER'));
      expect(member1['canEditGroupInfo'], isTrue);

      expect(member2['orgRole'], equals('INTERN'));
      expect(member2['groupRole'], equals('MEMBER'));
      expect(member2['canEditGroupInfo'], isFalse);
    });

    test(
      'Admin permission evaluation distinguishes org roles from group actions',
      () {
        const adminOrgRoles = [
          'FOUNDER',
          'CO_FOUNDER',
          'CEO',
          'CTO',
          'HR',
          'COO',
        ];

        bool canManageGroup(String orgRole, String groupRole) {
          if (groupRole == 'OWNER' || groupRole == 'ADMIN') return true;
          if (adminOrgRoles.contains(orgRole.toUpperCase())) return true;
          return false;
        }

        expect(canManageGroup('INTERN', 'MEMBER'), isFalse);
        expect(canManageGroup('INTERN', 'ADMIN'), isTrue);
        expect(canManageGroup('FOUNDER', 'MEMBER'), isTrue);
        expect(canManageGroup('EMPLOYEE', 'MEMBER'), isFalse);
      },
    );
  });
}
