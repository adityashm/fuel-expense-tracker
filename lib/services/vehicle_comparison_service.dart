import '../models/vehicle.dart';
import '../models/vehicle_comparison.dart';
import 'database_service.dart';

class VehicleComparisonService {
  VehicleComparisonService._init();
  static final VehicleComparisonService instance =
      VehicleComparisonService._init();
  final _dbService = DatabaseService.instance;

  // ==================== MAIN COMPARISON ====================

  /// Get comprehensive comparison for all vehicles
  Future<FamilyComparison> getFamilyComparison(ComparisonPeriod period) async {
    final dates = _getPeriodDates(period);
    final db = await _dbService.database;

    final vehiclesData = await db.query('vehicles', orderBy: 'name ASC');
    final vehicles = vehiclesData.map((map) => Vehicle.fromMap(map)).toList();

    final comparisons = <VehicleComparison>[];
    for (final vehicle in vehicles) {
      final comparison =
          await getVehicleComparison(vehicle, dates['start']!, dates['end']!);
      comparisons.add(comparison);
    }

    return FamilyComparison(
      vehicles: comparisons,
      startDate: dates['start']!,
      endDate: dates['end']!,
      period: period,
    );
  }

  /// Get detailed comparison for a single vehicle
  Future<VehicleComparison> getVehicleComparison(
    Vehicle vehicle,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Calculate total distance from odometer changes
    final totalDistance =
        await _calculateTotalDistance(vehicle.id!, startDate, endDate);

    // Get all expense costs
    final fuelCost = await _getFuelCost(vehicle.id!, startDate, endDate);
    final chargingCost =
        await _getChargingCost(vehicle.id!, startDate, endDate);
    final maintenanceCost =
        await _getMaintenanceCost(vehicle.id!, startDate, endDate);
    final generalCost = await _getGeneralCost(vehicle.id!, startDate, endDate);

    final totalCost = fuelCost + chargingCost + maintenanceCost + generalCost;

    // Calculate trips
    final totalTrips = await _getTotalTrips(vehicle.id!, startDate, endDate);

    // Calculate per-unit metrics
    final costPerKm = totalDistance > 0 ? totalCost / totalDistance : 0.0;

    final months = _getMonthsBetween(startDate, endDate);
    final costPerMonth = months > 0 ? totalCost / months : totalCost;
    final distancePerMonth =
        months > 0 ? totalDistance / months : totalDistance;

    final projectedAnnualCost = costPerMonth * 12;

    // Calculate efficiency
    double? fuelEfficiency;
    double? chargingEfficiency;
    double? avgKwhPerCharge;

    if (vehicle.isElectric) {
      chargingEfficiency =
          await _calculateChargingEfficiency(vehicle.id!, startDate, endDate);
      avgKwhPerCharge =
          await _calculateAvgKwhPerCharge(vehicle.id!, startDate, endDate);
    } else {
      fuelEfficiency =
          await _calculateFuelEfficiency(vehicle.id!, startDate, endDate);
    }

    // Calculate cost breakdown percentages
    final fuelCostPercentage =
        totalCost > 0 ? (fuelCost / totalCost) * 100 : 0.0;
    final maintenanceCostPercentage =
        totalCost > 0 ? (maintenanceCost / totalCost) * 100 : 0.0;
    final otherCostPercentage =
        100 - fuelCostPercentage - maintenanceCostPercentage;

    return VehicleComparison(
      vehicle: vehicle,
      startDate: startDate,
      endDate: endDate,
      totalDistance: totalDistance,
      totalTrips: totalTrips,
      avgTripDistance: totalTrips > 0 ? totalDistance / totalTrips : 0.0,
      distancePerMonth: distancePerMonth,
      totalCost: totalCost,
      fuelCost: fuelCost,
      chargingCost: chargingCost,
      maintenanceCost: maintenanceCost,
      generalCost: generalCost,
      costPerKm: costPerKm,
      costPerMonth: costPerMonth,
      projectedAnnualCost: projectedAnnualCost,
      fuelEfficiency: fuelEfficiency,
      chargingEfficiency: chargingEfficiency,
      avgKwhPerCharge: avgKwhPerCharge,
      fuelCostPercentage: fuelCostPercentage,
      maintenanceCostPercentage: maintenanceCostPercentage,
      otherCostPercentage: otherCostPercentage,
    );
  }

  // ==================== USAGE PATTERNS ====================

  /// Analyze usage patterns over time
  Future<UsagePattern> getUsagePattern(
    Vehicle vehicle,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Get monthly data
    final monthlyDistance = <int, double>{};
    final monthlyCost = <int, double>{};
    final monthlyTrips = <int, int>{};

    var currentDate = DateTime(startDate.year, startDate.month);
    final endMonth = DateTime(endDate.year, endDate.month);

    while (currentDate.isBefore(endMonth) ||
        currentDate.isAtSameMomentAs(endMonth)) {
      final monthStart = currentDate;
      final monthEnd = DateTime(currentDate.year, currentDate.month + 1, 0);

      final distance =
          await _calculateTotalDistance(vehicle.id!, monthStart, monthEnd);
      final fuelCost = await _getFuelCost(vehicle.id!, monthStart, monthEnd);
      final chargingCost =
          await _getChargingCost(vehicle.id!, monthStart, monthEnd);
      final maintenanceCost =
          await _getMaintenanceCost(vehicle.id!, monthStart, monthEnd);
      final generalCost =
          await _getGeneralCost(vehicle.id!, monthStart, monthEnd);
      final totalCost = fuelCost + chargingCost + maintenanceCost + generalCost;
      final trips = await _getTotalTrips(vehicle.id!, monthStart, monthEnd);

      monthlyDistance[currentDate.month] = distance;
      monthlyCost[currentDate.month] = totalCost;
      monthlyTrips[currentDate.month] = trips;

      currentDate = DateTime(currentDate.year, currentDate.month + 1);
    }

    // Find peak and lowest months
    var peakMonth = 1;
    var lowestMonth = 1;
    var maxDistance = 0.0;
    var minDistance = double.infinity;

    monthlyDistance.forEach((month, distance) {
      if (distance > maxDistance) {
        maxDistance = distance;
        peakMonth = month;
      }
      if (distance < minDistance && distance > 0) {
        minDistance = distance;
        lowestMonth = month;
      }
    });

    final avgMonthlyDistance = monthlyDistance.values.isNotEmpty
        ? monthlyDistance.values.reduce((a, b) => a + b) /
            monthlyDistance.length
        : 0.0;

    final avgMonthlyCost = monthlyCost.values.isNotEmpty
        ? monthlyCost.values.reduce((a, b) => a + b) / monthlyCost.length
        : 0.0;

    return UsagePattern(
      vehicle: vehicle,
      monthlyDistance: monthlyDistance,
      monthlyCost: monthlyCost,
      monthlyTrips: monthlyTrips,
      peakUsageMonth: peakMonth,
      lowestUsageMonth: lowestMonth,
      avgMonthlyDistance: avgMonthlyDistance,
      avgMonthlyCost: avgMonthlyCost,
    );
  }

  // ==================== RECOMMENDATIONS ====================

  /// Generate smart recommendations based on comparison
  Future<List<VehicleRecommendation>> generateRecommendations(
    FamilyComparison comparison,
  ) async {
    if (comparison.vehicles.isEmpty) {
      return const [];
    }
    final recommendations = <VehicleRecommendation>[];

    // Find most and least economical
    final mostEconomical = comparison.mostEconomical;
    final leastEconomical = comparison.leastEconomical;

    // Recommendation 1: Switch for short trips
    if (comparison.vehicles.length >= 2) {
      final evVehicle = comparison.vehicles.firstWhere(
        (v) => v.isElectric,
        orElse: () => mostEconomical,
      );

      if (evVehicle.costPerKm < mostEconomical.costPerKm * 0.5) {
        // Assume 30% of trips could be switched
        final avgMonthlyDistance = comparison.vehicles
            .where((v) => !v.isElectric)
            .map((v) => v.distancePerMonth)
            .reduce((a, b) => a + b);

        final switchableDistance = avgMonthlyDistance * 0.3;
        final currentCost = leastEconomical.costPerKm * switchableDistance;
        final newCost = evVehicle.costPerKm * switchableDistance;
        final savings = currentCost - newCost;

        if (savings > 100) {
          recommendations.add(
            VehicleRecommendation(
              title: 'Use ${evVehicle.vehicle.name} for short trips',
              description:
                  'Switch 30% of trips to ${evVehicle.vehicle.name} - it\'s ${((1 - (evVehicle.costPerKm / leastEconomical.costPerKm)) * 100).toStringAsFixed(0)}% cheaper per km',
              potentialSavings: savings,
              type: RecommendationType.switchVehicle,
              priority: 5,
            ),
          );
        }
      }
    }

    // Recommendation 2: High cost vehicle warning
    if (leastEconomical.costPerKm > comparison.avgFamilyCostPerKm * 1.5) {
      recommendations.add(
        VehicleRecommendation(
          title: '${leastEconomical.vehicle.name} is expensive to run',
          description:
              'At ₹${leastEconomical.costPerKm.toStringAsFixed(2)}/km, it\'s ${(leastEconomical.costPerKm / mostEconomical.costPerKm).toStringAsFixed(1)}x more expensive than ${mostEconomical.vehicle.name}',
          potentialSavings: 0.0,
          type: RecommendationType.general,
          priority: 4,
        ),
      );
    }

    // Recommendation 3: Most economical highlight
    recommendations.add(
      VehicleRecommendation(
        title: 'Most economical: ${mostEconomical.vehicle.name}',
        description:
            'At ₹${mostEconomical.costPerKm.toStringAsFixed(2)}/km, this is your cheapest vehicle to run',
        potentialSavings: 0.0,
        type: RecommendationType.general,
        priority: 3,
      ),
    );

    // Recommendation 4: High maintenance cost warning
    for (final vehicle in comparison.vehicles) {
      if (vehicle.maintenanceCostPercentage > 30) {
        recommendations.add(
          VehicleRecommendation(
            title: 'High maintenance on ${vehicle.vehicle.name}',
            description:
                'Maintenance is ${vehicle.maintenanceCostPercentage.toStringAsFixed(0)}% of total costs - check for recurring issues',
            potentialSavings: 0.0,
            type: RecommendationType.maintenance,
            priority: 4,
          ),
        );
      }
    }

    // Sort by priority
    recommendations.sort((a, b) => b.priority.compareTo(a.priority));

    return recommendations;
  }

  // ==================== WHAT-IF SCENARIOS ====================

  /// Calculate what-if scenario for switching vehicles
  Future<WhatIfScenario> calculateWhatIfScenario({
    required FamilyComparison comparison,
    required int fromVehicleId,
    required int toVehicleId,
    required double percentageToSwitch, // 0.0 to 1.0
  }) async {
    final fromVehicle = comparison.getVehicleComparison(fromVehicleId);
    final toVehicle = comparison.getVehicleComparison(toVehicleId);

    final switchableDistance =
        fromVehicle.distancePerMonth * percentageToSwitch;
    final currentCost = fromVehicle.costPerKm * switchableDistance;
    final projectedCost = toVehicle.costPerKm * switchableDistance;
    final savings = currentCost - projectedCost;
    final savingsPercentage =
        currentCost > 0 ? (savings / currentCost) * 100 : 0.0;

    return WhatIfScenario(
      title:
          'Switch ${(percentageToSwitch * 100).toStringAsFixed(0)}% of trips',
      description:
          'Use ${toVehicle.vehicle.name} instead of ${fromVehicle.vehicle.name} for ${(percentageToSwitch * 100).toStringAsFixed(0)}% of trips',
      currentCost: currentCost,
      projectedCost: projectedCost,
      savings: savings,
      savingsPercentage: savingsPercentage,
    );
  }

  // ==================== EV VS PETROL ====================

  /// Compare electric vs petrol/diesel vehicles
  Future<EVvsPetrolComparison?> getEVvsPetrolComparison(
    FamilyComparison comparison,
  ) async {
    if (comparison.vehicles.isEmpty) {
      return null;
    }
    final evVehicle = comparison.vehicles.firstWhere(
      (v) => v.isElectric,
      orElse: () => comparison.vehicles.first,
    );

    if (!evVehicle.isElectric) return null;

    final petrolVehicle = comparison.vehicles.firstWhere(
      (v) => !v.isElectric,
      orElse: () => comparison.vehicles.last,
    );

    if (petrolVehicle.isElectric) return null;

    final savingsPerKm = petrolVehicle.costPerKm - evVehicle.costPerKm;
    final savingsPercentage = (savingsPerKm / petrolVehicle.costPerKm) * 100;
    final monthlySavings = petrolVehicle.costPerMonth - evVehicle.costPerMonth;
    final annualSavings = monthlySavings * 12;
    final lifetimeSavings = annualSavings * 5;

    return EVvsPetrolComparison(
      electricVehicle: evVehicle,
      petrolVehicle: petrolVehicle,
      electricCostPerKm: evVehicle.costPerKm,
      petrolCostPerKm: petrolVehicle.costPerKm,
      savingsPerKm: savingsPerKm,
      savingsPercentage: savingsPercentage,
      monthlyElectricCost: evVehicle.costPerMonth,
      monthlyPetrolCost: petrolVehicle.costPerMonth,
      monthlySavings: monthlySavings,
      annualSavings: annualSavings,
      lifetimeSavings: lifetimeSavings,
    );
  }

  // ==================== HELPER METHODS ====================

  Map<String, DateTime> _getPeriodDates(ComparisonPeriod period) {
    final now = DateTime.now();
    DateTime startDate;
    final endDate = now;

    switch (period) {
      case ComparisonPeriod.thisMonth:
        startDate = DateTime(now.year, now.month);
        break;
      case ComparisonPeriod.last3Months:
        startDate = DateTime(now.year, now.month - 3);
        break;
      case ComparisonPeriod.last6Months:
        startDate = DateTime(now.year, now.month - 6);
        break;
      case ComparisonPeriod.thisYear:
        startDate = DateTime(now.year);
        break;
      case ComparisonPeriod.allTime:
        startDate = DateTime(2020); // Arbitrary far past date
        break;
    }

    return {'start': startDate, 'end': endDate};
  }

  int _getMonthsBetween(DateTime start, DateTime end) {
    return ((end.year - start.year) * 12 + end.month - start.month).abs() + 1;
  }

  Future<double> _calculateTotalDistance(
    int vehicleId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbService.database;

    // Get odometer readings from fuel expenses
    final fuelExpenses = await db.query(
      'fuel_expenses',
      where: 'vehicle_id = ? AND date >= ? AND date <= ?',
      whereArgs: [vehicleId, start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date ASC',
    );

    if (fuelExpenses.isEmpty) return 0.0;

    final firstOdometer =
        (fuelExpenses.first['odometer_reading'] as num).toDouble();
    final lastOdometer =
        (fuelExpenses.last['odometer_reading'] as num).toDouble();

    return (lastOdometer - firstOdometer).abs();
  }

  Future<double> _getFuelCost(
    int vehicleId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      '''
      SELECT SUM(amount_paid) as total
      FROM fuel_expenses
      WHERE vehicle_id = ? AND date >= ? AND date <= ?
    ''',
      [vehicleId, start.toIso8601String(), end.toIso8601String()],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<double> _getChargingCost(
    int vehicleId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      '''
      SELECT SUM(total_cost) as total
      FROM charging_expenses
      WHERE vehicle_id = ? AND date >= ? AND date <= ?
    ''',
      [vehicleId, start.toIso8601String(), end.toIso8601String()],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<double> _getMaintenanceCost(
    int vehicleId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      '''
      SELECT SUM(cost) as total
      FROM maintenance_records
      WHERE vehicle_id = ? AND date >= ? AND date <= ?
    ''',
      [vehicleId, start.toIso8601String(), end.toIso8601String()],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<double> _getGeneralCost(
    int vehicleId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      '''
      SELECT SUM(amount) as total
      FROM general_expenses
      WHERE vehicle_id = ? AND date >= ? AND date <= ?
    ''',
      [vehicleId, start.toIso8601String(), end.toIso8601String()],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<int> _getTotalTrips(
    int vehicleId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbService.database;

    // Count fuel fill-ups as proxy for trips
    final fuelTrips = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM fuel_expenses
      WHERE vehicle_id = ? AND date >= ? AND date <= ?
    ''',
      [vehicleId, start.toIso8601String(), end.toIso8601String()],
    );

    return (fuelTrips.first['count'] as int?) ?? 0;
  }

  Future<double?> _calculateFuelEfficiency(
    int vehicleId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbService.database;

    final expenses = await db.query(
      'fuel_expenses',
      where: 'vehicle_id = ? AND date >= ? AND date <= ?',
      whereArgs: [vehicleId, start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date ASC',
    );

    if (expenses.length < 2) return null;

    double totalDistance = 0;
    double totalLiters = 0;

    for (int i = 1; i < expenses.length; i++) {
      final prevOdometer =
          (expenses[i - 1]['odometer_reading'] as num).toDouble();
      final currOdometer = (expenses[i]['odometer_reading'] as num).toDouble();
      final liters = (expenses[i - 1]['liters'] as num).toDouble();

      final distance = currOdometer - prevOdometer;
      if (distance > 0 && liters > 0) {
        totalDistance += distance;
        totalLiters += liters;
      }
    }

    return totalLiters > 0 ? totalDistance / totalLiters : null;
  }

  Future<double?> _calculateChargingEfficiency(
    int vehicleId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbService.database;

    final sessions = await db.query(
      'charging_expenses',
      where: 'vehicle_id = ? AND date >= ? AND date <= ?',
      whereArgs: [vehicleId, start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date ASC',
    );

    if (sessions.length < 2) return null;

    double totalDistance = 0;
    double totalKwh = 0;

    for (int i = 1; i < sessions.length; i++) {
      final prevOdometer =
          (sessions[i - 1]['odometer_reading'] as num).toDouble();
      final currOdometer = (sessions[i]['odometer_reading'] as num).toDouble();
      final kwh = (sessions[i - 1]['kwh_charged'] as num).toDouble();

      final distance = currOdometer - prevOdometer;
      if (distance > 0 && kwh > 0) {
        totalDistance += distance;
        totalKwh += kwh;
      }
    }

    return totalKwh > 0 ? totalDistance / totalKwh : null;
  }

  Future<double?> _calculateAvgKwhPerCharge(
    int vehicleId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbService.database;

    final result = await db.rawQuery(
      '''
      SELECT AVG(kwh_charged) as avg_kwh
      FROM charging_expenses
      WHERE vehicle_id = ? AND date >= ? AND date <= ?
    ''',
      [vehicleId, start.toIso8601String(), end.toIso8601String()],
    );

    return (result.first['avg_kwh'] as num?)?.toDouble();
  }
}
