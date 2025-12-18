import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/receipt.dart';
import '../providers/receipt_provider.dart';

/// Screen for viewing, managing, and processing receipt images
/// Displays receipts in gallery format with OCR data overlay
class ReceiptGalleryScreen extends StatefulWidget {
  // Optional: filter by expense

  const ReceiptGalleryScreen({
    super.key,
    this.expenseId,
  });
  final String? expenseId;

  @override
  State<ReceiptGalleryScreen> createState() => _ReceiptGalleryScreenState();
}

class _ReceiptGalleryScreenState extends State<ReceiptGalleryScreen> {
  late ImagePicker _imagePicker;

  @override
  void initState() {
    super.initState();
    _imagePicker = ImagePicker();

    // Load receipts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.expenseId != null) {
        context
            .read<ReceiptProvider>()
            .loadReceiptsByExpense(widget.expenseId!);
      } else {
        context.read<ReceiptProvider>().loadReceipts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Gallery'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showStatisticsDialog(context),
            tooltip: 'Statistics',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showFilterMenu(context),
            tooltip: 'Filter',
          ),
        ],
      ),
      body: Consumer<ReceiptProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(provider.errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadReceipts(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.receipts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No receipts yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add receipts to track your expenses',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _pickReceiptImage,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Add Receipt'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Search bar
              TextField(
                onChanged: (value) => provider.setSearchQuery(value),
                decoration: InputDecoration(
                  hintText: 'Search by merchant...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Status filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all', provider),
                    const SizedBox(width: 8),
                    _buildFilterChip('Processed', 'processed', provider),
                    const SizedBox(width: 8),
                    _buildFilterChip('Verified', 'verified', provider),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending', 'pending', provider),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Receipt grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: provider.receipts.length,
                itemBuilder: (context, index) {
                  final receipt = provider.receipts[index];
                  return _buildReceiptCard(context, receipt, provider);
                },
              ),
              const SizedBox(height: 16),

              // Add receipt button
              ElevatedButton.icon(
                onPressed: _pickReceiptImage,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Add New Receipt'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Build filter chip
  Widget _buildFilterChip(
      String label, String value, ReceiptProvider provider,) {
    final isSelected = provider.receipts.isNotEmpty; // TODO: track filter state

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        provider.setStatusFilter(selected ? value : 'all');
      },
    );
  }

  /// Build receipt card
  Widget _buildReceiptCard(
    BuildContext context,
    Receipt receipt,
    ReceiptProvider provider,
  ) {
    final merchant = receipt.processedData['merchant'] ?? 'Unknown';
    final amount = receipt.processedData['amount'];
    final confidence = receipt.ocrConfidence;

    return GestureDetector(
      onTap: () => _showReceiptDetail(context, receipt, provider),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Receipt image
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  color: Colors.grey[300],
                ),
                child: _buildReceiptImagePreview(receipt),
              ),
            ),

            // Receipt info
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Merchant name
                  Text(
                    merchant.toString().length > 20
                        ? '${merchant.toString().substring(0, 17)}...'
                        : merchant.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Amount
                  if (amount != null)
                    Text(
                      '₹$amount',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),

                  // Confidence badge
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getConfidenceColor(confidence)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${(confidence * 100).toStringAsFixed(0)}% OCR',
                      style: TextStyle(
                        fontSize: 10,
                        color: _getConfidenceColor(confidence),
                      ),
                    ),
                  ),

                  // Status badge
                  const SizedBox(height: 4),
                  _buildStatusBadge(receipt.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build receipt image preview
  Widget _buildReceiptImagePreview(Receipt receipt) {
    try {
      final file = File(receipt.imagePath);
      if (file.existsSync()) {
        // Downscale cached image to reduce memory usage (Phase 5)
        return Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: 800,
          cacheHeight: 800,
        );
      }
    } catch (e) {
      // Silently handle error
    }

    return Center(
      child: Icon(
        Icons.receipt_long,
        size: 48,
        color: Colors.grey[400],
      ),
    );
  }

  /// Build status badge
  Widget _buildStatusBadge(String status) {
    final colors = {
      'pending': Colors.orange,
      'processed': Colors.blue,
      'verified': Colors.green,
      'rejected': Colors.red,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors[status]?.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.capitalize(),
        style: TextStyle(
          fontSize: 10,
          color: colors[status],
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Get color based on OCR confidence
  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.85) return Colors.green;
    if (confidence >= 0.7) return Colors.orange;
    return Colors.red;
  }

  /// Show receipt detail dialog
  void _showReceiptDetail(
    BuildContext context,
    Receipt receipt,
    ReceiptProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ReceiptDetailView(
        receipt: receipt,
        provider: provider,
      ),
    );
  }

  /// Show statistics dialog
  void _showStatisticsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receipt Statistics'),
        content: Consumer<ReceiptProvider>(
          builder: (context, provider, _) {
            final stats = provider.stats;
            if (stats == null) {
              return const CircularProgressIndicator();
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow('Total Receipts', '${stats.totalReceipts}'),
                _buildStatRow('Processed', '${stats.processedReceipts}'),
                _buildStatRow('Verified', '${stats.verifiedReceipts}'),
                _buildStatRow(
                  'Avg OCR Confidence',
                  '${(stats.averageOCRConfidence * 100).toStringAsFixed(1)}%',
                ),
                _buildStatRow(
                    'Total Amount', '₹${stats.totalAmount.toStringAsFixed(2)}',),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Build stat row
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Show filter menu
  void _showFilterMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Filter Options',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // Add filter options here
            const Text('Date range, status, confidence level'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  /// Pick receipt image from gallery or camera
  Future<void> _pickReceiptImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Receipt'),
        content: const Text('Choose image source'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Gallery'),
          ),
        ],
      ),
    );

    if (source == null) return;

    try {
      final image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        // Process receipt
        if (mounted) {
          final provider = context.read<ReceiptProvider>();
          await provider.processNewReceipt(
            imagePath: image.path,
            expenseId: widget.expenseId ?? 'general',
          );

          if (mounted && provider.errorMessage == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Receipt processed successfully')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

/// Detailed receipt view
class _ReceiptDetailView extends StatefulWidget {
  const _ReceiptDetailView({
    required this.receipt,
    required this.provider,
  });
  final Receipt receipt;
  final ReceiptProvider provider;

  @override
  State<_ReceiptDetailView> createState() => _ReceiptDetailViewState();
}

class _ReceiptDetailViewState extends State<_ReceiptDetailView> {
  late TextEditingController _merchantController;
  late TextEditingController _amountController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(
      text: widget.receipt.processedData['merchant']?.toString() ?? '',
    );
    _amountController = TextEditingController(
      text: widget.receipt.processedData['amount']?.toString() ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.receipt.processedData['date'];
    final items = widget.receipt.processedData['items'] as List? ?? [];

    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Receipt image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(widget.receipt.imagePath),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: 1200,
                cacheHeight: 1200,
              ),
            ),
            const SizedBox(height: 16),

            // OCR details
            Text(
              'OCR Data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            // Merchant
            TextFormField(
              controller: _merchantController,
              enabled: _isEditing,
              decoration: InputDecoration(
                labelText: 'Merchant',
                hintText: 'Unknown',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Amount
            TextFormField(
              controller: _amountController,
              enabled: _isEditing,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Date
            if (date != null)
              Text('Date: ${DateTime.parse(date).toString().split(' ')[0]}')
            else
              const Text('Date: Not detected'),
            const SizedBox(height: 16),

            // Items
            if (items.isNotEmpty) ...[
              Text(
                'Items',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('• $item'),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Confidence
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    'OCR Confidence: ${(widget.receipt.ocrConfidence * 100).toStringAsFixed(1)}%',),
                LinearProgressIndicator(
                  value: widget.receipt.ocrConfidence,
                  minHeight: 8,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                if (!_isEditing)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _isEditing = true),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveChanges,
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    final correctedData = {
      'merchant': _merchantController.text,
      'amount': double.tryParse(_amountController.text) ??
          widget.receipt.processedData['amount'],
    };

    await widget.provider.updateReceiptOCRData(
      receiptId: widget.receipt.id,
      correctedData: correctedData,
      confidence: 0.95, // User corrected = high confidence
    );

    if (mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt updated successfully')),
      );
    }
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}

extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
