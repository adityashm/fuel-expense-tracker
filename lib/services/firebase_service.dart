import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../utils/firebase_cache.dart';

class FirebaseService {
  FirebaseService._init();
  static final FirebaseService instance = FirebaseService._init();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? get currentUser => _auth.currentUser;
  String? get userId => currentUser?.uid;

  // Anonymous authentication for device identification
  Future<User?> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      return credential.user;
    } catch (e) {
      debugPrint('Anonymous sign-in error: $e');
      rethrow; // Propagate error to caller
    }
  }

  // Devices collection
  Future<void> syncDevice(Map<String, dynamic> deviceData) async {
    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc(deviceData['device_id'])
          .set(
        {
          ...deviceData,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Sync device error: $e');
      rethrow; // Propagate sync errors
    }
  }

  Future<List<Map<String, dynamic>>> getDevices() async {
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .get();

      return snapshot.docs
          .map(
            (doc) => {
              ...doc.data(),
              'id': doc.id,
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Get devices error: $e');
      rethrow; // Propagate fetch errors
    }
  }

  // Vehicles collection
  Future<void> syncVehicle(Map<String, dynamic> vehicleData) async {
    if (userId == null) return;

    try {
      final docId = vehicleData['id']?.toString() ?? '';
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('vehicles')
          .doc(docId)
          .set(
        {
          ...vehicleData,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Sync vehicle error: $e');
      rethrow; // Propagate sync errors
    }
  }

  Future<List<Map<String, dynamic>>> getVehicles() async {
    if (userId == null) return [];

    // Use cache to reduce Firebase reads
    final cacheKey = CacheKeys.vehicles(userId!);

    return FirebaseCache.instance.getOrFetch(
      cacheKey,
      () async {
        final snapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('vehicles')
            .orderBy('created_at', descending: true)
            .limit(50) // Limit results
            .get();

        return snapshot.docs
            .map(
              (doc) => {
                ...doc.data(),
                'firebase_id': doc.id,
              },
            )
            .toList();
      },
      ttl: const Duration(minutes: 5),
    );
  }

  // Fuel expenses collection
  Future<void> syncFuelExpense(Map<String, dynamic> expenseData) async {
    if (userId == null) return;

    try {
      final docId = expenseData['id']?.toString() ?? '';
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('fuel_expenses')
          .doc(docId)
          .set(
        {
          ...expenseData,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Sync fuel expense error: $e');
      rethrow; // Propagate sync errors
    }
  }

  // General expenses collection
  Future<void> syncGeneralExpense(Map<String, dynamic> expenseData) async {
    if (userId == null) return;

    try {
      final docId = expenseData['id']?.toString() ?? '';
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('general_expenses')
          .doc(docId)
          .set(
        {
          ...expenseData,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Sync general expense error: $e');
      rethrow; // Propagate sync errors
    }
  }

  // Trips collection
  Future<void> syncTrip(Map<String, dynamic> tripData) async {
    if (userId == null) return;

    try {
      final docId = tripData['id']?.toString() ?? '';
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('trips')
          .doc(docId)
          .set(
        {
          ...tripData,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Sync trip error: $e');
      rethrow; // Propagate sync errors
    }
  }

  // Upload receipt image
  Future<String?> uploadReceiptImage(File imageFile, String expenseId) async {
    if (userId == null) return null;

    try {
      final ref = _storage
          .ref()
          .child('users')
          .child(userId!)
          .child('receipts')
          .child('$expenseId.jpg');

      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload receipt error: $e');
      rethrow; // Propagate upload errors
    }
  }

  // Delete receipt image
  Future<void> deleteReceiptImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('Delete receipt error: $e');
      rethrow; // Propagate delete errors
    }
  }

  // Batch sync all local data
  Future<void> syncAllData({
    required List<Map<String, dynamic>> devices,
    required List<Map<String, dynamic>> vehicles,
    required List<Map<String, dynamic>> fuelExpenses,
    required List<Map<String, dynamic>> generalExpenses,
    required List<Map<String, dynamic>> trips,
  }) async {
    if (userId == null) return;

    try {
      final batch = _firestore.batch();

      // Sync devices
      for (final device in devices) {
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('devices')
            .doc(device['device_id']);
        batch.set(
          docRef,
          {
            ...device,
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      // Sync vehicles
      for (final vehicle in vehicles) {
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('vehicles')
            .doc(vehicle['id'].toString());
        batch.set(
          docRef,
          {
            ...vehicle,
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      debugPrint('Batch sync completed successfully');
    } catch (e) {
      debugPrint('Batch sync error: $e');
      rethrow; // Propagate batch sync errors
    }
  }

  // Legacy real-time listeners (deprecated, use existing methods with caching)
  @Deprecated('Use getVehicles() instead to reduce Firebase reads')
  Stream<QuerySnapshot> listenToVehicles() {
    if (userId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('vehicles')
        .limit(50)
        .snapshots();
  }

  @Deprecated('Use database queries instead to reduce Firebase reads')
  Stream<QuerySnapshot> listenToExpenses() {
    if (userId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('fuel_expenses')
        .orderBy('date', descending: true)
        .limit(100)
        .snapshots();
  }

  // ==================== DELETE OPERATIONS ====================

  /// Delete a vehicle and all related data (expenses, trips, receipts)
  Future<void> deleteVehicle(String vehicleId) async {
    if (userId == null) return;

    try {
      final vehicleRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('vehicles')
          .doc(vehicleId);

      // Delete all fuel expenses for this vehicle
      final fuelExpenses = await _firestore
          .collection('users')
          .doc(userId)
          .collection('fuel_expenses')
          .where('vehicle_id', isEqualTo: vehicleId)
          .get();

      for (final doc in fuelExpenses.docs) {
        // Delete receipt from storage if exists
        final receiptPath = doc.data()['receipt_path'] as String?;
        if (receiptPath != null) {
          await _deleteReceiptFromStorage(receiptPath);
        }
        await doc.reference.delete();
      }

      // Delete all trips for this vehicle
      final trips = await _firestore
          .collection('users')
          .doc(userId)
          .collection('trips')
          .where('vehicle_id', isEqualTo: vehicleId)
          .get();

      for (final doc in trips.docs) {
        await doc.reference.delete();
      }

      // Finally delete the vehicle
      await vehicleRef.delete();
      debugPrint('Vehicle $vehicleId and related data deleted from Firebase');
    } catch (e) {
      debugPrint('Delete vehicle error: $e');
      rethrow;
    }
  }

  /// Delete a fuel expense and its receipt
  Future<void> deleteFuelExpense(String expenseId) async {
    if (userId == null) return;

    try {
      final expenseRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('fuel_expenses')
          .doc(expenseId);

      // Get the expense to check for receipt
      final doc = await expenseRef.get();
      if (doc.exists) {
        final receiptPath = doc.data()?['receipt_path'] as String?;
        if (receiptPath != null) {
          await _deleteReceiptFromStorage(receiptPath);
        }
      }

      await expenseRef.delete();
      debugPrint('Fuel expense $expenseId deleted from Firebase');
    } catch (e) {
      debugPrint('Delete fuel expense error: $e');
      rethrow;
    }
  }

  /// Delete a general expense and its receipt
  Future<void> deleteGeneralExpense(String expenseId) async {
    if (userId == null) return;

    try {
      final expenseRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('general_expenses')
          .doc(expenseId);

      // Get the expense to check for receipt
      final doc = await expenseRef.get();
      if (doc.exists) {
        final receiptPath = doc.data()?['receipt_path'] as String?;
        if (receiptPath != null) {
          await _deleteReceiptFromStorage(receiptPath);
        }
      }

      await expenseRef.delete();
      debugPrint('General expense $expenseId deleted from Firebase');
    } catch (e) {
      debugPrint('Delete general expense error: $e');
      rethrow;
    }
  }

  /// Delete a trip
  Future<void> deleteTrip(String tripId) async {
    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('trips')
          .doc(tripId)
          .delete();
      debugPrint('Trip $tripId deleted from Firebase');
    } catch (e) {
      debugPrint('Delete trip error: $e');
      rethrow;
    }
  }

  /// Helper to delete receipt from Firebase Storage
  Future<void> _deleteReceiptFromStorage(String receiptPath) async {
    try {
      final ref = _storage.ref().child(receiptPath);
      await ref.delete();
      debugPrint('Receipt deleted from storage: $receiptPath');
    } catch (e) {
      // Receipt may not exist, log but don't fail
      debugPrint('Could not delete receipt from storage: $e');
    }
  }

  // ==================== CONNECTIVITY CHECK ====================

  /// Check if Firebase is reachable
  Future<bool> isOnline() async {
    try {
      await _firestore
          .collection('_health_check')
          .limit(1)
          .get(const GetOptions(source: Source.server));
      return true;
    } catch (e) {
      return false;
    }
  }
}
