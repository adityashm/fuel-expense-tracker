import 'package:flutter/foundation.dart';

import '../models/family_member.dart';
import '../services/database_service.dart';

class FamilyMemberProvider extends ChangeNotifier {
  static const int maxFamilyMembers = 5;

  List<FamilyMember> _members = [];
  final Map<int, int> _lastMemberByVehicle = {};
  bool _isLoading = false;
  bool _hasLoadedPreferences = false;

  List<FamilyMember> get members => List.unmodifiable(_members);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _members.isNotEmpty || !_isLoading;

  FamilyMember? memberById(int? id) {
    if (id == null) return null;
    try {
      return _members.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  int? lastMemberForVehicle(int vehicleId) => _lastMemberByVehicle[vehicleId];

  Future<void> loadMembers() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      await DatabaseService.instance.seedDefaultFamilyMembers();
      final members = await DatabaseService.instance.getFamilyMembers();
      _members = members;
      if (!_hasLoadedPreferences) {
        await _loadVehiclePreferences();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadVehiclePreferences() async {
    final prefs = await DatabaseService.instance.getVehicleMemberPreferences();
    _lastMemberByVehicle
      ..clear()
      ..addAll(prefs);
    _hasLoadedPreferences = true;
    notifyListeners();
  }

  Future<FamilyMember> createMember(FamilyMember member) async {
    if (_members.length >= maxFamilyMembers) {
      throw StateError('Maximum of $maxFamilyMembers family members supported');
    }
    final created = await DatabaseService.instance.createFamilyMember(member);
    _members.add(created);
    notifyListeners();
    return created;
  }

  Future<void> updateMember(FamilyMember member) async {
    await DatabaseService.instance.updateFamilyMember(member);
    final index = _members.indexWhere((m) => m.id == member.id);
    if (index != -1) {
      _members[index] = member;
      notifyListeners();
    }
  }

  Future<void> deleteMember(int memberId) async {
    await DatabaseService.instance.deleteFamilyMember(memberId);
    _members.removeWhere((m) => m.id == memberId);
    final vehicleKeysToRemove = _lastMemberByVehicle.entries
        .where((entry) => entry.value == memberId)
        .map((entry) => entry.key)
        .toList();
    for (final vehicleId in vehicleKeysToRemove) {
      _lastMemberByVehicle.remove(vehicleId);
      await DatabaseService.instance.clearVehicleMemberPreference(vehicleId);
    }
    notifyListeners();
  }

  Future<void> setPrimaryVehicle(int memberId, int? vehicleId) async {
    final member = memberById(memberId);
    if (member == null) return;
    final updated = member.copyWith(primaryVehicleId: vehicleId);
    await updateMember(updated);
  }

  Future<void> rememberMemberForVehicle(int vehicleId, int? memberId) async {
    if (memberId == null) {
      _lastMemberByVehicle.remove(vehicleId);
      await DatabaseService.instance.clearVehicleMemberPreference(vehicleId);
    } else {
      _lastMemberByVehicle[vehicleId] = memberId;
      await DatabaseService.instance
          .setVehicleMemberPreference(vehicleId, memberId);
    }
    notifyListeners();
  }
}
