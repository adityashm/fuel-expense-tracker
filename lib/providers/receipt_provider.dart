import 'package:flutter/material.dart';
import '../models/receipt.dart';
import '../services/receipt_service.dart';

/// Provider for managing receipt state across the application
/// Handles loading, processing, and updating receipts
class ReceiptProvider extends ChangeNotifier {
  ReceiptProvider() {
    _initializeService();
  }
  final ReceiptService _receiptService = ReceiptService();

  // State variables
  List<Receipt> _receipts = [];
  Receipt? _selectedReceipt;
  bool _isLoading = false;
  String? _errorMessage;
  ReceiptStats? _stats;

  // Filters
  String _statusFilter = 'all'; // all, pending, processed, verified, rejected
  String _searchQuery = '';
  DateTime? _dateFilter;

  // Getters
  List<Receipt> get receipts => _filteredReceipts;
  Receipt? get selectedReceipt => _selectedReceipt;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ReceiptStats? get stats => _stats;
  int get totalReceipts => _receipts.length;
  int get unprocessedCount =>
      _receipts.where((r) => r.status == 'pending').length;

  Future<void> _initializeService() async {
    await _receiptService.initializeStorage();
  }

  /// Load all receipts
  Future<void> loadReceipts() async {
    try {
      _setLoading(true);
      _clearError();

      _receipts = await _receiptService.getAllReceipts();
      await _refreshStats();

      notifyListeners();
    } catch (e) {
      _setError('Failed to load receipts: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load receipts for a specific expense
  Future<void> loadReceiptsByExpense(String expenseId) async {
    try {
      _setLoading(true);
      _clearError();

      _receipts = await _receiptService.getReceiptsByExpense(expenseId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load receipts for expense: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Process new receipt from image
  Future<Receipt?> processNewReceipt({
    required String imagePath,
    required String expenseId,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final receipt = await _receiptService.processAndSaveReceipt(
        imagePath: imagePath,
        expenseId: expenseId,
      );

      _receipts.add(receipt);
      await _refreshStats();
      notifyListeners();

      return receipt;
    } catch (e) {
      _setError('Failed to process receipt: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Select receipt for viewing/editing
  void selectReceipt(Receipt receipt) {
    _selectedReceipt = receipt;
    notifyListeners();
  }

  /// Clear selected receipt
  void deselectReceipt() {
    _selectedReceipt = null;
    notifyListeners();
  }

  /// Update receipt OCR data (when user corrects OCR results)
  Future<void> updateReceiptOCRData({
    required String receiptId,
    required Map<String, dynamic> correctedData,
    required double confidence,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      await _receiptService.updateReceiptOCRData(
        receiptId: receiptId,
        correctedData: correctedData,
        userCorrectionConfidence: confidence,
      );

      // Reload receipt
      final updated = await _receiptService.getReceipt(receiptId);
      if (updated != null) {
        final index = _receipts.indexWhere((r) => r.id == receiptId);
        if (index >= 0) {
          _receipts[index] = updated;
          _selectedReceipt = updated;
        }
      }

      await _refreshStats();
      notifyListeners();
    } catch (e) {
      _setError('Failed to update receipt: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Delete receipt
  Future<void> deleteReceipt(String receiptId) async {
    try {
      _setLoading(true);
      _clearError();

      await _receiptService.deleteReceipt(receiptId);
      _receipts.removeWhere((r) => r.id == receiptId);

      if (_selectedReceipt?.id == receiptId) {
        _selectedReceipt = null;
      }

      await _refreshStats();
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete receipt: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Re-process receipt OCR
  Future<void> reprocessReceipt(String receiptId) async {
    try {
      _setLoading(true);
      _clearError();

      final updated = await _receiptService.reprocessReceipt(receiptId);
      final index = _receipts.indexWhere((r) => r.id == receiptId);
      if (index >= 0) {
        _receipts[index] = updated;
        if (_selectedReceipt?.id == receiptId) {
          _selectedReceipt = updated;
        }
      }

      await _refreshStats();
      notifyListeners();
    } catch (e) {
      _setError('Failed to reprocess receipt: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Set status filter
  void setStatusFilter(String status) {
    _statusFilter = status;
    notifyListeners();
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Set date filter
  void setDateFilter(DateTime? date) {
    _dateFilter = date;
    notifyListeners();
  }

  /// Get filtered receipts based on current filters
  List<Receipt> get _filteredReceipts {
    var filtered = _receipts;

    // Apply status filter
    if (_statusFilter != 'all') {
      filtered = filtered.where((r) => r.status == _statusFilter).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (r) =>
                (r.processedData['merchant'] as String?)
                    ?.toLowerCase()
                    .contains(query) ??
                false,
          )
          .toList();
    }

    // Apply date filter
    if (_dateFilter != null) {
      filtered = filtered.where((r) {
        final receiptDate = r.createdAt;
        return receiptDate.year == _dateFilter!.year &&
            receiptDate.month == _dateFilter!.month &&
            receiptDate.day == _dateFilter!.day;
      }).toList();
    }

    return filtered;
  }

  /// Get receipts grouped by date
  Map<DateTime, List<Receipt>> getReceiptsByDate() {
    final grouped = <DateTime, List<Receipt>>{};

    for (final receipt in receipts) {
      final date = DateTime(
        receipt.createdAt.year,
        receipt.createdAt.month,
        receipt.createdAt.day,
      );

      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(receipt);
    }

    return grouped;
  }

  /// Get receipts grouped by merchant
  Map<String, List<Receipt>> getReceiptsByMerchant() {
    final grouped = <String, List<Receipt>>{};

    for (final receipt in receipts) {
      final merchant =
          receipt.processedData['merchant'] as String? ?? 'Unknown';

      if (!grouped.containsKey(merchant)) {
        grouped[merchant] = [];
      }
      grouped[merchant]!.add(receipt);
    }

    return grouped;
  }

  /// Get average OCR confidence for filtered receipts
  double getAverageConfidence() {
    if (receipts.isEmpty) return 0;
    final sum = receipts.fold(0.0, (prev, r) => prev + r.ocrConfidence);
    return sum / receipts.length;
  }

  /// Refresh statistics
  Future<void> _refreshStats() async {
    try {
      _stats = await _receiptService.getReceiptStats();
    } catch (e) {
      debugPrint('Error refreshing stats: $e');
    }
  }

  /// Cleanup old receipts
  Future<int> cleanupOldReceipts({required int olderThanDays}) async {
    try {
      _setLoading(true);
      _clearError();

      final count = await _receiptService.cleanupOldReceipts(
          olderThanDays: olderThanDays,);
      await loadReceipts(); // Reload

      return count;
    } catch (e) {
      _setError('Failed to cleanup receipts: $e');
      return 0;
    } finally {
      _setLoading(false);
    }
  }

  // Helper methods
  void _setLoading(bool value) {
    _isLoading = value;
  }

  void _setError(String message) {
    _errorMessage = message;
  }

  void _clearError() {
    _errorMessage = null;
  }

  @override
  void dispose() {
    _receiptService.dispose();
    super.dispose();
  }
}
