import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/ocr_result.dart';
import '../models/receipt.dart';
import 'database_service.dart';
import 'receipt_ocr_service.dart';

/// Service for managing receipts in the database and file system
/// Handles CRUD operations, image storage, and receipt validation
class ReceiptService {
  ReceiptService._internal() {
    _initializeService();
  }

  factory ReceiptService() {
    return _instance;
  }
  static final ReceiptService _instance = ReceiptService._internal();
  late final DatabaseService _databaseService;
  late final ReceiptOCRService _ocrService;

  // Receipt image storage directory
  late final Directory _receiptImagesDir;

  void _initializeService() {
    _databaseService = DatabaseService.instance;
    _ocrService = ReceiptOCRService();
  }

  /// Initialize receipt storage directory
  Future<void> initializeStorage() async {
    try {
      final documentsDir = Directory('/storage/emulated/0/Documents');
      _receiptImagesDir =
          Directory('${documentsDir.path}/fuel_expense_tracker/receipts');

      if (!_receiptImagesDir.existsSync()) {
        _receiptImagesDir.createSync(recursive: true);
      }
    } catch (e) {
      debugPrint('Error initializing receipt storage: $e');
    }
  }

  /// Process and save receipt with OCR
  Future<Receipt> processAndSaveReceipt({
    required String imagePath,
    required String expenseId,
    bool autoProcess = true,
  }) async {
    try {
      // Copy image to app storage
      final savedImagePath = await _copyImageToStorage(imagePath);

      // Process with OCR if requested
      OCRResult? ocrResult;
      if (autoProcess) {
        ocrResult = await _ocrService.processReceiptImage(imagePath);
      }

      // Create receipt object
      final receipt = Receipt(
        id: _generateReceiptId(),
        expenseId: expenseId,
        imagePath: savedImagePath,
        processedData: {
          'merchant': ocrResult?.merchantName,
          'date': ocrResult?.date?.toIso8601String(),
          'amount': ocrResult?.amount,
          'items': ocrResult?.items ?? [],
          'taxAmount': ocrResult?.taxAmount,
        },
        ocrConfidence: ocrResult?.confidence ?? 0.0,
        multiLanguageTexts: {
          'en': ocrResult?.rawText ?? '',
        },
        status: 'processed', // pending, processed, verified, rejected
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to database
      await _saveReceiptToDatabase(receipt);

      return receipt;
    } catch (e) {
      throw Exception('Failed to process receipt: $e');
    }
  }

  /// Copy receipt image to app's storage directory
  Future<String> _copyImageToStorage(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!sourceFile.existsSync()) {
        throw Exception('Source image file not found');
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destinationPath = '${_receiptImagesDir.path}/$fileName';

      await sourceFile.copy(destinationPath);
      return destinationPath;
    } catch (e) {
      throw Exception('Failed to copy image: $e');
    }
  }

  /// Save receipt to database
  Future<void> _saveReceiptToDatabase(Receipt receipt) async {
    try {
      await _databaseService.insertReceipt(receipt.toMap());
    } catch (e) {
      throw Exception('Failed to save receipt to database: $e');
    }
  }

  /// Get receipt by ID
  Future<Receipt?> getReceipt(String receiptId) async {
    try {
      final map = await _databaseService.getReceipt(receiptId);
      if (map == null) return null;
      return Receipt.fromMap(map);
    } catch (e) {
      throw Exception('Failed to retrieve receipt: $e');
    }
  }

  /// Get all receipts for an expense
  Future<List<Receipt>> getReceiptsByExpense(String expenseId) async {
    try {
      final maps = await _databaseService.getReceiptsByExpense(expenseId);
      return maps.map((map) => Receipt.fromMap(map)).toList();
    } catch (e) {
      throw Exception('Failed to retrieve receipts: $e');
    }
  }

  /// Get all receipts
  Future<List<Receipt>> getAllReceipts() async {
    try {
      final maps = await _databaseService.getAllReceipts();
      return maps.map((map) => Receipt.fromMap(map)).toList();
    } catch (e) {
      throw Exception('Failed to retrieve all receipts: $e');
    }
  }

  /// Update receipt data
  Future<void> updateReceipt(Receipt receipt) async {
    try {
      final updatedReceipt = receipt.copyWith(updatedAt: DateTime.now());
      await _databaseService.updateReceipt(updatedReceipt.toMap());
    } catch (e) {
      throw Exception('Failed to update receipt: $e');
    }
  }

  /// Update receipt OCR confidence (if user corrects data)
  Future<void> updateReceiptOCRData({
    required String receiptId,
    required Map<String, dynamic> correctedData,
    required double userCorrectionConfidence,
  }) async {
    try {
      final receipt = await getReceipt(receiptId);
      if (receipt == null) throw Exception('Receipt not found');

      // Merge original and corrected data
      final mergedData = {...receipt.processedData, ...correctedData};

      final updated = receipt.copyWith(
        processedData: mergedData,
        ocrConfidence: userCorrectionConfidence,
        status: 'verified',
        updatedAt: DateTime.now(),
      );

      await updateReceipt(updated);
    } catch (e) {
      throw Exception('Failed to update receipt OCR data: $e');
    }
  }

  /// Delete receipt and associated image
  Future<void> deleteReceipt(String receiptId) async {
    try {
      final receipt = await getReceipt(receiptId);
      if (receipt == null) return;

      // Delete image file
      final imageFile = File(receipt.imagePath);
      if (imageFile.existsSync()) {
        await imageFile.delete();
      }

      // Delete from database
      await _databaseService.deleteReceipt(receiptId);
    } catch (e) {
      throw Exception('Failed to delete receipt: $e');
    }
  }

  /// Generate unique receipt ID
  String _generateReceiptId() {
    return 'rcpt_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 1000).toString().padLeft(3, '0')}';
  }

  /// Get receipt file size
  int getReceiptImageSize(String receiptId) {
    try {
      final receipt = _databaseService.getReceiptSync(receiptId);
      if (receipt == null) return 0;

      final file = File(receipt['imagePath']);
      if (file.existsSync()) {
        return file.lengthSync();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get total storage used by receipts
  Future<int> getTotalReceiptStorage() async {
    try {
      int totalSize = 0;
      if (_receiptImagesDir.existsSync()) {
        final files = _receiptImagesDir.listSync();
        for (final file in files) {
          if (file is File) {
            totalSize += file.lengthSync();
          }
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Clean up old receipt images (older than days)
  Future<int> cleanupOldReceipts({required int olderThanDays}) async {
    try {
      int deletedCount = 0;
      final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));

      final receipts = await getAllReceipts();
      for (final receipt in receipts) {
        if (receipt.createdAt.isBefore(cutoffDate)) {
          await deleteReceipt(receipt.id);
          deletedCount++;
        }
      }

      return deletedCount;
    } catch (e) {
      throw Exception('Failed to cleanup receipts: $e');
    }
  }

  /// Re-process receipt OCR (for improvement)
  Future<Receipt> reprocessReceipt(String receiptId) async {
    try {
      final receipt = await getReceipt(receiptId);
      if (receipt == null) throw Exception('Receipt not found');

      // Re-process OCR
      final ocrResult =
          await _ocrService.processReceiptImage(receipt.imagePath);

      // Update receipt with new OCR data
      final updated = receipt.copyWith(
        processedData: {
          'merchant': ocrResult.merchantName,
          'date': ocrResult.date?.toIso8601String(),
          'amount': ocrResult.amount,
          'items': ocrResult.items,
          'taxAmount': ocrResult.taxAmount,
        },
        ocrConfidence: ocrResult.confidence,
        status: 'processed',
        updatedAt: DateTime.now(),
      );

      await updateReceipt(updated);
      return updated;
    } catch (e) {
      throw Exception('Failed to reprocess receipt: $e');
    }
  }

  /// Get receipts by status
  Future<List<Receipt>> getReceiptsByStatus(String status) async {
    try {
      final allReceipts = await getAllReceipts();
      return allReceipts.where((r) => r.status == status).toList();
    } catch (e) {
      throw Exception('Failed to retrieve receipts by status: $e');
    }
  }

  /// Search receipts by merchant name
  Future<List<Receipt>> searchByMerchant(String query) async {
    try {
      final allReceipts = await getAllReceipts();
      final queryLower = query.toLowerCase();
      return allReceipts
          .where(
            (r) =>
                (r.processedData['merchant'] as String?)
                    ?.toLowerCase()
                    .contains(queryLower) ??
                false,
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to search receipts: $e');
    }
  }

  /// Get receipt statistics
  Future<ReceiptStats> getReceiptStats() async {
    try {
      final receipts = await getAllReceipts();

      final int totalReceipts = receipts.length;
      final int processedCount =
          receipts.where((r) => r.status == 'processed').length;
      final int verifiedCount =
          receipts.where((r) => r.status == 'verified').length;
      final double averageConfidence = receipts.isEmpty
          ? 0
          : receipts.map((r) => r.ocrConfidence).reduce((a, b) => a + b) /
              receipts.length;
      double totalAmount = 0;

      for (final receipt in receipts) {
        final amount = receipt.processedData['amount'];
        if (amount != null) {
          totalAmount += (amount as num).toDouble();
        }
      }

      return ReceiptStats(
        totalReceipts: totalReceipts,
        processedReceipts: processedCount,
        verifiedReceipts: verifiedCount,
        averageOCRConfidence: averageConfidence,
        totalAmount: totalAmount,
      );
    } catch (e) {
      throw Exception('Failed to get receipt stats: $e');
    }
  }

  /// Dispose service
  void dispose() {
    _ocrService.dispose();
  }
}

/// Class to hold receipt statistics
class ReceiptStats {
  ReceiptStats({
    required this.totalReceipts,
    required this.processedReceipts,
    required this.verifiedReceipts,
    required this.averageOCRConfidence,
    required this.totalAmount,
  });
  final int totalReceipts;
  final int processedReceipts;
  final int verifiedReceipts;
  final double averageOCRConfidence;
  final double totalAmount;

  int get pendingReceipts => totalReceipts - processedReceipts;
  double get processingPercentage =>
      totalReceipts == 0 ? 0 : (processedReceipts / totalReceipts) * 100;
  double get verificationPercentage =>
      totalReceipts == 0 ? 0 : (verifiedReceipts / totalReceipts) * 100;
}
