import 'package:flutter/material.dart';
import '../models/family_member.dart';
import '../models/fuel_expense.dart';
import '../models/general_expense.dart';
import '../models/payment.dart';
import '../models/recurring_expense.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';
// 🆕 PHASE 3: Import optimistic update manager
import '../utils/data_consistency.dart';

class ExpenseProvider extends ChangeNotifier {
  List<FuelExpense> _fuelExpenses = [];
  List<GeneralExpense> _generalExpenses = [];
  List<GeneralExpense> _householdExpenses = [];
  List<FamilyMember> _familyMembers = [];
  bool _isFuelLoading = false;
  bool _isGeneralLoading = false;
  bool _isHouseholdLoading = false;
  bool _isLoadingMore = false;
  int _currentOffset = 0;
  bool _hasMoreData = true;
  
  // 🆕 PHASE 3: Optimistic update managers
  late final OptimisticUpdateManager<FuelExpense> _fuelOptimisticManager;
  late final OptimisticUpdateManager<GeneralExpense> _generalOptimisticManager;

  ExpenseProvider() {
    _fuelOptimisticManager = OptimisticUpdateManager<FuelExpense>(_fuelExpenses);
    _generalOptimisticManager = OptimisticUpdateManager<GeneralExpense>(_generalExpenses);
  }

  List<FuelExpense> get fuelExpenses => _fuelExpenses;
  List<GeneralExpense> get generalExpenses => _generalExpenses;
  List<GeneralExpense> get householdExpenses => _householdExpenses;
  List<FamilyMember> get familyMembers => _familyMembers;
  bool get isFuelLoading => _isFuelLoading;
  bool get isGeneralLoading => _isGeneralLoading;
  bool get isHouseholdLoading => _isHouseholdLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;

  // ==================== FUEL EXPENSES ====================

  Future<void> loadFuelExpenses({bool refresh = false}) async {
    if (refresh) {
      _currentOffset = 0;
      _hasMoreData = true;
      _fuelExpenses.clear();
    }

    _isFuelLoading = true;
    notifyListeners();

    try {
      final expenses = await DatabaseService.instance.getFuelExpensesPaginated(
        offset: _currentOffset,
      );

      if (refresh) {
        _fuelExpenses = expenses;
      } else {
        _fuelExpenses.addAll(expenses);
      }

      _currentOffset += expenses.length;
      _hasMoreData = expenses.length >= AppConstants.paginationBatchSize;
    } finally {
      _isFuelLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreFuelExpenses() async {
    if (_isLoadingMore || !_hasMoreData) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final expenses = await DatabaseService.instance.getFuelExpensesPaginated(
        offset: _currentOffset,
      );

      _fuelExpenses.addAll(expenses);
      _currentOffset += expenses.length;
      _hasMoreData = expenses.length >= AppConstants.paginationBatchSize;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadFuelExpensesByVehicle(int vehicleId) async {
    _isFuelLoading = true;
    notifyListeners();

    try {
      _fuelExpenses =
          await DatabaseService.instance.getFuelExpensesByVehicle(vehicleId);
    } finally {
      _isFuelLoading = false;
      notifyListeners();
    }
  }

  Future<FuelExpense> createFuelExpense(FuelExpense expense) async {
    try {
      final createdExpense =
          await DatabaseService.instance.createFuelExpense(expense);
      // Reload expenses from database to prevent duplicates
      await loadFuelExpenses(refresh: true);
      return createdExpense;
    } catch (e) {
      debugPrint('Error creating fuel expense: $e');
      rethrow;
    }
  }

  Future<void> updateFuelExpense(FuelExpense expense, String? deviceId) async {
    try {
      await DatabaseService.instance.updateFuelExpense(expense, deviceId);
      // Reload from database to ensure consistency
      await loadFuelExpenses(refresh: true);
    } catch (e) {
      debugPrint('Error updating fuel expense: $e');
      rethrow;
    }
  }

  Future<void> deleteFuelExpense(int expenseId, String? deviceId) async {
    try {
      await DatabaseService.instance.deleteFuelExpense(expenseId, deviceId);
      // Reload from database to ensure consistency
      await loadFuelExpenses(refresh: true);
    } catch (e) {
      debugPrint('Error deleting fuel expense: $e');
      rethrow;
    }
  }

  // ==================== GENERAL EXPENSES ====================

  Future<void> loadGeneralExpenses({bool refresh = false}) async {
    if (refresh) {
      _currentOffset = 0;
      _hasMoreData = true;
      _generalExpenses.clear();
    }

    _isGeneralLoading = true;
    notifyListeners();

    try {
      final expenses =
          await DatabaseService.instance.getGeneralExpensesPaginated(
        offset: _currentOffset,
      );

      if (refresh) {
        _generalExpenses =
            expenses.where((e) => !e.isHouseholdExpense).toList();
      } else {
        _generalExpenses.addAll(expenses.where((e) => !e.isHouseholdExpense));
      }

      _currentOffset += expenses.length;
      _hasMoreData = expenses.length >= AppConstants.paginationBatchSize;
    } finally {
      _isGeneralLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreGeneralExpenses() async {
    if (_isLoadingMore || !_hasMoreData) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final expenses =
          await DatabaseService.instance.getGeneralExpensesPaginated(
        offset: _currentOffset,
      );

      _generalExpenses.addAll(expenses.where((e) => !e.isHouseholdExpense));
      _currentOffset += expenses.length;
      _hasMoreData = expenses.length >= AppConstants.paginationBatchSize;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadGeneralExpensesByVehicle(int vehicleId) async {
    _isGeneralLoading = true;
    notifyListeners();

    try {
      _generalExpenses =
          await DatabaseService.instance.getGeneralExpensesByVehicle(vehicleId);
    } finally {
      _isGeneralLoading = false;
      notifyListeners();
    }
  }

  Future<GeneralExpense> createGeneralExpense(GeneralExpense expense) async {
    try {
      final createdExpense =
          await DatabaseService.instance.createGeneralExpense(expense);

      // Reset pagination state
      _currentOffset = 0;
      _hasMoreData = true;

      // Reload ALL lists to ensure UI consistency across all screens
      await Future.wait([
        if (createdExpense.isHouseholdExpense)
          loadHouseholdExpenses(refresh: true)
        else
          loadGeneralExpenses(refresh: true),
        // Also reload fuel expenses to update totals
        loadFuelExpenses(refresh: true),
      ]);

      // Force UI update
      notifyListeners();

      return createdExpense;
    } catch (e) {
      debugPrint('Error creating general expense: $e');
      rethrow;
    }
  }

  Future<void> updateGeneralExpense(
    GeneralExpense expense,
    String? deviceId,
  ) async {
    try {
      await DatabaseService.instance.updateGeneralExpense(expense, deviceId);

      // Reload appropriate list based on expense type
      if (expense.isHouseholdExpense) {
        await loadHouseholdExpenses(refresh: true);
      } else {
        await loadGeneralExpenses(refresh: true);
      }
    } catch (e) {
      debugPrint('Error updating general expense: $e');
      rethrow;
    }
  }

  Future<void> deleteGeneralExpense(int expenseId, String? deviceId) async {
    await DatabaseService.instance.deleteGeneralExpense(expenseId, deviceId);
    _generalExpenses.removeWhere((e) => e.id == expenseId);
    _householdExpenses.removeWhere((e) => e.id == expenseId);
    notifyListeners();
  }

  // ==================== HOUSEHOLD EXPENSES ====================

  Future<void> loadHouseholdExpenses({bool refresh = false}) async {
    _isHouseholdLoading = true;
    notifyListeners();

    try {
      // Always fetch fresh data from database for household expenses
      final db = await DatabaseService.instance.database;
      final results = await db.query(
        'general_expenses',
        where: 'is_household_expense = ?',
        whereArgs: [1],
        orderBy: 'date DESC',
        limit: refresh ? 50 : null,
      );

      _householdExpenses = results
          .map((map) => GeneralExpense.fromMap(map))
          .toList();
    } catch (e) {
      debugPrint('Error loading household expenses: $e');
    } finally {
      _isHouseholdLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreHouseholdExpenses() async {
    if (_isLoadingMore || !_hasMoreData) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final expenses =
          await DatabaseService.instance.getGeneralExpensesPaginated(
        offset: _currentOffset,
      );

      _householdExpenses.addAll(expenses.where((e) => e.isHouseholdExpense));
      _currentOffset += expenses.length;
      _hasMoreData = expenses.length >= AppConstants.paginationBatchSize;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ==================== ANALYTICS ====================

  Future<Map<String, double>> getMonthlyExpenseSummary(
    DateTime month,
  ) async {
    return DatabaseService.instance.getMonthlyExpenseSummary(month);
  }

  // Calculate totals directly from database to ensure accuracy
  Future<double> getTotalFuelExpensesFromDb() async {
    final db = await DatabaseService.instance.database;
    final result = await db
        .rawQuery('SELECT SUM(amount_paid) as total FROM fuel_expenses');
    if (result.isNotEmpty && result[0]['total'] != null) {
      return (result[0]['total'] as num).toDouble();
    }
    return 0.0;
  }

  Future<double> getTotalGeneralExpensesFromDb() async {
    final db = await DatabaseService.instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM general_expenses WHERE is_household_expense = 0',
    );
    if (result.isNotEmpty && result[0]['total'] != null) {
      return (result[0]['total'] as num).toDouble();
    }
    return 0.0;
  }

  Future<double> getTotalHouseholdExpensesFromDb() async {
    final db = await DatabaseService.instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM general_expenses WHERE is_household_expense = 1',
    );
    if (result.isNotEmpty && result[0]['total'] != null) {
      return (result[0]['total'] as num).toDouble();
    }
    return 0.0;
  }

  // Legacy methods using cached data (less reliable)
  double getTotalFuelExpenses() {
    return _fuelExpenses.fold(0.0, (sum, expense) => sum + expense.amountPaid);
  }

  double getTotalGeneralExpenses() {
    return _generalExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  double getTotalHouseholdExpenses() {
    return _householdExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  Map<ExpenseCategory, double> getExpensesByCategory() {
    final Map<ExpenseCategory, double> categoryExpenses = {};

    for (final expense in _generalExpenses) {
      categoryExpenses[expense.category] =
          (categoryExpenses[expense.category] ?? 0.0) + expense.amount;
    }

    return categoryExpenses;
  }

  // ==================== FAMILY MEMBERS ====================

  Future<void> loadFamilyMembers() async {
    try {
      // Ensure default members exist
      await DatabaseService.instance.seedDefaultFamilyMembers();
      _familyMembers = await DatabaseService.instance.getFamilyMembers();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading family members: $e');
    }
  }

  Future<FamilyMember> createFamilyMember(FamilyMember member) async {
    final created = await DatabaseService.instance.createFamilyMember(member);
    _familyMembers.add(created);
    notifyListeners();
    return created;
  }

  Future<void> updateFamilyMember(FamilyMember member) async {
    await DatabaseService.instance.updateFamilyMember(member);
    final index = _familyMembers.indexWhere((m) => m.id == member.id);
    if (index != -1) {
      _familyMembers[index] = member;
      notifyListeners();
    }
  }

  Future<void> deleteFamilyMember(int memberId) async {
    await DatabaseService.instance.deleteFamilyMember(memberId);
    _familyMembers.removeWhere((m) => m.id == memberId);
    notifyListeners();
  }

  // ==================== V2: RECURRING EXPENSES ====================

  List<RecurringExpense> _recurringExpenses = [];
  List<RecurringExpense> get recurringExpenses => _recurringExpenses;

  Future<void> loadRecurringExpenses() async {
    try {
      final result = await DatabaseService.instance.getRecurringExpenses();
      _recurringExpenses = result.whereType<RecurringExpense>().toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading recurring expenses: $e');
    }
  }

  Future<void> createRecurringExpense(RecurringExpense recurring) async {
    await DatabaseService.instance.createRecurringExpense(recurring);
    _recurringExpenses.add(recurring);
    notifyListeners();
  }

  Future<void> updateRecurringExpense(RecurringExpense recurring) async {
    await DatabaseService.instance.updateRecurringExpense(recurring);
    final index = _recurringExpenses.indexWhere((r) => r.id == recurring.id);
    if (index != -1) {
      _recurringExpenses[index] = recurring;
      notifyListeners();
    }
  }

  Future<void> deleteRecurringExpense(String id) async {
    await DatabaseService.instance.deleteRecurringExpense(id);
    _recurringExpenses.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  Future<void> toggleRecurringExpense(String id) async {
    final index = _recurringExpenses.indexWhere((r) => r.id == id);
    if (index != -1) {
      final RecurringExpense recurring = _recurringExpenses[index];
      final updated = recurring.copyWith(isActive: !recurring.isActive);
      await updateRecurringExpense(updated);
    }
  }

  // ==================== DATABASE SYNCHRONIZATION ====================

  /// Remove duplicate expenses and verify data consistency
  Future<void> syncDatabaseAndRemoveDuplicates() async {
    try {
      debugPrint('Starting database synchronization...');

      // Remove duplicates
      final removedCount =
          await DatabaseService.instance.removeDuplicateExpenses();
      debugPrint('Removed $removedCount duplicate expenses');

      // Get database stats
      final stats = await DatabaseService.instance.getDatabaseStats();
      debugPrint('Database stats: $stats');

      // Reload all expenses to ensure consistency
      await loadFuelExpenses(refresh: true);
      await loadGeneralExpenses(refresh: true);
      await loadHouseholdExpenses(refresh: true);

      debugPrint('Database synchronization completed successfully');
    } catch (e) {
      debugPrint('Error during database synchronization: $e');
      rethrow;
    }
  }

  /// Verify totals match between database and loaded lists
  Future<bool> verifyTotalConsistency() async {
    try {
      final dbFuelTotal = await getTotalFuelExpensesFromDb();
      final cachedFuelTotal = getTotalFuelExpenses();

      final dbGeneralTotal = await getTotalGeneralExpensesFromDb();
      final cachedGeneralTotal = getTotalGeneralExpenses();

      final dbHouseholdTotal = await getTotalHouseholdExpensesFromDb();
      final cachedHouseholdTotal = getTotalHouseholdExpenses();

      final fuelMatch = (dbFuelTotal - cachedFuelTotal).abs() < 0.01;
      final generalMatch = (dbGeneralTotal - cachedGeneralTotal).abs() < 0.01;
      final householdMatch =
          (dbHouseholdTotal - cachedHouseholdTotal).abs() < 0.01;

      debugPrint('''
        Fuel Total: DB=$dbFuelTotal, Cached=$cachedFuelTotal, Match=$fuelMatch
        General Total: DB=$dbGeneralTotal, Cached=$cachedGeneralTotal, Match=$generalMatch
        Household Total: DB=$dbHouseholdTotal, Cached=$cachedHouseholdTotal, Match=$householdMatch
      ''');

      return fuelMatch && generalMatch && householdMatch;
    } catch (e) {
      debugPrint('Error verifying consistency: $e');
      return false;
    }
  }

  // ==================== V2: PAYMENTS ====================

  List<Payment> _payments = [];
  List<Payment> get payments => _payments;

  Future<void> loadPayments() async {
    try {
      final result = await DatabaseService.instance.getPayments();
      _payments = result.whereType<Payment>().toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading payments: $e');
    }
  }

  Future<void> createPayment(Payment payment) async {
    await DatabaseService.instance.createPayment(payment);
    _payments.add(payment);
    notifyListeners();
  }

  Future<void> updatePayment(Payment payment) async {
    await DatabaseService.instance.updatePayment(payment);
    final index = _payments.indexWhere((p) => p.id == payment.id);
    if (index != -1) {
      _payments[index] = payment;
      notifyListeners();
    }
  }

  Future<void> deletePayment(String id) async {
    await DatabaseService.instance.deletePayment(id);
    _payments.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  // ==================== FUEL EFFICIENCY CALCULATIONS ====================

  /// Calculate average fuel consumption (km/liter) for a vehicle based on full tank fill-ups
  Future<double?> calculateFuelEfficiencyAverage(int vehicleId) async {
    try {
      final fuelExpenses =
          await DatabaseService.instance.getFuelExpensesByVehicle(vehicleId);

      // Filter only full tank fill-ups
      final fullTankFillups = fuelExpenses.where((e) => e.isFullTank).toList();

      if (fullTankFillups.length < 2) {
        return null; // Need at least 2 full tank fill-ups to calculate efficiency
      }

      // Sort by date to calculate distance between fill-ups
      fullTankFillups.sort((a, b) => a.date.compareTo(b.date));

      double totalDistance = 0;
      double totalLiters = 0;

      // Calculate efficiency between consecutive full tank fill-ups
      for (int i = 1; i < fullTankFillups.length; i++) {
        final current = fullTankFillups[i];
        final previous = fullTankFillups[i - 1];

        final distance = current.odometerReading - previous.odometerReading;
        if (distance > 0) {
          totalDistance += distance;
          totalLiters += current.liters;
        }
      }

      if (totalLiters <= 0) return null;

      final efficiency = totalDistance / totalLiters;
      return efficiency > 0 ? efficiency : null;
    } catch (e) {
      debugPrint('Error calculating fuel efficiency: $e');
      return null;
    }
  }

  /// Get the last fuel efficiency value for a vehicle
  Future<double?> getLastFuelEfficiency(int vehicleId) async {
    try {
      final fuelExpenses =
          await DatabaseService.instance.getFuelExpensesByVehicle(vehicleId);
      final fullTankFillups = fuelExpenses
          .where((e) => e.isFullTank && e.fuelEfficiency != null)
          .toList();

      if (fullTankFillups.isEmpty) return null;

      fullTankFillups.sort((a, b) => b.date.compareTo(a.date));
      return fullTankFillups.first.fuelEfficiency;
    } catch (e) {
      debugPrint('Error getting last fuel efficiency: $e');
      return null;
    }
  }

  /// Calculate cost per liter for a fuel expense
  double calculateCostPerLiter(double amountPaid, double liters) {
    if (liters <= 0) return 0;
    return amountPaid / liters;
  }

  /// Get average cost per liter for a vehicle
  Future<double?> getAverageCostPerLiter(int vehicleId) async {
    try {
      final fuelExpenses =
          await DatabaseService.instance.getFuelExpensesByVehicle(vehicleId);

      if (fuelExpenses.isEmpty) return null;

      double totalCost = 0;
      double totalLiters = 0;

      for (final expense in fuelExpenses) {
        totalCost += expense.amountPaid;
        totalLiters += expense.liters;
      }

      if (totalLiters <= 0) return null;
      return totalCost / totalLiters;
    } catch (e) {
      debugPrint('Error calculating average cost per liter: $e');
      return null;
    }
  }

  /// Update a fuel expense with new efficiency data
  Future<void> updateFuelEfficiencyData(
    FuelExpense expense, {
    required double costPerLiter,
    double? fuelEfficiency,
    String? deviceId,
  }) async {
    final updated = expense.copyWith(
      costPerLiter: costPerLiter,
      fuelEfficiency: fuelEfficiency,
    );

    await updateFuelExpense(updated, deviceId ?? expense.deviceId);
  }
}
