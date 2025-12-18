import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/family_task.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

/// Provider for managing family tasks
class FamilyTaskProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final NotificationService _notificationService = NotificationService.instance;

  List<FamilyTask> _tasks = [];
  List<FamilyTask> _completedTasks = [];
  bool _isLoading = false;
  String? _error;

  // Filters
  TaskFilter _currentFilter = TaskFilter.all;
  int? _filterMemberId;
  int? _filterVehicleId;
  TaskType? _filterType;

  // Getters
  List<FamilyTask> get tasks => _getFilteredTasks();
  List<FamilyTask> get completedTasks => _completedTasks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  TaskFilter get currentFilter => _currentFilter;

  // Statistics
  int get totalTasks => _tasks.length;
  int get urgentTasks =>
      _tasks.where((t) => t.isUrgent && !t.isCompleted).length;
  int get overdueTasks => _tasks.where((t) => t.isOverdue).length;
  int get dueTodayTasks => _tasks.where((t) => t.isDueToday).length;
  int get shoppingTasks =>
      _tasks.where((t) => t.isShoppingTask && !t.isCompleted).length;

  List<FamilyTask> _getFilteredTasks() {
    var filtered = _tasks.where((task) => !task.isCompleted).toList();

    switch (_currentFilter) {
      case TaskFilter.urgent:
        filtered = filtered.where((t) => t.isUrgent || t.isOverdue).toList();
        break;
      case TaskFilter.today:
        filtered = filtered.where((t) => t.isDueToday).toList();
        break;
      case TaskFilter.week:
        filtered = filtered.where((t) => t.isDueWithin(7)).toList();
        break;
      case TaskFilter.shopping:
        filtered = filtered.where((t) => t.isShoppingTask).toList();
        break;
      case TaskFilter.assigned:
        if (_filterMemberId != null) {
          filtered = filtered
              .where((t) => t.assignedToMemberId == _filterMemberId)
              .toList();
        }
        break;
      case TaskFilter.vehicle:
        if (_filterVehicleId != null) {
          filtered =
              filtered.where((t) => t.vehicleId == _filterVehicleId).toList();
        }
        break;
      case TaskFilter.type:
        if (_filterType != null) {
          filtered = filtered.where((t) => t.type == _filterType).toList();
        }
        break;
      case TaskFilter.all:
        break;
    }

    // Sort: urgent first, then by due date
    filtered.sort((a, b) {
      if (a.isUrgent && !b.isUrgent) return -1;
      if (!a.isUrgent && b.isUrgent) return 1;
      if (a.isOverdue && !b.isOverdue) return -1;
      if (!a.isOverdue && b.isOverdue) return 1;

      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });

    return filtered;
  }

  /// Load all tasks from database
  Future<void> loadTasks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final tasksData = await _db.getAllFamilyTasks();
      _tasks = tasksData.map((data) => FamilyTask.fromMap(data)).toList();

      final completedData = await _db.getCompletedTasks(limit: 100);
      _completedTasks =
          completedData.map((data) => FamilyTask.fromMap(data)).toList();

      _error = null;
    } catch (e) {
      _error = 'Failed to load tasks: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new task
  Future<bool> createTask(FamilyTask task) async {
    try {
      final taskMap = task.toMap()..remove('id'); // Let database generate ID

      // Convert shopping items to JSON
      if (task.shoppingItems != null && task.shoppingItems!.isNotEmpty) {
        taskMap['shopping_items_json'] = jsonEncode(
          task.shoppingItems!.map((item) => item.toJson()).toList(),
        );
      }

      final id = await _db.createFamilyTask(taskMap);

      final newTask = task.copyWith(id: id);
      _tasks.add(newTask);
      notifyListeners();

      // Schedule notification if has due date
      if (task.dueDate != null && task.assignedToMemberId != null) {
        await _scheduleTaskNotification(newTask);
      }

      // Create recurring instances if needed
      if (task.recurrencePattern != RecurrencePattern.none) {
        await _createRecurringInstance(newTask);
      }

      return true;
    } catch (e) {
      _error = 'Failed to create task: $e';
      debugPrint(_error);
      notifyListeners();
      return false;
    }
  }

  /// Update an existing task
  Future<bool> updateTask(FamilyTask task) async {
    try {
      final taskMap = task.toMap();

      // Convert shopping items to JSON
      if (task.shoppingItems != null && task.shoppingItems!.isNotEmpty) {
        taskMap['shopping_items_json'] = jsonEncode(
          task.shoppingItems!.map((item) => item.toJson()).toList(),
        );
      }

      // Ensure task has an ID before updating
      final taskId = task.id;
      if (taskId == null) {
        throw Exception('Cannot update task without ID');
      }

      await _db.updateFamilyTask(taskId, taskMap);

      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = task;
        notifyListeners();
      }

      // Update notification if due date changed
      if (task.dueDate != null && task.assignedToMemberId != null) {
        await _scheduleTaskNotification(task);
      }

      return true;
    } catch (e) {
      _error = 'Failed to update task: $e';
      debugPrint(_error);
      notifyListeners();
      return false;
    }
  }

  /// Complete a task
  Future<bool> completeTask(
    int taskId,
    int completedByMemberId,
    String? completedByName,
  ) async {
    try {
      await _db.completeTask(taskId, completedByMemberId, completedByName);

      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        final task = _tasks[index];
        final completedTask = task.copyWith(
          isCompleted: true,
          completedAt: DateTime.now(),
          completedByMemberId: completedByMemberId,
          completedByName: completedByName,
        );

        _tasks.removeAt(index);
        _completedTasks.insert(0, completedTask);
        notifyListeners();

        // Cancel notification
        await _notificationService.cancelNotification(taskId);

        // Show completion notification to other family members
        await _notifyTaskCompleted(completedTask);

        // Create next recurring instance if needed
        if (task.recurrencePattern != RecurrencePattern.none) {
          await _createRecurringInstance(completedTask);
        }
      }

      return true;
    } catch (e) {
      _error = 'Failed to complete task: $e';
      debugPrint(_error);
      notifyListeners();
      return false;
    }
  }

  /// Uncomplete a task (move back to active)
  Future<bool> uncompleteTask(int taskId) async {
    try {
      await _db.uncompleteTask(taskId);

      final index = _completedTasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        // Clear all completion-related fields when uncompleting
        final task = _completedTasks[index].copyWith(
          isCompleted: false,
        );

        _completedTasks.removeAt(index);
        _tasks.add(task);
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = 'Failed to uncomplete task: $e';
      debugPrint(_error);
      notifyListeners();
      return false;
    }
  }

  /// Delete a task
  Future<bool> deleteTask(int taskId) async {
    try {
      await _db.deleteFamilyTask(taskId);

      _tasks.removeWhere((t) => t.id == taskId);
      _completedTasks.removeWhere((t) => t.id == taskId);
      notifyListeners();

      // Cancel notification
      await _notificationService.cancelNotification(taskId);

      return true;
    } catch (e) {
      _error = 'Failed to delete task: $e';
      debugPrint(_error);
      notifyListeners();
      return false;
    }
  }

  /// Set filter
  void setFilter(
    TaskFilter filter, {
    int? memberId,
    int? vehicleId,
    TaskType? type,
  }) {
    _currentFilter = filter;
    _filterMemberId = memberId;
    _filterVehicleId = vehicleId;
    _filterType = type;
    notifyListeners();
  }

  /// Clear filter
  void clearFilter() {
    _currentFilter = TaskFilter.all;
    _filterMemberId = null;
    _filterVehicleId = null;
    _filterType = null;
    notifyListeners();
  }

  /// Get tasks for a specific vehicle
  Future<List<FamilyTask>> getTasksForVehicle(int vehicleId) async {
    try {
      final data = await _db.getTasksForVehicle(vehicleId);
      return data.map((d) => FamilyTask.fromMap(d)).toList();
    } catch (e) {
      debugPrint('Failed to load vehicle tasks: $e');
      return [];
    }
  }

  /// Get tasks assigned to a member
  Future<List<FamilyTask>> getTasksForMember(int memberId) async {
    try {
      final data = await _db.getTasksAssignedTo(memberId);
      return data.map((d) => FamilyTask.fromMap(d)).toList();
    } catch (e) {
      debugPrint('Failed to load member tasks: $e');
      return [];
    }
  }

  /// Get shopping list
  Future<List<FamilyTask>> getShoppingList() async {
    try {
      final data = await _db.getShoppingTasks();
      return data.map((d) => FamilyTask.fromMap(d)).toList();
    } catch (e) {
      debugPrint('Failed to load shopping tasks: $e');
      return [];
    }
  }

  /// Schedule task notification
  Future<void> _scheduleTaskNotification(FamilyTask task) async {
    if (task.dueDate == null) return;

    final title = task.assignedToName != null
        ? '${task.assignedToName}: ${task.title}'
        : task.title;

    final body = task.vehicleName != null
        ? 'Vehicle: ${task.vehicleName}'
        : task.description ?? 'Task reminder';

    // Schedule notification 1 day before
    final oneDayBefore = task.dueDate!.subtract(const Duration(days: 1));
    if (oneDayBefore.isAfter(DateTime.now())) {
      await _notificationService.scheduleReminder(
        id: task.id! * 10 + 1, // Unique ID
        title: '⏰ Task due tomorrow: $title',
        body: body,
        scheduledDate: oneDayBefore,
        payload: 'task_${task.id}',
      );
    }

    // Schedule notification on due date
    if (task.dueDate!.isAfter(DateTime.now())) {
      await _notificationService.scheduleReminder(
        id: task.id! * 10 + 2,
        title: '🚨 Task due today: $title',
        body: body,
        scheduledDate: task.dueDate!,
        payload: 'task_${task.id}',
      );
    }
  }

  /// Notify family members when task is completed
  Future<void> _notifyTaskCompleted(FamilyTask task) async {
    final completer = task.completedByName ?? 'Someone';
    await _notificationService.showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '✅ Task completed',
      body: '$completer completed: ${task.title}',
      payload: 'task_completed_${task.id}',
    );
  }

  /// Create next recurring task instance
  Future<void> _createRecurringInstance(FamilyTask completedTask) async {
    if (completedTask.recurrencePattern == RecurrencePattern.none) return;
    if (completedTask.dueDate == null) return;

    // Check if we've reached the end date
    if (completedTask.recurrenceEndDate != null &&
        DateTime.now().isAfter(completedTask.recurrenceEndDate!)) {
      return;
    }

    // Calculate next due date
    DateTime? nextDueDate;
    final interval = completedTask.recurrenceInterval ??
        completedTask.recurrencePattern.daysInterval;

    if (interval != null) {
      nextDueDate = completedTask.dueDate!.add(Duration(days: interval));
    }

    if (nextDueDate != null) {
      final nextTask = completedTask.copyWith(
        dueDate: nextDueDate,
        isCompleted: false,
        parentTaskId: completedTask.id,
        createdAt: DateTime.now(),
        isSynced: false,
      );

      await createTask(nextTask);
    }
  }

  /// Check and create recurring tasks (call this periodically)
  Future<void> processRecurringTasks() async {
    try {
      final recurringTasks = await _db.getRecurringTasksDue();

      for (final taskData in recurringTasks) {
        final task = FamilyTask.fromMap(taskData);
        await _createRecurringInstance(task);
      }
    } catch (e) {
      debugPrint('Failed to process recurring tasks: $e');
    }
  }
}

/// Filter enum for tasks
enum TaskFilter {
  all,
  urgent,
  today,
  week,
  shopping,
  assigned,
  vehicle,
  type,
}
