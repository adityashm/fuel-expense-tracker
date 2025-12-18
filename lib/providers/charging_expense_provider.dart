import 'package:flutter/foundation.dart';
import '../models/charging_expense.dart';
import '../services/database_service.dart';

class ChargingExpenseProvider with ChangeNotifier {
  List<ChargingExpense> _chargingExpenses = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ChargingExpense> get chargingExpenses => _chargingExpenses;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Get charging expenses for a specific vehicle
  List<ChargingExpense> getExpensesByVehicle(int vehicleId) {
    return _chargingExpenses.where((e) => e.vehicleId == vehicleId).toList();
  }

  // Get charging expenses by location type
  List<ChargingExpense> getExpensesByLocation(
    int vehicleId,
    ChargingLocationType location,
  ) {
    return _chargingExpenses
        .where((e) => e.vehicleId == vehicleId && e.locationType == location)
        .toList();
  }

  // Get charging expenses by date range
  List<ChargingExpense> getExpensesByDateRange(
    int vehicleId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return _chargingExpenses
        .where(
          (e) =>
              e.vehicleId == vehicleId &&
              e.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
              e.date.isBefore(endDate.add(const Duration(days: 1))),
        )
        .toList();
  }

  Future<void> loadChargingExpenses([int? vehicleId]) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = vehicleId != null
          ? await DatabaseService.instance.getChargingExpenses(vehicleId)
          : await DatabaseService.instance.getAllChargingExpenses();

      _chargingExpenses = data.map((e) => ChargingExpense.fromMap(e)).toList();
    } catch (e) {
      _errorMessage = 'Failed to load charging expenses: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ChargingExpense> createChargingExpense(ChargingExpense expense) async {
    try {
      final id =
          await DatabaseService.instance.createChargingExpense(expense.toMap());
      final created = expense.copyWith(id: id);
      _chargingExpenses.insert(0, created);
      notifyListeners();
      return created;
    } catch (e) {
      _errorMessage = 'Failed to create charging expense: $e';
      debugPrint(_errorMessage);
      rethrow;
    }
  }

  Future<void> updateChargingExpense(ChargingExpense expense) async {
    if (expense.id == null) {
      throw ArgumentError('Charging expense must have an ID to update');
    }

    try {
      await DatabaseService.instance.updateChargingExpense(
        expense.id!,
        expense.toMap(),
      );

      final index = _chargingExpenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        _chargingExpenses[index] = expense;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to update charging expense: $e';
      debugPrint(_errorMessage);
      rethrow;
    }
  }

  Future<void> deleteChargingExpense(int id) async {
    try {
      await DatabaseService.instance.deleteChargingExpense(id);
      _chargingExpenses.removeWhere((e) => e.id == id);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete charging expense: $e';
      debugPrint(_errorMessage);
      rethrow;
    }
  }

  // Get last charging expense for a vehicle
  Future<ChargingExpense?> getLastChargingExpense(int vehicleId) async {
    try {
      final data =
          await DatabaseService.instance.getLastChargingExpense(vehicleId);
      return data != null ? ChargingExpense.fromMap(data) : null;
    } catch (e) {
      debugPrint('Failed to get last charging expense: $e');
      return null;
    }
  }

  // Get EV efficiency metrics
  Future<EVEfficiencyMetrics> getEVEfficiencyMetrics(
    int vehicleId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final data = await DatabaseService.instance.getEVEfficiencyMetrics(
        vehicleId,
        startDate,
        endDate,
      );

      return EVEfficiencyMetrics(
        totalKwhCharged: (data['total_kwh'] as num).toDouble(),
        totalCost: (data['total_cost'] as num).toDouble(),
        totalKmDriven: (data['total_km'] as num).toDouble(),
        chargingCycles: data['charging_cycles'] as int,
        homeChargingCost: (data['home_cost'] as num).toDouble(),
        publicChargingCost: (data['public_cost'] as num).toDouble() +
            (data['office_cost'] as num).toDouble(),
        averageCostPerKwh: (data['avg_cost_per_kwh'] as num).toDouble(),
        periodStart: startDate,
        periodEnd: endDate,
      );
    } catch (e) {
      debugPrint('Failed to get EV efficiency metrics: $e');
      rethrow;
    }
  }

  // Get battery health data
  Future<BatteryHealthData> getBatteryHealthData(int vehicleId) async {
    try {
      final data =
          await DatabaseService.instance.getBatteryHealthData(vehicleId);

      final firstChargeStr = data['first_charge'] as String?;
      final lastChargeStr = data['last_charge'] as String?;

      final firstCharge = firstChargeStr != null
          ? DateTime.parse(firstChargeStr)
          : DateTime.now();
      final lastCharge = lastChargeStr != null
          ? DateTime.parse(lastChargeStr)
          : DateTime.now();

      final totalCycles = data['total_cycles'] as int;

      // Estimate battery health (simplified)
      // Ola S1 Pro battery rated for ~1000 cycles to 80% capacity
      final estimatedHealth = totalCycles < 1000
          ? 100.0 - (totalCycles / 1000 * 20) // Linear degradation to 80%
          : 80.0 - ((totalCycles - 1000) / 1000 * 30); // Further degradation

      return BatteryHealthData(
        totalChargingCycles: totalCycles,
        fastChargingCycles: data['fast_cycles'] as int,
        slowChargingCycles: data['slow_cycles'] as int,
        averageBatteryGainPerCycle:
            (data['avg_battery_gain'] as num).toDouble(),
        estimatedHealthPercent: estimatedHealth.clamp(50.0, 100.0),
        firstChargeDate: firstCharge,
        lastChargeDate: lastCharge,
      );
    } catch (e) {
      debugPrint('Failed to get battery health data: $e');
      rethrow;
    }
  }

  // Calculate EV vs Petrol comparison
  Future<EVVsPetrolComparison> getEVVsPetrolComparison(
    int vehicleId,
    DateTime startDate,
    DateTime endDate, {
    double petrolPrice = 105.0, // Default petrol price per liter
    double petrolMileage = 45.0, // Default bike mileage (km/l)
  }) async {
    try {
      final metrics =
          await getEVEfficiencyMetrics(vehicleId, startDate, endDate);

      final evCostPerKm = metrics.costPerKm;
      final petrolCostPerKm = petrolPrice / petrolMileage;

      final equivalentPetrolCost = metrics.totalKmDriven * petrolCostPerKm;
      final monthlySavings = equivalentPetrolCost - metrics.totalCost;

      // CO2 savings calculation
      // Average petrol bike emits ~100g CO2/km
      // EV emits ~50g CO2/km (considering power generation mix in India)
      final co2Saved = metrics.totalKmDriven * 0.05; // in kg

      return EVVsPetrolComparison(
        evCostPerKm: evCostPerKm,
        petrolCostPerKm: petrolCostPerKm,
        monthlySavings: monthlySavings,
        co2Saved: co2Saved,
        totalEvCost: metrics.totalCost,
        equivalentPetrolCost: equivalentPetrolCost,
      );
    } catch (e) {
      debugPrint('Failed to calculate EV vs Petrol comparison: $e');
      rethrow;
    }
  }

  // Calculate estimated monthly cost
  double calculateMonthlyEstimate({
    required double monthlyKwh,
    required double electricityRate,
  }) {
    return monthlyKwh * electricityRate;
  }

  // Get charging statistics
  Map<String, dynamic> getChargingStats(int vehicleId) {
    final expenses = getExpensesByVehicle(vehicleId);

    if (expenses.isEmpty) {
      return {
        'total_charges': 0,
        'total_cost': 0.0,
        'total_kwh': 0.0,
        'avg_cost_per_charge': 0.0,
        'home_charges': 0,
        'public_charges': 0,
      };
    }

    double totalCost = 0;
    double totalKwh = 0;
    int homeCharges = 0;
    int publicCharges = 0;

    for (final expense in expenses) {
      totalCost += expense.totalCost;
      totalKwh += expense.kwhCharged;

      if (expense.locationType == ChargingLocationType.home) {
        homeCharges++;
      } else {
        publicCharges++;
      }
    }

    return {
      'total_charges': expenses.length,
      'total_cost': totalCost,
      'total_kwh': totalKwh,
      'avg_cost_per_charge': totalCost / expenses.length,
      'home_charges': homeCharges,
      'public_charges': publicCharges,
    };
  }
}
