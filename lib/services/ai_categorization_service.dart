import 'database_service.dart';

/// AI-based expense categorization using machine learning patterns
class AICategorizationService {
  AICategorizationService._internal() {
    _databaseService = DatabaseService.instance;
  }

  factory AICategorizationService() {
    return _instance;
  }
  static final AICategorizationService _instance =
      AICategorizationService._internal();
  late final DatabaseService _databaseService;

  // Category keywords mapping
  final Map<String, List<String>> _categoryKeywords = {
    'Groceries': [
      'grocery',
      'supermarket',
      'mart',
      'vegetables',
      'fruits',
      'food',
      'provisions',
      'kirana',
      'store',
    ],
    'Utilities': [
      'electricity',
      'water',
      'gas',
      'internet',
      'wifi',
      'broadband',
      'phone',
      'mobile',
      'recharge',
    ],
    'Transportation': [
      'fuel',
      'petrol',
      'diesel',
      'cng',
      'uber',
      'ola',
      'taxi',
      'auto',
      'metro',
      'bus',
      'train',
    ],
    'Healthcare': [
      'medicine',
      'medical',
      'hospital',
      'clinic',
      'doctor',
      'pharmacy',
      'health',
      'lab',
      'test',
    ],
    'Entertainment': [
      'movie',
      'cinema',
      'netflix',
      'prime',
      'spotify',
      'game',
      'concert',
      'show',
      'ticket',
    ],
    'Dining': [
      'restaurant',
      'cafe',
      'zomato',
      'swiggy',
      'food',
      'dinner',
      'lunch',
      'breakfast',
      'hotel',
    ],
    'Shopping': [
      'amazon',
      'flipkart',
      'myntra',
      'clothes',
      'shoes',
      'fashion',
      'mall',
      'shop',
    ],
    'Education': [
      'school',
      'college',
      'tuition',
      'course',
      'books',
      'fees',
      'exam',
      'education',
    ],
    'Rent': ['rent', 'lease', 'housing', 'apartment', 'flat'],
    'Insurance': ['insurance', 'policy', 'premium', 'lic', 'medical insurance'],
    'Investment': [
      'mutual fund',
      'sip',
      'stocks',
      'shares',
      'investment',
      'fd',
      'rd',
    ],
    'Personal Care': [
      'salon',
      'spa',
      'grooming',
      'cosmetics',
      'beauty',
      'haircut',
    ],
  };

  // Category patterns based on amount ranges
  final Map<String, AmountRange> _categoryAmountPatterns = {
    'Rent': AmountRange(min: 5000, max: 50000),
    'Utilities': AmountRange(min: 100, max: 5000),
    'Groceries': AmountRange(min: 200, max: 10000),
    'Transportation': AmountRange(min: 50, max: 5000),
    'Dining': AmountRange(min: 100, max: 3000),
    'Shopping': AmountRange(min: 500, max: 20000),
  };

  static AICategorizationService get instance => _instance;

  /// Predict category for an expense using ML-like approach
  Future<CategoryPrediction> predictCategory({
    required String description,
    double? amount,
    DateTime? date,
    int? householdId,
  }) async {
    final predictions = <String, double>{};

    // Step 1: Keyword-based scoring
    final keywordScores = _calculateKeywordScores(description);
    predictions.addAll(keywordScores);

    // Step 2: Amount-based scoring
    if (amount != null) {
      final amountScores = _calculateAmountScores(amount);
      _mergeScores(predictions, amountScores, weight: 0.3);
    }

    // Step 3: Historical pattern scoring
    if (householdId != null) {
      final historicalScores = await _calculateHistoricalScores(
        householdId,
        description,
        amount,
      );
      _mergeScores(predictions, historicalScores, weight: 0.4);
    }

    // Step 4: Time-based patterns
    if (date != null) {
      final timeScores = _calculateTimeBasedScores(date);
      _mergeScores(predictions, timeScores, weight: 0.1);
    }

    // Normalize scores
    final totalScore =
        predictions.values.fold<double>(0, (sum, score) => sum + score);
    if (totalScore > 0) {
      predictions.forEach((key, value) {
        predictions[key] = value / totalScore;
      });
    }

    // Get top 3 predictions
    final sortedPredictions = predictions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topPredictions = sortedPredictions.take(3).map((entry) {
      return CategoryScore(
        category: entry.key,
        confidence: entry.value,
      );
    }).toList();

    return CategoryPrediction(
      primaryCategory: topPredictions.isNotEmpty
          ? topPredictions.first.category
          : 'Uncategorized',
      confidence:
          topPredictions.isNotEmpty ? topPredictions.first.confidence : 0.0,
      alternatives: topPredictions.skip(1).toList(),
    );
  }

  /// Auto-categorize uncategorized expenses
  Future<int> autoCategorizeExpenses(int householdId) async {
    final db = await _databaseService.database;

    // Get uncategorized expenses
    final uncategorized = await db.query(
      'household_expenses',
      where:
          'household_id = ? AND (category IS NULL OR category = ? OR category = ?)',
      whereArgs: [householdId, '', 'Uncategorized'],
    );

    int categorizedCount = 0;

    for (final expense in uncategorized) {
      final prediction = await predictCategory(
        description: expense['description'] as String? ?? '',
        amount: expense['amount'] as double?,
        date: DateTime.parse(expense['date'] as String),
        householdId: householdId,
      );

      // Only auto-categorize if confidence is high enough
      if (prediction.confidence >= 0.6) {
        await db.update(
          'household_expenses',
          {'category': prediction.primaryCategory},
          where: 'id = ?',
          whereArgs: [expense['id']],
        );
        categorizedCount++;
      }
    }

    return categorizedCount;
  }

  /// Learn from user corrections
  Future<void> learnFromCorrection({
    required String description,
    required String predictedCategory,
    required String correctedCategory,
    double? amount,
  }) async {
    // Store learning data for future improvements
    final db = await _databaseService.database;

    await db.insert('category_learning', {
      'description': description,
      'predicted_category': predictedCategory,
      'corrected_category': correctedCategory,
      'amount': amount,
      'learned_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get category suggestions based on partial input
  Future<List<String>> suggestCategories(String partialDescription) async {
    final suggestions = <String, double>{};
    final lowerDescription = partialDescription.toLowerCase();

    // Check keyword matches
    _categoryKeywords.forEach((category, keywords) {
      for (final keyword in keywords) {
        if (keyword.contains(lowerDescription) ||
            lowerDescription.contains(keyword)) {
          suggestions[category] = (suggestions[category] ?? 0) + 1;
        }
      }
    });

    // Sort by relevance
    final sortedCategories = suggestions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedCategories.take(5).map((e) => e.key).toList();
  }

  /// Calculate keyword-based scores
  Map<String, double> _calculateKeywordScores(String description) {
    final scores = <String, double>{};
    final lowerDescription = description.toLowerCase();

    _categoryKeywords.forEach((category, keywords) {
      double score = 0;
      for (final keyword in keywords) {
        if (lowerDescription.contains(keyword)) {
          // Exact word match gets higher score
          final words = lowerDescription.split(RegExp(r'\s+'));
          if (words.contains(keyword)) {
            score += 2.0;
          } else {
            score += 1.0;
          }
        }
      }
      if (score > 0) {
        scores[category] = score;
      }
    });

    return scores;
  }

  /// Calculate amount-based scores
  Map<String, double> _calculateAmountScores(double amount) {
    final scores = <String, double>{};

    _categoryAmountPatterns.forEach((category, range) {
      if (amount >= range.min && amount <= range.max) {
        // Score based on how close to typical range
        final midpoint = (range.min + range.max) / 2;
        final distance = (amount - midpoint).abs();
        final normalizedDistance = distance / (range.max - range.min);
        scores[category] = 1.0 - normalizedDistance;
      }
    });

    return scores;
  }

  /// Calculate historical pattern scores
  Future<Map<String, double>> _calculateHistoricalScores(
    int householdId,
    String description,
    double? amount,
  ) async {
    final db = await _databaseService.database;
    final scores = <String, double>{};

    // Find similar past expenses
    final words = description.toLowerCase().split(RegExp(r'\s+'));
    if (words.isEmpty) return scores;

    final similarExpenses = await db.query(
      'household_expenses',
      where: 'household_id = ? AND category IS NOT NULL AND category != ?',
      whereArgs: [householdId, 'Uncategorized'],
      limit: 100,
      orderBy: 'date DESC',
    );

    for (final expense in similarExpenses) {
      final expenseDesc =
          (expense['description'] as String? ?? '').toLowerCase();
      final category = expense['category'] as String?;

      if (category == null || category.isEmpty) continue;

      // Calculate similarity
      double similarity = 0;
      for (final word in words) {
        if (word.length > 2 && expenseDesc.contains(word)) {
          similarity += 1;
        }
      }

      if (similarity > 0) {
        scores[category] = (scores[category] ?? 0) + similarity;
      }

      // Amount similarity bonus
      if (amount != null && expense['amount'] != null) {
        final expenseAmount = expense['amount'] as double;
        final amountDiff = (amount - expenseAmount).abs();
        if (amountDiff < amount * 0.2) {
          // Within 20%
          scores[category] = (scores[category] ?? 0) + 0.5;
        }
      }
    }

    return scores;
  }

  /// Calculate time-based pattern scores
  Map<String, double> _calculateTimeBasedScores(DateTime date) {
    final scores = <String, double>{};
    final hour = date.hour;
    final dayOfWeek = date.weekday;

    // Morning patterns (6-10 AM)
    if (hour >= 6 && hour <= 10) {
      scores['Dining'] = 0.5; // Breakfast
      scores['Transportation'] = 0.3; // Commute
    }

    // Lunch patterns (12-2 PM)
    if (hour >= 12 && hour <= 14) {
      scores['Dining'] = 0.7;
    }

    // Evening patterns (5-9 PM)
    if (hour >= 17 && hour <= 21) {
      scores['Dining'] = 0.6;
      scores['Entertainment'] = 0.4;
      scores['Shopping'] = 0.3;
    }

    // Weekend patterns
    if (dayOfWeek >= 6) {
      // Saturday, Sunday
      scores['Entertainment'] = (scores['Entertainment'] ?? 0) + 0.3;
      scores['Shopping'] = (scores['Shopping'] ?? 0) + 0.3;
      scores['Dining'] = (scores['Dining'] ?? 0) + 0.2;
    }

    // Weekday patterns
    if (dayOfWeek >= 1 && dayOfWeek <= 5) {
      scores['Transportation'] = (scores['Transportation'] ?? 0) + 0.2;
      scores['Groceries'] = (scores['Groceries'] ?? 0) + 0.1;
    }

    return scores;
  }

  /// Merge scores with weight
  void _mergeScores(Map<String, double> target, Map<String, double> source,
      {double weight = 1.0,}) {
    source.forEach((category, score) {
      target[category] = (target[category] ?? 0) + (score * weight);
    });
  }

  /// Get categorization accuracy stats
  Future<CategorizationStats> getAccuracyStats(int householdId) async {
    final db = await _databaseService.database;

    final total = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM household_expenses
      WHERE household_id = ?
    ''',
      [householdId],
    );

    final categorized = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM household_expenses
      WHERE household_id = ? AND category IS NOT NULL AND category != ? AND category != ?
    ''',
      [householdId, '', 'Uncategorized'],
    );

    final totalCount = (total.first['count'] as int?) ?? 0;
    final categorizedCount = (categorized.first['count'] as int?) ?? 0;

    return CategorizationStats(
      totalExpenses: totalCount,
      categorizedExpenses: categorizedCount,
      uncategorizedExpenses: totalCount - categorizedCount,
      categorizationRate:
          totalCount > 0 ? (categorizedCount / totalCount) * 100 : 0,
    );
  }
}

/// Amount range for category patterns
class AmountRange {
  AmountRange({required this.min, required this.max});
  final double min;
  final double max;
}

/// Category prediction result
class CategoryPrediction {
  CategoryPrediction({
    required this.primaryCategory,
    required this.confidence,
    required this.alternatives,
  });
  final String primaryCategory;
  final double confidence;
  final List<CategoryScore> alternatives;
}

/// Category score
class CategoryScore {
  CategoryScore({
    required this.category,
    required this.confidence,
  });
  final String category;
  final double confidence;
}

/// Categorization statistics
class CategorizationStats {
  CategorizationStats({
    required this.totalExpenses,
    required this.categorizedExpenses,
    required this.uncategorizedExpenses,
    required this.categorizationRate,
  });
  final int totalExpenses;
  final int categorizedExpenses;
  final int uncategorizedExpenses;
  final double categorizationRate;
}
