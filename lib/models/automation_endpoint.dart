class AutomationEndpoint {
  const AutomationEndpoint({
    this.id,
    required this.deviceId,
    required this.name,
    required this.url,
    this.headers = const {},
    this.isEnabled = true,
    required this.createdAt,
    this.lastTriggered,
  });

  factory AutomationEndpoint.fromMap(Map<String, dynamic> map) {
    return AutomationEndpoint(
      id: map['id'] as int?,
      deviceId: map['device_id'] as String,
      name: map['name'] as String,
      url: map['url'] as String,
      headers: _decodeHeaders(map['headers'] as String?),
      isEnabled: (map['is_enabled'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastTriggered: map['last_triggered'] != null
          ? DateTime.parse(map['last_triggered'] as String)
          : null,
    );
  }
  final int? id;
  final String deviceId;
  final String name;
  final String url;
  final Map<String, String> headers;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime? lastTriggered;

  AutomationEndpoint copyWith({
    int? id,
    String? name,
    String? url,
    Map<String, String>? headers,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? lastTriggered,
  }) {
    return AutomationEndpoint(
      id: id ?? this.id,
      deviceId: deviceId,
      name: name ?? this.name,
      url: url ?? this.url,
      headers: headers ?? this.headers,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      lastTriggered: lastTriggered ?? this.lastTriggered,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'name': name,
      'url': url,
      'headers': headers.isEmpty ? null : _encodeHeaders(headers),
      'is_enabled': isEnabled ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'last_triggered': lastTriggered?.toIso8601String(),
    };
  }

  static Map<String, String> _decodeHeaders(String? headers) {
    if (headers == null || headers.isEmpty) return const {};
    try {
      final entries = headers.split('\n');
      return {
        for (final entry in entries)
          if (entry.contains(':'))
            entry.substring(0, entry.indexOf(':')).trim():
                entry.substring(entry.indexOf(':') + 1).trim(),
      };
    } catch (_) {
      return const {};
    }
  }

  static String _encodeHeaders(Map<String, String> headers) {
    return headers.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }
}
