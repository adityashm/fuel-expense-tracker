import 'package:flutter/foundation.dart';

/// Voice Entry Service for V2.5
/// Uses on-device speech recognition for hands-free expense entry
///
/// Supports commands like:
/// - "Add 500 rupees for groceries"
/// - "Fuel expense 2000 rupees"
/// - "Split dinner 1500 with family"
class VoiceEntryService {
  VoiceEntryService._internal();
  factory VoiceEntryService() => _instance;
  static final VoiceEntryService _instance = VoiceEntryService._internal();

  static VoiceEntryService get instance => _instance;

  // Callback for when parsing is complete
  Function(ParsedVoiceExpense)? onExpenseParsed;
  Function(String)? onError;
  Function(bool)? onListeningStateChanged;

  // Category keyword mappings
  static const Map<String, List<String>> categoryKeywords = {
    'Fuel': [
      'fuel',
      'petrol',
      'diesel',
      'gas',
      'cng',
      'lpg',
      'ev charge',
      'charging',
    ],
    'Groceries': [
      'grocery',
      'groceries',
      'vegetables',
      'fruits',
      'sabzi',
      'kirana',
    ],
    'Food': [
      'food',
      'restaurant',
      'dinner',
      'lunch',
      'breakfast',
      'snacks',
      'coffee',
      'tea',
      'eating',
    ],
    'Transport': [
      'uber',
      'ola',
      'auto',
      'rickshaw',
      'taxi',
      'bus',
      'metro',
      'train',
      'travel',
    ],
    'Shopping': ['shopping', 'clothes', 'amazon', 'flipkart', 'online', 'mall'],
    'Utilities': [
      'electricity',
      'water',
      'gas bill',
      'internet',
      'wifi',
      'mobile',
      'recharge',
      'bill',
    ],
    'Healthcare': [
      'medical',
      'doctor',
      'medicine',
      'hospital',
      'health',
      'pharmacy',
      'clinic',
    ],
    'Entertainment': [
      'movie',
      'cinema',
      'netflix',
      'spotify',
      'subscription',
      'game',
    ],
    'Education': [
      'school',
      'college',
      'tuition',
      'books',
      'course',
      'class',
      'fees',
    ],
    'Maintenance': ['repair', 'service', 'maintenance', 'mechanic', 'spare'],
  };

  // Hindi/Regional keywords for amounts
  static const Map<String, int> hindiNumberWords = {
    'ek': 1,
    'do': 2,
    'teen': 3,
    'char': 4,
    'paanch': 5,
    'chhe': 6,
    'saat': 7,
    'aath': 8,
    'nau': 9,
    'das': 10,
    'bees': 20,
    'tees': 30,
    'chaalis': 40,
    'pachaas': 50,
    'saath': 60,
    'sattar': 70,
    'assi': 80,
    'nabbe': 90,
    'sau': 100,
    'hazaar': 1000,
    'lakh': 100000,
  };

  /// Parse voice text into expense components
  ParsedVoiceExpense parseVoiceText(String text) {
    debugPrint('VoiceEntry: Parsing text: "$text"');

    final lowerText = text.toLowerCase().trim();

    // Extract amount
    final amount = _extractAmount(lowerText);

    // Extract category
    final category = _extractCategory(lowerText);

    // Extract merchant (if mentioned)
    final merchant = _extractMerchant(lowerText);

    // Check if it's a split expense
    final isSplit = _checkIfSplit(lowerText);

    // Extract date (today/yesterday/specific date)
    final date = _extractDate(lowerText);

    final parsed = ParsedVoiceExpense(
      amount: amount,
      category: category,
      merchant: merchant,
      isSplit: isSplit,
      date: date,
      rawText: text,
      confidence: _calculateConfidence(amount, category),
    );

    debugPrint(
        'VoiceEntry: Parsed result - amount: $amount, category: $category, merchant: $merchant',);

    return parsed;
  }

  /// Extract amount from voice text
  double? _extractAmount(String text) {
    // Pattern 1: Direct numbers (500, 2000, etc.)
    final numericPattern =
        RegExp(r'(\d+(?:\.\d+)?)\s*(?:rupees?|rs\.?|₹|rupay)?');
    final numericMatch = numericPattern.firstMatch(text);
    if (numericMatch != null) {
      return double.tryParse(numericMatch.group(1) ?? '');
    }

    // Pattern 2: Word-based numbers
    for (final entry in hindiNumberWords.entries) {
      if (text.contains(entry.key)) {
        // Check for compound numbers like "paanch sau" (500)
        if (text.contains('${entry.key} sau')) {
          return entry.value * 100;
        }
        if (text.contains('${entry.key} hazaar')) {
          return entry.value * 1000;
        }
        return entry.value.toDouble();
      }
    }

    // Pattern 3: English word numbers
    final englishNumbers = {
      'one': 1,
      'two': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'ten': 10,
      'twenty': 20,
      'fifty': 50,
      'hundred': 100,
      'thousand': 1000,
    };
    for (final entry in englishNumbers.entries) {
      if (text.contains(entry.key)) {
        return entry.value.toDouble();
      }
    }

    return null;
  }

  /// Extract category from voice text
  String? _extractCategory(String text) {
    for (final entry in categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// Extract merchant name from voice text
  String? _extractMerchant(String text) {
    // Pattern: "at [merchant]" or "from [merchant]" or "to [merchant]"
    final patterns = [
      RegExp(r'(?:at|from|to)\s+([a-zA-Z\s]+?)(?:\s+for|\s+on|\s*$)',
          caseSensitive: false,),
      RegExp(r'(?:paid|paid to)\s+([a-zA-Z\s]+?)(?:\s+for|\s*$)',
          caseSensitive: false,),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final merchant = match.group(1)?.trim();
        if (merchant != null && merchant.isNotEmpty && merchant.length > 2) {
          return _capitalizeMerchant(merchant);
        }
      }
    }

    // Check for known merchant names
    final knownMerchants = [
      'big bazaar',
      'reliance',
      'dmart',
      'more',
      'star bazaar',
      'hp petrol',
      'indian oil',
      'bharat petroleum',
      'shell',
      'swiggy',
      'zomato',
      'amazon',
      'flipkart',
      'myntra',
      'starbucks',
      'cafe coffee day',
      'ccd',
      'barista',
    ];

    for (final merchant in knownMerchants) {
      if (text.contains(merchant)) {
        return _capitalizeMerchant(merchant);
      }
    }

    return null;
  }

  String _capitalizeMerchant(String merchant) {
    return merchant
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : '',
        )
        .join(' ');
  }

  /// Check if expense should be split with family
  bool _checkIfSplit(String text) {
    final splitKeywords = [
      'split',
      'share',
      'divide',
      'baant',
      'half',
      'equal',
    ];
    return splitKeywords.any((keyword) => text.contains(keyword));
  }

  /// Extract date from voice text
  DateTime _extractDate(String text) {
    final now = DateTime.now();

    if (text.contains('yesterday') || text.contains('kal')) {
      return now.subtract(const Duration(days: 1));
    }

    if (text.contains('day before') || text.contains('parso')) {
      return now.subtract(const Duration(days: 2));
    }

    // Check for specific day names
    final dayNames = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    for (int i = 0; i < dayNames.length; i++) {
      if (text.contains(dayNames[i])) {
        // Calculate the date for the mentioned day in the past week
        final currentDay = now.weekday;
        final targetDay = i + 1; // DateTime weekday is 1-7
        int daysAgo = currentDay - targetDay;
        if (daysAgo <= 0) daysAgo += 7;
        return now.subtract(Duration(days: daysAgo));
      }
    }

    return now; // Default to today
  }

  /// Calculate confidence score based on parsed data
  double _calculateConfidence(double? amount, String? category) {
    double confidence = 0.0;

    if (amount != null && amount > 0) {
      confidence += 0.5;
    }

    if (category != null && category.isNotEmpty) {
      confidence += 0.5;
    }

    return confidence;
  }

  /// Check if the voice command is a query (not adding expense)
  VoiceQueryType? parseQuery(String text) {
    final lowerText = text.toLowerCase();

    // Total/summary queries
    if (lowerText.contains('total') ||
        lowerText.contains('how much') ||
        lowerText.contains('kitna')) {
      if (lowerText.contains('today') || lowerText.contains('aaj')) {
        return VoiceQueryType.todayTotal;
      }
      if (lowerText.contains('week') || lowerText.contains('hafta')) {
        return VoiceQueryType.weekTotal;
      }
      if (lowerText.contains('month') || lowerText.contains('mahina')) {
        return VoiceQueryType.monthTotal;
      }

      // Category-specific total
      for (final category in categoryKeywords.keys) {
        if (lowerText.contains(category.toLowerCase())) {
          return VoiceQueryType.categoryTotal;
        }
      }

      return VoiceQueryType.todayTotal;
    }

    // Show expenses queries
    if (lowerText.contains('show') ||
        lowerText.contains('list') ||
        lowerText.contains('dikha')) {
      return VoiceQueryType.showExpenses;
    }

    return null;
  }

  /// Get suggested voice commands for help
  List<String> getSuggestedCommands() {
    return [
      'Add 500 rupees for groceries',
      'Fuel expense 2000 at HP Petrol',
      'Split dinner 1500 with family',
      'Add 200 for coffee at Starbucks',
      'Show today\'s total',
      'How much spent on fuel this month?',
      'Yesterday\'s expenses',
    ];
  }
}

/// Parsed voice expense data
class ParsedVoiceExpense {
  ParsedVoiceExpense({
    this.amount,
    this.category,
    this.merchant,
    this.isSplit = false,
    required this.date,
    required this.rawText,
    this.confidence = 0.0,
  });

  final double? amount;
  final String? category;
  final String? merchant;
  final bool isSplit;
  final DateTime date;
  final String rawText;
  final double confidence;

  bool get isValid => amount != null && amount! > 0;
  bool get hasCategory => category != null && category!.isNotEmpty;
  bool get hasMerchant => merchant != null && merchant!.isNotEmpty;
  bool get isHighConfidence => confidence >= 0.7;

  @override
  String toString() {
    return 'ParsedVoiceExpense(amount: $amount, category: $category, merchant: $merchant, split: $isSplit, confidence: $confidence)';
  }
}

/// Voice query types for information retrieval
enum VoiceQueryType {
  todayTotal,
  weekTotal,
  monthTotal,
  categoryTotal,
  showExpenses,
}
