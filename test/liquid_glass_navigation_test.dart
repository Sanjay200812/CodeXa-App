import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codexa_mobile/core/navigation/cx_liquid_glass_bar.dart';
import 'package:codexa_mobile/core/navigation/cx_navigation_controller.dart';

void main() {
  group('CodeXa Liquid Glass Navigation Controller & Physics Tests', () {
    test('1. Initial State has Home tab active and idle state', () {
      final controller = CodeXaNavigationController(initialIndex: 0);

      expect(controller.currentIndex, 0);
      expect(controller.fractionalIndex, 0.0);
      expect(controller.state, CodeXaNavigationState.idle);
      expect(controller.isDraggingNavBar, false);
      expect(controller.isDraggingPage, false);

      controller.dispose();
    });

    test('2. Direct Tab Tap commits target index', () {
      int committedIndex = -1;
      final controller = CodeXaNavigationController(
        initialIndex: 0,
        onTabCommitted: (idx) => committedIndex = idx,
      );

      controller.animateToTab(3);

      expect(controller.currentIndex, 3);
      expect(committedIndex, 3);

      controller.dispose();
    });

    test(
      '3. Full-Screen Page Swipe synchronizes fractional index continuously',
      () {
        final controller = CodeXaNavigationController(initialIndex: 0);

        // Simulate user swiping page 40% towards Attendance
        controller.onPageScrolled(0.4);
        expect(controller.fractionalIndex, 0.4);

        // Simulate swiping between Attendance and Messages
        controller.onPageScrolled(1.75);
        expect(controller.fractionalIndex, 1.75);

        // Clamping bounds
        controller.onPageScrolled(4.8);
        expect(controller.fractionalIndex, 4.0);

        controller.onPageScrolled(-0.5);
        expect(controller.fractionalIndex, 0.0);

        controller.dispose();
      },
    );

    test('4. Full-Screen Page Settling updates current index and state', () {
      int committedIndex = -1;
      final controller = CodeXaNavigationController(
        initialIndex: 0,
        onTabCommitted: (idx) => committedIndex = idx,
      );

      controller.onPageScrolled(2.0);
      controller.onPageScrollEnded(2);

      expect(controller.currentIndex, 2);
      expect(controller.fractionalIndex, 2.0);
      expect(controller.state, CodeXaNavigationState.idle);
      expect(committedIndex, 2);

      controller.dispose();
    });

    testWidgets(
      '5. Insufficient Drag Cancellation ignores accidental movement under touch slop',
      (tester) async {
        int committedIndex = -1;
        final controller = CodeXaNavigationController(
          initialIndex: 1,
          onTabCommitted: (idx) => committedIndex = idx,
        );

        const barWidth = 400.0;
        // Tab 1 center is at (1.5 / 5) * 400 = 120.0
        const startX = 120.0;

        controller.onNavBarPointerDown(
          const PointerDownEvent(position: Offset(startX, 30)),
          barWidth,
        );

        // Move only 3 pixels (less than 8px touch slop)
        controller.onNavBarPointerMove(
          const PointerMoveEvent(position: Offset(startX + 3, 30)),
          barWidth,
        );

        expect(controller.isDraggingNavBar, false);

        // Release finger
        controller.onNavBarPointerUp(
          const PointerUpEvent(position: Offset(startX + 3, 30)),
          barWidth,
        );

        // Settles back to tab 1 without changing
        expect(controller.currentIndex, 1);
        expect(committedIndex, 1);

        controller.dispose();
      },
    );

    testWidgets('6. Scrubbing past touch slop enters draggingNavBar state', (
      tester,
    ) async {
      final controller = CodeXaNavigationController(initialIndex: 0);
      const barWidth = 500.0; // 100px per tab

      controller.onNavBarPointerDown(
        const PointerDownEvent(position: Offset(50, 30)),
        barWidth,
      );

      // Move 40 pixels (well above 8px touch slop) towards tab 1
      controller.onNavBarPointerMove(
        const PointerMoveEvent(position: Offset(150, 30)),
        barWidth,
      );

      expect(controller.isDraggingNavBar, true);
      // At x = 150, tabWidth = 100 -> fractional = (150 / 100) - 0.5 = 1.0 (center of Tab 1)
      expect(controller.fractionalIndex, closeTo(1.0, 0.05));

      controller.dispose();
    });

    testWidgets(
      '7. Release settling physics settles to nearest tab when low velocity',
      (tester) async {
        int committedIndex = -1;
        final controller = CodeXaNavigationController(
          initialIndex: 0,
          onTabCommitted: (idx) => committedIndex = idx,
        );
        const barWidth = 500.0;

        controller.onNavBarPointerDown(
          const PointerDownEvent(position: Offset(50, 30)),
          barWidth,
        );

        // Drag to x = 210 -> fractional = (210/100) - 0.5 = 1.6 (closer to Tab 2)
        controller.onNavBarPointerMove(
          const PointerMoveEvent(position: Offset(210, 30)),
          barWidth,
        );

        controller.onNavBarPointerUp(
          const PointerUpEvent(position: Offset(210, 30)),
          barWidth,
        );

        expect(committedIndex, 2);
        expect(controller.currentIndex, 2);

        controller.dispose();
      },
    );

    testWidgets('8. High-velocity release flings in gesture direction', (
      tester,
    ) async {
      int committedIndex = -1;
      final controller = CodeXaNavigationController(
        initialIndex: 0,
        onTabCommitted: (idx) => committedIndex = idx,
      );
      const barWidth = 500.0;

      controller.onNavBarPointerDown(
        const PointerDownEvent(
          position: Offset(50, 30),
          timeStamp: Duration(milliseconds: 0),
        ),
        barWidth,
      );

      // Fast swipe right towards Tab 1 with high velocity
      controller.onNavBarPointerMove(
        const PointerMoveEvent(
          position: Offset(120, 30),
          timeStamp: Duration(milliseconds: 30),
        ),
        barWidth,
      );

      controller.onNavBarPointerUp(
        const PointerUpEvent(
          position: Offset(150, 30),
          timeStamp: Duration(milliseconds: 40),
        ),
        barWidth,
      );

      // Target committed should be 1
      expect(committedIndex, 1);

      controller.dispose();
    });

    test('9. External route index synchronization', () {
      final controller = CodeXaNavigationController(initialIndex: 0);

      controller.syncWithRouteIndex(4);
      expect(controller.currentIndex, 4);
      expect(controller.fractionalIndex, 4.0);

      // Out of bounds is safely ignored
      controller.syncWithRouteIndex(9);
      expect(controller.currentIndex, 4);

      controller.dispose();
    });
  });

  group('CodeXa Liquid Glass Navigation Bar Widget Tests', () {
    testWidgets('10. Renders all 5 official CodeXa tabs with correct labels', (
      tester,
    ) async {
      final controller = CodeXaNavigationController(initialIndex: 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CodeXaLiquidGlassBar(controller: controller),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('11. Direct tap on a tab item animates controller', (
      tester,
    ) async {
      int committed = -1;
      final controller = CodeXaNavigationController(
        initialIndex: 0,
        onTabCommitted: (idx) => committed = idx,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CodeXaLiquidGlassBar(controller: controller),
          ),
        ),
      );

      // Tap on 'Messages' (Tab 2)
      await tester.tap(find.text('Messages'));
      await tester.pump();

      expect(controller.currentIndex, 2);
      expect(committed, 2);

      controller.dispose();
    });

    testWidgets(
      '12. Android Three-Button Navigation SafeArea padding verification',
      (tester) async {
        final controller = CodeXaNavigationController(initialIndex: 0);

        // Simulate Android 3-button navigation (48dp bottom system inset)
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(bottom: 48.0)),
            child: MaterialApp(
              home: Scaffold(
                bottomNavigationBar: CodeXaLiquidGlassBar(
                  controller: controller,
                ),
              ),
            ),
          ),
        );

        final paddingFinder = find.byType(Padding);
        expect(paddingFinder, findsWidgets);

        final barPadding = tester.widget<Padding>(paddingFinder.first);
        final insets = barPadding.padding as EdgeInsets;
        // 48.0 + 8.0 = 56.0 bottom clearance to prevent overlapping Android buttons
        expect(insets.bottom, 56.0);

        controller.dispose();
      },
    );

    testWidgets('13. Soft Keyboard Active: Bottom bar disappears cleanly', (
      tester,
    ) async {
      final controller = CodeXaNavigationController(initialIndex: 0);

      // Simulate soft keyboard open (viewInsets.bottom = 280)
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            viewInsets: EdgeInsets.only(bottom: 280.0),
          ),
          child: MaterialApp(
            home: Scaffold(
              bottomNavigationBar: CodeXaLiquidGlassBar(controller: controller),
            ),
          ),
        ),
      );

      // When keyboard is active, bar is collapsed to SizedBox.shrink()
      expect(find.text('Home'), findsNothing);

      controller.dispose();
    });

    testWidgets(
      '14. Press-and-drag horizontal gesture moves fractional capsule',
      (tester) async {
        final controller = CodeXaNavigationController(initialIndex: 0);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              bottomNavigationBar: CodeXaLiquidGlassBar(controller: controller),
            ),
          ),
        );

        final navBarFinder = find.byType(CodeXaLiquidGlassBar);
        expect(navBarFinder, findsOneWidget);

        // Drag across the bottom bar horizontally
        await tester.drag(navBarFinder, const Offset(150, 0));
        await tester.pump();

        expect(controller.fractionalIndex, greaterThan(0.0));

        controller.dispose();
      },
    );
  });
}
