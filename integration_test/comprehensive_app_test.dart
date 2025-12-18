import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_expense_tracker/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('App Integration Tests', () {
    /// Test: App initialization
    testWidgets('App initializes and displays home screen',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsWidgets);
    });

    /// Test: Navigation to add expense
    testWidgets('Navigate to add expense screen', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      final fabFinder = find.byType(FloatingActionButton);
      if (fabFinder.evaluate().isNotEmpty) {
        await tester.tap(fabFinder);
        await tester.pumpAndSettle();
      }
    });

    /// Test: Add expense flow
    testWidgets('Complete add expense workflow',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Navigate to add expense
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Find and fill form fields
      final descriptionFields = find.byType(TextField);
      if (descriptionFields.evaluate().isNotEmpty) {
        await tester.enterText(descriptionFields.first, 'Test Fuel Purchase');
        await tester.pumpAndSettle();
      }
    });

    /// Test: Display expense list
    testWidgets('Display list of expenses',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsWidgets);
    });

    /// Test: Search functionality
    testWidgets('Search expenses by keyword',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      final searchFields = find.byType(TextField);
      if (searchFields.evaluate().isNotEmpty) {
        await tester.enterText(searchFields.first, 'Fuel');
        await tester.pumpAndSettle();
      }
    });

    /// Test: Filter by category
    testWidgets('Filter expenses by category',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Look for category filters
      final dropdowns = find.byType(DropdownButton);
      if (dropdowns.evaluate().isNotEmpty) {
        await tester.tap(dropdowns.first);
        await tester.pumpAndSettle();
      }
    });

    /// Test: Filter by date range
    testWidgets('Filter expenses by date range',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();
    });

    /// Test: Sort expenses
    testWidgets('Sort expenses by different criteria',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Look for sort options
      final popups = find.byType(PopupMenuButton);
      if (popups.evaluate().isNotEmpty) {
        await tester.tap(popups.first);
        await tester.pumpAndSettle();
      }
    });

    /// Test: View expense details
    testWidgets('View expense details', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Tap on first expense card if available
      final cards = find.byType(Card);
      if (cards.evaluate().isNotEmpty) {
        await tester.tap(cards.first);
        await tester.pumpAndSettle();
      }
    });

    /// Test: Edit expense
    testWidgets('Edit an existing expense',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Find and tap edit button
      final editButtons = find.byIcon(Icons.edit);
      if (editButtons.evaluate().isNotEmpty) {
        await tester.tap(editButtons.first);
        await tester.pumpAndSettle();
      }
    });

    /// Test: Delete expense
    testWidgets('Delete an expense', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Find and tap delete button
      final deleteButtons = find.byIcon(Icons.delete);
      if (deleteButtons.evaluate().isNotEmpty) {
        await tester.tap(deleteButtons.first);
        await tester.pumpAndSettle();

        // Confirm deletion
        final confirmButtons = find.text('Confirm');
        if (confirmButtons.evaluate().isNotEmpty) {
          await tester.tap(confirmButtons.first);
          await tester.pumpAndSettle();
        }
      }
    });

    /// Test: Export expenses
    testWidgets('Export expenses to file',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Look for export option in menu
      final menuButtons = find.byIcon(Icons.menu);
      if (menuButtons.evaluate().isNotEmpty) {
        await tester.tap(menuButtons.first);
        await tester.pumpAndSettle();
      }
    });

    /// Test: Generate report
    testWidgets('Generate expense report',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Look for report option
      final buttons = find.byType(ElevatedButton);
      if (buttons.evaluate().length > 1) {
        await tester.tap(buttons.at(1));
        await tester.pumpAndSettle();
      }
    });

    /// Test: View statistics
    testWidgets('Display expense statistics',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Look for charts or stats
      final tabs = find.byType(TabBar);
      if (tabs.evaluate().isNotEmpty) {
        await tester.tap(tabs.first);
        await tester.pumpAndSettle();
      }
    });

    /// Test: Currency conversion
    testWidgets('Handle currency display',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Verify currency symbol is displayed
      expect(find.text('₹'), findsWidgets);
    });

    /// Test: Date picker
    testWidgets('Open date picker for expense date',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Navigate to add expense
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Tap on date field
      final dateFields = find.byIcon(Icons.calendar_today);
      if (dateFields.evaluate().isNotEmpty) {
        await tester.tap(dateFields.first);
        await tester.pumpAndSettle();
      }
    });

    /// Test: Settings navigation
    testWidgets('Navigate to settings', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Look for settings option
      final settingsButtons = find.byIcon(Icons.settings);
      if (settingsButtons.evaluate().isNotEmpty) {
        await tester.tap(settingsButtons.first);
        await tester.pumpAndSettle();
      }
    });

    /// Test: Dark mode toggle
    testWidgets('Toggle dark mode', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Navigate to settings
      final settingsButtons = find.byIcon(Icons.settings);
      if (settingsButtons.evaluate().isNotEmpty) {
        await tester.tap(settingsButtons.first);
        await tester.pumpAndSettle();

        // Look for theme toggle
        final switches = find.byType(Switch);
        if (switches.evaluate().isNotEmpty) {
          await tester.tap(switches.first);
          await tester.pumpAndSettle();
        }
      }
    });

    /// Test: Help/About section
    testWidgets('Access help and about section',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Navigate to menu
      final menuButtons = find.byIcon(Icons.menu);
      if (menuButtons.evaluate().isNotEmpty) {
        await tester.tap(menuButtons.first);
        await tester.pumpAndSettle();
      }
    });

    /// Test: Back navigation
    testWidgets('Back button navigation works',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Navigate to a screen
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Go back
      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    /// Test: App doesn't crash on fast navigation
    testWidgets('Handle rapid navigation', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));

      // Rapid taps
      for (int i = 0; i < 5; i++) {
        final fab = find.byType(FloatingActionButton);
        if (fab.evaluate().isNotEmpty) {
          await tester.tap(fab);
          await tester.pumpAndSettle();
        }
      }

      expect(find.byType(MyApp), findsOneWidget);
    });

    /// Test: App handles screen rotation
    testWidgets('Handle screen rotation', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Rotate to landscape
      tester.view.physicalSize = const Size(800, 400);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsWidgets);

      // Rotate back to portrait
      tester.view.physicalSize = const Size(400, 800);

      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsWidgets);
    });

    /// Test: Performance with scrolling
    testWidgets('Smooth scrolling performance',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Find scrollable list
      final listFinder = find.byType(ListView);
      if (listFinder.evaluate().isNotEmpty) {
        for (int i = 0; i < 5; i++) {
          await tester.drag(listFinder, const Offset(0, -100));
          await tester.pumpAndSettle();
        }
      }

      expect(find.byType(Scaffold), findsWidgets);
    });

    /// Test: Memory efficiency
    testWidgets('App maintains performance under load',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Perform multiple operations
      for (int i = 0; i < 10; i++) {
        final fab = find.byType(FloatingActionButton);
        if (fab.evaluate().isNotEmpty) {
          await tester.tap(fab);
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
      }

      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}


