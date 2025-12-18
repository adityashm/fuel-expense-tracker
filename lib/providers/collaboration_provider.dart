import 'package:flutter/material.dart';
import '../models/activity_log.dart';
import '../models/expense_comment.dart';
import '../models/settlement.dart';
import '../services/collaboration_service.dart';

class CollaborationProvider extends ChangeNotifier {
  final CollaborationService _service = CollaborationService.instance;

  final List<ActivityLog> _activityLogs = [];
  final Map<String, List<ExpenseComment>> _commentsCache = {};
  final Map<int, List<Settlement>> _settlements = {};
  bool _isLoadingActivity = false;

  List<ActivityLog> get activityLogs => List.unmodifiable(_activityLogs);
  bool get isLoadingActivity => _isLoadingActivity;

  List<ExpenseComment> commentsFor(ExpenseType type, int expenseId) {
    return _commentsCache['${type.name}_$expenseId'] ??
        const <ExpenseComment>[];
  }

  List<Settlement> settlementsForVehicle(int vehicleId) {
    return _settlements[vehicleId] ?? const <Settlement>[];
  }

  Future<void> loadActivity({int? vehicleId}) async {
    _isLoadingActivity = true;
    notifyListeners();

    final logs = await _service.fetchActivityLogs(vehicleId: vehicleId);
    _activityLogs
      ..clear()
      ..addAll(logs);

    _isLoadingActivity = false;
    notifyListeners();
  }

  Future<void> addComment(ExpenseComment comment) async {
    final saved = await _service.addComment(comment);
    final key = '${comment.type.name}_${comment.expenseId}';
    _commentsCache.putIfAbsent(key, () => []).insert(0, saved);
    notifyListeners();
  }

  Future<void> loadComments(ExpenseType type, int expenseId) async {
    final list = await _service.fetchComments(type, expenseId);
    _commentsCache['${type.name}_$expenseId'] = list;
    notifyListeners();
  }

  Future<void> loadSettlements(int vehicleId) async {
    final list = await _service.fetchSettlements(vehicleId);
    _settlements[vehicleId] = list;
    notifyListeners();
  }

  Future<void> recordSettlement(Settlement settlement) async {
    final saved = await _service.createSettlement(settlement);
    _settlements.putIfAbsent(settlement.vehicleId, () => []).insert(0, saved);
    notifyListeners();
  }

  Future<void> markSettlementAsSettled(int vehicleId, int settlementId) async {
    await _service.markSettlementSettled(settlementId);
    final list = _settlements[vehicleId];
    if (list != null) {
      final index = list.indexWhere((item) => item.id == settlementId);
      if (index != -1) {
        list[index] = list[index].copyWith(
          status: SettlementStatus.settled,
          settledAt: DateTime.now(),
        );
      }
    }
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> settlementSuggestions(int vehicleId) {
    return _service.generateSettlementSuggestions(vehicleId);
  }
}
