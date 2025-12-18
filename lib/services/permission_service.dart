import 'database_service.dart';

enum VehicleAccessLevel {
  none,
  viewer,
  contributor,
  owner,
}

class PermissionService {
  PermissionService._init();
  static final PermissionService instance = PermissionService._init();

  final _db = DatabaseService.instance;

  Future<VehicleAccessLevel> getVehicleAccessLevel(
    int vehicleId,
    String deviceId,
  ) async {
    // Check if user is the vehicle owner
    final vehicle = await _db.getVehicle(vehicleId);
    if (vehicle == null) return VehicleAccessLevel.none;

    if (vehicle.ownerDeviceId == deviceId) {
      return VehicleAccessLevel.owner;
    }

    // Check if vehicle is shared
    if (!vehicle.isShared) {
      return VehicleAccessLevel.none;
    }

    // Check vehicle_access table
    final access = await _db.getVehicleAccess(vehicleId, deviceId);
    if (access == null) {
      // If vehicle is shared, default to contributor access
      return VehicleAccessLevel.contributor;
    }

    final accessType = access['access_type'] as String?;
    switch (accessType) {
      case 'owner':
        return VehicleAccessLevel.owner;
      case 'contributor':
        return VehicleAccessLevel.contributor;
      case 'viewer':
        return VehicleAccessLevel.viewer;
      default:
        return VehicleAccessLevel.none;
    }
  }

  Future<bool> canEditVehicle(int vehicleId, String deviceId) async {
    final level = await getVehicleAccessLevel(vehicleId, deviceId);
    return level == VehicleAccessLevel.owner;
  }

  Future<bool> canDeleteVehicle(int vehicleId, String deviceId) async {
    final level = await getVehicleAccessLevel(vehicleId, deviceId);
    return level == VehicleAccessLevel.owner;
  }

  Future<bool> canAddExpense(int vehicleId, String deviceId) async {
    final level = await getVehicleAccessLevel(vehicleId, deviceId);
    return level == VehicleAccessLevel.owner ||
        level == VehicleAccessLevel.contributor;
  }

  Future<bool> canViewVehicle(int vehicleId, String deviceId) async {
    final level = await getVehicleAccessLevel(vehicleId, deviceId);
    return level != VehicleAccessLevel.none;
  }

  Future<bool> canEditExpense(
    int expenseId,
    String deviceId,
    bool isFuelExpense,
  ) async {
    if (isFuelExpense) {
      final expense = await _db.getFuelExpense(expenseId);
      if (expense == null) return false;
      return expense.deviceId == deviceId;
    } else {
      final expense = await _db.getGeneralExpense(expenseId);
      if (expense == null) return false;
      return expense.deviceId == deviceId;
    }
  }
}
