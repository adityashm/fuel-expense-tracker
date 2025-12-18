/// Data class for OCR processing results
/// Contains all extracted receipt information with confidence scores
class OCRResult {
  // Per-field confidence scores

  OCRResult({
    required this.rawText,
    this.merchantName,
    this.amount,
    this.date,
    required this.items,
    this.taxAmount,
    required this.confidence,
    required this.fieldConfidences,
  });

  /// Create from JSON
  factory OCRResult.fromJson(Map<String, dynamic> json) {
    return OCRResult(
      rawText: json['rawText'] ?? '',
      merchantName: json['merchantName'],
      amount:
          json['amount'] != null ? (json['amount'] as num).toDouble() : null,
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      items: List<String>.from(json['items'] ?? []),
      taxAmount: json['taxAmount'] != null
          ? (json['taxAmount'] as num).toDouble()
          : null,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      fieldConfidences: Map<String, double>.from(
        (json['fieldConfidences'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            ) ??
            {},
      ),
    );
  }
  final String rawText;
  final String? merchantName;
  final double? amount;
  final DateTime? date;
  final List<String> items;
  final double? taxAmount;
  final double confidence; // Overall confidence (0-1)
  final Map<String, double> fieldConfidences;

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'rawText': rawText,
      'merchantName': merchantName,
      'amount': amount,
      'date': date?.toIso8601String(),
      'items': items,
      'taxAmount': taxAmount,
      'confidence': confidence,
      'fieldConfidences': fieldConfidences,
    };
  }

  @override
  String toString() =>
      'OCRResult(merchant: $merchantName, amount: $amount, date: $date, confidence: $confidence)';
}
