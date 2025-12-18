import 'package:flutter/foundation.dart';
import 'database_service.dart';

/// Smart Suggestions Service for V2.5
/// Provides intelligent suggestions based on user's expense history
/// All processing is done locally using SQLite queries
class SmartSuggestionsService {
  factory SmartSuggestionsService() => _instance;
  SmartSuggestionsService._internal();
  static final SmartSuggestionsService _instance =
      SmartSuggestionsService._internal();

  static SmartSuggestionsService get instance => _instance;

  final DatabaseService _db = DatabaseService.instance;

  // Cache for frequently used suggestions
  final Map<String, List<String>> _merchantCache = {};
  final Map<String, double> _amountCache = {};

  /// Get recent merchants for a specific category
  Future<List<RecentMerchant>> getRecentMerchants({
    String? category,
    int limit = 5,
  }) async {
    try {
      final db = await _db.database;

      String query;
      List<dynamic> args;

      if (category != null && category.isNotEmpty) {
        query = '''
          SELECT 
            merchant, 
            category,
            COUNT(*) as frequency,
            MAX(date) as last_used,
            AVG(amount) as avg_amount
          FROM (
            SELECT merchant, category, date, amount FROM fuel_expenses
            WHERE merchant IS NOT NULL AND merchant != '' AND category = ?
            UNION ALL
            SELECT merchant, category, date, amount FROM general_expenses  
            WHERE merchant IS NOT NULL AND merchant != '' AND category = ?
          )
          GROUP BY merchant
          ORDER BY frequency DESC, last_used DESC
          LIMIT ?
        ''';
        args = [category, category, limit];
      } else {
        query = '''
          SELECT 
            merchant, 
            category,
            COUNT(*) as frequency,
            MAX(date) as last_used,
            AVG(amount) as avg_amount
          FROM (
            SELECT merchant, category, date, amount FROM fuel_expenses
            WHERE merchant IS NOT NULL AND merchant != ''
            UNION ALL
            SELECT merchant, category, date, amount FROM general_expenses  
            WHERE merchant IS NOT NULL AND merchant != ''
          )
          GROUP BY merchant
          ORDER BY frequency DESC, last_used DESC
          LIMIT ?
        ''';
        args = [limit];
      }

      final results = await db.rawQuery(query, args);

      return results
          .map(
            (row) => RecentMerchant(
              name: row['merchant'] as String,
              category: row['category'] as String?,
              frequency: row['frequency'] as int,
              lastUsed: DateTime.tryParse(row['last_used'] as String? ?? ''),
              averageAmount: (row['avg_amount'] as num?)?.toDouble(),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('SmartSuggestions: Error getting recent merchants: $e');
      return [];
    }
  }

  /// Suggest category based on current time of day
  String suggestCategoryByTime() {
    final hour = DateTime.now().hour;

    if (hour >= 6 && hour < 10) {
      return 'Food'; // Breakfast time
    } else if (hour >= 11 && hour < 14) {
      return 'Food'; // Lunch time
    } else if (hour >= 15 && hour < 17) {
      return 'Food'; // Snacks/Tea time
    } else if (hour >= 17 && hour < 21) {
      return 'Groceries'; // Evening shopping time
    } else if (hour >= 19 && hour < 22) {
      return 'Food'; // Dinner time
    } else {
      return 'Other';
    }
  }

  /// Suggest category based on day of week
  String suggestCategoryByDayOfWeek() {
    final dayOfWeek = DateTime.now().weekday;

    switch (dayOfWeek) {
      case DateTime.saturday:
      case DateTime.sunday:
        return 'Entertainment'; // Weekend = entertainment
      case DateTime.monday:
        return 'Fuel'; // Start of week = fuel up
      default:
        return suggestCategoryByTime();
    }
  }

  /// Get predicted amount for a category based on history
  Future<AmountPrediction> predictAmount({
    required String category,
    String? merchant,
  }) async {
    try {
      final db = await _db.database;

      String query;
      List<dynamic> args;

      if (merchant != null && merchant.isNotEmpty) {
        // More specific: predict based on merchant + category
        query = '''
          SELECT 
            AVG(amount) as avg_amount,
            MIN(amount) as min_amount,
            MAX(amount) as max_amount,
            COUNT(*) as count
          FROM (
            SELECT amount FROM fuel_expenses 
            WHERE category = ? AND merchant = ?
            UNION ALL
            SELECT amount FROM general_expenses 
            WHERE category = ? AND merchant = ?
          )
        ''';
        args = [category, merchant, category, merchant];
      } else {
        // General: predict based on category only
        query = '''
          SELECT 
            AVG(amount) as avg_amount,
            MIN(amount) as min_amount,
            MAX(amount) as max_amount,
            COUNT(*) as count
          FROM (
            SELECT amount FROM fuel_expenses WHERE category = ?
            UNION ALL
            SELECT amount FROM general_expenses WHERE category = ?
          )
        ''';
        args = [category, category];
      }

      final results = await db.rawQuery(query, args);

      if (results.isEmpty || results.first['count'] == 0) {
        return AmountPrediction.empty();
      }

      final row = results.first;
      return AmountPrediction(
        suggestedAmount: (row['avg_amount'] as num?)?.toDouble() ?? 0,
        minAmount: (row['min_amount'] as num?)?.toDouble() ?? 0,
        maxAmount: (row['max_amount'] as num?)?.toDouble() ?? 0,
        dataPoints: (row['count'] as int?) ?? 0,
      );
    } catch (e) {
      debugPrint('SmartSuggestions: Error predicting amount: $e');
      return AmountPrediction.empty();
    }
  }

  /// Get the last expense to enable "repeat" functionality
  Future<LastExpense?> getLastExpense() async {
    try {
      final db = await _db.database;

      const query = '''
        SELECT * FROM (
          SELECT 
            id, amount, category, merchant, date, 'fuel' as type, description
          FROM fuel_expenses
          UNION ALL
          SELECT 
            id, amount, category, merchant, date, 'general' as type, description
          FROM general_expenses
        )
        ORDER BY date DESC
        LIMIT 1
      ''';

      final results = await db.rawQuery(query);

      if (results.isEmpty) return null;

      final row = results.first;
      return LastExpense(
        id: row['id'] as int,
        amount: (row['amount'] as num).toDouble(),
        category: row['category'] as String,
        merchant: row['merchant'] as String?,
        date: DateTime.tryParse(row['date'] as String) ?? DateTime.now(),
        type: row['type'] as String,
        description: row['description'] as String?,
      );
    } catch (e) {
      debugPrint('SmartSuggestions: Error getting last expense: $e');
      return null;
    }
  }

  /// Get frequently used categories sorted by usage
  Future<List<CategorySuggestion>> getFrequentCategories(
      {int limit = 6,}) async {
    try {
      final db = await _db.database;

      const query = '''
        SELECT 
          category,
          COUNT(*) as frequency,
          SUM(amount) as total_amount
        FROM (
          SELECT category, amount FROM fuel_expenses
          UNION ALL
          SELECT category, amount FROM general_expenses
        )
        WHERE category IS NOT NULL AND category != ''
        GROUP BY category
        ORDER BY frequency DESC
        LIMIT ?
      ''';

      final results = await db.rawQuery(query, [limit]);

      return results
          .map(
            (row) => CategorySuggestion(
              category: row['category'] as String,
              frequency: row['frequency'] as int,
              totalAmount: (row['total_amount'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('SmartSuggestions: Error getting frequent categories: $e');
      return [];
    }
  }

  /// Get spending anomaly detection
  Future<SpendingAnomaly?> detectAnomaly({
    required double amount,
    required String category,
  }) async {
    try {
      final prediction = await predictAmount(category: category);

      if (prediction.dataPoints < 3) {
        return null; // Not enough data for anomaly detection
      }

      final percentageAboveAvg =
          ((amount - prediction.suggestedAmount) / prediction.suggestedAmount) *
              100;

      if (percentageAboveAvg > 50) {
        return SpendingAnomaly(
          isAnomaly: true,
          percentageAboveAverage: percentageAboveAvg,
          averageAmount: prediction.suggestedAmount,
          message:
              'This is ${percentageAboveAvg.toStringAsFixed(0)}% higher than your usual $category expense',
        );
      }

      return SpendingAnomaly(
          isAnomaly: false, percentageAboveAverage: percentageAboveAvg,);
    } catch (e) {
      debugPrint('SmartSuggestions: Error detecting anomaly: $e');
      return null;
    }
  }

  /// Get quick fill suggestions based on context
  Future<QuickFillSuggestion> getQuickFillSuggestion() async {
    final suggestedCategory = suggestCategoryByTime();
    final merchants =
        await getRecentMerchants(category: suggestedCategory, limit: 3);
    final amountPrediction = await predictAmount(category: suggestedCategory);
    final lastExpense = await getLastExpense();

    return QuickFillSuggestion(
      suggestedCategory: suggestedCategory,
      recentMerchants: merchants,
      predictedAmount: amountPrediction,
      lastExpense: lastExpense,
    );
  }

  /// Clear suggestion cache
  void clearCache() {
    _merchantCache.clear();
    _amountCache.clear();
  }
}

/// Recent merchant data
class RecentMerchant {
  RecentMerchant({
    required this.name,
    this.category,
    required this.frequency,
    this.lastUsed,
    this.averageAmount,
  });
  final String name;
  final String? category;
  final int frequency;
  final DateTime? lastUsed;
  final double? averageAmount;

  String get displayName => name;

  String get subtitle {
    if (averageAmount != null) {
      return 'Avg: ₹${averageAmount!.toStringAsFixed(0)} • $frequency times';
    }
    return '$frequency times';
  }
}

/// Amount prediction data
class AmountPrediction {
  AmountPrediction({
    required this.suggestedAmount,
    required this.minAmount,
    required this.maxAmount,
    required this.dataPoints,
  });

  factory AmountPrediction.empty() => AmountPrediction(
        suggestedAmount: 0,
        minAmount: 0,
        maxAmount: 0,
        dataPoints: 0,
      );
  final double suggestedAmount;
  final double minAmount;
  final double maxAmount;
  final int dataPoints;

  bool get hasData => dataPoints > 0;

  String get rangeText {
    if (!hasData) return 'No history';
    return '₹${minAmount.toStringAsFixed(0)} - ₹${maxAmount.toStringAsFixed(0)}';
  }

  String get suggestionText {
    if (!hasData) return '';
    return 'Usually ₹${suggestedAmount.toStringAsFixed(0)}';
  }
}

/// Last expense for repeat functionality
class LastExpense {
  LastExpense({
    required this.id,
    required this.amount,
    required this.category,
    this.merchant,
    required this.date,
    required this.type,
    this.description,
  });
  final int id;
  final double amount;
  final String category;
  final String? merchant;
  final DateTime date;
  final String type;
  final String? description;

  String get displayText =>
      '₹${amount.toStringAsFixed(0)} for $category${merchant != null ? ' at $merchant' : ''}';
}

/// Category suggestion with usage stats
class CategorySuggestion {
  CategorySuggestion({
    required this.category,
    required this.frequency,
    required this.totalAmount,
  });
  final String category;
  final int frequency;
  final double totalAmount;
}

/// Spending anomaly detection result
class SpendingAnomaly {
  SpendingAnomaly({
    required this.isAnomaly,
    required this.percentageAboveAverage,
    this.averageAmount,
    this.message,
  });
  final bool isAnomaly;
  final double percentageAboveAverage;
  final double? averageAmount;
  final String? message;
}

/// Combined quick fill suggestion
class QuickFillSuggestion {
  QuickFillSuggestion({
    required this.suggestedCategory,
    required this.recentMerchants,
    required this.predictedAmount,
    this.lastExpense,
  });
  final String suggestedCategory;
  final List<RecentMerchant> recentMerchants;
  final AmountPrediction predictedAmount;
  final LastExpense? lastExpense;
}
