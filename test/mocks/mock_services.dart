import 'package:fuel_expense_tracker/models/expense_model.dart';
import 'package:fuel_expense_tracker/services/database_service.dart';
import 'package:fuel_expense_tracker/services/firebase_service.dart';
import 'package:mockito/mockito.dart';

/// Mock Firebase Service for testing
class MockFirebaseService extends Mock implements FirebaseService {
  // Mock implementations can be added as needed for specific tests
}

/// Mock Database Service for testing
class MockDatabaseService extends Mock implements DatabaseService {
  final List<Expense> _mockExpenses = [];

  Future<List<Expense>> getAllExpenses() async => _mockExpenses;

  Future<Expense?> getExpenseById(String id) async {
    try {
      return _mockExpenses.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> insertExpense(Expense expense) async {
    _mockExpenses.add(expense);
  }

  Future<void> updateExpense(Expense expense) async {
    final index = _mockExpenses.indexWhere((e) => e.id == expense.id);
    if (index != -1) {
      _mockExpenses[index] = expense;
    }
  }

  Future<void> deleteExpense(String id) async {
    _mockExpenses.removeWhere((e) => e.id == id);
  }

  /// Clear all mock data
  void clearMockData() {
    _mockExpenses.clear();
  }

  /// Add multiple expenses to mock
  void addMockExpenses(List<Expense> expenses) {
    _mockExpenses.addAll(expenses);
  }
}

/// Mock implementation with controlled responses
class MockDatabaseServiceWithResponse extends Mock implements DatabaseService {

  MockDatabaseServiceWithResponse(List<Expense> expenses) {
    _expensesToReturn = expenses;
  }
  late List<Expense> _expensesToReturn;

  Future<List<Expense>> getAllExpenses() async => _expensesToReturn;

  void setExpensesToReturn(List<Expense> expenses) {
    _expensesToReturn = expenses;
  }
}
