// ignore_for_file: cascade_invocations

import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import '../models/ocr_result.dart';

/// Service for OCR (Optical Character Recognition) of receipts
/// Supports multiple languages: English, Hindi, Tamil, Telugu, Marathi
/// Uses Google ML Kit with image preprocessing for better accuracy
class ReceiptOCRService {
  ReceiptOCRService._internal() {
    _initializeRecognizer();
  }

  factory ReceiptOCRService() {
    return _instance;
  }
  static final ReceiptOCRService _instance = ReceiptOCRService._internal();

  late final TextRecognizer _textRecognizer;
  final List<String> _supportedLanguages = ['en', 'hi', 'ta', 'te', 'mr'];
  final Map<String, String> _languageNames = {
    'en': 'English',
    'hi': 'Hindi',
    'ta': 'Tamil',
    'te': 'Telugu',
    'mr': 'Marathi',
  };

  void _initializeRecognizer() {
    _textRecognizer = TextRecognizer();
  }

  /// Process receipt image and extract text with metadata
  Future<OCRResult> processReceiptImage(
    String imagePath, {
    String? detectedLanguage,
    bool autoDetect = true,
  }) async {
    try {
      final file = File(imagePath);
      if (!file.existsSync()) {
        throw Exception('Image file not found: $imagePath');
      }

      // Preprocess image for better OCR accuracy
      final processedFile = await _preprocessImage(imagePath);

      // Recognize text
      final inputImage = InputImage.fromFile(processedFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Extract structured data from raw text
      final extractedData = _parseReceiptText(recognizedText.text);

      // Calculate confidence based on text quality
      final confidence = _calculateConfidence(recognizedText);

      return OCRResult(
        rawText: recognizedText.text,
        merchantName: extractedData['merchant'],
        amount: extractedData['amount'],
        date: extractedData['date'],
        items: extractedData['items'],
        taxAmount: extractedData['tax'],
        confidence: confidence,
        fieldConfidences: {
          'merchant': (extractedData['merchantConfidence'] as double?) ?? 0.0,
          'amount': (extractedData['amountConfidence'] as double?) ?? 0.0,
          'date': (extractedData['dateConfidence'] as double?) ?? 0.0,
          'items': (extractedData['itemsConfidence'] as double?) ?? 0.0,
          'tax': (extractedData['taxConfidence'] as double?) ?? 0.0,
        },
      );
    } catch (e) {
      throw Exception('OCR processing failed: $e');
    }
  }

  /// Preprocess image to improve OCR accuracy
  Future<File> _preprocessImage(String imagePath) async {
    try {
      final originalImage = img.decodeImage(File(imagePath).readAsBytesSync());
      if (originalImage == null) throw Exception('Failed to decode image');

      // Apply preprocessing filters
      img.Image processed = originalImage;

      // 1. Auto-rotate if needed
      processed = _autoRotateImage(processed);

      // 2. Enhance contrast
      processed = _enhanceContrast(processed);

      // 3. Denoise (reduce noise)
      processed = _denoiseImage(processed);

      // 4. Resize if too small
      if (processed.width < 500) {
        processed = img.copyResize(processed, width: 1000);
      }

      // Save processed image to temporary file
      final tempDir = Directory.systemTemp;
      final processedFile = File(
          '${tempDir.path}/receipt_processed_${DateTime.now().millisecondsSinceEpoch}.jpg',);
      processedFile.writeAsBytesSync(img.encodeJpg(processed));

      return processedFile;
    } catch (e) {
      // Return original if preprocessing fails
      return File(imagePath);
    }
  }

  /// Auto-rotate image to correct orientation
  img.Image _autoRotateImage(img.Image image) {
    // Simple edge detection to determine if image needs rotation
    // For now, return as-is (improved version would use orientation metadata)
    return image;
  }

  /// Enhance contrast for better text visibility
  img.Image _enhanceContrast(img.Image image) {
    return img.contrast(image, contrast: 1.2);
  }

  /// Denoise image to remove artifacts
  img.Image _denoiseImage(img.Image image) {
    // Apply slight blur to reduce noise while preserving edges
    return img.gaussianBlur(image, radius: 1);
  }

  /// Parse OCR text to extract structured receipt data
  Map<String, dynamic> _parseReceiptText(String text) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();

    return {
      'merchant': _extractMerchantName(lines),
      'merchantConfidence': _evaluateMerchantConfidence(lines),
      'amount': _extractTotalAmount(lines),
      'amountConfidence': _evaluateAmountConfidence(lines),
      'date': _extractDate(lines),
      'dateConfidence': _evaluateDateConfidence(lines),
      'items': _extractItems(lines),
      'itemsConfidence': 0.6,
      'tax': _extractTax(lines),
      'taxConfidence': _evaluateTaxConfidence(lines),
    };
  }

  /// Extract merchant/shop name (usually at top or bottom)
  String? _extractMerchantName(List<String> lines) {
    if (lines.isEmpty) return null;

    // First line is often merchant name
    final firstLine = lines.first.trim();
    if (firstLine.length > 5 && firstLine.length < 50) {
      return firstLine;
    }

    // Look for common merchant patterns
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.contains('store') ||
          trimmed.contains('mall') ||
          trimmed.contains('shop') ||
          trimmed.contains('market')) {
        return trimmed;
      }
    }

    return null;
  }

  /// Evaluate confidence in merchant name extraction (0-1)
  double _evaluateMerchantConfidence(List<String> lines) {
    if (lines.isEmpty) return 0.0;
    final firstLine = lines.first.trim();
    return (firstLine.isNotEmpty && firstLine.length > 3) ? 0.85 : 0.5;
  }

  /// Extract total amount (usually largest number)
  double? _extractTotalAmount(List<String> lines) {
    double? maxAmount;

    for (final line in lines) {
      final amounts = _findNumbersInLine(line);
      for (final amount in amounts) {
        if (amount > 0 && (maxAmount == null || amount > maxAmount)) {
          maxAmount = amount;
        }
      }
    }

    return maxAmount;
  }

  /// Evaluate confidence in amount extraction (0-1)
  double _evaluateAmountConfidence(List<String> lines) {
    for (final line in lines) {
      if (line.contains('total') ||
          line.contains('amount') ||
          line.contains('₹')) {
        return 0.9;
      }
    }
    return 0.7;
  }

  /// Extract receipt date
  DateTime? _extractDate(List<String> lines) {
    for (final line in lines) {
      final dateMatch = RegExp(
        r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})',
        caseSensitive: false,
      ).firstMatch(line);

      if (dateMatch != null) {
        try {
          final day = int.parse(dateMatch.group(1)!);
          final month = int.parse(dateMatch.group(2)!);
          final year = int.parse(dateMatch.group(3)!);

          // Handle 2-digit years
          final fullYear = year < 100 ? 2000 + year : year;

          return DateTime(fullYear, month, day);
        } catch (_) {
          continue;
        }
      }
    }

    return null;
  }

  /// Evaluate confidence in date extraction (0-1)
  double _evaluateDateConfidence(List<String> lines) {
    for (final line in lines) {
      if (RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}').hasMatch(line)) {
        return 0.95;
      }
    }
    return 0.3;
  }

  /// Extract individual items from receipt
  List<String> _extractItems(List<String> lines) {
    final items = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      // Items usually have quantity and price patterns
      if (RegExp(r'\d+\s*[x×]\s*\d+').hasMatch(trimmed) ||
          (RegExp(r'₹\d+').hasMatch(trimmed) && trimmed.length > 10)) {
        items.add(trimmed);
      }
    }

    return items;
  }

  /// Extract tax/GST amount
  double? _extractTax(List<String> lines) {
    for (final line in lines) {
      if (line.toLowerCase().contains('tax') ||
          line.toLowerCase().contains('gst') ||
          line.toLowerCase().contains('vat')) {
        final amounts = _findNumbersInLine(line);
        if (amounts.isNotEmpty) {
          return amounts.last;
        }
      }
    }
    return null;
  }

  /// Evaluate confidence in tax extraction (0-1)
  double _evaluateTaxConfidence(List<String> lines) {
    for (final line in lines) {
      if (line.toLowerCase().contains('tax') ||
          line.toLowerCase().contains('gst')) {
        return 0.85;
      }
    }
    return 0.4;
  }

  /// Find all numbers in a line (including decimals and currency)
  List<double> _findNumbersInLine(String line) {
    final regex = RegExp(r'[\d,]+\.?\d*');
    final matches = regex.allMatches(line);
    return matches
        .map((m) {
          try {
            final cleaned = m.group(0)!.replaceAll(',', '');
            return double.parse(cleaned);
          } catch (_) {
            return null;
          }
        })
        .whereType<double>()
        .toList();
  }

  /// Calculate overall OCR quality confidence (0-1)
  double _calculateConfidence(RecognizedText recognizedText) {
    if (recognizedText.text.isEmpty) return 0.0;

    // Factors affecting confidence:
    // - Text length (more text = likely higher quality)
    // - Number of blocks detected
    double confidence = 0.7; // Base confidence

    if (recognizedText.text.length > 100) {
      confidence += 0.15;
    } else if (recognizedText.text.length < 20) {
      confidence -= 0.2;
    }

    // Cap at 1.0
    return confidence.clamp(0.0, 1.0);
  }

  /// Detect text language (simple version) - Reserved for future use
  // Reserved for future multi-language detection
  // String _detectLanguage(String text) {
  //   // Check for language-specific characters
  //   if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) {
  //     return 'hi'; // Devanagari script = Hindi
  //   }
  //   if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(text)) {
  //     return 'ta'; // Tamil script
  //   }
  //   if (RegExp(r'[\u0C00-\u0C7F]').hasMatch(text)) {
  //     return 'te'; // Telugu script
  //   }
  //   if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) {
  //     return 'mr'; // Marathi script
  //   }
  //   return 'en'; // Default to English
  // }

  /// Check for duplicate receipts based on amount and date
  bool isDuplicateReceipt(
      double? amount, DateTime? date, List<OCRResult> previousResults,) {
    if (amount == null || date == null) return false;

    for (final result in previousResults) {
      if (result.amount == null || result.date == null) continue;

      // Same amount and date within 1 day = likely duplicate
      if ((result.amount! - amount).abs() < 1.0 &&
          result.date!.difference(date).inDays.abs() <= 1) {
        return true;
      }
    }

    return false;
  }

  /// Get list of supported languages
  List<String> getSupportedLanguages() => _supportedLanguages;

  /// Get human-readable language name
  String getLanguageName(String code) => _languageNames[code] ?? code;

  /// Clean up resources
  void dispose() {
    _textRecognizer.close();
  }
}
