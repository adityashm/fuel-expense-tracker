import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/fuel_expense.dart';
import '../models/general_expense.dart';
import '../services/database_service.dart';
import '../services/firebase_service.dart';
import '../utils/constants.dart';

enum SyncStatus {
  idle,
  syncing,
  synced,
  error,
  offline,
}

class SyncService {
  SyncService._init();
  static final SyncService instance = SyncService._init();

  final _connectivity = Connectivity();
  final _db = DatabaseService.instance;
  final _firebase = FirebaseService.instance;

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  Timer? _autoSyncTimer;
  bool _isSyncing = false;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream {
    // Emit current status immediately when stream is accessed
    _statusController.add(_status);
    return _statusController.stream;
  }

  /// Checks if the device has internet connectivity.
  /// 
  /// Returns `true` if connected to any network (WiFi, mobile, etc.),
  /// `false` if offline.
  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Initializes automatic background synchronization.
  /// 
  /// Sets up a periodic timer that calls [syncAll] at intervals defined by
  /// [AppConstants.autoSyncInterval]. This is a fire-and-forget operation
  /// that runs in the background, which is why it's not awaited in main.dart.
  /// 
  /// Note: This method returns `void`, not `Future<void>`, as it sets up
  /// a background timer rather than performing an async operation.
  void startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(
      AppConstants.autoSyncInterval,
      (_) => syncAll(),
    );
  }

  /// Stops automatic background synchronization.
  /// 
  /// Cancels the periodic timer if it's running.
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
  }

  /// Updates the current sync status and notifies listeners.
  /// 
  /// [newStatus] The new sync status to set.
  void _updateStatus(SyncStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  /// Ensures Firebase is authenticated before syncing.
  /// 
  /// Attempts to sign in anonymously if not already authenticated.
  /// Returns `true` if Firebase is ready, `false` if authentication fails.
  Future<bool> _ensureFirebaseReady() async {
    if (_firebase.userId != null) return true;
    try {
      await _firebase.signInAnonymously();
      return _firebase.userId != null;
    } catch (e) {
      debugPrint('Firebase sign-in failed, sync aborted: $e');
      return false;
    }
  }

  /// Syncs all local data to Firebase with batching to prevent ANR.
  /// 
  /// This method:
  /// - Checks connectivity and Firebase authentication
  /// - Syncs vehicles, fuel expenses, and general expenses in batches
  /// - Updates sync status throughout the process
  /// - Prevents multiple simultaneous syncs
  /// 
  /// Returns `true` if sync completed successfully, `false` otherwise.
  Future<bool> syncAll() async {
    if (_isSyncing) return false;
    if (!await isOnline()) {
      _updateStatus(SyncStatus.offline);
      return false;
    }
    if (!await _ensureFirebaseReady()) {
      _updateStatus(SyncStatus.error);
      return false;
    }

    _isSyncing = true;
    _updateStatus(SyncStatus.syncing);

    try {
      // Get all local data
      final vehicles = await _db.getAllVehicles();

      // Sync in batches to prevent ANR
      const batchSize = 50;

      // Sync vehicles
      for (var i = 0; i < vehicles.length; i += batchSize) {
        final end =
            (i + batchSize < vehicles.length) ? i + batchSize : vehicles.length;
        final batch = vehicles.sublist(i, end);

        for (final vehicle in batch) {
          await _firebase.syncVehicle(vehicle.toMap());
        }

        // Small delay to keep UI responsive
        if (i + batchSize < vehicles.length) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      // Sync fuel expenses in batches using pagination
      int offset = 0;
      List<FuelExpense> fuelBatch;
      do {
        fuelBatch = await _db.getFuelExpensesPaginated(offset: offset);
        for (final expense in fuelBatch) {
          await _firebase.syncFuelExpense(expense.toMap());
        }
        offset += batchSize;

        if (fuelBatch.length == batchSize) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      } while (fuelBatch.length == batchSize);

      // Sync general expenses in batches
      offset = 0;
      List<GeneralExpense> generalBatch;
      do {
        generalBatch = await _db.getGeneralExpensesPaginated(offset: offset);
        for (final expense in generalBatch) {
          await _firebase.syncGeneralExpense(expense.toMap());
        }
        offset += batchSize;

        if (generalBatch.length == batchSize) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      } while (generalBatch.length == batchSize);

      // Update last sync time
      _lastSyncTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', _lastSyncTime!.toIso8601String());

      _updateStatus(SyncStatus.synced);
      _isSyncing = false;
      return true;
    } catch (e) {
      debugPrint('Sync error: $e');
      _updateStatus(SyncStatus.error);
      _isSyncing = false;
      return false;
    }
  }

  // Sync individual vehicle
  Future<void> syncVehicle(int vehicleId) async {
    if (!await isOnline()) return;
    if (!await _ensureFirebaseReady()) return;

    try {
      final vehicle = await _db.getVehicle(vehicleId);
      if (vehicle != null) {
        await _firebase.syncVehicle(vehicle.toMap());
      }
    } catch (e) {
      debugPrint('Sync vehicle error: $e');
    }
  }

  // Sync individual expense
  Future<void> syncFuelExpense(int expenseId) async {
    if (!await isOnline()) return;
    if (!await _ensureFirebaseReady()) return;

    try {
      final expenses = await _db.getAllFuelExpenses();
      final expense = expenses.cast<FuelExpense?>().firstWhere(
            (e) => e?.id == expenseId,
            orElse: () => null,
          );
      if (expense != null) {
        await _firebase.syncFuelExpense(expense.toMap());
      }
    } catch (e) {
      debugPrint('Sync fuel expense error: $e');
    }
  }

  Future<void> syncGeneralExpense(int expenseId) async {
    if (!await isOnline()) return;
    if (!await _ensureFirebaseReady()) return;

    try {
      final expenses = await _db.getAllGeneralExpenses();
      final expense = expenses.cast<GeneralExpense?>().firstWhere(
            (e) => e?.id == expenseId,
            orElse: () => null,
          );
      if (expense != null) {
        await _firebase.syncGeneralExpense(expense.toMap());
      }
    } catch (e) {
      debugPrint('Sync general expense error: $e');
    }
  }

  // Pull data from Firebase
  Future<void> pullFromFirebase() async {
    if (!await isOnline()) {
      _updateStatus(SyncStatus.offline);
      return;
    }
    if (!await _ensureFirebaseReady()) {
      _updateStatus(SyncStatus.error);
      return;
    }

    _updateStatus(SyncStatus.syncing);

    try {
      // Pull vehicles from Firebase
      final remoteVehicles = await _firebase.getVehicles();

      // Merge with local data (implement conflict resolution)
      for (final vehicleData in remoteVehicles) {
        // Check if vehicle exists locally
        final localVehicle = await _db.getVehicle(vehicleData['id']);

        if (localVehicle == null) {
          // New vehicle from cloud, add to local DB
          // Note: You'll need to implement a fromMap method that handles Firebase data
          debugPrint('New vehicle from cloud: ${vehicleData['name']}');
        }
      }

      _updateStatus(SyncStatus.synced);
    } catch (e) {
      debugPrint('Pull from Firebase error: $e');
      _updateStatus(SyncStatus.error);
    }
  }

  // Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeString = prefs.getString('last_sync_time');
    if (timeString != null) {
      return DateTime.parse(timeString);
    }
    return null;
  }

  // Check if sync is needed (data changed since last sync)
  Future<bool> needsSync() async {
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;

    // Check if any data was modified after last sync
    // This is a simplified check - you'd want to track modification timestamps
    return DateTime.now().difference(lastSync).inMinutes > 5;
  }

  void dispose() {
    _autoSyncTimer?.cancel();
    _statusController.close();
  }
}
