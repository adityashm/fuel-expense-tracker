import '../models/vehicle.dart';

enum ComparisonPeriod {
  thisMonth,
  last3Months,
  last6Months,
  thisYear,
  allTime,
}

enum CostCategory {
  fuel,
  charging,
  maintenance,
  general,
}

class VehicleComparison {
  VehicleComparison({
    required this.vehicle,
    required this.startDate,
    required this.endDate,
    required this.totalDistance,
    required this.totalTrips,
    required this.avgTripDistance,
    required this.distancePerMonth,
    required this.totalCost,
    required this.fuelCost,
    required this.chargingCost,
    required this.maintenanceCost,
    required this.generalCost,
    required this.costPerKm,
    required this.costPerMonth,
    required this.projectedAnnualCost,
    this.fuelEfficiency,
    this.chargingEfficiency,
    this.avgKwhPerCharge,
    required this.fuelCostPercentage,
    required this.maintenanceCostPercentage,
    required this.otherCostPercentage,
  });
  final Vehicle vehicle;
  final DateTime startDate;
  final DateTime endDate;

  // Distance & Usage
  final double totalDistance;
  final int totalTrips;
  final double avgTripDistance;
  final double distancePerMonth;

  // Costs
  final double totalCost;
  final double fuelCost;
  final double chargingCost;
  final double maintenanceCost;
  final double generalCost;
  final double costPerKm;
  final double costPerMonth;
  final double projectedAnnualCost;

  // Efficiency
  final double? fuelEfficiency; // km/liter for petrol/diesel
  final double? chargingEfficiency; // km/kWh for electric
  final double? avgKwhPerCharge; // For EVs

  // Cost breakdown percentages
  final double fuelCostPercentage;
  final double maintenanceCostPercentage;
  final double otherCostPercentage;

  bool get isElectric => vehicle.isElectric;

  String getEfficiencyDisplay() {
    if (isElectric && chargingEfficiency != null) {
      return '${chargingEfficiency!.toStringAsFixed(1)} km/kWh';
    } else if (fuelEfficiency != null) {
      return '${fuelEfficiency!.toStringAsFixed(1)} km/L';
    }
    return 'N/A';
  }

  Map<CostCategory, double> getCostBreakdown() {
    return {
      CostCategory.fuel: fuelCost,
      CostCategory.charging: chargingCost,
      CostCategory.maintenance: maintenanceCost,
      CostCategory.general: generalCost,
    };
  }
}

class FamilyComparison {
  FamilyComparison({
    required this.vehicles,
    required this.startDate,
    required this.endDate,
    required this.period,
  });
  final List<VehicleComparison> vehicles;
  final DateTime startDate;
  final DateTime endDate;
  final ComparisonPeriod period;

  // Family totals
  double get totalFamilyCost => vehicles.fold(0, (sum, v) => sum + v.totalCost);
  double get totalFamilyDistance =>
      vehicles.fold(0, (sum, v) => sum + v.totalDistance);
  double get avgFamilyCostPerKm =>
      totalFamilyDistance > 0 ? totalFamilyCost / totalFamilyDistance : 0;

  // Most/Least economical
  VehicleComparison get mostEconomical {
    return vehicles.reduce((a, b) => a.costPerKm < b.costPerKm ? a : b);
  }

  VehicleComparison get leastEconomical {
    return vehicles.reduce((a, b) => a.costPerKm > b.costPerKm ? a : b);
  }

  // Most/Least used
  VehicleComparison get mostUsed {
    return vehicles.reduce((a, b) => a.totalDistance > b.totalDistance ? a : b);
  }

  VehicleComparison get leastUsed {
    return vehicles.reduce((a, b) => a.totalDistance < b.totalDistance ? a : b);
  }

  // Share of expenses
  Map<Vehicle, double> getExpenseShare() {
    final total = totalFamilyCost;
    if (total == 0) return {};

    return Map.fromEntries(
      vehicles.map((v) => MapEntry(v.vehicle, (v.totalCost / total) * 100)),
    );
  }

  // Get comparison for specific vehicle
  VehicleComparison getVehicleComparison(int vehicleId) {
    return vehicles.firstWhere((v) => v.vehicle.id == vehicleId);
  }

  // Savings potential
  double calculateSavingsIfSwitched(
    VehicleComparison from,
    VehicleComparison to,
    double distanceToSwitch,
  ) {
    final currentCost = from.costPerKm * distanceToSwitch;
    final newCost = to.costPerKm * distanceToSwitch;
    return currentCost - newCost;
  }
}

class VehicleRecommendation {
  // 1-5, 5 being highest

  VehicleRecommendation({
    required this.title,
    required this.description,
    required this.potentialSavings,
    required this.type,
    required this.priority,
  });
  final String title;
  final String description;
  final double potentialSavings;
  final RecommendationType type;
  final int priority;
}

enum RecommendationType {
  switchVehicle,
  reduceUsage,
  maintenance,
  efficiency,
  general,
}

class UsagePattern {
  UsagePattern({
    required this.vehicle,
    required this.monthlyDistance,
    required this.monthlyCost,
    required this.monthlyTrips,
    required this.peakUsageMonth,
    required this.lowestUsageMonth,
    required this.avgMonthlyDistance,
    required this.avgMonthlyCost,
  });
  final Vehicle vehicle;
  final Map<int, double> monthlyDistance; // month -> distance
  final Map<int, double> monthlyCost; // month -> cost
  final Map<int, int> monthlyTrips; // month -> trip count

  final int peakUsageMonth;
  final int lowestUsageMonth;
  final double avgMonthlyDistance;
  final double avgMonthlyCost;

  String getPeakMonthName() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[peakUsageMonth - 1];
  }

  String getLowestMonthName() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[lowestUsageMonth - 1];
  }
}

class CostTrendData {
  // vehicleId -> costs over time

  CostTrendData({
    required this.dates,
    required this.vehicleCosts,
  });
  final List<DateTime> dates;
  final Map<int, List<double>> vehicleCosts;
}

class WhatIfScenario {
  WhatIfScenario({
    required this.title,
    required this.description,
    required this.currentCost,
    required this.projectedCost,
    required this.savings,
    required this.savingsPercentage,
  });
  final String title;
  final String description;
  final double currentCost;
  final double projectedCost;
  final double savings;
  final double savingsPercentage;

  String getSavingsDisplay() {
    if (savings > 0) {
      return 'Save ₹${savings.toStringAsFixed(0)} (${savingsPercentage.toStringAsFixed(0)}%)';
    } else {
      return 'Costs ₹${(-savings).toStringAsFixed(0)} more (${(-savingsPercentage).toStringAsFixed(0)}%)';
    }
  }
}

class EVvsPetrolComparison {
  // 5 years projection

  EVvsPetrolComparison({
    required this.electricVehicle,
    required this.petrolVehicle,
    required this.electricCostPerKm,
    required this.petrolCostPerKm,
    required this.savingsPerKm,
    required this.savingsPercentage,
    required this.monthlyElectricCost,
    required this.monthlyPetrolCost,
    required this.monthlySavings,
    required this.annualSavings,
    required this.lifetimeSavings,
  });
  final VehicleComparison electricVehicle;
  final VehicleComparison petrolVehicle;

  final double electricCostPerKm;
  final double petrolCostPerKm;
  final double savingsPerKm;
  final double savingsPercentage;

  final double monthlyElectricCost;
  final double monthlyPetrolCost;
  final double monthlySavings;

  final double annualSavings;
  final double lifetimeSavings;

  String getComparisonSummary() {
    return '${electricVehicle.vehicle.name} is ${savingsPercentage.toStringAsFixed(0)}% cheaper than ${petrolVehicle.vehicle.name}';
  }
}
