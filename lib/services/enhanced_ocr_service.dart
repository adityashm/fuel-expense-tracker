import 'package:flutter/foundation.dart';

import '../models/ocr_result.dart';
import 'receipt_ocr_service.dart';

/// Enhanced OCR Service V2.5 - Multi-receipt and smart validation
class EnhancedOCRService {
  factory EnhancedOCRService() => _instance;
  EnhancedOCRService._internal();
  static final EnhancedOCRService _instance = EnhancedOCRService._internal();

  final ReceiptOCRService _ocrService = ReceiptOCRService();
  final List<OCRCorrection> _userCorrections = [];

  /// Process multiple receipt images in batch
  Future<List<OCRResult>> processMultipleReceipts(
      List<String> imagePaths,) async {
    final results = <OCRResult>[];

    for (int i = 0; i < imagePaths.length; i++) {
      try {
        debugPrint('Processing receipt ${i + 1}/${imagePaths.length}...');
        final result = await _ocrService.processReceiptImage(imagePaths[i]);
        results.add(result);
      } catch (e) {
        debugPrint('Error processing receipt ${i + 1}: $e');
        results.add(
          OCRResult(
            rawText: 'Failed to process receipt: $e',
            items: const [],
            confidence: 0,
            fieldConfidences: const {},
          ),
        );
      }
    }

    return results;
  }

  /// Smart validation of OCR results with learned corrections
  Future<OCRValidationResult> validateOCRResult(OCRResult result) async {
    final issues = <String>[];
    final suggestions = <String, dynamic>{};

    // Check merchant name
    if (result.merchantName == null || result.merchantName!.isEmpty) {
      issues.add('Merchant name not detected');
    } else {
      // Apply learned corrections
      final correctedMerchant = _applyLearnedCorrections(
        'merchant',
        result.merchantName!,
      );
      if (correctedMerchant != result.merchantName) {
        suggestions['merchant'] = correctedMerchant;
      }
    }

    // Check amount
    if (result.amount == null || result.amount! <= 0) {
      issues.add('Amount not detected or invalid');
    } else {
      // Check if amount is reasonable
      if (result.amount! > 100000) {
        issues.add('Amount seems unusually high (₹${result.amount})');
      }
    }

    // Check date
    if (result.date == null) {
      issues.add('Date not detected');
      suggestions['date'] = DateTime.now();
    } else {
      // Check if date is in future
      if (result.date!.isAfter(DateTime.now())) {
        issues.add('Date is in the future');
        suggestions['date'] = DateTime.now();
      }

      // Check if date is too old
      if (DateTime.now().difference(result.date!).inDays > 365) {
        issues.add('Date is more than 1 year old');
      }
    }

    // Check confidence
    if (result.confidence < 0.6) {
      issues.add(
          'Low OCR confidence (${(result.confidence * 100).toStringAsFixed(0)}%)',);
    }

    // Check for duplicate
    // TODO: Query database for similar receipts

    return OCRValidationResult(
      isValid: issues.isEmpty,
      issues: issues,
      suggestions: suggestions,
      overallScore: _calculateValidationScore(result, issues),
    );
  }

  /// Calculate validation score (0-1)
  double _calculateValidationScore(OCRResult result, List<String> issues) {
    double score = 1.0;

    // Deduct for each issue
    score -= issues.length * 0.15;

    // Factor in OCR confidence
    score *= result.confidence;

    // Bonus for complete data
    if (result.merchantName != null &&
        result.amount != null &&
        result.date != null) {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Learn from user corrections to improve future OCR
  void learnFromCorrection({
    required String field,
    required String ocrValue,
    required String correctedValue,
  }) {
    _userCorrections.add(
      OCRCorrection(
        field: field,
        ocrValue: ocrValue,
        correctedValue: correctedValue,
        timestamp: DateTime.now(),
      ),
    );

    // Keep only last 100 corrections
    if (_userCorrections.length > 100) {
      _userCorrections.removeAt(0);
    }

    debugPrint('Learned correction: $field: "$ocrValue" → "$correctedValue"');
  }

  /// Apply learned corrections to OCR output
  String _applyLearnedCorrections(String field, String value) {
    // Find exact match corrections
    for (final correction in _userCorrections.reversed) {
      if (correction.field == field &&
          correction.ocrValue.toLowerCase() == value.toLowerCase()) {
        return correction.correctedValue;
      }
    }

    // Find fuzzy match corrections (Levenshtein distance)
    for (final correction in _userCorrections.reversed) {
      if (correction.field == field) {
        final similarity = _calculateSimilarity(
          correction.ocrValue.toLowerCase(),
          value.toLowerCase(),
        );
        if (similarity > 0.85) {
          return correction.correctedValue;
        }
      }
    }

    return value;
  }

  /// Calculate string similarity (0-1) using Levenshtein distance
  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final len1 = s1.length;
    final len2 = s2.length;
    final maxLen = len1 > len2 ? len1 : len2;

    final distance = _levenshteinDistance(s1, s2);
    return 1.0 - (distance / maxLen);
  }

  /// Calculate Levenshtein distance between two strings
  int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;

    final matrix = List.generate(
      len1 + 1,
      (i) => List.filled(len2 + 1, 0),
    );

    for (int i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[len1][len2];
  }

  /// Get receipt templates for common merchant formats
  ReceiptTemplate? getTemplateForMerchant(String merchantName) {
    // Common Indian retail templates
    final templates = {
      'reliance': ReceiptTemplate(
        name: 'Reliance Retail',
        amountPattern: r'TOTAL.*?(\d+\.?\d*)',
        datePattern: r'(\d{2}/\d{2}/\d{4})',
        itemsPattern: r'(\d+)\s+([A-Z\s]+)\s+(\d+\.?\d*)',
      ),
      'dmart': ReceiptTemplate(
        name: 'DMart',
        amountPattern: r'NET TOTAL.*?(\d+\.?\d*)',
        datePattern: r'DATE:\s*(\d{2}-\d{2}-\d{4})',
        itemsPattern: r'(\d+)\s+([A-Z\s]+)\s+(\d+\.?\d*)',
      ),
      'bigbazaar': ReceiptTemplate(
        name: 'Big Bazaar',
        amountPattern: r'GRAND TOTAL.*?(\d+\.?\d*)',
        datePattern: r'(\d{2}/\d{2}/\d{4})',
        itemsPattern: r'([A-Z\s]+)\s+(\d+\.?\d*)',
      ),
    };

    final merchantLower = merchantName.toLowerCase();
    for (final entry in templates.entries) {
      if (merchantLower.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Apply merchant-specific template to improve accuracy
  Future<OCRResult> applyTemplate(
    OCRResult result,
    ReceiptTemplate template,
  ) async {
    final rawText = result.rawText;

    // Extract using template patterns
    final amount = _extractUsingPattern(rawText, template.amountPattern);
    final date = _extractUsingPattern(rawText, template.datePattern);

    return OCRResult(
      rawText: rawText,
      merchantName: result.merchantName,
      amount: amount ?? result.amount,
      date: date != null ? _parseDate(date) : result.date,
      items: result.items,
      taxAmount: result.taxAmount,
      confidence: (result.confidence * 1.1)
          .clamp(0.0, 1.0), // Boost confidence with template
      fieldConfidences: result.fieldConfidences,
    );
  }

  /// Extract value using regex pattern
  dynamic _extractUsingPattern(String text, String pattern) {
    final regex = RegExp(pattern, caseSensitive: false);
    final match = regex.firstMatch(text);
    if (match != null && match.groupCount > 0) {
      return match.group(1);
    }
    return null;
  }

  /// Parse date string to DateTime
  DateTime? _parseDate(String dateStr) {
    try {
      // Try DD/MM/YYYY
      final parts = dateStr.split(RegExp('[/-]'));
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    } catch (_) {}
    return null;
  }

  /// Get correction history
  List<OCRCorrection> getCorrectionHistory() =>
      List.unmodifiable(_userCorrections);

  /// Clear correction history
  void clearCorrectionHistory() {
    _userCorrections.clear();
  }

  /// Get OCR statistics
  OCRStatistics getStatistics() {
    final now = DateTime.now();
    final last30Days = now.subtract(const Duration(days: 30));

    final recentCorrections =
        _userCorrections.where((c) => c.timestamp.isAfter(last30Days)).length;

    return OCRStatistics(
      totalCorrections: _userCorrections.length,
      recentCorrections: recentCorrections,
      mostCorrectedField: _getMostCorrectedField(),
      accuracyImprovement: _calculateAccuracyImprovement(),
    );
  }

  String _getMostCorrectedField() {
    if (_userCorrections.isEmpty) return 'none';

    final fieldCounts = <String, int>{};
    for (final correction in _userCorrections) {
      fieldCounts[correction.field] = (fieldCounts[correction.field] ?? 0) + 1;
    }

    return fieldCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  double _calculateAccuracyImprovement() {
    // Simple heuristic: more corrections = learning more patterns
    return (_userCorrections.length * 0.01).clamp(0.0, 0.5);
  }
}

/// OCR Correction record
class OCRCorrection {
  OCRCorrection({
    required this.field,
    required this.ocrValue,
    required this.correctedValue,
    required this.timestamp,
  });

  final String field;
  final String ocrValue;
  final String correctedValue;
  final DateTime timestamp;
}

/// OCR Validation result
class OCRValidationResult {
  OCRValidationResult({
    required this.isValid,
    required this.issues,
    required this.suggestions,
    required this.overallScore,
  });

  final bool isValid;
  final List<String> issues;
  final Map<String, dynamic> suggestions;
  final double overallScore;
}

/// Receipt template for merchant-specific parsing
class ReceiptTemplate {
  ReceiptTemplate({
    required this.name,
    required this.amountPattern,
    required this.datePattern,
    required this.itemsPattern,
  });

  final String name;
  final String amountPattern;
  final String datePattern;
  final String itemsPattern;
}

/// OCR Statistics
class OCRStatistics {
  OCRStatistics({
    required this.totalCorrections,
    required this.recentCorrections,
    required this.mostCorrectedField,
    required this.accuracyImprovement,
  });

  final int totalCorrections;
  final int recentCorrections;
  final String mostCorrectedField;
  final double accuracyImprovement;

  String get improvementPercentage =>
      '${(accuracyImprovement * 100).toStringAsFixed(1)}%';
}
