import 'dart:math';

import '../models/fuel_expense.dart';
import '../models/general_expense.dart';
import '../models/smart_insight.dart';
import '../models/vehicle.dart';
import 'database_service.dart';

class InsightsService {
  InsightsService._();

  static final InsightsService instance = InsightsService._();
  final DatabaseService _db = DatabaseService.instance;

  Future<List<SmartInsight>> generateInsights({String? deviceId}) async {
    final vehicles = deviceId == null
        ? await _db.getAllVehicles()
        : await _db.getVehiclesByOwnerDevice(deviceId);
    final fuelExpenses = deviceId == null
        ? await _db.getAllFuelExpenses()
        : await _db.getFuelExpensesByDevice(deviceId);
    final generalExpenses = deviceId == null
        ? await _db.getAllGeneralExpenses()
        : await _db.getGeneralExpensesByDevice(deviceId);

    final insights = <SmartInsight>[
      ..._buildSpendingInsights(fuelExpenses, generalExpenses),
      ...await _buildEfficiencyInsights(vehicles),
      ...await _buildMaintenanceInsights(),
      ..._buildPlanningInsights(fuelExpenses),
    ]..sort((a, b) => b.priority.compareTo(a.priority));
    return insights;
  }

  List<SmartInsight> _buildSpendingInsights(
    List<FuelExpense> fuelExpenses,
    List<GeneralExpense> generalExpenses,
  ) {
    final insights = <SmartInsight>[];
    final now = DateTime.now();
    final last30 = now.subtract(const Duration(days: 30));
    final prev30 = now.subtract(const Duration(days: 60));

    double sumForRange(DateTime start, DateTime end) {
      double total = 0;
      for (final expense in fuelExpenses) {
        if (expense.date.isAfter(start) && expense.date.isBefore(end)) {
          total += expense.amountPaid;
        }
      }
      for (final expense in generalExpenses) {
        if (expense.date.isAfter(start) && expense.date.isBefore(end)) {
          total += expense.amount;
        }
      }
      return total;
    }

    final recent = sumForRange(last30, now);
    final previous = sumForRange(prev30, last30);

    if (previous > 0 && recent > previous * 1.12) {
      insights.add(
        SmartInsight(
          id: 'spend_up',
          title:
              'Spending trending ↑ ${(recent / previous * 100 - 100).toStringAsFixed(1)}%',
          description:
              'You spent ₹${recent.toStringAsFixed(0)} over the last month, significantly higher than the prior month. Review maintenance and discretionary costs to stay on budget.',
          category: InsightCategory.savings,
          priority: recent - previous,
          actionLabel: 'Review expenses',
        ),
      );
    }

    final categoryTotals = <String, double>{};
    for (final expense in generalExpenses) {
      categoryTotals.update(
        expense.category.name,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    if (categoryTotals.isNotEmpty) {
      final sorted = categoryTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top = sorted.first;
      final total = categoryTotals.values.reduce((a, b) => a + b);
      final share = top.value / total;
      if (share > 0.45) {
        insights.add(
          SmartInsight(
            id: 'category_${top.key}',
            title:
                '${top.key} taking ${(share * 100).toStringAsFixed(0)}% of vehicle spend',
            description:
                'Most of your general expense budget goes to ${top.key}. Consider splitting big bills or creating a dedicated limit.',
            category: InsightCategory.savings,
            priority: share,
            actionLabel: 'Adjust budgets',
          ),
        );
      }
    }

    return insights;
  }

  Future<List<SmartInsight>> _buildEfficiencyInsights(
    List<Vehicle> vehicles,
  ) async {
    final insights = <SmartInsight>[];
    for (final vehicle in vehicles) {
      if (vehicle.id == null) continue;
      final averages = await _db.calculateFuelAverages(vehicle.id!);
      final lifetime = averages['lifetime_average'] ?? 0;
      final recent = averages['last_5_average'] ?? lifetime;
      if (lifetime <= 0 || recent <= 0) continue;
      final drop = (lifetime - recent) / lifetime;
      if (drop > 0.12) {
        insights.add(
          SmartInsight(
            id: 'efficiency_drop_${vehicle.id}',
            title: '${vehicle.name} efficiency slipping',
            description:
                'Recent fillups show ${(drop * 100).toStringAsFixed(0)}% lower efficiency than the lifetime average. Check tyre pressure and filter health.',
            category: InsightCategory.maintenance,
            priority: drop,
            actionLabel: 'Schedule tune-up',
          ),
        );
      }
    }
    return insights;
  }

  Future<List<SmartInsight>> _buildMaintenanceInsights() async {
    final insights = <SmartInsight>[];
    final db = await _db.database;
    List<Map<String, dynamic>> rows = [];
    try {
      rows = await db.query(
        'maintenance_records',
        where: 'next_due_date IS NOT NULL',
      );
    } catch (_) {
      return insights;
    }
    final now = DateTime.now();
    for (final row in rows) {
      final nextDueRaw = row['next_due_date'] as String?;
      if (nextDueRaw == null) continue;
      final nextDue = DateTime.tryParse(nextDueRaw);
      if (nextDue == null) continue;
      final daysLeft = nextDue.difference(now).inDays;
      if (daysLeft <= 20) {
        insights.add(
          SmartInsight(
            id: 'maintenance_${row['id']}',
            title: 'Service due in ${max(daysLeft, 0)} days',
            description:
                'Your ${row['type']} entry scheduled at ${row['workshop'] ?? 'preferred workshop'} is due soon. Pre-book a slot to avoid last-minute rush.',
            category: InsightCategory.maintenance,
            priority: 1 / max(daysLeft.abs(), 1),
            actionLabel: 'View maintenance log',
          ),
        );
      }
    }
    return insights;
  }

  List<SmartInsight> _buildPlanningInsights(List<FuelExpense> fuelExpenses) {
    final insights = <SmartInsight>[];
    if (fuelExpenses.length < 3) {
      return insights;
    }
    final sorted = List<FuelExpense>.from(fuelExpenses)
      ..sort((a, b) => a.date.compareTo(b.date));
    final intervals = <int>[];
    for (var i = 1; i < sorted.length; i++) {
      final diff = sorted[i].date.difference(sorted[i - 1].date).inDays;
      if (diff > 0) intervals.add(diff);
    }
    if (intervals.isEmpty) {
      return insights;
    }
    final avgDays = intervals.reduce((a, b) => a + b) / intervals.length;
    final lastFill = sorted.last.date;
    final projected = lastFill
        .add(Duration(days: avgDays.round()))
        .add(const Duration(days: 1));
    if (projected.isBefore(DateTime.now().add(const Duration(days: 3)))) {
      insights.add(
        SmartInsight(
          id: 'refill_prediction',
          title: 'Plan next fuel stop',
          description:
              'Based on your past pattern you usually refuel every ${avgDays.toStringAsFixed(1)} days. Expect the next top-up around ${projected.day}/${projected.month}.',
          category: InsightCategory.planning,
          priority: 0.5,
          actionLabel: 'Bookmark pump',
        ),
      );
    }
    return insights;
  }
}
