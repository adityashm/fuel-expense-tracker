import 'dart:convert';

/// Receipt model for storing OCR-processed receipt information
/// Stores receipt image, OCR extracted data, and verification status
class Receipt {
  Receipt({
    required this.id,
    required this.expenseId,
    required this.imagePath,
    required this.processedData,
    required this.ocrConfidence,
    required this.multiLanguageTexts,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from map (database)
  factory Receipt.fromMap(Map<String, dynamic> map) {
    return Receipt(
      id: map['id'] ?? '',
      expenseId: map['expense_id'] ?? '',
      imagePath: map['image_path'] ?? '',
      processedData: map['processed_data'] != null
          ? jsonDecode(map['processed_data'])
          : {},
      ocrConfidence: (map['ocr_confidence'] as num?)?.toDouble() ?? 0.0,
      multiLanguageTexts: map['multi_language_texts'] != null
          ? Map<String, String>.from(jsonDecode(map['multi_language_texts']))
          : {},
      status: map['status'] ?? 'pending',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
    );
  }

  /// Create from JSON
  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'] ?? '',
      expenseId: json['expenseId'] ?? '',
      imagePath: json['imagePath'] ?? '',
      processedData: (json['processedData'] ?? {}) as Map<String, dynamic>,
      ocrConfidence: (json['ocrConfidence'] as num?)?.toDouble() ?? 0.0,
      multiLanguageTexts:
          Map<String, String>.from(json['multiLanguageTexts'] ?? {}),
      status: json['status'] ?? 'pending',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }
  final String id;
  final String expenseId;
  final String imagePath; // Local file path to receipt image
  final Map<String, dynamic>
      processedData; // OCR extracted data: merchant, date, amount, items, tax
  final double ocrConfidence; // OCR accuracy score (0.0-1.0)
  final Map<String, String>
      multiLanguageTexts; // Raw OCR text in multiple languages
  final String status; // pending, processed, verified, rejected
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Create a copy with modified fields
  Receipt copyWith({
    String? id,
    String? expenseId,
    String? imagePath,
    Map<String, dynamic>? processedData,
    double? ocrConfidence,
    Map<String, String>? multiLanguageTexts,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Receipt(
      id: id ?? this.id,
      expenseId: expenseId ?? this.expenseId,
      imagePath: imagePath ?? this.imagePath,
      processedData: processedData ?? this.processedData,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
      multiLanguageTexts: multiLanguageTexts ?? this.multiLanguageTexts,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expense_id': expenseId,
      'image_path': imagePath,
      'processed_data': jsonEncode(processedData),
      'ocr_confidence': ocrConfidence,
      'multi_language_texts': jsonEncode(multiLanguageTexts),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expenseId': expenseId,
      'imagePath': imagePath,
      'processedData': processedData,
      'ocrConfidence': ocrConfidence,
      'multiLanguageTexts': multiLanguageTexts,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Check if receipt has been processed
  bool isProcessed() => status == 'processed' || status == 'verified';

  /// Check if receipt data is complete
  bool isDataComplete() {
    return processedData.containsKey('merchant') &&
        processedData.containsKey('amount') &&
        processedData.containsKey('date');
  }

  @override
  String toString() =>
      'Receipt(id: $id, expenseId: $expenseId, status: $status)';
}
