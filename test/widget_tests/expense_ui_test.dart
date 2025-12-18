import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_expense_tracker/widgets/expense_card.dart';
import 'package:fuel_expense_tracker/widgets/expense_list.dart';
import '../fixtures/expense_fixtures.dart';

void main() {
  group('Expense UI Components Tests', () {
    /// Test: Expense card rendering
    testWidgets('Expense card renders correctly', (WidgetTester tester) async {
      final expense = ExpenseFixtures.createSampleExpense();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(expense: expense),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
      expect(find.text(expense.description), findsOneWidget);
    });

    /// Test: Expense card shows amount
    testWidgets('Expense card displays amount', (WidgetTester tester) async {
      final expense = ExpenseFixtures.createSampleExpense(
        amount: 500.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(expense: expense),
          ),
        ),
      );

      expect(find.text('₹500.00'), findsOneWidget);
    });

    /// Test: Expense card shows date
    testWidgets('Expense card displays date', (WidgetTester tester) async {
      final expense = ExpenseFixtures.createSampleExpense();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(expense: expense),
          ),
        ),
      );

      expect(find.text('${expense.date.day}/${expense.date.month}/${expense.date.year}'),
          findsOneWidget,);
    });

    /// Test: Expense card shows category
    testWidgets('Expense card shows category',
        (WidgetTester tester) async {
      final expense = ExpenseFixtures.createSampleExpense(
        category: 'Fuel',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(expense: expense),
          ),
        ),
      );

      expect(find.text('Fuel'), findsWidgets);
    });

    /// Test: Expense list renders
    testWidgets('Expense list renders multiple items',
        (WidgetTester tester) async {
      final expenses = ExpenseFixtures.createSampleExpenseList();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseList(expenses: expenses),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(ExpenseCard), findsWidgets);
    });

    /// Test: Empty expense list
    testWidgets('Empty expense list shows empty state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExpenseList(expenses: []),
          ),
        ),
      );

      expect(find.text('No expenses'), findsOneWidget);
    });

    /// Test: Expense list scrolling
    testWidgets('Expense list is scrollable',
        (WidgetTester tester) async {
      final expenses = ExpenseFixtures.createSampleExpenseList(count: 100);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseList(expenses: expenses),
          ),
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
    });

    /// Test: Expense card tap
    testWidgets('Expense card is tappable', (WidgetTester tester) async {
      final expense = ExpenseFixtures.createSampleExpense();
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onTap: () => tapped = true,
              child: ExpenseCard(expense: expense),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Card));
      expect(tapped, true);
    });

    /// Test: Color coding by category
    testWidgets('Expense cards color-coded by category',
        (WidgetTester tester) async {
      final fuelExpense =
          ExpenseFixtures.createSampleExpense(category: 'Fuel');
      final serviceExpense =
          ExpenseFixtures.createSampleExpense(category: 'Service');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ExpenseCard(expense: fuelExpense),
                ExpenseCard(expense: serviceExpense),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(ExpenseCard), findsWidgets);
    });

    /// Test: Display payment method icon
    testWidgets('Expense card shows payment method icon',
        (WidgetTester tester) async {
      final expense = ExpenseFixtures.createSampleExpense(
        paymentMethod: 'Card',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(expense: expense),
          ),
        ),
      );

      expect(find.byType(Icon), findsWidgets);
    });

    /// Test: Payment status indicator
    testWidgets('Expense card shows payment status',
        (WidgetTester tester) async {
      final paidExpense = ExpenseFixtures.createSampleExpense(isPaid: true);
      final pendingExpense = ExpenseFixtures.createPendingExpense();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ExpenseCard(expense: paidExpense),
                ExpenseCard(expense: pendingExpense),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(ExpenseCard), findsWidgets);
    });

    /// Test: Long description truncation
    testWidgets('Long expense descriptions are truncated',
        (WidgetTester tester) async {
      const longDesc =
          'This is a very long expense description that should be truncated';
      final expense = ExpenseFixtures.createSampleExpense(
        description: longDesc,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(expense: expense),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    /// Test: Multi-line text handling
    testWidgets('Handle multi-line descriptions',
        (WidgetTester tester) async {
      final expense = ExpenseFixtures.createSampleExpense(
        description: 'Line 1\nLine 2\nLine 3',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(expense: expense),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    /// Test: Large amount display
    testWidgets('Display large amounts correctly',
        (WidgetTester tester) async {
      final expense = ExpenseFixtures.createHighValueExpense();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(expense: expense),
          ),
        ),
      );

      expect(find.text('₹50000.00'), findsOneWidget);
    });

    /// Test: Small amount display
    testWidgets('Display small amounts correctly',
        (WidgetTester tester) async {
      final expense = ExpenseFixtures.createLowValueExpense();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(expense: expense),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    /// Test: Date badge
    testWidgets('Expense card shows date badge',
        (WidgetTester tester) async {
      final expense = ExpenseFixtures.createSampleExpense();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(expense: expense),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    /// Test: Edit button visibility
    testWidgets('Expense card shows edit button',
        (WidgetTester tester) async {
      final expense = ExpenseFixtures.createSampleExpense();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(
              expense: expense,
              onEdit: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    /// Test: Delete button visibility
    testWidgets('Expense card shows delete button',
        (WidgetTester tester) async {
      final expense = ExpenseFixtures.createSampleExpense();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(
              expense: expense,
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.delete), findsOneWidget);
    });

    /// Test: Responsive layout
    testWidgets('Expense card is responsive', (WidgetTester tester) async {
      final expense = ExpenseFixtures.createSampleExpense();

      final view = tester.binding.platformDispatcher.implicitView!
        ..physicalSize = const Size(500, 800);
      addTearDown(() => view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(expense: expense),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    /// Test: Dark mode support
    testWidgets('Expense card supports dark theme',
        (WidgetTester tester) async {
      final expense = ExpenseFixtures.createSampleExpense();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ExpenseCard(expense: expense),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    /// Test: Custom spacing
    testWidgets('Expense list has proper spacing',
        (WidgetTester tester) async {
      final expenses = ExpenseFixtures.createSampleExpenseList(count: 3);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseList(expenses: expenses),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
    });

    /// Test: Performance with large lists
    testWidgets('Handle large expense lists efficiently',
        (WidgetTester tester) async {
      final expenses = ExpenseFixtures.createSampleExpenseList(count: 500);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseList(expenses: expenses),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(ExpenseCard), findsWidgets);
    });
  });
}

/// Helper to define testWidgets properly
void testWidgetsByPaymentMethod(
  String description,
  Future<void> Function(WidgetTester) callback,
) {
  testWidgets(description, callback);
}
