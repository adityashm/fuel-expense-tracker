// ignore_for_file: cascade_invocations

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_service.dart';
import 'firebase_service.dart';

/// Represents a pending sync operation
class SyncOperation {
  SyncOperation({
    required this.id,
    required this.type,
    required this.table,
    required this.localId,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  factory SyncOperation.fromMap(Map<String, dynamic> map) => SyncOperation(
        id: map['id'] as String,
        type: SyncOperationType.values.byName(map['type'] as String),
        table: map['table'] as String,
        localId: map['localId'] as int,
        data: jsonDecode(map['data'] as String) as Map<String, dynamic>,
        createdAt: DateTime.parse(map['createdAt'] as String),
        retryCount: map['retryCount'] as int? ?? 0,
        lastError: map['lastError'] as String?,
      );
  final String id;
  final SyncOperationType type;
  final String table;
  final int localId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  int retryCount;
  String? lastError;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'table': table,
        'localId': localId,
        'data': jsonEncode(data),
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
        'lastError': lastError,
      };
}

enum SyncOperationType {
  create,
  update,
  delete,
}

/// Queue status
class QueueStatus {
  QueueStatus({
    required this.pendingCount,
    required this.failedCount,
    required this.isSyncing,
    this.lastSyncAttempt,
    this.lastError,
  });
  final int pendingCount;
  final int failedCount;
  final bool isSyncing;
  final DateTime? lastSyncAttempt;
  final String? lastError;
}

/// Enhanced offline sync service with queue-based operations
class OfflineSyncQueueService {
  OfflineSyncQueueService._();
  static final OfflineSyncQueueService instance = OfflineSyncQueueService._();

  final _firebase = FirebaseService.instance;
  final _connectivity = Connectivity();

  final List<SyncOperation> _queue = [];
  bool _isSyncing = false;
  Timer? _autoSyncTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  final _statusController = StreamController<QueueStatus>.broadcast();
  Stream<QueueStatus> get statusStream => _statusController.stream;

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 5);
  static const Duration _autoSyncInterval = Duration(minutes: 5);
  static const String _queueKey = 'offline_sync_queue';

  /// Initialize the service
  Future<void> initialize() async {
    // Load persisted queue
    await _loadQueue();

    // Listen for connectivity changes
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((result) {
      final isOnline = result != ConnectivityResult.none;
      if (isOnline && _queue.isNotEmpty) {
        processQueue();
      }
    });

    // Start auto-sync timer
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (_) => processQueue());

    // Process queue if online
    if (await _isOnline()) {
      unawaited(processQueue());
    }
  }

  /// Check if device is online
  Future<bool> _isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Add operation to sync queue
  Future<void> enqueue({
    required SyncOperationType type,
    required String table,
    required int localId,
    required Map<String, dynamic> data,
  }) async {
    final operation = SyncOperation(
      id: '${table}_${localId}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      table: table,
      localId: localId,
      data: data,
      createdAt: DateTime.now(),
    );

    // Remove any existing operations for the same record
    _queue.removeWhere((op) => op.table == table && op.localId == localId);

    // Add new operation
    _queue.add(operation);
    await _saveQueue();
    _emitStatus();

    // Try to sync immediately if online
    if (await _isOnline()) {
      unawaited(processQueue());
    }
  }

  /// Enqueue a fuel expense operation
  Future<void> enqueueFuelExpense(
    int expenseId,
    Map<String, dynamic> data, {
    SyncOperationType type = SyncOperationType.create,
  }) async {
    await enqueue(
      type: type,
      table: 'fuel_expenses',
      localId: expenseId,
      data: data,
    );
  }

  /// Enqueue a general expense operation
  Future<void> enqueueGeneralExpense(
    int expenseId,
    Map<String, dynamic> data, {
    SyncOperationType type = SyncOperationType.create,
  }) async {
    await enqueue(
      type: type,
      table: 'general_expenses',
      localId: expenseId,
      data: data,
    );
  }

  /// Enqueue a vehicle operation
  Future<void> enqueueVehicle(
    int vehicleId,
    Map<String, dynamic> data, {
    SyncOperationType type = SyncOperationType.create,
  }) async {
    await enqueue(
      type: type,
      table: 'vehicles',
      localId: vehicleId,
      data: data,
    );
  }

  /// Process the sync queue
  Future<void> processQueue() async {
    if (_isSyncing || _queue.isEmpty) return;
    if (!await _isOnline()) {
      _emitStatus();
      return;
    }

    // Ensure Firebase is ready
    if (_firebase.userId == null) {
      try {
        await _firebase.signInAnonymously();
      } catch (e) {
        debugPrint('Firebase sign-in failed: $e');
        return;
      }
    }

    _isSyncing = true;
    _emitStatus();

    // Process operations in order
    final toProcess = List<SyncOperation>.from(_queue);

    for (final operation in toProcess) {
      try {
        await _processOperation(operation);

        // Remove successful operation
        _queue.removeWhere((op) => op.id == operation.id);
        await _saveQueue();
        _emitStatus();

        // Small delay to prevent overwhelming the server
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        operation.retryCount++;
        operation.lastError = e.toString();

        if (operation.retryCount >= _maxRetries) {
          // Move to failed state but keep in queue for manual retry
          debugPrint(
              'Sync operation failed after $_maxRetries retries: ${operation.id}',);
        }

        await _saveQueue();
        _emitStatus();

        // Wait before retrying
        await Future.delayed(_retryDelay);
      }
    }

    _isSyncing = false;
    _emitStatus();

    // Update last sync time
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_queue_sync', DateTime.now().toIso8601String());
  }

  /// Process a single sync operation
  Future<void> _processOperation(SyncOperation operation) async {
    switch (operation.table) {
      case 'fuel_expenses':
        await _syncFuelExpense(operation);
        break;
      case 'general_expenses':
        await _syncGeneralExpense(operation);
        break;
      case 'vehicles':
        await _syncVehicle(operation);
        break;
      default:
        debugPrint('Unknown table: ${operation.table}');
    }
  }

  Future<void> _syncFuelExpense(SyncOperation operation) async {
    switch (operation.type) {
      case SyncOperationType.create:
      case SyncOperationType.update:
        await _firebase.syncFuelExpense(operation.data);
        break;
      case SyncOperationType.delete:
        // Mark as deleted in Firebase
        final deleteData = Map<String, dynamic>.from(operation.data);
        deleteData['deleted'] = true;
        deleteData['deletedAt'] = DateTime.now().toIso8601String();
        await _firebase.syncFuelExpense(deleteData);
        break;
    }
  }

  Future<void> _syncGeneralExpense(SyncOperation operation) async {
    switch (operation.type) {
      case SyncOperationType.create:
      case SyncOperationType.update:
        await _firebase.syncGeneralExpense(operation.data);
        break;
      case SyncOperationType.delete:
        final deleteData = Map<String, dynamic>.from(operation.data);
        deleteData['deleted'] = true;
        deleteData['deletedAt'] = DateTime.now().toIso8601String();
        await _firebase.syncGeneralExpense(deleteData);
        break;
    }
  }

  Future<void> _syncVehicle(SyncOperation operation) async {
    switch (operation.type) {
      case SyncOperationType.create:
      case SyncOperationType.update:
        await _firebase.syncVehicle(operation.data);
        break;
      case SyncOperationType.delete:
        final deleteData = Map<String, dynamic>.from(operation.data);
        deleteData['deleted'] = true;
        deleteData['deletedAt'] = DateTime.now().toIso8601String();
        await _firebase.syncVehicle(deleteData);
        break;
    }
  }

  /// Get current queue status
  QueueStatus getStatus() {
    final pending = _queue.where((op) => op.retryCount < _maxRetries).length;
    final failed = _queue.where((op) => op.retryCount >= _maxRetries).length;

    return QueueStatus(
      pendingCount: pending,
      failedCount: failed,
      isSyncing: _isSyncing,
      lastSyncAttempt: _queue.isNotEmpty ? _queue.last.createdAt : null,
      lastError: _queue.isNotEmpty ? _queue.last.lastError : null,
    );
  }

  /// Retry all failed operations
  Future<void> retryFailed() async {
    for (final operation in _queue) {
      if (operation.retryCount >= _maxRetries) {
        operation.retryCount = 0;
        operation.lastError = null;
      }
    }
    await _saveQueue();
    _emitStatus();
    await processQueue();
  }

  /// Clear all failed operations
  Future<void> clearFailed() async {
    _queue.removeWhere((op) => op.retryCount >= _maxRetries);
    await _saveQueue();
    _emitStatus();
  }

  /// Clear entire queue (use with caution)
  Future<void> clearQueue() async {
    _queue.clear();
    await _saveQueue();
    _emitStatus();
  }

  /// Get pending operations count
  int get pendingCount =>
      _queue.where((op) => op.retryCount < _maxRetries).length;

  /// Get failed operations count
  int get failedCount =>
      _queue.where((op) => op.retryCount >= _maxRetries).length;

  /// Check if there are pending operations
  bool get hasPendingOperations => _queue.isNotEmpty;

  void _emitStatus() {
    _statusController.add(getStatus());
  }

  /// Persist queue to SharedPreferences
  Future<void> _saveQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = _queue.map((op) => jsonEncode(op.toMap())).toList();
    await prefs.setStringList(_queueKey, queueJson);
  }

  /// Load queue from SharedPreferences
  Future<void> _loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getStringList(_queueKey) ?? [];

    _queue.clear();
    for (final json in queueJson) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        _queue.add(SyncOperation.fromMap(map));
      } catch (e) {
        debugPrint('Failed to parse sync operation: $e');
      }
    }
    _emitStatus();
  }

  /// Dispose resources
  void dispose() {
    _autoSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _statusController.close();
  }
}

/// Extension to easily add sync operations after database operations
extension SyncQueueExtension on DatabaseService {
  Future<void> syncAfterFuelExpenseAdd(
      int expenseId, Map<String, dynamic> data,) async {
    await OfflineSyncQueueService.instance.enqueueFuelExpense(
      expenseId,
      data,
    );
  }

  Future<void> syncAfterFuelExpenseUpdate(
      int expenseId, Map<String, dynamic> data,) async {
    await OfflineSyncQueueService.instance.enqueueFuelExpense(
      expenseId,
      data,
      type: SyncOperationType.update,
    );
  }

  Future<void> syncAfterFuelExpenseDelete(
      int expenseId, Map<String, dynamic> data,) async {
    await OfflineSyncQueueService.instance.enqueueFuelExpense(
      expenseId,
      data,
      type: SyncOperationType.delete,
    );
  }

  Future<void> syncAfterGeneralExpenseAdd(
      int expenseId, Map<String, dynamic> data,) async {
    await OfflineSyncQueueService.instance.enqueueGeneralExpense(
      expenseId,
      data,
    );
  }

  Future<void> syncAfterGeneralExpenseUpdate(
      int expenseId, Map<String, dynamic> data,) async {
    await OfflineSyncQueueService.instance.enqueueGeneralExpense(
      expenseId,
      data,
      type: SyncOperationType.update,
    );
  }

  Future<void> syncAfterGeneralExpenseDelete(
      int expenseId, Map<String, dynamic> data,) async {
    await OfflineSyncQueueService.instance.enqueueGeneralExpense(
      expenseId,
      data,
      type: SyncOperationType.delete,
    );
  }
}
