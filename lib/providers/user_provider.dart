import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/database_service.dart';

class UserProvider extends ChangeNotifier {
  List<User> _users = [];
  User? _currentUser;
  bool _isLoading = false;

  List<User> get users => _users;
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  Future<void> loadUsers() async {
    _isLoading = true;
    notifyListeners();

    _users = await DatabaseService.instance.getAllUsers();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> createUser(String name, String? profilePicturePath) async {
    if (_users.length >= 5) {
      throw Exception('Maximum 5 users allowed');
    }

    final user = User(
      name: name,
      profilePicturePath: profilePicturePath,
    );

    final createdUser = await DatabaseService.instance.createUser(user);
    _users.add(createdUser);
    notifyListeners();
  }

  Future<void> updateUser(User user) async {
    await DatabaseService.instance.updateUser(user);
    final index = _users.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _users[index] = user;
      if (_currentUser?.id == user.id) {
        _currentUser = user;
      }
      notifyListeners();
    }
  }

  Future<void> deleteUser(int userId) async {
    await DatabaseService.instance.deleteUser(userId);
    _users.removeWhere((u) => u.id == userId);
    if (_currentUser?.id == userId) {
      _currentUser = null;
    }
    notifyListeners();
  }

  void setCurrentUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  void clearCurrentUser() {
    _currentUser = null;
    notifyListeners();
  }
}
