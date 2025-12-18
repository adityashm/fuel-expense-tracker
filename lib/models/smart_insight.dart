enum InsightCategory {
  savings,
  maintenance,
  planning,
  collaboration,
}

class SmartInsight {
  const SmartInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.priority = 0,
    this.actionLabel,
  });
  final String id;
  final String title;
  final String description;
  final InsightCategory category;
  final double priority;
  final String? actionLabel;
}
