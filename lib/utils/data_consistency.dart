import 'dart:async';

import 'package:flutter/foundation.dart';

/// Prevents race conditions in async operations
class OperationLock {
  final Map<String, Completer<void>> _locks = {};

  /// Acquire lock for operation
  Future<void> acquire(String key) async {
    while (_locks.containsKey(key)) {
      await _locks[key]!.future;
    }
    _locks[key] = Completer<void>();
  }

  /// Release lock for operation
  void release(String key) {
    final completer = _locks.remove(key);
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  /// Execute operation with automatic lock management
  Future<T> synchronized<T>(
    String key,
    Future<T> Function() operation,
  ) async {
    await acquire(key);
    try {
      return await operation();
    } finally {
      release(key);
    }
  }
}

/// Service for managing data consistency
class DataConsistencyService {
  DataConsistencyService._();
  static final DataConsistencyService instance = DataConsistencyService._();

  final _lock = OperationLock();

  /// Execute database operation with lock
  Future<T> executeWithLock<T>(
    String operationType,
    int? entityId,
    Future<T> Function() operation,
  ) async {
    final lockKey = '${operationType}_${entityId ?? 'all'}';
    return _lock.synchronized(lockKey, operation);
  }

  /// Remove duplicates safely
  Future<int> removeDuplicates(
    Future<int> Function() removalOperation,
  ) async {
    return executeWithLock('remove_duplicates', null, removalOperation);
  }
}

/// Optimistic update manager
class OptimisticUpdateManager<T> {
  final List<T> _items;
  final Map<String, T> _pendingUpdates = {};

  OptimisticUpdateManager(this._items);

  /// Add item optimistically
  void addOptimistic(String tempId, T item) {
    _items.insert(0, item);
    _pendingUpdates[tempId] = item;
  }

  /// Confirm successful creation
  void confirmCreate(String tempId, T updatedItem) {
    _pendingUpdates.remove(tempId);
    // Update item in list with server data
    final index = _items.indexWhere((item) {
      final pending = _pendingUpdates[tempId];
      return identical(item, pending);
    });
    if (index != -1) {
      _items[index] = updatedItem;
    }
  }

  /// Rollback failed creation
  void rollbackCreate(String tempId) {
    final item = _pendingUpdates.remove(tempId);
    if (item != null) {
      _items.remove(item);
    }
  }

  /// Update item optimistically
  void updateOptimistic(String tempId, T updatedItem, bool Function(T) matcher) {
    final index = _items.indexWhere(matcher);
    if (index != -1) {
      _pendingUpdates[tempId] = _items[index];
      _items[index] = updatedItem;
    }
  }

  /// Confirm successful update
  void confirmUpdate(String tempId) {
    _pendingUpdates.remove(tempId);
  }

  /// Rollback failed update
  void rollbackUpdate(String tempId, bool Function(T) matcher) {
    final original = _pendingUpdates.remove(tempId);
    if (original != null) {
      final index = _items.indexWhere(matcher);
      if (index != -1) {
        _items[index] = original;
      }
    }
  }

  /// Delete item optimistically
  void deleteOptimistic(String tempId, bool Function(T) matcher) {
    final index = _items.indexWhere(matcher);
    if (index != -1) {
      _pendingUpdates[tempId] = _items[index];
      _items.removeAt(index);
    }
  }

  /// Confirm successful deletion
  void confirmDelete(String tempId) {
    _pendingUpdates.remove(tempId);
  }

  /// Rollback failed deletion
  void rollbackDelete(String tempId, int originalIndex) {
    final item = _pendingUpdates.remove(tempId);
    if (item != null) {
      _items.insert(originalIndex.clamp(0, _items.length), item);
    }
  }

  /// Check if there are pending operations
  bool get hasPendingOperations => _pendingUpdates.isNotEmpty;

  /// Get count of pending operations
  int get pendingCount => _pendingUpdates.length;
}
