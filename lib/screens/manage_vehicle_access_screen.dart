import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../models/vehicle_access.dart';
import '../services/database_service.dart';

class ManageVehicleAccessScreen extends StatefulWidget {
  const ManageVehicleAccessScreen({
    super.key,
    required this.vehicle,
  });
  final Vehicle vehicle;

  @override
  State<ManageVehicleAccessScreen> createState() =>
      _ManageVehicleAccessScreenState();
}

class _ManageVehicleAccessScreenState extends State<ManageVehicleAccessScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Access - ${widget.vehicle.name}'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseService.instance
            .getDevicesWithAccessDetails(widget.vehicle.id!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final usersWithAccess = snapshot.data ?? [];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Access Levels',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildAccessLevelInfo(
                          'Owner',
                          'Full control - can manage access, edit, and delete vehicle',
                          Icons.admin_panel_settings,
                          Colors.purple,
                        ),
                        const SizedBox(height: 8),
                        _buildAccessLevelInfo(
                          'Contributor',
                          'Can add expenses and view reports',
                          Icons.edit,
                          Colors.blue,
                        ),
                        const SizedBox(height: 8),
                        _buildAccessLevelInfo(
                          'Viewer',
                          'Can only view vehicle and expense data',
                          Icons.visibility,
                          Colors.green,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Devices with Access (${usersWithAccess.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: usersWithAccess.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No users have access yet',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to grant access',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: usersWithAccess.length,
                        itemBuilder: (context, index) {
                          final userAccess = usersWithAccess[index];
                          return _buildUserAccessCard(userAccess);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showGrantAccessDialog,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildAccessLevelInfo(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                description,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserAccessCard(Map<String, dynamic> userAccess) {
    final userName =
        (userAccess['device_name'] ?? userAccess['user_name']) as String;
    final accessType = userAccess['access_type'] as String;
    final isOwner = accessType == 'owner';

    IconData icon;
    Color color;
    switch (accessType) {
      case 'owner':
        icon = Icons.admin_panel_settings;
        color = Colors.purple;
        break;
      case 'contributor':
        icon = Icons.edit;
        color = Colors.blue;
        break;
      case 'viewer':
        icon = Icons.visibility;
        color = Colors.green;
        break;
      default:
        icon = Icons.person;
        color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(userName),
        subtitle: Text(accessType.toUpperCase()),
        trailing: !isOwner
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'change') {
                    _showChangeAccessDialog(userAccess);
                  } else if (value == 'revoke') {
                    _revokeAccess(userAccess);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'change',
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz),
                        SizedBox(width: 8),
                        Text('Change Access Level'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'revoke',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Revoke Access',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : const Chip(label: Text('OWNER')),
      ),
    );
  }

  Future<void> _showGrantAccessDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    // Get all devices
    final allDevices = await DatabaseService.instance.getAllDevices();

    // Get devices who already have access
    final devicesWithAccess = await DatabaseService.instance
        .getDevicesWithAccessDetails(widget.vehicle.id!);
    final deviceIdsWithAccess =
        devicesWithAccess.map((u) => u['device_id'] as String).toSet();

    // Filter out devices who already have access
    final availableDevices = allDevices
        .where(
          (device) =>
              !deviceIdsWithAccess.contains(device['device_id'] as String),
        )
        .toList();

    if (!mounted) return;

    if (availableDevices.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('All devices already have access to this vehicle'),
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => GrantAccessDialog(
        vehicle: widget.vehicle,
        availableDevices: availableDevices,
        onGranted: () => setState(() {}),
      ),
    );
  }

  Future<void> _showChangeAccessDialog(Map<String, dynamic> userAccess) async {
    final messenger = ScaffoldMessenger.of(context);
    final deviceId = userAccess['device_id'] as String;
    final currentAccessType = userAccess['access_type'] as String;

    final newAccessType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Change Access for ${userAccess['device_name'] ?? userAccess['user_name']}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentAccessType != 'contributor')
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Contributor'),
                subtitle: const Text('Can add expenses and view reports'),
                onTap: () => Navigator.pop(context, 'contributor'),
              ),
            if (currentAccessType != 'viewer')
              ListTile(
                leading: const Icon(Icons.visibility, color: Colors.green),
                title: const Text('Viewer'),
                subtitle: const Text('Can only view data'),
                onTap: () => Navigator.pop(context, 'viewer'),
              ),
          ],
        ),
      ),
    );

    if (newAccessType != null) {
      await DatabaseService.instance
          .revokeVehicleAccess(widget.vehicle.id!, deviceId);
      await DatabaseService.instance.grantVehicleAccess(
        widget.vehicle.id!,
        deviceId,
        newAccessType,
      );
      if (!mounted) return;
      setState(() {});
      messenger.showSnackBar(
        const SnackBar(content: Text('Access level updated')),
      );
    }
  }

  Future<void> _revokeAccess(Map<String, dynamic> userAccess) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Access'),
        content: Text(
          'Are you sure you want to revoke access for ${userAccess['device_name'] ?? userAccess['user_name']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.revokeVehicleAccess(
        widget.vehicle.id!,
        userAccess['device_id'] as String,
      );
      if (!mounted) return;
      setState(() {});
      messenger.showSnackBar(
        const SnackBar(content: Text('Access revoked')),
      );
    }
  }
}

// Grant Access Dialog
class GrantAccessDialog extends StatefulWidget {
  const GrantAccessDialog({
    super.key,
    required this.vehicle,
    required this.availableDevices,
    required this.onGranted,
  });
  final Vehicle vehicle;
  final List<Map<String, dynamic>> availableDevices;
  final VoidCallback onGranted;

  @override
  State<GrantAccessDialog> createState() => _GrantAccessDialogState();
}

class _GrantAccessDialogState extends State<GrantAccessDialog> {
  String? _selectedDeviceId;
  AccessType _accessType = AccessType.viewer;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Grant Access'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedDeviceId,
            decoration: const InputDecoration(
              labelText: 'Select Device',
              prefixIcon: Icon(Icons.phone_android),
            ),
            items: widget.availableDevices.map((device) {
              return DropdownMenuItem<String>(
                value: device['device_id'] as String,
                child: Text(device['person_name'] as String),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedDeviceId = value),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<AccessType>(
            initialValue: _accessType,
            decoration: const InputDecoration(
              labelText: 'Access Level',
              prefixIcon: Icon(Icons.security),
            ),
            items: const [
              DropdownMenuItem(
                value: AccessType.contributor,
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Contributor'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: AccessType.viewer,
                child: Row(
                  children: [
                    Icon(Icons.visibility, size: 20, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Viewer'),
                  ],
                ),
              ),
            ],
            onChanged: (value) => setState(() => _accessType = value!),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _accessType == AccessType.contributor
                        ? 'Can add expenses and view reports'
                        : 'Can only view vehicle and expense data',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedDeviceId == null ? null : _grantAccess,
          child: const Text('Grant Access'),
        ),
      ],
    );
  }

  Future<void> _grantAccess() async {
    await DatabaseService.instance.grantVehicleAccess(
      widget.vehicle.id!,
      _selectedDeviceId!,
      _accessType.name,
    );

    if (mounted) {
      Navigator.pop(context);
      widget.onGranted();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access granted successfully')),
      );
    }
  }
}
