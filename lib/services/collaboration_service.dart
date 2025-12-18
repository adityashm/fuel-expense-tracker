import 'dart:math';
import '../models/activity_log.dart';
import '../models/expense_comment.dart';
import '../models/settlement.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class CollaborationService {
  CollaborationService._();

  static final CollaborationService instance = CollaborationService._();

  final DatabaseService _dbService = DatabaseService.instance;

  Future<ActivityLog> logActivity({
    required int vehicleId,
    required String deviceId,
    required String title,
    required String description,
    required String type,
    String? referenceType,
    int? referenceId,
    bool notify = false,
  }) async {
    final db = await _dbService.database;
    final log = ActivityLog(
      vehicleId: vehicleId,
      deviceId: deviceId,
      title: title,
      description: description,
      type: type,
      referenceType: referenceType,
      referenceId: referenceId,
    );
    final id = await db.insert('activity_logs', log.toMap());
    final saved = log.copyWith(id: id);

    if (notify) {
      await NotificationService.instance.showNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: description,
      );
    }

    return saved;
  }

  Future<List<ActivityLog>> fetchActivityLogs({
    int? vehicleId,
    int limit = 100,
  }) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'activity_logs',
      where: vehicleId != null ? 'vehicle_id = ?' : null,
      whereArgs: vehicleId != null ? [vehicleId] : null,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(ActivityLog.fromMap).toList();
  }

  Future<ExpenseComment> addComment(ExpenseComment comment) async {
    final db = await _dbService.database;
    final id = await db.insert('expense_comments', comment.toMap());
    final saved = comment.copyWith(id: id);

    final vehicleId = await _resolveVehicleIdForExpense(saved);
    if (vehicleId > 0) {
      await logActivity(
        vehicleId: vehicleId,
        deviceId: comment.deviceId,
        title: 'New comment',
        description: comment.message,
        type: 'comment',
        referenceType: comment.type.name,
        referenceId: comment.expenseId,
      );
    }

    return saved;
  }

  Future<List<ExpenseComment>> fetchComments(
    ExpenseType type,
    int expenseId,
  ) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'expense_comments',
      where: 'expense_type = ? AND expense_id = ?',
      whereArgs: [type.name, expenseId],
      orderBy: 'created_at DESC',
    );
    return rows.map(ExpenseComment.fromMap).toList();
  }

  Future<Settlement> createSettlement(Settlement settlement) async {
    final db = await _dbService.database;
    final id = await db.insert('settlements', settlement.toMap());
    final saved = settlement.copyWith(id: id);
    await logActivity(
      vehicleId: settlement.vehicleId,
      deviceId: settlement.payerDeviceId,
      title: 'Settlement recorded',
      description:
          '₹${settlement.amount.toStringAsFixed(0)} to ${settlement.payeeDeviceId}',
      type: 'settlement',
      referenceType: 'settlement',
      referenceId: id,
    );
    return saved;
  }

  Future<int> markSettlementSettled(int settlementId) async {
    final db = await _dbService.database;
    return db.update(
      'settlements',
      {
        'status': SettlementStatus.settled.name,
        'settled_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [settlementId],
    );
  }

  Future<List<Settlement>> fetchSettlements(
    int vehicleId, {
    SettlementStatus? status,
  }) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'settlements',
      where:
          status != null ? 'vehicle_id = ? AND status = ?' : 'vehicle_id = ?',
      whereArgs: status != null ? [vehicleId, status.name] : [vehicleId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Settlement.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> generateSettlementSuggestions(
    int vehicleId,
  ) async {
    final contributions =
        await _dbService.getVehicleContributionSummary(vehicleId);
    if (contributions.isEmpty) return [];

    final totals = contributions
        .map((row) => (row['total_spent'] as num?)?.toDouble() ?? 0.0)
        .toList();
    final totalSpent = totals.fold<double>(0, (sum, value) => sum + value);
    final equalShare = totalSpent / contributions.length;

    final payers = <Map<String, dynamic>>[];
    final receivers = <Map<String, dynamic>>[];

    for (final row in contributions) {
      final spent = (row['total_spent'] as num?)?.toDouble() ?? 0.0;
      final delta = spent - equalShare;
      final deviceId = row['device_id'] as String;
      final name = row['person_name'] as String? ?? deviceId;
      if (delta < -1) {
        payers.add({'deviceId': deviceId, 'name': name, 'amount': delta.abs()});
      } else if (delta > 1) {
        receivers.add({'deviceId': deviceId, 'name': name, 'amount': delta});
      }
    }

    final suggestions = <Map<String, dynamic>>[];
    int payerIndex = 0;
    int receiverIndex = 0;

    while (payerIndex < payers.length && receiverIndex < receivers.length) {
      final payer = payers[payerIndex];
      final receiver = receivers[receiverIndex];
      final settlementAmount =
          min(payer['amount'] as double, receiver['amount'] as double);

      suggestions.add({
        'fromDeviceId': payer['deviceId'],
        'fromName': payer['name'],
        'toDeviceId': receiver['deviceId'],
        'toName': receiver['name'],
        'amount': settlementAmount,
      });

      payer['amount'] = (payer['amount'] as double) - settlementAmount;
      receiver['amount'] = (receiver['amount'] as double) - settlementAmount;

      if ((payer['amount'] as double) <= 0.5) payerIndex++;
      if ((receiver['amount'] as double) <= 0.5) receiverIndex++;
    }

    return suggestions;
  }

  Future<int> _resolveVehicleIdForExpense(ExpenseComment comment) async {
    final db = await _dbService.database;
    if (comment.type == ExpenseType.fuel) {
      final rows = await db.query(
        'fuel_expenses',
        columns: ['vehicle_id'],
        where: 'id = ?',
        whereArgs: [comment.expenseId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first['vehicle_id'] as int;
      }
    } else {
      final rows = await db.query(
        'general_expenses',
        columns: ['vehicle_id'],
        where: 'id = ?',
        whereArgs: [comment.expenseId],
        limit: 1,
      );
      if (rows.isNotEmpty && rows.first['vehicle_id'] != null) {
        return rows.first['vehicle_id'] as int;
      }
    }
    return -1;
  }
}
