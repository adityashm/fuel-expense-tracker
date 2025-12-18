import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reminder.dart';
import '../providers/device_provider.dart';
import '../providers/vehicle_provider.dart';
import '../services/database_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReminders();
    });
  }

  Future<void> _loadReminders() async {
    // Data will be fetched by FutureBuilder
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = Provider.of<DeviceProvider>(context);

    if (deviceProvider.currentDevice == null) {
      return const Scaffold(
        body: Center(child: Text('Please select a device')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseService.instance
            .getRemindersForDevice(deviceProvider.currentDevice!.deviceId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final reminders = snapshot.data ?? [];

          if (reminders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Reminders',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add a reminder',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Separate upcoming and overdue reminders
          final now = DateTime.now();
          final upcoming = reminders.where((r) {
            final dueDate = DateTime.parse(r['due_date'] as String);
            return (r['is_completed'] as int) == 0 && !dueDate.isBefore(now);
          }).toList();

          final overdue = reminders.where((r) {
            final dueDate = DateTime.parse(r['due_date'] as String);
            return (r['is_completed'] as int) == 0 && dueDate.isBefore(now);
          }).toList();

          final completed =
              reminders.where((r) => (r['is_completed'] as int) == 1).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (overdue.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  'Overdue',
                  Colors.red,
                  overdue.length,
                ),
                ...overdue.map(
                  (r) => _buildReminderCard(context, r, isOverdue: true),
                ),
                const SizedBox(height: 16),
              ],
              if (upcoming.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  'Upcoming',
                  Colors.orange,
                  upcoming.length,
                ),
                ...upcoming.map((r) => _buildReminderCard(context, r)),
                const SizedBox(height: 16),
              ],
              if (completed.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  'Completed',
                  Colors.green,
                  completed.length,
                ),
                ...completed.map(
                  (r) => _buildReminderCard(context, r, isCompleted: true),
                ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddReminderDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    Color color,
    int count,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            color: color,
          ),
          const SizedBox(width: 12),
          Text(
            '$title ($count)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(
    BuildContext context,
    Map<String, dynamic> reminder, {
    bool isOverdue = false,
    bool isCompleted = false,
  }) {
    final dueDate = DateTime.parse(reminder['due_date'] as String);
    final type = reminder['type'] as String;
    final title = reminder['title'] as String;
    final description = reminder['description'] as String?;

    IconData icon;
    switch (type) {
      case 'insurance':
        icon = Icons.security;
        break;
      case 'puc':
        icon = Icons.eco;
        break;
      case 'service':
        icon = Icons.build;
        break;
      case 'tax':
        icon = Icons.account_balance;
        break;
      default:
        icon = Icons.notifications;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isOverdue
          ? Colors.red.withValues(alpha: 0.1)
          : isCompleted
              ? Colors.grey.withValues(alpha: 0.1)
              : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOverdue
              ? Colors.red
              : isCompleted
                  ? Colors.grey
                  : Colors.blue,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(
          title,
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description != null && description.isNotEmpty)
              Text(description),
            const SizedBox(height: 4),
            Text(
              'Due: ${dueDate.day}/${dueDate.month}/${dueDate.year}',
              style: TextStyle(
                color: isOverdue ? Colors.red : Colors.grey[600],
                fontWeight: isOverdue ? FontWeight.bold : null,
              ),
            ),
          ],
        ),
        trailing: !isCompleted
            ? IconButton(
                icon: const Icon(Icons.check_circle_outline),
                onPressed: () => _completeReminder(reminder['id'] as int),
              )
            : null,
        onLongPress: () => _deleteReminder(reminder['id'] as int),
      ),
    );
  }

  Future<void> _showAddReminderDialog() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final vehicleProvider =
        Provider.of<VehicleProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    // Load vehicles if not loaded
    if (vehicleProvider.vehicles.isEmpty &&
        deviceProvider.currentDeviceId != null) {
      await vehicleProvider.loadVehicles(deviceProvider.currentDeviceId!);
    }

    if (!mounted) return;

    if (vehicleProvider.vehicles.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please add a vehicle first')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AddReminderDialog(
        vehicles: vehicleProvider.vehicles,
        deviceId: deviceProvider.currentDeviceId!,
        onSaved: _loadReminders,
      ),
    );
  }

  Future<void> _completeReminder(int reminderId) async {
    final messenger = ScaffoldMessenger.of(context);
    await DatabaseService.instance.completeReminder(reminderId);
    if (!mounted) return;
    setState(() {});
    messenger.showSnackBar(
      const SnackBar(content: Text('Reminder marked as completed')),
    );
  }

  Future<void> _deleteReminder(int reminderId) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: const Text('Are you sure you want to delete this reminder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.deleteReminder(reminderId);
      if (!mounted) return;
      setState(() {});
      messenger.showSnackBar(
        const SnackBar(content: Text('Reminder deleted')),
      );
    }
  }
}

// Add Reminder Dialog
class AddReminderDialog extends StatefulWidget {
  const AddReminderDialog({
    super.key,
    required this.vehicles,
    required this.deviceId,
    required this.onSaved,
  });
  final List<dynamic> vehicles;
  final String deviceId;
  final VoidCallback onSaved;

  @override
  State<AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<AddReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  int? _selectedVehicleId;
  ReminderType _reminderType = ReminderType.insurance;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Reminder'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _selectedVehicleId,
                decoration: const InputDecoration(
                  labelText: 'Select Vehicle',
                  prefixIcon: Icon(Icons.directions_car),
                ),
                items: widget.vehicles.map<DropdownMenuItem<int>>((vehicle) {
                  final v = vehicle as Map<String, dynamic>;
                  return DropdownMenuItem<int>(
                    value: v['id'] as int,
                    child: Text(v['name'] as String),
                  );
                }).toList(),
                onChanged: (int? value) =>
                    setState(() => _selectedVehicleId = value),
                validator: (int? value) =>
                    value == null ? 'Please select a vehicle' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ReminderType>(
                initialValue: _reminderType,
                decoration: const InputDecoration(
                  labelText: 'Reminder Type',
                  prefixIcon: Icon(Icons.category),
                ),
                items: ReminderType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _reminderType = value!;
                    if (value != ReminderType.custom) {
                      _titleController.text =
                          '${value.name.toUpperCase()} Renewal';
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Due Date'),
                subtitle:
                    Text('${_dueDate.day}/${_dueDate.month}/${_dueDate.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selectDate,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveReminder,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _saveReminder() async {
    if (_formKey.currentState!.validate()) {
      await DatabaseService.instance.createReminder(
        vehicleId: _selectedVehicleId!,
        deviceId: widget.deviceId,
        type: _reminderType.name,
        title: _titleController.text,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        dueDate: _dueDate,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder added successfully')),
        );
      }
    }
  }
}
