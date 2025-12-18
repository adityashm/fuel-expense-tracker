import 'package:flutter/foundation.dart';
import '../models/budget.dart';
import '../models/vehicle.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class BudgetService {
  BudgetService._init();
  static final BudgetService instance = BudgetService._init();

  /// Calculate budget status for a vehicle
  Future<BudgetStatus?> getBudgetStatus(
    Vehicle vehicle, {
    DateTime? forMonth,
  }) async {
    if (vehicle.monthlyBudget == null || vehicle.monthlyBudget! <= 0) {
      return null;
    }

    final month = forMonth ?? DateTime.now();
    final spentResult =
        await DatabaseService.instance.getVehicleSpendingForMonth(
      vehicle.id!,
      month,
    );
    final spent = spentResult.toDouble();

    final budgetAmount = vehicle.monthlyBudget!.toDouble();
    final remaining = budgetAmount - spent;
    final percentageUsed = (spent / budgetAmount) * 100;

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final currentDay = month.day;
    final daysRemaining = daysInMonth - currentDay;

    final dailyBudgetRemaining =
        daysRemaining > 0 ? remaining / daysRemaining : 0.0;

    // Calculate projected spending
    final daysElapsed = currentDay;
    final dailySpendRate = daysElapsed > 0 ? spent / daysElapsed : 0.0;
    final projectedSpending = dailySpendRate * daysInMonth;

    // Determine alert level
    final alertLevel = _getAlertLevel(percentageUsed);

    // Is on track?
    final expectedSpent = (daysElapsed / daysInMonth) * budgetAmount;
    final isOnTrack = spent <= expectedSpent * 1.1; // 10% tolerance

    return BudgetStatus(
      vehicleId: vehicle.id!,
      vehicleName: vehicle.name,
      budgetAmount: budgetAmount,
      spent: spent.toDouble(),
      remaining: remaining.toDouble(),
      percentageUsed: percentageUsed,
      daysInMonth: daysInMonth,
      daysRemaining: daysRemaining,
      dailyBudgetRemaining: dailyBudgetRemaining,
      alertLevel: alertLevel,
      projectedSpending: projectedSpending,
      isOnTrack: isOnTrack,
    );
  }

  BudgetAlertLevel _getAlertLevel(double percentageUsed) {
    if (percentageUsed >= 100) return BudgetAlertLevel.overBudget;
    if (percentageUsed >= 90) return BudgetAlertLevel.exceeded;
    if (percentageUsed >= 75) return BudgetAlertLevel.critical;
    if (percentageUsed >= 50) return BudgetAlertLevel.warning;
    return BudgetAlertLevel.safe;
  }

  /// Get spending pace
  SpendingPace getSpendingPace(BudgetStatus status) {
    final daysElapsed = status.daysInMonth - status.daysRemaining;
    if (daysElapsed == 0) return SpendingPace.onTrack;

    final expectedPercentage = (daysElapsed / status.daysInMonth) * 100;
    final actualPercentage = status.percentageUsed;

    if (actualPercentage > expectedPercentage * 1.15) {
      return SpendingPace.tooFast;
    } else if (actualPercentage < expectedPercentage * 0.85) {
      return SpendingPace.underBudget;
    }
    return SpendingPace.onTrack;
  }

  /// Get family budget summary
  Future<FamilyBudgetSummary> getFamilyBudgetSummary({
    DateTime? forMonth,
  }) async {
    final month = forMonth ?? DateTime.now();
    final vehiclesData =
        await DatabaseService.instance.getAllVehiclesWithBudgets();
    final vehicles = vehiclesData.map((data) => Vehicle.fromMap(data)).toList();

    final List<BudgetStatus> vehicleBudgets = [];
    double totalBudget = 0;
    double totalSpent = 0;
    int vehiclesOverBudget = 0;
    int vehiclesOnTrack = 0;

    for (final vehicle in vehicles) {
      if (vehicle.monthlyBudget != null && vehicle.monthlyBudget! > 0) {
        final status = await getBudgetStatus(vehicle, forMonth: month);
        if (status != null) {
          vehicleBudgets.add(status);
          totalBudget += status.budgetAmount;
          totalSpent += status.spent;

          if (status.isOverBudget) {
            vehiclesOverBudget++;
          }
          if (status.isOnTrack) {
            vehiclesOnTrack++;
          }
        }
      }
    }

    final totalRemaining = totalBudget - totalSpent;
    final percentageUsed =
        totalBudget > 0 ? (totalSpent / totalBudget) * 100 : 0.0;

    return FamilyBudgetSummary(
      totalBudget: totalBudget,
      totalSpent: totalSpent.toDouble(),
      totalRemaining: totalRemaining.toDouble(),
      percentageUsed: percentageUsed,
      vehicleBudgets: vehicleBudgets,
      vehiclesOverBudget: vehiclesOverBudget,
      vehiclesOnTrack: vehiclesOnTrack,
      month: month,
    );
  }

  /// Check and trigger budget alerts
  Future<void> checkBudgetAlerts(Vehicle vehicle) async {
    final status = await getBudgetStatus(vehicle);
    if (status == null) return;

    // Check if alert needs to be sent
    final shouldAlert =
        await _shouldSendAlert(vehicle.id!, status.percentageUsed);
    if (!shouldAlert) return;

    String title;
    String body;

    switch (status.alertLevel) {
      case BudgetAlertLevel.warning:
        title = '50% Budget Used - ${vehicle.name}';
        body =
            'You\'ve spent ₹${status.spent.toStringAsFixed(0)} of ₹${status.budgetAmount.toStringAsFixed(0)}';
        break;
      case BudgetAlertLevel.critical:
        title = '⚠️ 75% Budget Warning - ${vehicle.name}';
        body =
            'Only ₹${status.remaining.toStringAsFixed(0)} remaining! ${status.daysRemaining} days left.';
        break;
      case BudgetAlertLevel.exceeded:
        title = '🚨 Almost at Limit! - ${vehicle.name}';
        body =
            'Budget almost reached: ₹${status.spent.toStringAsFixed(0)}/₹${status.budgetAmount.toStringAsFixed(0)}';
        break;
      case BudgetAlertLevel.overBudget:
        title = '❌ Budget Exceeded - ${vehicle.name}';
        body = 'Over budget by ₹${status.overBudgetAmount.toStringAsFixed(0)}!';
        break;
      default:
        return;
    }

    await NotificationService.instance.showNotification(
      id: vehicle.id! * 1000,
      title: title,
      body: body,
      payload: 'budget_alert_${vehicle.id}',
    );

    // Save alert sent marker
    await _markAlertSent(vehicle.id!, status.percentageUsed);
  }

  /// Track which alerts have been sent this month
  final Map<String, Set<int>> _alertsSent = {};

  String _getMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<bool> _shouldSendAlert(int vehicleId, double percentage) async {
    final monthKey = _getMonthKey();
    final alertKey = '${vehicleId}_$monthKey';

    final sentAlerts = _alertsSent[alertKey] ?? {};

    // Alert thresholds
    if (percentage >= 100 && !sentAlerts.contains(100)) return true;
    if (percentage >= 90 && !sentAlerts.contains(90)) return true;
    if (percentage >= 75 && !sentAlerts.contains(75)) return true;
    if (percentage >= 50 && !sentAlerts.contains(50)) return true;

    return false;
  }

  Future<void> _markAlertSent(int vehicleId, double percentage) async {
    final monthKey = _getMonthKey();
    final alertKey = '${vehicleId}_$monthKey';

    _alertsSent[alertKey] ??= {};

    if (percentage >= 100) _alertsSent[alertKey]!.add(100);
    if (percentage >= 90) _alertsSent[alertKey]!.add(90);
    if (percentage >= 75) _alertsSent[alertKey]!.add(75);
    if (percentage >= 50) _alertsSent[alertKey]!.add(50);
  }

  /// Save budget history at end of month
  Future<void> saveBudgetHistoryForMonth(
    Vehicle vehicle,
    DateTime month,
  ) async {
    if (vehicle.monthlyBudget == null || vehicle.monthlyBudget! <= 0) return;

    final spentResult =
        await DatabaseService.instance.getVehicleSpendingForMonth(
      vehicle.id!,
      month,
    );
    final spent = spentResult.toDouble();

    final history = BudgetHistory(
      vehicleId: vehicle.id!,
      month: '${month.year}-${month.month.toString().padLeft(2, '0')}',
      budgetAmount: vehicle.monthlyBudget!,
      actualSpent: spent,
      difference: vehicle.monthlyBudget! - spent,
    );

    await DatabaseService.instance.saveBudgetHistory(history.toMap());
  }

  /// Auto-save budget history for all vehicles (call at month-end)
  Future<void> autoSaveBudgetHistory() async {
    final now = DateTime.now();

    // Only run on the 1st of the month
    if (now.day != 1) return;

    final lastMonth = DateTime(now.year, now.month - 1);
    final vehiclesData =
        await DatabaseService.instance.getAllVehiclesWithBudgets();
    final vehicles = vehiclesData.map((data) => Vehicle.fromMap(data)).toList();

    for (final vehicle in vehicles) {
      if (vehicle.monthlyBudget != null && vehicle.monthlyBudget! > 0) {
        try {
          await saveBudgetHistoryForMonth(vehicle, lastMonth);
          debugPrint('✅ Saved budget history for ${vehicle.name}');
        } catch (e) {
          debugPrint(
            '⚠️ Failed to save budget history for ${vehicle.name}: $e',
          );
        }
      }
    }

    // Clear alert markers for new month
    _alertsSent.clear();
  }

  /// Get budget history list
  Future<List<BudgetHistory>> getBudgetHistory(
    int vehicleId, {
    int? limit,
  }) async {
    final data = await DatabaseService.instance
        .getBudgetHistory(vehicleId, limit: limit);
    return data.map((item) => BudgetHistory.fromMap(item)).toList();
  }

  /// Compare current month vs last month
  Future<Map<String, dynamic>> compareMonths(Vehicle vehicle) async {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);

    final currentSpentResult =
        await DatabaseService.instance.getVehicleSpendingForMonth(
      vehicle.id!,
      now,
    );
    final currentSpent = currentSpentResult.toDouble();

    final lastMonthSpentResult =
        await DatabaseService.instance.getVehicleSpendingForMonth(
      vehicle.id!,
      lastMonth,
    );
    final lastMonthSpent = lastMonthSpentResult.toDouble();

    final difference = currentSpent - lastMonthSpent;
    final percentageChange =
        lastMonthSpent > 0 ? (difference / lastMonthSpent) * 100 : 0.0;

    return {
      'current_month': currentSpent,
      'last_month': lastMonthSpent,
      'difference': difference,
      'percentage_change': percentageChange,
      'is_increase': difference > 0,
    };
  }

  /// Get message for spending pace
  String getSpendingPaceMessage(BudgetStatus status) {
    final pace = getSpendingPace(status);

    switch (pace) {
      case SpendingPace.underBudget:
        return 'Under budget! Keep it up 👍';
      case SpendingPace.onTrack:
        return 'On track to stay within budget';
      case SpendingPace.tooFast:
        return 'Spending too fast! Slow down 🚨';
    }
  }

  /// Format currency in INR
  String formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0)}';
  }
}
