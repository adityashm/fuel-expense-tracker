
import '../models/fuel_expense.dart';
import 'database_service_base.dart';

/// Fuel expense database operations
/// 
/// Handles all database operations related to fuel expenses including:
/// - Creating and updating fuel expense records
/// - Querying fuel expenses by vehicle or device
/// - Calculating fuel consumption averages and statistics
/// - Searching and paginating through fuel expenses
class FuelExpenseDatabase extends DatabaseServiceBase {
  /// Creates a fuel expense record in the database
  /// 
  /// Parameters:
  ///   - expense: FuelExpense object containing expense details
  /// 
  /// Returns: The created FuelExpense with generated ID
  /// 
  /// Example:
  /// ```dart
  /// final expense = FuelExpense(
  ///   vehicleId: 1,
  ///   amountPaid: 45.50,
  ///   liters: 30.0,
  ///   date: DateTime.now(),
  ///   fuelType: FuelType.petrol,
  ///   deviceId: 'device123',
  ///   odometerReading: 45000,
  /// );
  /// final created = await db.createFuelExpense(expense);
  /// ```
  Future<FuelExpense> createFuelExpense(FuelExpense expense) async {
    final db = await database;
    final id = await db.insert('fuel_expenses', expense.toMap());
    return FuelExpense(
      id: id,
      deviceId: expense.deviceId,
      vehicleId: expense.vehicleId,
      date: expense.date,
      fuelType: expense.fuelType,
      amountPaid: expense.amountPaid,
      liters: expense.liters,
      odometerReading: expense.odometerReading,
      pumpName: expense.pumpName,
      location: expense.location,
      receiptImagePath: expense.receiptImagePath,
      notes: expense.notes,
      familyMemberId: expense.familyMemberId,
      familyMemberName: expense.familyMemberName,
    );
  }

  /// Retrieves all fuel expenses for a specific vehicle
  /// 
  /// Parameters:
  ///   - vehicleId: ID of the vehicle
  /// 
  /// Returns: List of FuelExpense objects for the vehicle
  /// 
  /// Results are ordered by date in descending order (newest first)
  Future<List<FuelExpense>> getFuelExpensesByVehicle(int vehicleId) async {
    final db = await database;
    final result = await db.query(
      'fuel_expenses',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC',
    );

    return result.map((map) => FuelExpense.fromMap(map)).toList();
  }

  /// Retrieves all fuel expenses across all vehicles
  /// 
  /// Returns: List of all FuelExpense objects
  /// 
  /// Warning: This may return a large dataset. Consider using
  /// [getFuelExpensesByDevice] or [getFuelExpensesPaginated] for
  /// better performance with large datasets.
  Future<List<FuelExpense>> getAllFuelExpenses() async {
    final db = await database;
    final result = await db.query(
      'fuel_expenses',
      orderBy: 'date DESC',
    );

    return result.map((map) => FuelExpense.fromMap(map)).toList();
  }

  /// Retrieves fuel expenses for a specific device
  /// 
  /// Parameters:
  ///   - deviceId: Device identifier
  /// 
  /// Returns: List of FuelExpense objects for the device
  /// 
  /// Filters expenses by device_id which is useful for multi-device
  /// scenarios where you want to fetch device-specific data.
  Future<List<FuelExpense>> getFuelExpensesByDevice(String deviceId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT fe.* FROM fuel_expenses fe
      JOIN vehicles v ON fe.vehicle_id = v.id
      WHERE v.device_id = ? OR fe.device_id = ?
      ORDER BY fe.date DESC
    ''', [deviceId, deviceId],);

    return maps.map((map) => FuelExpense.fromMap(map)).toList();
  }

  /// Updates an existing fuel expense record
  /// 
  /// Parameters:
  ///   - expense: Updated FuelExpense object
  ///   - deviceId: Optional device ID for ownership verification
  /// 
  /// Returns: Number of rows updated (should be 1 for success)
  /// 
  /// Note: If deviceId is provided, only updates records that belong
  /// to that device (security measure for multi-device apps)
  Future<int> updateFuelExpense(FuelExpense expense, String? deviceId) async {
    final db = await database;
    
    String whereClause = 'id = ?';
    final List<dynamic> whereArgs = [expense.id];
    
    if (deviceId != null) {
      whereClause += ' AND device_id = ?';
      whereArgs.add(deviceId);
    }

    return db.update(
      'fuel_expenses',
      expense.toMap(),
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  /// Deletes a fuel expense record
  /// 
  /// Parameters:
  ///   - id: ID of the expense to delete
  ///   - deviceId: Optional device ID for ownership verification
  /// 
  /// Returns: Number of rows deleted (should be 1 for success)
  /// 
  /// Returns 0 if the expense doesn't exist or deviceId doesn't match
  Future<int> deleteFuelExpense(int id, String? deviceId) async {
    final db = await database;
    
    String whereClause = 'id = ?';
    final List<dynamic> whereArgs = [id];
    
    if (deviceId != null) {
      whereClause += ' AND device_id = ?';
      whereArgs.add(deviceId);
    }

    return db.delete(
      'fuel_expenses',
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  /// Retrieves a specific fuel expense by ID
  /// 
  /// Parameters:
  ///   - id: ID of the fuel expense
  /// 
  /// Returns: FuelExpense object or null if not found
  Future<FuelExpense?> getFuelExpense(int id) async {
    final db = await database;
    final result = await db.query(
      'fuel_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isEmpty) return null;
    return FuelExpense.fromMap(result.first);
  }

  /// Retrieves the most recent fuel expense for a vehicle
  /// 
  /// Parameters:
  ///   - vehicleId: ID of the vehicle
  /// 
  /// Returns: Most recent FuelExpense or null if none found
  /// 
  /// Useful for calculating fuel efficiency since you need the
  /// previous odometer reading from the last expense
  Future<FuelExpense?> getLastFuelExpense(int vehicleId) async {
    final db = await database;
    final result = await db.query(
      'fuel_expenses',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC',
      limit: 1,
    );

    if (result.isEmpty) return null;
    return FuelExpense.fromMap(result.first);
  }

  /// Retrieves fuel expenses with pagination
  /// 
  /// Parameters:
  ///   - limit: Number of records per page (default: 20)
  ///   - offset: Number of records to skip (for pagination)
  /// 
  /// Returns: List of FuelExpense objects for the requested page
  /// 
  /// Example:
  /// ```dart
  /// // Get first 20 expenses
  /// final page1 = await db.getFuelExpensesPaginated(limit: 20, offset: 0);
  /// // Get next 20 expenses
  /// final page2 = await db.getFuelExpensesPaginated(limit: 20, offset: 20);
  /// ```
  Future<List<FuelExpense>> getFuelExpensesPaginated({
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await database;
    final result = await db.query(
      'fuel_expenses',
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );

    return result.map((map) => FuelExpense.fromMap(map)).toList();
  }

  /// Searches fuel expenses by query string
  /// 
  /// Parameters:
  ///   - query: Search term (searches pump name and location)
  /// 
  /// Returns: List of matching FuelExpense objects
  /// 
  /// Performs case-insensitive search on pump name and location fields
  Future<List<FuelExpense>> searchFuelExpenses(String query) async {
    final db = await database;
    final result = await db.query(
      'fuel_expenses',
      where: 'pumpName LIKE ? OR location LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'date DESC',
    );

    return result.map((map) => FuelExpense.fromMap(map)).toList();
  }

  /// Calculates fuel consumption statistics for a vehicle
  /// 
  /// Parameters:
  ///   - vehicleId: ID of the vehicle
  /// 
  /// Returns: Map containing:
  ///   - 'avgFuelConsumption': Average L/100km or km/L
  ///   - 'avgCostPerLiter': Average cost per liter
  ///   - 'totalExpenses': Sum of all fuel expenses
  ///   - 'totalLiters': Total liters purchased
  ///   - 'recordCount': Number of expense records
  /// 
  /// Example:
  /// ```dart
  /// final stats = await db.calculateFuelAverages(vehicleId);
  /// print('Avg consumption: ${stats['avgFuelConsumption']} L/100km');
  /// ```
  Future<Map<String, double>> calculateFuelAverages(int vehicleId) async {
    // Get all expenses for the vehicle
    final expenses = await getFuelExpensesByVehicle(vehicleId);
    
    if (expenses.isEmpty) {
      return {
        'avgFuelConsumption': 0.0,
        'avgCostPerLiter': 0.0,
        'totalExpenses': 0.0,
        'totalLiters': 0.0,
      };
    }

    double totalCost = 0.0;
    double totalLiters = 0.0;
    double totalDistance = 0.0;
    int validExpenses = 0;

    for (int i = 0; i < expenses.length - 1; i++) {
      final current = expenses[i];
      final previous = expenses[i + 1];

      totalCost += current.amountPaid;
      totalLiters += current.liters;

      if (current.odometerReading > previous.odometerReading) {
        totalDistance += current.odometerReading - previous.odometerReading;
        validExpenses++;
      }
    }

    final avgConsumption = validExpenses > 0 && totalDistance > 0
        ? (totalLiters / totalDistance) * 100
        : 0.0;
    
    final avgCostPerLiter = totalLiters > 0 ? totalCost / totalLiters : 0.0;

    return {
      'avgFuelConsumption': avgConsumption,
      'avgCostPerLiter': avgCostPerLiter,
      'totalExpenses': totalCost,
      'totalLiters': totalLiters,
    };
  }

  /// Calculates simple fuel average (km/L or L/100km)
  /// 
  /// Parameters:
  ///   - vehicleId: ID of the vehicle
  /// 
  /// Returns: Average fuel consumption value
  /// 
  /// Simplified version of [calculateFuelAverages] that returns only
  /// the fuel consumption metric
  Future<double> calculateFuelAverage(int vehicleId) async {
    final stats = await calculateFuelAverages(vehicleId);
    return stats['avgFuelConsumption'] ?? 0.0;
  }
}
