
import '../models/general_expense.dart';
import 'database_service_base.dart';

/// General expense database operations
/// 
/// Handles all database operations for general (non-fuel) expenses including:
/// - Personal expenses (groceries, utilities, entertainment)
/// - Household expenses (for family/household management feature)
/// - Creating, updating, querying, and deleting expense records
/// - Paginating and searching through expense records
class GeneralExpenseDatabase extends DatabaseServiceBase {
  /// Creates a general expense record
  /// 
  /// Parameters:
  ///   - expense: GeneralExpense object with expense details
  /// 
  /// Returns: The newly created GeneralExpense with generated ID
  /// 
  /// Example:
  /// ```dart
  /// final expense = GeneralExpense(
  ///   category: ExpenseCategory.groceries,
  ///   amount: 50.00,
  ///   date: DateTime.now(),
  ///   description: 'Weekly groceries',
  ///   deviceId: 'device123',
  /// );
  /// final created = await db.createGeneralExpense(expense);
  /// ```
  Future<GeneralExpense> createGeneralExpense(GeneralExpense expense) async {
    final db = await database;
    final id = await db.insert('general_expenses', expense.toMap());
    return GeneralExpense(
      id: id,
      deviceId: expense.deviceId,
      vehicleId: expense.vehicleId,
      date: expense.date,
      amount: expense.amount,
      category: expense.category,
      description: expense.description,
      receiptImagePath: expense.receiptImagePath,
      isHouseholdExpense: expense.isHouseholdExpense,
      familyMemberId: expense.familyMemberId,
      familyMemberName: expense.familyMemberName,
    );
  }

  /// Retrieves all general expenses
  /// 
  /// Returns: List of all GeneralExpense objects ordered by date (newest first)
  /// 
  /// Warning: Large datasets should use [getGeneralExpensesPaginated] instead
  Future<List<GeneralExpense>> getAllGeneralExpenses() async {
    final db = await database;
    final result = await db.query(
      'general_expenses',
      where: 'is_household_expense = 0',
      orderBy: 'date DESC',
    );

    return result.map((map) => GeneralExpense.fromMap(map)).toList();
  }

  /// Retrieves general expenses with pagination
  /// 
  /// Parameters:
  ///   - limit: Number of records per page (default: 20)
  ///   - offset: Number of records to skip for pagination
  ///   - category: Optional category filter
  /// 
  /// Returns: Paginated list of GeneralExpense objects
  /// 
  /// Example:
  /// ```dart
  /// // Get expenses for a specific category with pagination
  /// final page1 = await db.getGeneralExpensesPaginated(
  ///   limit: 20,
  ///   offset: 0,
  ///   category: 'Groceries',
  /// );
  /// ```
  Future<List<GeneralExpense>> getGeneralExpensesPaginated({
    int limit = 20,
    int offset = 0,
    String? category,
  }) async {
    final db = await database;
    
    String whereClause = 'is_household_expense = 0';
    final List<dynamic> whereArgs = [];
    
    if (category != null) {
      whereClause += ' AND category = ?';
      whereArgs.add(category);
    }

    final result = await db.query(
      'general_expenses',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );

    return result.map((map) => GeneralExpense.fromMap(map)).toList();
  }

  /// Retrieves all household expenses
  /// 
  /// Returns: List of household expense GeneralExpense objects
  /// 
  /// Filters expenses marked as household expenses (family/shared expenses)
  /// ordered by date in descending order
  Future<List<GeneralExpense>> getAllHouseholdExpenses() async {
    final db = await database;
    final result = await db.query(
      'general_expenses',
      where: 'is_household_expense = 1',
      orderBy: 'date DESC',
    );

    return result.map((map) => GeneralExpense.fromMap(map)).toList();
  }

  /// Retrieves a specific general expense by ID
  /// 
  /// Parameters:
  ///   - id: ID of the expense to retrieve
  /// 
  /// Returns: GeneralExpense object or null if not found
  Future<GeneralExpense?> getGeneralExpense(int id) async {
    final db = await database;
    final result = await db.query(
      'general_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isEmpty) return null;
    return GeneralExpense.fromMap(result.first);
  }

  /// Searches general expenses by query string
  /// 
  /// Parameters:
  ///   - query: Search term for category or description
  /// 
  /// Returns: List of matching GeneralExpense objects
  /// 
  /// Performs case-insensitive search across category and description fields
  Future<List<GeneralExpense>> searchGeneralExpenses(String query) async {
    final db = await database;
    final result = await db.query(
      'general_expenses',
      where: 'category LIKE ? OR description LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'date DESC',
    );

    return result.map((map) => GeneralExpense.fromMap(map)).toList();
  }

  /// Deletes a general expense
  /// 
  /// Parameters:
  ///   - id: ID of the expense to delete
  ///   - deviceId: Optional device ID for ownership verification
  /// 
  /// Returns: Number of rows deleted (should be 1 for success)
  /// 
  /// If deviceId is provided, only deletes if the record belongs to that device
  Future<int> deleteGeneralExpense(int id, String? deviceId) async {
    final db = await database;
    
    String whereClause = 'id = ?';
    final List<dynamic> whereArgs = [id];
    
    if (deviceId != null) {
      whereClause += ' AND device_id = ?';
      whereArgs.add(deviceId);
    }

    return db.delete(
      'general_expenses',
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  /// Updates a general expense record
  /// 
  /// Parameters:
  ///   - id: ID of the expense to update
  ///   - updates: Map of field names to new values
  ///   - deviceId: Optional device ID for ownership verification
  /// 
  /// Returns: Number of rows updated (should be 1 for success)
  /// 
  /// Example:
  /// ```dart
  /// await db.updateGeneralExpense(
  ///   1,
  ///   {
  ///     'amount': 75.00,
  ///     'category': 'Dining',
  ///   },
  /// );
  /// ```
  Future<int> updateGeneralExpense(
    int id,
    Map<String, dynamic> updates, {
    String? deviceId,
  }) async {
    final db = await database;
    
    String whereClause = 'id = ?';
    final List<dynamic> whereArgs = [id];
    
    if (deviceId != null) {
      whereClause += ' AND device_id = ?';
      whereArgs.add(deviceId);
    }

    return db.update(
      'general_expenses',
      updates,
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  /// Gets total expense amount for a category
  /// 
  /// Parameters:
  ///   - category: Expense category name
  ///   - startDate: Optional start date for filtering
  ///   - endDate: Optional end date for filtering
  /// 
  /// Returns: Total amount spent in the category, or 0 if none found
  /// 
  /// Useful for budget tracking and category-wise expense analysis
  Future<double> getCategoryTotal(
    String category, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    
    String whereClause = 'category = ?';
    final List<dynamic> whereArgs = [category];
    
    if (startDate != null) {
      whereClause += ' AND date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    
    if (endDate != null) {
      whereClause += ' AND date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM general_expenses WHERE $whereClause',
      whereArgs,
    );

    if (result.isEmpty || result[0]['total'] == null) return 0.0;
    return (result[0]['total'] as num).toDouble();
  }

  /// Gets all unique expense categories
  /// 
  /// Returns: List of category names
  /// 
  /// Useful for populating dropdown filters and category statistics
  Future<List<String>> getAllCategories() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT category FROM general_expenses WHERE category IS NOT NULL ORDER BY category',
    );

    return result.map((map) => map['category'] as String).toList();
  }
}
