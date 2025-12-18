import 'package:flutter/foundation.dart';

/// OCR Validator Service for V2.5
/// Validates and cleans OCR results with rule-based checks
/// Improves data quality with confidence scoring
class OCRValidatorService {
  factory OCRValidatorService() => _instance;
  OCRValidatorService._internal();
  static final OCRValidatorService _instance = OCRValidatorService._internal();

  static OCRValidatorService get instance => _instance;

  // Store user corrections for learning
  final Map<String, String> _merchantCorrections = {};
  final Map<String, String> _categoryCorrections = {};

  /// Validate complete OCR result
  ValidationResult validate(OCRResult result) {
    final issues = <ValidationIssue>[];
    double confidence = 1.0;

    // Validate amount
    final amountValidation = _validateAmount(result.amount);
    if (!amountValidation.isValid) {
      issues.add(amountValidation.issue!);
      confidence -= 0.3;
    }

    // Validate date
    final dateValidation = _validateDate(result.date);
    if (!dateValidation.isValid) {
      issues.add(dateValidation.issue!);
      confidence -= 0.2;
    }

    // Validate GST number if present
    if (result.gstNumber != null) {
      final gstValidation = _validateGST(result.gstNumber!);
      if (!gstValidation.isValid) {
        issues.add(gstValidation.issue!);
        confidence -= 0.1;
      }
    }

    // Validate merchant name
    final merchantValidation = _validateMerchant(result.merchant);
    if (!merchantValidation.isValid) {
      issues.add(merchantValidation.issue!);
      confidence -= 0.1;
    }

    // Check item sum vs total (if items present)
    if (result.items.isNotEmpty) {
      final sumValidation = _validateItemSum(result.items, result.amount);
      if (!sumValidation.isValid) {
        issues.add(sumValidation.issue!);
        confidence -= 0.15;
      }
    }

    return ValidationResult(
      isValid: issues.isEmpty,
      confidence: confidence.clamp(0.0, 1.0),
      issues: issues,
      correctedResult: _applyCorrections(result),
    );
  }

  /// Validate amount
  _FieldValidation _validateAmount(double? amount) {
    if (amount == null) {
      return _FieldValidation(
        isValid: false,
        issue: ValidationIssue(
          field: 'amount',
          message: 'Amount not detected',
          severity: IssueSeverity.error,
          suggestion: 'Please enter the amount manually',
        ),
      );
    }

    if (amount <= 0) {
      return _FieldValidation(
        isValid: false,
        issue: ValidationIssue(
          field: 'amount',
          message: 'Invalid amount: ₹$amount',
          severity: IssueSeverity.error,
          suggestion: 'Amount must be positive',
        ),
      );
    }

    if (amount > 1000000) {
      return _FieldValidation(
        isValid: false,
        issue: ValidationIssue(
          field: 'amount',
          message: 'Amount seems unusually high: ₹$amount',
          severity: IssueSeverity.warning,
          suggestion: 'Please verify the amount',
        ),
      );
    }

    // Check for common OCR errors (e.g., reading 1 as 7)
    final amountString = amount.toString();
    if (amountString.contains('77') || amountString.contains('11')) {
      return _FieldValidation(
        isValid: true,
        issue: ValidationIssue(
          field: 'amount',
          message: 'Amount may have OCR errors',
          severity: IssueSeverity.info,
          suggestion: 'Double-check digits 1 and 7',
        ),
      );
    }

    return _FieldValidation(isValid: true);
  }

  /// Validate date
  _FieldValidation _validateDate(DateTime? date) {
    if (date == null) {
      return _FieldValidation(
        isValid: false,
        issue: ValidationIssue(
          field: 'date',
          message: 'Date not detected',
          severity: IssueSeverity.warning,
          suggestion: 'Using current date',
        ),
      );
    }

    final now = DateTime.now();

    // Future date check
    if (date.isAfter(now.add(const Duration(days: 1)))) {
      return _FieldValidation(
        isValid: false,
        issue: ValidationIssue(
          field: 'date',
          message: 'Future date detected: ${_formatDate(date)}',
          severity: IssueSeverity.error,
          suggestion: 'Please correct the date',
        ),
      );
    }

    // Very old date check (more than 1 year)
    if (date.isBefore(now.subtract(const Duration(days: 365)))) {
      return _FieldValidation(
        isValid: false,
        issue: ValidationIssue(
          field: 'date',
          message: 'Date is more than 1 year old',
          severity: IssueSeverity.warning,
          suggestion: 'Please verify the date',
        ),
      );
    }

    return _FieldValidation(isValid: true);
  }

  /// Validate GST number format
  _FieldValidation _validateGST(String gstNumber) {
    // Indian GST format: 22AAAAA0000A1Z5
    // 2 digits state code + 10 character PAN + 1 entity number + 1 Z + 1 check digit
    final gstRegex = RegExp(
      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
      caseSensitive: false,
    );

    final cleanGST = gstNumber.replaceAll(RegExp(r'\s+'), '').toUpperCase();

    if (!gstRegex.hasMatch(cleanGST)) {
      return _FieldValidation(
        isValid: false,
        issue: ValidationIssue(
          field: 'gstNumber',
          message: 'Invalid GST format: $gstNumber',
          severity: IssueSeverity.warning,
          suggestion: 'GST format should be like 22AAAAA0000A1Z5',
        ),
      );
    }

    // Validate state code (01-37 for Indian states)
    final stateCode = int.tryParse(cleanGST.substring(0, 2));
    if (stateCode == null || stateCode < 1 || stateCode > 37) {
      return _FieldValidation(
        isValid: false,
        issue: ValidationIssue(
          field: 'gstNumber',
          message: 'Invalid state code in GST',
          severity: IssueSeverity.warning,
          suggestion: 'State code should be between 01-37',
        ),
      );
    }

    return _FieldValidation(isValid: true);
  }

  /// Validate merchant name
  _FieldValidation _validateMerchant(String? merchant) {
    if (merchant == null || merchant.isEmpty) {
      return _FieldValidation(
        isValid: true, // Merchant is optional
      );
    }

    // Check for garbage characters (allow letters, numbers, spaces, dash, dot, ampersand, apostrophe)
    if (RegExp(r"[^\w\s\-\.&']").hasMatch(merchant)) {
      return _FieldValidation(
        isValid: false,
        issue: ValidationIssue(
          field: 'merchant',
          message: 'Merchant name contains invalid characters',
          severity: IssueSeverity.info,
          suggestion: 'Please verify merchant name',
        ),
      );
    }

    // Check for too short names (likely OCR error)
    if (merchant.length < 2) {
      return _FieldValidation(
        isValid: false,
        issue: ValidationIssue(
          field: 'merchant',
          message: 'Merchant name too short',
          severity: IssueSeverity.info,
          suggestion: 'Please enter complete merchant name',
        ),
      );
    }

    return _FieldValidation(isValid: true);
  }

  /// Validate item prices sum against total
  _FieldValidation _validateItemSum(List<OCRItem> items, double? total) {
    if (total == null) return _FieldValidation(isValid: true);

    final itemSum = items.fold<double>(
      0,
      (sum, item) => sum + (item.price ?? 0) * (item.quantity ?? 1),
    );

    // Allow 10% tolerance for taxes, discounts, etc.
    final tolerance = total * 0.1;
    final difference = (itemSum - total).abs();

    if (difference > tolerance && difference > 10) {
      return _FieldValidation(
        isValid: false,
        issue: ValidationIssue(
          field: 'items',
          message:
              'Item total (₹${itemSum.toStringAsFixed(0)}) doesn\'t match receipt total (₹${total.toStringAsFixed(0)})',
          severity: IssueSeverity.warning,
          suggestion: 'Check for missing items or tax',
        ),
      );
    }

    return _FieldValidation(isValid: true);
  }

  /// Apply learned corrections to result
  OCRResult _applyCorrections(OCRResult result) {
    String? correctedMerchant = result.merchant;

    // Apply merchant corrections
    if (result.merchant != null &&
        _merchantCorrections.containsKey(result.merchant!.toLowerCase())) {
      correctedMerchant = _merchantCorrections[result.merchant!.toLowerCase()];
    }

    // Clean up amount (remove common OCR artifacts)
    double? correctedAmount = result.amount;
    if (correctedAmount != null) {
      // Round to 2 decimal places
      correctedAmount = double.parse(correctedAmount.toStringAsFixed(2));
    }

    return OCRResult(
      amount: correctedAmount,
      date: result.date,
      merchant: correctedMerchant,
      category: result.category,
      gstNumber: result.gstNumber,
      items: result.items,
      rawText: result.rawText,
    );
  }

  /// Learn from user correction
  void learnCorrection(String field, String original, String corrected) {
    debugPrint(
        'OCRValidator: Learning correction - $field: "$original" → "$corrected"',);

    switch (field) {
      case 'merchant':
        _merchantCorrections[original.toLowerCase()] = corrected;
        break;
      case 'category':
        _categoryCorrections[original.toLowerCase()] = corrected;
        break;
    }
  }

  /// Get confidence level label
  String getConfidenceLabel(double confidence) {
    if (confidence >= 0.9) return 'High';
    if (confidence >= 0.7) return 'Medium';
    if (confidence >= 0.5) return 'Low';
    return 'Very Low';
  }

  /// Get confidence color
  String getConfidenceColor(double confidence) {
    if (confidence >= 0.9) return 'green';
    if (confidence >= 0.7) return 'amber';
    return 'red';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Clean and format OCR text
  String cleanOCRText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s₹\.\,\-\/]'), '')
        .trim();
  }

  /// Extract amount from OCR text
  double? extractAmount(String text) {
    // Pattern 1: ₹ symbol followed by number
    final rupeePattern = RegExp(r'₹\s*(\d+(?:,\d{3})*(?:\.\d{1,2})?)');
    var match = rupeePattern.firstMatch(text);
    if (match != null) {
      return double.tryParse(match.group(1)!.replaceAll(',', ''));
    }

    // Pattern 2: "Total" followed by number
    final totalPattern = RegExp(
        r'(?:total|amount|grand\s*total|net\s*amount)[:\s]*₹?\s*(\d+(?:,\d{3})*(?:\.\d{1,2})?)',
        caseSensitive: false,);
    match = totalPattern.firstMatch(text);
    if (match != null) {
      return double.tryParse(match.group(1)!.replaceAll(',', ''));
    }

    // Pattern 3: Just a large number at end of text (likely total)
    final numberPattern = RegExp(r'(\d+(?:,\d{3})*(?:\.\d{1,2})?)(?:\s*$)');
    match = numberPattern.firstMatch(text);
    if (match != null) {
      return double.tryParse(match.group(1)!.replaceAll(',', ''));
    }

    return null;
  }

  /// Extract date from OCR text
  DateTime? extractDate(String text) {
    // Pattern 1: DD/MM/YYYY or DD-MM-YYYY
    final datePattern1 = RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})');
    var match = datePattern1.firstMatch(text);
    if (match != null) {
      final day = int.tryParse(match.group(1)!);
      final month = int.tryParse(match.group(2)!);
      var year = int.tryParse(match.group(3)!);

      if (day != null && month != null && year != null) {
        if (year < 100) year += 2000; // Convert 24 to 2024
        try {
          return DateTime(year, month, day);
        } catch (e) {
          // Invalid date
        }
      }
    }

    // Pattern 2: Month name (Jan 15, 2024 or 15 Jan 2024)
    final monthNames = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    for (int i = 0; i < monthNames.length; i++) {
      final monthPattern = RegExp(
          '(\\d{1,2})\\s*${monthNames[i]}[a-z]*\\s*(\\d{2,4})',
          caseSensitive: false,);
      match = monthPattern.firstMatch(text);
      if (match != null) {
        final day = int.tryParse(match.group(1)!);
        var year = int.tryParse(match.group(2)!);

        if (day != null && year != null) {
          if (year < 100) year += 2000;
          try {
            return DateTime(year, i + 1, day);
          } catch (e) {
            // Invalid date
          }
        }
      }
    }

    return null;
  }
}

/// OCR Result data class
class OCRResult {
  OCRResult({
    this.amount,
    DateTime? date,
    this.merchant,
    this.category,
    this.gstNumber,
    this.items = const [],
    this.rawText = '',
  }) : date = date ?? DateTime.now();
  final double? amount;
  final DateTime date;
  final String? merchant;
  final String? category;
  final String? gstNumber;
  final List<OCRItem> items;
  final String rawText;
}

/// OCR Item (line item from receipt)
class OCRItem {
  OCRItem({
    this.name,
    this.price,
    this.quantity,
  });
  final String? name;
  final double? price;
  final int? quantity;
}

/// Validation result
class ValidationResult {
  ValidationResult({
    required this.isValid,
    required this.confidence,
    required this.issues,
    required this.correctedResult,
  });
  final bool isValid;
  final double confidence;
  final List<ValidationIssue> issues;
  final OCRResult correctedResult;

  bool get hasErrors => issues.any((i) => i.severity == IssueSeverity.error);
  bool get hasWarnings =>
      issues.any((i) => i.severity == IssueSeverity.warning);

  List<ValidationIssue> get errors =>
      issues.where((i) => i.severity == IssueSeverity.error).toList();
  List<ValidationIssue> get warnings =>
      issues.where((i) => i.severity == IssueSeverity.warning).toList();
}

/// Validation issue
class ValidationIssue {
  ValidationIssue({
    required this.field,
    required this.message,
    required this.severity,
    this.suggestion,
  });
  final String field;
  final String message;
  final IssueSeverity severity;
  final String? suggestion;
}

enum IssueSeverity {
  error,
  warning,
  info,
}

/// Internal field validation helper
class _FieldValidation {
  _FieldValidation({
    required this.isValid,
    this.issue,
  });
  final bool isValid;
  final ValidationIssue? issue;
}
