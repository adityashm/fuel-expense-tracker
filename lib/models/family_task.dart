import 'dart:convert';

import 'package:intl/intl.dart';

/// Task type enum
enum TaskType {
  maintenance,
  shopping,
  refuel,
  insurance,
  cleaning,
  inspection,
  other;

  String get displayName {
    switch (this) {
      case TaskType.maintenance:
        return 'Maintenance';
      case TaskType.shopping:
        return 'Shopping';
      case TaskType.refuel:
        return 'Refuel';
      case TaskType.insurance:
        return 'Insurance';
      case TaskType.cleaning:
        return 'Cleaning';
      case TaskType.inspection:
        return 'Inspection';
      case TaskType.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case TaskType.maintenance:
        return '🔧';
      case TaskType.shopping:
        return '🛒';
      case TaskType.refuel:
        return '⛽';
      case TaskType.insurance:
        return '📋';
      case TaskType.cleaning:
        return '🧼';
      case TaskType.inspection:
        return '🔍';
      case TaskType.other:
        return '📝';
    }
  }
}

/// Task priority enum
enum TaskPriority {
  low,
  normal,
  high,
  urgent;

  String get displayName {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.normal:
        return 'Normal';
      case TaskPriority.high:
        return 'High';
      case TaskPriority.urgent:
        return 'Urgent';
    }
  }
}

/// Recurrence pattern enum
enum RecurrencePattern {
  none,
  daily,
  weekly,
  biweekly,
  monthly,
  custom;

  String get displayName {
    switch (this) {
      case RecurrencePattern.none:
        return 'Does not repeat';
      case RecurrencePattern.daily:
        return 'Daily';
      case RecurrencePattern.weekly:
        return 'Weekly';
      case RecurrencePattern.biweekly:
        return 'Every 2 weeks';
      case RecurrencePattern.monthly:
        return 'Monthly';
      case RecurrencePattern.custom:
        return 'Custom';
    }
  }

  int? get daysInterval {
    switch (this) {
      case RecurrencePattern.daily:
        return 1;
      case RecurrencePattern.weekly:
        return 7;
      case RecurrencePattern.biweekly:
        return 14;
      case RecurrencePattern.monthly:
        return 30;
      default:
        return null;
    }
  }
}

/// Shopping item model
class ShoppingItem {
  ShoppingItem({
    required this.itemName,
    this.description,
    this.quantity = 1,
    this.estimatedCost,
    this.unit,
    this.isPurchased = false,
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      itemName: json['itemName'] as String,
      description: json['description'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      estimatedCost: json['estimatedCost'] as double?,
      unit: json['unit'] as String?,
      isPurchased: json['isPurchased'] as bool? ?? false,
    );
  }
  final String itemName;
  final String? description;
  final int quantity;
  final double? estimatedCost;
  final String? unit; // e.g., "liters", "bottles", "pieces"
  final bool isPurchased;

  Map<String, dynamic> toJson() {
    return {
      'itemName': itemName,
      'description': description,
      'quantity': quantity,
      'estimatedCost': estimatedCost,
      'unit': unit,
      'isPurchased': isPurchased,
    };
  }

  ShoppingItem copyWith({
    String? itemName,
    String? description,
    int? quantity,
    double? estimatedCost,
    String? unit,
    bool? isPurchased,
  }) {
    return ShoppingItem(
      itemName: itemName ?? this.itemName,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      unit: unit ?? this.unit,
      isPurchased: isPurchased ?? this.isPurchased,
    );
  }

  String get displayText {
    final buffer = StringBuffer()..write(itemName);
    if (quantity > 1) {
      buffer.write(' x$quantity');
      if (unit != null) buffer.write(' $unit');
    }
    if (estimatedCost != null) {
      buffer.write(' (₹${estimatedCost!.toStringAsFixed(0)})');
    }
    return buffer.toString();
  }
}

/// Family task model
class FamilyTask {
  FamilyTask({
    this.id,
    required this.title,
    this.description,
    this.vehicleId,
    this.vehicleName,
    this.assignedToMemberId,
    this.assignedToName,
    this.dueDate,
    this.type = TaskType.other,
    this.priority = TaskPriority.normal,
    this.isUrgent = false,
    this.isCompleted = false,
    this.completedAt,
    this.completedByMemberId,
    this.completedByName,
    required this.createdByMemberId,
    this.createdByName,
    DateTime? createdAt,
    this.updatedAt,
    this.recurrencePattern = RecurrencePattern.none,
    this.recurrenceInterval,
    this.recurrenceEndDate,
    this.parentTaskId,
    this.isShoppingTask = false,
    this.shoppingItems,
    this.firebaseId,
    this.isSynced = false,
  }) : createdAt = createdAt ?? DateTime.now();

  // Create from database map
  factory FamilyTask.fromMap(Map<String, dynamic> map) {
    List<ShoppingItem>? items;
    if (map['shopping_items_json'] != null) {
      try {
        // Parse JSON string to list of shopping items
        final String jsonString = map['shopping_items_json'] as String;
        if (jsonString.isNotEmpty &&
            jsonString != '[]' &&
            jsonString != 'null') {
          // Handle both JSON array format and toString() format
          final dynamic decoded = json.decode(jsonString);
          if (decoded is List) {
            items = decoded
                .whereType<Map<String, dynamic>>()
                .map((itemMap) => ShoppingItem.fromJson(itemMap))
                .toList();
          }
        }
      } catch (e) {
        // Fallback: if parsing fails, leave items as null
        items = null;
      }
    }

    return FamilyTask(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      vehicleId: map['vehicle_id'] as int?,
      vehicleName: map['vehicle_name'] as String?,
      assignedToMemberId: map['assigned_to_member_id'] as int?,
      assignedToName: map['assigned_to_name'] as String?,
      dueDate: map['due_date'] != null
          ? DateTime.parse(map['due_date'] as String)
          : null,
      type: TaskType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TaskType.other,
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => TaskPriority.normal,
      ),
      isUrgent: map['is_urgent'] == 1,
      isCompleted: map['is_completed'] == 1,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      completedByMemberId: map['completed_by_member_id'] as int?,
      completedByName: map['completed_by_name'] as String?,
      createdByMemberId: map['created_by_member_id'] as int,
      createdByName: map['created_by_name'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      recurrencePattern: RecurrencePattern.values.firstWhere(
        (e) => e.name == map['recurrence_pattern'],
        orElse: () => RecurrencePattern.none,
      ),
      recurrenceInterval: map['recurrence_interval'] as int?,
      recurrenceEndDate: map['recurrence_end_date'] != null
          ? DateTime.parse(map['recurrence_end_date'] as String)
          : null,
      parentTaskId: map['parent_task_id'] as int?,
      isShoppingTask: map['is_shopping_task'] == 1,
      shoppingItems: items,
      firebaseId: map['firebase_id'] as String?,
      isSynced: map['is_synced'] == 1,
    );
  }
  final int? id;
  final String title;
  final String? description;
  final int? vehicleId;
  final String? vehicleName;
  final int? assignedToMemberId;
  final String? assignedToName;
  final DateTime? dueDate;
  final TaskType type;
  final TaskPriority priority;
  final bool isUrgent;
  final bool isCompleted;
  final DateTime? completedAt;
  final int? completedByMemberId;
  final String? completedByName;
  final int createdByMemberId;
  final String? createdByName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Recurrence fields
  final RecurrencePattern recurrencePattern;
  final int? recurrenceInterval; // For custom intervals
  final DateTime? recurrenceEndDate;
  final int? parentTaskId; // For tracking recurring task instances

  // Shopping list fields
  final bool isShoppingTask;
  final List<ShoppingItem>? shoppingItems;

  // Sync fields
  final String? firebaseId;
  final bool isSynced;

  // Check if task is overdue
  bool get isOverdue {
    if (isCompleted || dueDate == null) return false;
    return dueDate!.isBefore(DateTime.now());
  }

  // Check if task is due today
  bool get isDueToday {
    if (isCompleted || dueDate == null) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year &&
        dueDate!.month == now.month &&
        dueDate!.day == now.day;
  }

  // Check if task is due within X days
  bool isDueWithin(int days) {
    if (isCompleted || dueDate == null) return false;
    final deadline = DateTime.now().add(Duration(days: days));
    return dueDate!.isBefore(deadline);
  }

  // Get days until due
  int? get daysUntilDue {
    if (dueDate == null) return null;
    final now = DateTime.now();
    final difference =
        dueDate!.difference(DateTime(now.year, now.month, now.day));
    return difference.inDays;
  }

  // Get formatted due date
  String get formattedDueDate {
    if (dueDate == null) return 'No due date';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final difference = taskDate.difference(today).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference == -1) return 'Yesterday';
    if (difference > 1 && difference <= 7) return 'In $difference days';
    if (difference < -1 && difference >= -7) return '${-difference} days ago';

    return DateFormat('MMM dd, yyyy').format(dueDate!);
  }

  // Get total shopping cost
  double? get totalShoppingCost {
    if (!isShoppingTask || shoppingItems == null || shoppingItems!.isEmpty) {
      return null;
    }

    double total = 0;
    bool hasAnyCost = false;

    for (final item in shoppingItems!) {
      if (item.estimatedCost != null) {
        total += item.estimatedCost! * item.quantity;
        hasAnyCost = true;
      }
    }

    return hasAnyCost ? total : null;
  }

  // Get purchased items count
  int get purchasedItemsCount {
    if (!isShoppingTask || shoppingItems == null) return 0;
    return shoppingItems!.where((item) => item.isPurchased).length;
  }

  // Check if all shopping items purchased
  bool get allItemsPurchased {
    if (!isShoppingTask || shoppingItems == null || shoppingItems!.isEmpty) {
      return false;
    }
    return shoppingItems!.every((item) => item.isPurchased);
  }

  // Convert to map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'vehicle_id': vehicleId,
      'vehicle_name': vehicleName,
      'assigned_to_member_id': assignedToMemberId,
      'assigned_to_name': assignedToName,
      'due_date': dueDate?.toIso8601String(),
      'type': type.name,
      'priority': priority.name,
      'is_urgent': isUrgent ? 1 : 0,
      'is_completed': isCompleted ? 1 : 0,
      'completed_at': completedAt?.toIso8601String(),
      'completed_by_member_id': completedByMemberId,
      'completed_by_name': completedByName,
      'created_by_member_id': createdByMemberId,
      'created_by_name': createdByName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'recurrence_pattern': recurrencePattern.name,
      'recurrence_interval': recurrenceInterval,
      'recurrence_end_date': recurrenceEndDate?.toIso8601String(),
      'parent_task_id': parentTaskId,
      'is_shopping_task': isShoppingTask ? 1 : 0,
      'shopping_items_json': shoppingItems != null
          ? json.encode(shoppingItems!.map((item) => item.toJson()).toList())
          : null,
      'firebase_id': firebaseId,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  // Copy with method
  FamilyTask copyWith({
    int? id,
    String? title,
    String? description,
    int? vehicleId,
    String? vehicleName,
    int? assignedToMemberId,
    String? assignedToName,
    DateTime? dueDate,
    TaskType? type,
    TaskPriority? priority,
    bool? isUrgent,
    bool? isCompleted,
    DateTime? completedAt,
    int? completedByMemberId,
    String? completedByName,
    int? createdByMemberId,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    RecurrencePattern? recurrencePattern,
    int? recurrenceInterval,
    DateTime? recurrenceEndDate,
    int? parentTaskId,
    bool? isShoppingTask,
    List<ShoppingItem>? shoppingItems,
    String? firebaseId,
    bool? isSynced,
  }) {
    return FamilyTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleName: vehicleName ?? this.vehicleName,
      assignedToMemberId: assignedToMemberId ?? this.assignedToMemberId,
      assignedToName: assignedToName ?? this.assignedToName,
      dueDate: dueDate ?? this.dueDate,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      isUrgent: isUrgent ?? this.isUrgent,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      completedByMemberId: completedByMemberId ?? this.completedByMemberId,
      completedByName: completedByName ?? this.completedByName,
      createdByMemberId: createdByMemberId ?? this.createdByMemberId,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      isShoppingTask: isShoppingTask ?? this.isShoppingTask,
      shoppingItems: shoppingItems ?? this.shoppingItems,
      firebaseId: firebaseId ?? this.firebaseId,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
