import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_expense_tracker/models/expense_model.dart';
import '../../fixtures/expense_fixtures.dart';

void main() {
  group('Expense Model Advanced Tests', () {
    /// Test: Expense creation with all parameters
    test('Create expense with all parameters', () {
      final expense = ExpenseFixtures.createSampleExpense(
        id: 'exp-001',
        description: 'Full Tank',
        amount: 1000,
        tax: 100,
        category: 'Fuel',
        paymentMethod: 'Card',
        isPaid: true,
      );

      expect(expense.id, 'exp-001');
      expect(expense.description, 'Full Tank');
      expect(expense.amount, 1000);
      expect(expense.tax, 100);
      expect(expense.category, 'Fuel');
      expect(expense.paymentMethod, 'Card');
      expect(expense.isPaid, true);
    });

    /// Test: Total calculation includes tax
    test('Expense total includes tax', () {
      final expense = ExpenseFixtures.createSampleExpense(
        amount: 1000,
        tax: 100,
      );

      expect(expense.total, 1100);
    });

    /// Test: Expense with zero tax
    test('Expense with zero tax', () {
      final expense = ExpenseFixtures.createSampleExpense(
        amount: 500,
        tax: 0,
      );

      expect(expense.total, 500);
    });

    /// Test: High value expense
    test('Handle high value expense', () {
      final expense = ExpenseFixtures.createHighValueExpense();

      expect(expense.amount, 50000);
      expect(expense.tax, 5000);
      expect(expense.total, 55000);
    });

    /// Test: Low value expense
    test('Handle low value expense', () {
      final expense = ExpenseFixtures.createLowValueExpense();

      expect(expense.amount, 10);
      expect(expense.tax, 1);
      expect(expense.total, 11);
    });

    /// Test: Expense equality
    test('Same expenses are equal', () {
      final exp1 = ExpenseFixtures.createSampleExpense(id: 'exp-1');
      final exp2 = ExpenseFixtures.createSampleExpense(id: 'exp-1');

      expect(exp1, exp2);
    });

    /// Test: Different expenses are not equal
    test('Different expenses are not equal', () {
      final exp1 = ExpenseFixtures.createSampleExpense(id: 'exp-1');
      final exp2 = ExpenseFixtures.createSampleExpense(id: 'exp-2');

      expect(exp1, isNot(exp2));
    });

    /// Test: CopyWith creates new instance
    test('CopyWith creates new instance with updated values', () {
      final original = ExpenseFixtures.createSampleExpense(
        amount: 500,
        description: 'Original',
      );

      final updated = original.copyWith(
        amount: 1000,
        description: 'Updated',
      );

      expect(updated.amount, 1000);
      expect(updated.description, 'Updated');
      expect(original.amount, 500);
      expect(original.description, 'Original');
    });

    /// Test: CopyWith preserves unchanged fields
    test('CopyWith preserves unchanged fields', () {
      final original = ExpenseFixtures.createSampleExpense(
        id: 'exp-1',
        amount: 500,
        category: 'Fuel',
      );

      final updated = original.copyWith(amount: 1000);

      expect(updated.id, 'exp-1');
      expect(updated.category, 'Fuel');
      expect(updated.amount, 1000);
    });

    /// Test: Pending vs Paid expense
    test('Distinguish between pending and paid expenses', () {
      final paid = ExpenseFixtures.createSampleExpense(isPaid: true);
      final pending = ExpenseFixtures.createPendingExpense();

      expect(paid.isPaid, true);
      expect(pending.isPaid, false);
    });

    /// Test: Expense date handling
    test('Handle expense dates correctly', () {
      final today = DateTime(2024, 12, 11);
      final expense = ExpenseFixtures.createSampleExpense(date: today);

      expect(expense.date, today);
      expect(expense.date.year, 2024);
      expect(expense.date.month, 12);
      expect(expense.date.day, 11);
    });

    /// Test: Multiple expenses with different categories
    test('Handle expenses with various categories', () {
      final expenses = ExpenseFixtures.createExpensesByCategory();

      expect(expenses, hasLength(5));
      expect(expenses.map((e) => e.category), [
        'Fuel',
        'Service',
        'Parts',
        'Insurance',
        'Other',
      ]);
    });

    /// Test: Multiple expenses with different payment methods
    test('Handle expenses with various payment methods', () {
      final expenses = ExpenseFixtures.createExpensesByPaymentMethod();

      expect(expenses, hasLength(4));
      expect(expenses.map((e) => e.paymentMethod), [
        'Cash',
        'Card',
        'UPI',
        'Wallet',
      ]);
    });

    /// Test: Calculate total from multiple expenses
    test('Calculate total from multiple expenses', () {
      final expenses = ExpenseFixtures.createSampleExpenseList(count: 3);

      double totalAmount = 0;
      double totalTax = 0;
      for (final expense in expenses) {
        totalAmount += expense.amount;
        totalTax += expense.tax;
      }

      expect(totalAmount, greaterThan(0));
      expect(totalTax, greaterThan(0));
    });

    /// Test: Filter expenses by category
    test('Filter expenses by category', () {
      final allExpenses = ExpenseFixtures.createExpensesByCategory();
      final fuelExpenses = allExpenses
          .where((e) => e.category == 'Fuel')
          .toList();

      expect(fuelExpenses, hasLength(1));
      expect(fuelExpenses.first.category, 'Fuel');
    });

    /// Test: Filter expenses by payment method
    test('Filter expenses by payment method', () {
      final allExpenses = ExpenseFixtures.createExpensesByPaymentMethod();
      final cardPayments = allExpenses
          .where((e) => e.paymentMethod == 'Card')
          .toList();

      expect(cardPayments, hasLength(1));
      expect(cardPayments.first.paymentMethod, 'Card');
    });

    /// Test: Sort expenses by amount
    test('Sort expenses by amount', () {
      final expenses = ExpenseFixtures.createSampleExpenseList()
        ..sort((a, b) => a.amount.compareTo(b.amount));

      for (int i = 0; i < expenses.length - 1; i++) {
        expect(
          expenses[i].amount,
          lessThanOrEqualTo(expenses[i + 1].amount),
        );
      }
    });

    /// Test: Sort expenses by date
    test('Sort expenses by date descending', () {
      final expenses = ExpenseFixtures.createSampleExpenseList()
        ..sort((a, b) => b.date.compareTo(a.date));

      for (int i = 0; i < expenses.length - 1; i++) {
        expect(
          expenses[i].date.isAfter(expenses[i + 1].date) ||
              expenses[i].date.isAtSameMomentAs(expenses[i + 1].date),
          true,
        );
      }
    });

    /// Test: Expense to JSON
    test('Convert expense to JSON', () {
      final expense = ExpenseFixtures.createSampleExpense();
      final json = expense.toJson();

      expect(json, isA<Map<String, dynamic>>());
      expect(json['id'], 'test-expense-1');
      expect(json['description'], 'Test Fuel Purchase');
    });

    /// Test: Expense from JSON
    test('Create expense from JSON', () {
      final json = {
        'id': 'json-exp-1',
        'description': 'JSON Expense',
        'amount': 500.0,
        'tax': 50.0,
        'date': '2024-12-11',
        'category': 'Fuel',
        'paymentMethod': 'Card',
        'isPaid': true,
      };

      final expense = Expense.fromJson(json);

      expect(expense.id, 'json-exp-1');
      expect(expense.description, 'JSON Expense');
    });

    /// Test: Negative amount handling
    test('Handle negative amounts', () {
      final expense = ExpenseFixtures.createSampleExpense(
        amount: -500,
      );

      expect(expense.amount, -500);
    });

    /// Test: Large list of expenses
    test('Handle large list of expenses', () {
      final expenses = ExpenseFixtures.createSampleExpenseList(count: 1000);

      expect(expenses, hasLength(1000));
      expect(expenses.every((e) => e.id.isNotEmpty), true);
    });

    /// Test: Batch operations
    test('Perform batch operations on expenses', () {
      final expenses = ExpenseFixtures.createSampleExpenseList(count: 10);

      // Filter, sort, and calculate
      final filtered = expenses
          .where((e) => e.amount > 300)
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

      expect(filtered.isNotEmpty, true);
      expect(filtered.first.amount, greaterThan(300));
    });
  });
}
