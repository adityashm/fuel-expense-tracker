import 'package:fuel_expense_tracker/models/expense_model.dart';

/// Test fixtures for Expense model
class ExpenseFixtures {
  /// Create a sample expense for testing
  static Expense createSampleExpense({
    String? id,
    String? description,
    double? amount,
    double? tax,
    DateTime? date,
    String? category,
    String? paymentMethod,
    bool? isPaid,
  }) {
    return Expense(
      id: id ?? 'test-expense-1',
      description: description ?? 'Test Fuel Purchase',
      amount: amount ?? 500.0,
      tax: tax ?? 50.0,
      date: date ?? DateTime(2024, 12, 11),
      category: category ?? 'Fuel',
      paymentMethod: paymentMethod ?? 'Card',
      isPaid: isPaid ?? true,
    );
  }

  /// Create multiple sample expenses
  static List<Expense> createSampleExpenseList({int count = 5}) {
    return List.generate(
      count,
      (index) => createSampleExpense(
        id: 'expense-$index',
        amount: 200.0 + (index * 100),
        tax: 20.0 + (index * 10),
        date: DateTime(2024, 12, 11 - index),
      ),
    );
  }

  /// Create expense with various payment methods
  static List<Expense> createExpensesByPaymentMethod() {
    return [
      createSampleExpense(
        id: 'cash-1',
        paymentMethod: 'Cash',
        amount: 500.0,
      ),
      createSampleExpense(
        id: 'card-1',
        paymentMethod: 'Card',
        amount: 1000.0,
      ),
      createSampleExpense(
        id: 'upi-1',
        paymentMethod: 'UPI',
        amount: 750.0,
      ),
      createSampleExpense(
        id: 'wallet-1',
        paymentMethod: 'Wallet',
        amount: 600.0,
      ),
    ];
  }

  /// Create expenses with various categories
  static List<Expense> createExpensesByCategory() {
    return [
      createSampleExpense(id: 'fuel-1', category: 'Fuel', amount: 500.0),
      createSampleExpense(id: 'service-1', category: 'Service', amount: 2000.0),
      createSampleExpense(id: 'parts-1', category: 'Parts', amount: 3000.0),
      createSampleExpense(id: 'insurance-1', category: 'Insurance', amount: 5000.0),
      createSampleExpense(id: 'other-1', category: 'Other', amount: 200.0),
    ];
  }

  /// Create high value expense
  static Expense createHighValueExpense() {
    return createSampleExpense(
      id: 'high-value-1',
      amount: 50000.0,
      tax: 5000.0,
      description: 'Major vehicle repair',
    );
  }

  /// Create low value expense
  static Expense createLowValueExpense() {
    return createSampleExpense(
      id: 'low-value-1',
      amount: 10.0,
      tax: 1.0,
      description: 'Small purchase',
    );
  }

  /// Create pending payment expense
  static Expense createPendingExpense() {
    return createSampleExpense(
      id: 'pending-1',
      isPaid: false,
      description: 'Pending repair bill',
    );
  }
}
