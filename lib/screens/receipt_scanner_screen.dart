import 'dart:io';

import 'package:flutter/material.dart';
// import 'package:image_cropper/image_cropper.dart'; // Removed for Phase 1 - optional feature
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/ocr_service.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  final _picker = ImagePicker();
  final _ocrService = OCRService.instance;

  File? _imageFile;
  Map<String, dynamic>? _extractedData;
  bool _isProcessing = false;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _captureImage(ImageSource source) async {
    try {
      // Request necessary permissions before proceeding
      if (source == ImageSource.camera) {
        final camStatus = await Permission.camera.request();
        if (!camStatus.isGranted) {
          _showError('Camera permission denied');
          return;
        }
      } else {
        final photosStatus = await Permission.photos.request();
        if (!photosStatus.isGranted && Platform.isIOS) {
          _showError('Photos permission denied');
          return;
        }
      }

      final startTime = DateTime.now();
      debugPrint('ReceiptScanner: Image capture initiated (${source.name})');
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // Skip cropping for Phase 1 - use image directly
        // Image cropping will be added back in Phase 2 with compatible package
        setState(() {
          _imageFile = File(pickedFile.path);
        });

        // Process with OCR
        await _processImage();
        final duration = DateTime.now().difference(startTime).inMilliseconds;
        debugPrint(
            'ReceiptScanner: Total capture+process duration ${duration}ms',);
      }
    } catch (e) {
      _showError('Failed to capture image: $e');
    }
  }

  Future<void> _processImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isProcessing = true;
      _extractedData = null; // Clear previous data
    });

    try {
      final start = DateTime.now();
      // Check if file exists
      final file = File(_imageFile!.path);
      if (!file.existsSync()) {
        throw Exception('Image file not found. Please try again.');
      }

      final extractedData =
          await _ocrService.extractReceiptData(_imageFile!.path);

      if (mounted) {
        setState(() {
          _extractedData = extractedData;
          _isProcessing = false;
        });
        final ms = DateTime.now().difference(start).inMilliseconds;
        debugPrint('ReceiptScanner: OCR processing completed in ${ms}ms');
      }
    } catch (e, stackTrace) {
      debugPrint('OCR Error: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _showError('Failed to process image. Please try again.');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _confirmAndSave() {
    if (_imageFile == null) return;

    final result = <String, dynamic>{
      'imagePath': _imageFile!.path,
      ...?_extractedData,
    };

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
        actions: [
          if (_imageFile != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _isProcessing ? null : _confirmAndSave,
              tooltip: 'Use This Scan',
            ),
        ],
      ),
      body: Column(
        children: [
          // Image preview
          if (_imageFile != null)
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Image.file(
                  _imageFile!,
                  fit: BoxFit.contain,
                ),
              ),
            ),

          // Processing indicator
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Processing receipt...'),
                ],
              ),
            ),

          // Extracted data
          if (_imageFile != null && !_isProcessing)
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Extracted Data',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        _buildDataRow(
                          'Date',
                          _extractedData?['date'] != null
                              ? '${_extractedData!['date']}'
                              : 'Not found',
                        ),
                        _buildDataRow(
                          'Amount',
                          _extractedData?['amount'] != null
                              ? '₹${_extractedData!['amount']}'
                              : 'Not found',
                        ),
                        _buildDataRow(
                          'Liters',
                          _extractedData?['liters'] != null
                              ? '${_extractedData!['liters']} L'
                              : 'Not found',
                        ),
                        _buildDataRow(
                          'Pump Name',
                          _extractedData?['pumpName'] ?? 'Not found',
                        ),
                        const SizedBox(height: 16),
                        if (_extractedData?['error'] != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 16,),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'OCR processing error: ${_extractedData!['error']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Please verify extracted data before saving',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _confirmAndSave,
                          icon: const Icon(Icons.check),
                          label: const Text('Use This Data'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Action buttons
          if (_imageFile == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.camera_alt,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Capture or select a receipt',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _captureImage(ImageSource.camera),
                          icon: const Icon(Icons.camera),
                          label: const Text('Camera'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () => _captureImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton:
          _imageFile != null && !_isProcessing && _extractedData != null
              ? FloatingActionButton.extended(
                  onPressed: () => _captureImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Retake'),
                )
              : null,
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
