// ignore_for_file: avoid_slow_async_io

import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

class OCRService {
  OCRService._init() {
    try {
      _textRecognizer = TextRecognizer();
      debugPrint('OCR Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing OCR Service: $e');
      rethrow;
    }
  }
  static final OCRService instance = OCRService._init();
  late final TextRecognizer _textRecognizer;

  Future<Map<String, dynamic>> extractReceiptData(String imagePath) async {
    try {
      debugPrint('OCR: Processing image at $imagePath');

      // Check if file exists
      final file = File(imagePath);
      if (!file.existsSync()) {
        throw Exception('Image file does not exist: $imagePath');
      }
      // Log file size for diagnostics
      final fileSizeBytes = file.lengthSync();
      debugPrint('OCR: Image file size = $fileSizeBytes bytes');
      if (fileSizeBytes > 8 * 1024 * 1024) {
        // >8MB very large
        debugPrint('OCR: Warning - large image may impact processing speed');
      }

      // Preprocess image (resize + grayscale) to improve recognition stability
      final processedPath = await _preprocessImage(imagePath);
      final inputImage = InputImage.fromFilePath(processedPath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final text = recognizedText.text;
      debugPrint('OCR: Recognized text length: ${text.length} characters');
      debugPrint(
        'OCR: First 200 chars: ${text.substring(0, text.length > 200 ? 200 : text.length)}',
      );

      final Map<String, dynamic> extractedData = {
        'date': null,
        'amount': null,
        'liters': null,
        'pumpName': null,
      };

      // Extract date
      extractedData['date'] = _extractDate(text);
      debugPrint('OCR: Extracted date: ${extractedData['date']}');

      // Extract amount
      extractedData['amount'] = _extractAmount(text);
      debugPrint('OCR: Extracted amount: ${extractedData['amount']}');

      // Extract liters
      extractedData['liters'] = _extractLiters(text);
      debugPrint('OCR: Extracted liters: ${extractedData['liters']}');

      // Extract pump name
      extractedData['pumpName'] = _extractPumpName(text);
      debugPrint('OCR: Extracted pump name: ${extractedData['pumpName']}');

      return extractedData;
    } catch (e, stackTrace) {
      debugPrint('OCR: Error processing image: $e');
      debugPrint('OCR: Stack trace: $stackTrace');
      // Fail gracefully: return empty structured result instead of throwing
      return {
        'date': null,
        'amount': null,
        'liters': null,
        'pumpName': null,
        'error': e.toString(),
      };
    }
  }

  // Track temp files for cleanup
  final List<String> _tempFiles = [];

  // Basic image preprocessing: resize if very large and convert to grayscale to reduce noise
  Future<String> _preprocessImage(String originalPath) async {
    try {
      final file = File(originalPath);
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        debugPrint('OCR: Preprocess failed - could not decode image');
        return originalPath; // fallback
      }

      // Resize if width too large
      const int maxWidth = 1500; // heuristic cap
      img.Image working = decoded;
      if (working.width > maxWidth) {
        final scale = maxWidth / working.width;
        final newHeight = max(1, (working.height * scale).round());
        working = img.copyResize(working, width: maxWidth, height: newHeight);
        debugPrint('OCR: Image resized to ${working.width}x${working.height}');
      }

      // Convert to grayscale to reduce color artifacts
      working = img.grayscale(working);

      // Simple contrast enhancement (empirical value)
      working = img.adjustColor(working, contrast: 1.2);
      debugPrint('OCR: Applied simple contrast enhancement');

      final processedBytes = img.encodeJpg(working, quality: 92);
      final tempDir = Directory.systemTemp;
      final outFile = File(
          '${tempDir.path}/ocr_processed_${DateTime.now().millisecondsSinceEpoch}.jpg',);
      await outFile.writeAsBytes(processedBytes, flush: true);
      _tempFiles.add(outFile.path); // Track for cleanup
      debugPrint(
          'OCR: Preprocessed image written to ${outFile.path} (${processedBytes.length} bytes)',);
      return outFile.path;
    } catch (e) {
      debugPrint('OCR: Preprocess error $e - using original image');
      return originalPath; // Fallback to original
    }
  }

  /// Clean up temporary processed images
  Future<void> cleanupTempFiles() async {
    for (final path in _tempFiles) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          debugPrint('OCR: Cleaned up temp file: $path');
        }
      } catch (e) {
        debugPrint('OCR: Failed to cleanup temp file $path: $e');
      }
    }
    _tempFiles.clear();
  }

  DateTime? _extractDate(String text) {
    final datePatterns = [
      RegExp(
        r'(\d{2})[\/\.\-](\d{2})[\/\.\-](\d{4})',
      ),
      RegExp(r'(\d{2})[\/\.\-](\d{2})[\/\.\-](\d{2})'),
    ];

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          final int day = int.parse(match.group(1)!);
          final int month = int.parse(match.group(2)!);
          int year = int.parse(match.group(3)!);

          if (year < 100) {
            year += 2000;
          }

          return DateTime(year, month, day);
        } catch (e) {
          continue;
        }
      }
    }
    return null;
  }

  double? _extractAmount(String text) {
    final amountPatterns = [
      RegExp(r'₹\s*(\d+\.?\d*)'),
      RegExp(r'Rs\.?\s*(\d+\.?\d*)'),
      RegExp(r'INR\s*(\d+\.?\d*)'),
      RegExp(r'Total[:\s]*₹?\s*(\d+\.?\d*)'),
      RegExp(r'Amount[:\s]*₹?\s*(\d+\.?\d*)'),
      RegExp(r'(\d+\.\d{2})\s*(?:Rs|₹|INR)'),
    ];

    final List<double> amounts = [];

    for (final pattern in amountPatterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        try {
          final double amount = double.parse(
            match.group(1) ?? match.group(0)!.replaceAll(RegExp(r'[^\d.]'), ''),
          );
          if (amount > 10 && amount < 10000) {
            amounts.add(amount);
          }
        } catch (e) {
          continue;
        }
      }
    }

    return amounts.isNotEmpty ? amounts.reduce((a, b) => a > b ? a : b) : null;
  }

  double? _extractLiters(String text) {
    final literPatterns = [
      RegExp(
        r'(\d+\.?\d*)\s*(?:L|LTR|Ltr|LTRS|Liters?|लीटर)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:Quantity|Qty|Vol|Volume)[:\s]*(\d+\.?\d*)',
        caseSensitive: false,
      ),
      RegExp(r'(\d+\.?\d*)\s*(?:Litres?)', caseSensitive: false),
    ];

    for (final pattern in literPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          final double liters = double.parse(match.group(1)!);
          if (liters > 0 && liters < 200) {
            return liters;
          }
        } catch (e) {
          continue;
        }
      }
    }
    return null;
  }

  String? _extractPumpName(String text) {
    final pumpNames = [
      'Indian Oil',
      'IOCL',
      'Bharat Petroleum',
      'BPCL',
      'Hindustan Petroleum',
      'HPCL',
      'Shell',
      'Reliance',
      'Essar',
      'Nayara Energy',
    ];

    final upperText = text.toUpperCase();

    for (final pump in pumpNames) {
      if (upperText.contains(pump.toUpperCase())) {
        return pump;
      }
    }

    // Fallback: try to extract first line as pump name
    final lines = text.split('\n');
    if (lines.isNotEmpty) {
      final firstLine = lines.first.trim();
      if (firstLine.length > 3 && firstLine.length < 50) {
        return firstLine;
      }
    }

    return null;
  }

  Future<String?> extractAmountFromReceipt(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    final amount = _extractAmount(recognizedText.text);
    return amount?.toStringAsFixed(2);
  }

  void dispose() {
    _textRecognizer.close();
  }
}
