import 'dart:math' as math;

import 'database_service.dart';

/// Spending patterns data class
class SpendingPatterns {
  SpendingPatterns({
    required this.totalAmount,
    required this.transactionCount,
    required this.averageTransaction,
    required this.memberSpending,
    required this.categorySpending,
    required this.dayOfWeekSpending,
    required this.hourlySpending,
    required this.startDate,
    required this.endDate,
  });
  final double totalAmount;
  final int transactionCount;
  final double averageTransaction;
  final Map<int, double> memberSpending;
  final Map<String, double> categorySpending;
  final List<double> dayOfWeekSpending; // 7 days
  final List<double> hourlySpending; // 24 hours
  final DateTime startDate;
  final DateTime endDate;
}

/// Category insight data class
class CategoryInsight {
  // increasing, decreasing, stable

  CategoryInsight({
    required this.category,
    required this.totalAmount,
    required this.transactionCount,
    required this.averageAmount,
    required this.maxAmount,
    required this.minAmount,
    required this.changePercent,
    required this.trend,
  });
  final String category;
  final double totalAmount;
  final int transactionCount;
  final double averageAmount;
  final double maxAmount;
  final double minAmount;
  final double changePercent;
  final String trend;
}

/// Expense prediction data class
class ExpensePrediction {
  ExpensePrediction({
    required this.predictedAmount,
    required this.confidence,
    required this.daysAhead,
    required this.historicalAverage,
  });
  final double predictedAmount;
  final double confidence; // 0-100
  final int daysAhead;
  final double historicalAverage;
}

/// Optimization suggestion data class
class OptimizationSuggestion {
  // high, medium, low

  OptimizationSuggestion({
    required this.category,
    required this.type,
    required this.title,
    required this.description,
    required this.potentialSavings,
    required this.priority,
  });
  final String category;
  final String type; // reduce_spending, review_outliers, consolidate_purchases
  final String title;
  final String description;
  final double potentialSavings;
  final String priority;
}

/// Period comparison data class
class PeriodComparison {
  PeriodComparison({
    required this.period1Total,
    required this.period1Count,
    required this.period1Average,
    required this.period2Total,
    required this.period2Count,
    required this.period2Average,
    required this.totalChange,
    required this.totalChangePercent,
    required this.countChange,
    required this.averageChange,
  });
  final double period1Total;
  final int period1Count;
  final double period1Average;
  final double period2Total;
  final int period2Count;
  final double period2Average;
  final double totalChange;
  final double totalChangePercent;
  final int countChange;
  final double averageChange;
}

/// Member comparison data class
class MemberComparison {
  MemberComparison({
    required this.memberId,
    required this.memberName,
    required this.transactionCount,
    required this.totalAmount,
    required this.averageAmount,
  });
  final int memberId;
  final String memberName;
  final int transactionCount;
  final double totalAmount;
  final double averageAmount;
}

/// Advanced analytics service for household and vehicle expenses
class AdvancedAnalyticsService {
  AdvancedAnalyticsService._internal() {
    _databaseService = DatabaseService.instance;
  }

  factory AdvancedAnalyticsService() {
    return _instance;
  }
  static final AdvancedAnalyticsService _instance =
      AdvancedAnalyticsService._internal();
  late final DatabaseService _databaseService;

  static AdvancedAnalyticsService get instance => _instance;

  /// Get spending patterns for household members
  Future<SpendingPatterns> getMemberSpendingPatterns(
    int householdId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _databaseService.database;

    final start =
        startDate ?? DateTime.now().subtract(const Duration(days: 90));
    final end = endDate ?? DateTime.now();

    // Get all household expenses in date range
    final expenses = await db.query(
      'household_expenses',
      where: 'household_id = ? AND date >= ? AND date <= ?',
      whereArgs: [householdId, start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );

    // Calculate patterns
    final memberSpending = <int, double>{};
    final categorySpending = <String, double>{};
    final dayOfWeekSpending = List<double>.filled(7, 0.0);
    final hourlySpending = List<double>.filled(24, 0.0);

    double totalAmount = 0.0;
    int transactionCount = 0;

    for (final expense in expenses) {
      final amount = expense['amount'] as double;
      final memberId = expense['member_id'] as int?;
      final category = expense['category'] as String? ?? 'Uncategorized';
      final date = DateTime.parse(expense['date'] as String);

      totalAmount += amount;
      transactionCount++;

      // Member spending
      if (memberId != null) {
        memberSpending[memberId] = (memberSpending[memberId] ?? 0) + amount;
      }

      // Category spending
      categorySpending[category] = (categorySpending[category] ?? 0) + amount;

      // Day of week pattern
      dayOfWeekSpending[date.weekday - 1] += amount;

      // Hourly pattern
      hourlySpending[date.hour] += amount;
    }

    return SpendingPatterns(
      totalAmount: totalAmount,
      transactionCount: transactionCount,
      averageTransaction:
          transactionCount > 0 ? totalAmount / transactionCount : 0,
      memberSpending: memberSpending,
      categorySpending: categorySpending,
      dayOfWeekSpending: dayOfWeekSpending,
      hourlySpending: hourlySpending,
      startDate: start,
      endDate: end,
    );
  }

  /// Get category insights with trends
  Future<List<CategoryInsight>> getCategoryInsights(
    int householdId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _databaseService.database;

    final start =
        startDate ?? DateTime.now().subtract(const Duration(days: 90));
    final end = endDate ?? DateTime.now();

    // Get current period expenses
    final currentExpenses = await db.rawQuery(
      '''
      SELECT category, 
             SUM(amount) as total_amount,
             COUNT(*) as transaction_count,
             AVG(amount) as avg_amount,
             MAX(amount) as max_amount,
             MIN(amount) as min_amount
      FROM household_expenses
      WHERE household_id = ? AND date >= ? AND date <= ?
      GROUP BY category
      ORDER BY total_amount DESC
    ''',
      [householdId, start.toIso8601String(), end.toIso8601String()],
    );

    // Get previous period for comparison
    final previousStart = start.subtract(end.difference(start));
    final previousEnd = start;

    final previousExpenses = await db.rawQuery(
      '''
      SELECT category, SUM(amount) as total_amount
      FROM household_expenses
      WHERE household_id = ? AND date >= ? AND date <= ?
      GROUP BY category
    ''',
      [
        householdId,
        previousStart.toIso8601String(),
        previousEnd.toIso8601String(),
      ],
    );

    final previousTotals = <String, double>{};
    for (final row in previousExpenses) {
      previousTotals[row['category'] as String] = row['total_amount'] as double;
    }

    final insights = <CategoryInsight>[];
    for (final row in currentExpenses) {
      final category = row['category'] as String;
      final currentTotal = row['total_amount'] as double;
      final previousTotal = previousTotals[category] ?? 0.0;

      final changePercent = previousTotal > 0
          ? ((currentTotal - previousTotal) / previousTotal) * 100
          : 0.0;

      insights.add(
        CategoryInsight(
          category: category,
          totalAmount: currentTotal,
          transactionCount: row['transaction_count'] as int,
          averageAmount: row['avg_amount'] as double,
          maxAmount: row['max_amount'] as double,
          minAmount: row['min_amount'] as double,
          changePercent: changePercent,
          trend: changePercent > 5
              ? 'increasing'
              : (changePercent < -5 ? 'decreasing' : 'stable'),
        ),
      );
    }

    return insights;
  }

  /// Predict future expenses using simple linear regression
  Future<ExpensePrediction> predictExpenses(
      int householdId, int daysAhead,) async {
    final db = await _databaseService.database;

    // Get last 90 days of daily totals
    final expenses = await db.rawQuery('''
      SELECT DATE(date) as day, SUM(amount) as daily_total
      FROM household_expenses
      WHERE household_id = ? AND date >= ?
      GROUP BY DATE(date)
      ORDER BY day ASC
    ''', [
      householdId,
      DateTime.now().subtract(const Duration(days: 90)).toIso8601String(),
    ]);

    if (expenses.length < 7) {
      return ExpensePrediction(
        predictedAmount: 0,
        confidence: 0,
        daysAhead: daysAhead,
        historicalAverage: 0,
      );
    }

    // Calculate linear regression
    final dataPoints = <MapEntry<int, double>>[];
    for (int i = 0; i < expenses.length; i++) {
      dataPoints.add(MapEntry(i, expenses[i]['daily_total'] as double));
    }

    final regression = _linearRegression(dataPoints);
    final predictedDaily =
        regression['slope']! * (dataPoints.length + daysAhead) +
            regression['intercept']!;
    final predictedTotal = predictedDaily * daysAhead;

    // Calculate confidence based on R-squared
    final rSquared = regression['rSquared']!;
    final confidence = (rSquared * 100).toDouble().clamp(0.0, 100.0);

    // Calculate historical average
    final historicalAvg = expenses.fold<double>(
          0,
          (sum, row) => sum + (row['daily_total'] as double),
        ) /
        expenses.length;

    return ExpensePrediction(
      predictedAmount: predictedTotal,
      confidence: confidence,
      daysAhead: daysAhead,
      historicalAverage: historicalAvg * daysAhead,
    );
  }

  /// Calculate linear regression for prediction
  Map<String, double> _linearRegression(List<MapEntry<int, double>> data) {
    final n = data.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

    for (final point in data) {
      sumX += point.key;
      sumY += point.value;
      sumXY += point.key * point.value;
      sumX2 += point.key * point.key;
    }

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    // Calculate R-squared
    final yMean = sumY / n;
    double ssRes = 0, ssTot = 0;
    for (final point in data) {
      final yPred = slope * point.key + intercept;
      ssRes += math.pow(point.value - yPred, 2);
      ssTot += math.pow(point.value - yMean, 2);
    }
    final rSquared = ssTot > 0 ? 1 - (ssRes / ssTot) : 0;

    return {
      'slope': slope,
      'intercept': intercept,
      'rSquared': rSquared.toDouble(),
    };
  }

  /// Get cost optimization suggestions
  Future<List<OptimizationSuggestion>> getOptimizationSuggestions(
      int householdId,) async {
    final suggestions = <OptimizationSuggestion>[];

    // Get insights
    final insights = await getCategoryInsights(householdId);
    final patterns = await getMemberSpendingPatterns(householdId);

    // Find categories with high spending
    final sortedCategories = insights.toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    for (int i = 0; i < math.min(3, sortedCategories.length); i++) {
      final category = sortedCategories[i];

      if (category.trend == 'increasing' && category.changePercent > 15) {
        suggestions.add(
          OptimizationSuggestion(
            category: category.category,
            type: 'reduce_spending',
            title:
                '${category.category} spending increased by ${category.changePercent.toStringAsFixed(1)}%',
            description:
                'Consider reviewing your ${category.category} expenses. Look for subscriptions or recurring costs that can be reduced.',
            potentialSavings: category.totalAmount * 0.15,
            priority: 'high',
          ),
        );
      }
    }

    // Check for unusual high-value transactions
    for (final category in insights) {
      if (category.maxAmount > category.averageAmount * 3) {
        suggestions.add(
          OptimizationSuggestion(
            category: category.category,
            type: 'review_outliers',
            title: 'Unusual ${category.category} transaction detected',
            description:
                'A transaction of ₹${category.maxAmount.toStringAsFixed(2)} is much higher than your average of ₹${category.averageAmount.toStringAsFixed(2)}',
            potentialSavings: 0,
            priority: 'medium',
          ),
        );
      }
    }

    // Check for budget opportunities
    if (patterns.transactionCount > 50) {
      final avgTransaction = patterns.averageTransaction;
      suggestions.add(
        OptimizationSuggestion(
          category: 'General',
          type: 'consolidate_purchases',
          title: 'Consolidate small purchases',
          description:
              'You have ${patterns.transactionCount} transactions with average ₹${avgTransaction.toStringAsFixed(2)}. Consider bulk buying to save.',
          potentialSavings: patterns.totalAmount * 0.05,
          priority: 'low',
        ),
      );
    }

    return suggestions;
  }

  /// Compare spending between two periods
  Future<PeriodComparison> comparePeriodsData(
    int householdId,
    DateTime period1Start,
    DateTime period1End,
    DateTime period2Start,
    DateTime period2End,
  ) async {
    final db = await _databaseService.database;

    // Get period 1 data
    final period1Data = await db.rawQuery(
      '''
      SELECT 
        SUM(amount) as total,
        COUNT(*) as count,
        AVG(amount) as average
      FROM household_expenses
      WHERE household_id = ? AND date >= ? AND date <= ?
    ''',
      [
        householdId,
        period1Start.toIso8601String(),
        period1End.toIso8601String(),
      ],
    );

    // Get period 2 data
    final period2Data = await db.rawQuery(
      '''
      SELECT 
        SUM(amount) as total,
        COUNT(*) as count,
        AVG(amount) as average
      FROM household_expenses
      WHERE household_id = ? AND date >= ? AND date <= ?
    ''',
      [
        householdId,
        period2Start.toIso8601String(),
        period2End.toIso8601String(),
      ],
    );

    final p1Total = (period1Data.first['total'] as double?) ?? 0;
    final p1Count = (period1Data.first['count'] as int?) ?? 0;
    final p1Avg = (period1Data.first['average'] as double?) ?? 0;

    final p2Total = (period2Data.first['total'] as double?) ?? 0;
    final p2Count = (period2Data.first['count'] as int?) ?? 0;
    final p2Avg = (period2Data.first['average'] as double?) ?? 0;

    return PeriodComparison(
      period1Total: p1Total,
      period1Count: p1Count,
      period1Average: p1Avg,
      period2Total: p2Total,
      period2Count: p2Count,
      period2Average: p2Avg,
      totalChange: p2Total - p1Total,
      totalChangePercent:
          p1Total > 0 ? ((p2Total - p1Total) / p1Total) * 100 : 0,
      countChange: p2Count - p1Count,
      averageChange: p2Avg - p1Avg,
    );
  }

  /// Get member comparison data
  Future<List<MemberComparison>> compareMembersData(
    int householdId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _databaseService.database;

    final data = await db.rawQuery(
      '''
      SELECT 
        m.id as member_id,
        m.name as member_name,
        COUNT(e.id) as transaction_count,
        SUM(e.amount) as total_amount,
        AVG(e.amount) as avg_amount
      FROM family_members m
      LEFT JOIN household_expenses e ON m.id = e.member_id
        AND e.date >= ? AND e.date <= ?
      WHERE m.household_id = ?
      GROUP BY m.id
      ORDER BY total_amount DESC
    ''',
      [startDate.toIso8601String(), endDate.toIso8601String(), householdId],
    );

    return data
        .map(
          (row) => MemberComparison(
            memberId: row['member_id'] as int,
            memberName: row['member_name'] as String,
            transactionCount: row['transaction_count'] as int,
            totalAmount: (row['total_amount'] as double?) ?? 0,
            averageAmount: (row['avg_amount'] as double?) ?? 0,
          ),
        )
        .toList();
  }
}
