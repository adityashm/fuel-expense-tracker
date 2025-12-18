import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/family_task.dart';
import '../providers/device_provider.dart';
import '../providers/family_task_provider.dart';
import '../services/database_service.dart';

class FamilyTasksScreen extends StatefulWidget {
  const FamilyTasksScreen({super.key});

  @override
  State<FamilyTasksScreen> createState() => _FamilyTasksScreenState();
}

class _FamilyTasksScreenState extends State<FamilyTasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Pagination
  final ScrollController _activeScrollController = ScrollController();
  final ScrollController _completedScrollController = ScrollController();
  int _activePage = 1;
  int _completedPage = 1;
  final int _itemsPerPage = 20;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _activeScrollController.addListener(_onActiveScroll);
    _completedScrollController.addListener(_onCompletedScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FamilyTaskProvider>(context, listen: false).loadTasks();
    });
  }

  void _onActiveScroll() {
    if (_activeScrollController.position.pixels >=
        _activeScrollController.position.maxScrollExtent * 0.8) {
      _loadMoreActive();
    }
  }

  void _onCompletedScroll() {
    if (_completedScrollController.position.pixels >=
        _completedScrollController.position.maxScrollExtent * 0.8) {
      _loadMoreCompleted();
    }
  }

  Future<void> _loadMoreActive() async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _activePage++;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadMoreCompleted() async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _completedPage++;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _activeScrollController.dispose();
    _completedScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Tasks'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active', icon: Icon(Icons.task_alt)),
            Tab(text: 'Completed', icon: Icon(Icons.check_circle)),
          ],
        ),
      ),
      body: Consumer<FamilyTaskProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildActiveTasksTab(provider),
              _buildCompletedTasksTab(provider),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTaskDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }

  Widget _buildActiveTasksTab(FamilyTaskProvider provider) {
    final tasks = provider.tasks;

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Active Tasks',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Tap + to add a new task'),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildStatsCards(provider),
        Expanded(
          child: ListView.builder(
            controller: _activeScrollController,
            padding: const EdgeInsets.all(16),
            itemCount: (_activePage * _itemsPerPage).clamp(0, tasks.length) +
                (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              final maxIndex =
                  (_activePage * _itemsPerPage).clamp(0, tasks.length);
              if (index == maxIndex) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _buildTaskCard(tasks[index], provider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedTasksTab(FamilyTaskProvider provider) {
    final completedTasks = provider.completedTasks;

    if (completedTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Completed Tasks',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _completedScrollController,
      padding: const EdgeInsets.all(16),
      itemCount:
          (_completedPage * _itemsPerPage).clamp(0, completedTasks.length) +
              (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        final maxIndex =
            (_completedPage * _itemsPerPage).clamp(0, completedTasks.length);
        if (index == maxIndex) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildCompletedTaskCard(completedTasks[index], provider);
      },
    );
  }

  Widget _buildStatsCards(FamilyTaskProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Urgent',
              provider.urgentTasks.toString(),
              Colors.red,
              Icons.priority_high,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Due Today',
              provider.dueTodayTasks.toString(),
              Colors.orange,
              Icons.today,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Shopping',
              provider.shoppingTasks.toString(),
              Colors.blue,
              Icons.shopping_cart,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, Color color, IconData icon,) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(FamilyTask task, FamilyTaskProvider provider) {
    final isOverdue = task.isOverdue;
    final isUrgent = task.isUrgent || isOverdue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isUrgent
          ? (isOverdue ? Colors.red.shade50 : Colors.orange.shade50)
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPriorityColor(task.priority),
          child: Text(
            task.type.icon,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(task.title)),
            if (isUrgent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isOverdue ? Colors.red : Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOverdue ? 'OVERDUE' : 'URGENT',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description != null) ...[
              Text(task.description!),
              const SizedBox(height: 4),
            ],
            if (task.vehicleName != null) Text('Vehicle: ${task.vehicleName}'),
            if (task.assignedToName != null)
              Text('Assigned to: ${task.assignedToName}'),
            if (task.dueDate != null)
              Text(
                task.formattedDueDate,
                style: TextStyle(
                  color: isOverdue ? Colors.red : null,
                  fontWeight: isOverdue ? FontWeight.bold : null,
                ),
              ),
            if (task.isShoppingTask && task.shoppingItems != null) ...[
              const SizedBox(height: 4),
              Text(
                '${task.purchasedItemsCount}/${task.shoppingItems!.length} items purchased',
                style: TextStyle(
                  color: task.allItemsPurchased ? Colors.green : null,
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'complete') {
              final deviceProvider =
                  Provider.of<DeviceProvider>(context, listen: false);
              final device = deviceProvider.currentDevice;
              if (device != null) {
                final memberId = await _getCurrentMemberId();
                final memberName = device.personName;
                await provider.completeTask(task.id!, memberId, memberName);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task completed!')),
                  );
                }
              }
            } else if (value == 'edit') {
              await _showEditTaskDialog(context, task, provider);
            } else if (value == 'delete') {
              await _confirmDelete(task, provider);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'complete', child: Text('Complete')),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        onTap: () => _showTaskDetails(context, task, provider),
      ),
    );
  }

  Widget _buildCompletedTaskCard(FamilyTask task, FamilyTaskProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.grey.shade100,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.check, color: Colors.white),
        ),
        title: Text(
          task.title,
          style: const TextStyle(
            decoration: TextDecoration.lineThrough,
            color: Colors.grey,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.completedByName != null)
              Text('Completed by: ${task.completedByName}'),
            if (task.completedAt != null)
              Text(
                'Completed: ${DateFormat('MMM dd, yyyy').format(task.completedAt!)}',
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.undo),
          onPressed: () async {
            await provider.uncompleteTask(task.id!);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Task restored')),
              );
            }
          },
        ),
      ),
    );
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.grey;
      case TaskPriority.normal:
        return Colors.blue;
      case TaskPriority.high:
        return Colors.orange;
      case TaskPriority.urgent:
        return Colors.red;
    }
  }

  Future<void> _showAddTaskDialog(BuildContext context) async {
    final provider = Provider.of<FamilyTaskProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final result = await showDialog<FamilyTask>(
      context: context,
      builder: (context) => const _TaskDialog(),
    );

    if (result != null) {
      final success = await provider.createTask(result);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Task created successfully' : 'Failed to create task',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showEditTaskDialog(
    BuildContext context,
    FamilyTask task,
    FamilyTaskProvider provider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    final result = await showDialog<FamilyTask>(
      context: context,
      builder: (context) => _TaskDialog(existing: task),
    );

    if (result != null) {
      final success = await provider.updateTask(result);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Task updated successfully' : 'Failed to update task',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showTaskDetails(
    BuildContext context,
    FamilyTask task,
    FamilyTaskProvider provider,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (task.description != null) ...[
                Text('Description: ${task.description}'),
                const SizedBox(height: 8),
              ],
              Text('Type: ${task.type.displayName}'),
              Text('Priority: ${task.priority.displayName}'),
              if (task.vehicleName != null)
                Text('Vehicle: ${task.vehicleName}'),
              if (task.assignedToName != null)
                Text('Assigned to: ${task.assignedToName}'),
              if (task.dueDate != null) Text('Due: ${task.formattedDueDate}'),
              if (task.isShoppingTask && task.shoppingItems != null) ...[
                const SizedBox(height: 8),
                const Text('Shopping Items:',
                    style: TextStyle(fontWeight: FontWeight.bold),),
                ...task.shoppingItems!
                    .map((item) => Text('  • ${item.displayText}')),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      FamilyTask task, FamilyTaskProvider provider,) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await provider.deleteTask(task.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task deleted')),
        );
      }
    }
  }

  Future<int> _getCurrentMemberId() async {
    // Get current member ID from device
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final device = deviceProvider.currentDevice;
    if (device == null) return 1;

    final members = await DatabaseService.instance.getFamilyMembers();
    if (members.isEmpty) return 1;

    final member = members.firstWhere(
      (m) => m.name == device.personName,
      orElse: () => members.first,
    );
    return member.id ?? 1;
  }
}

class _TaskDialog extends StatefulWidget {
  const _TaskDialog({this.existing});

  final FamilyTask? existing;

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TaskType _type;
  late TaskPriority _priority;
  DateTime? _dueDate;
  int? _vehicleId;
  int? _assignedToMemberId;
  bool _isUrgent = false;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.existing?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.existing?.description ?? '');
    _type = widget.existing?.type ?? TaskType.other;
    _priority = widget.existing?.priority ?? TaskPriority.normal;
    _dueDate = widget.existing?.dueDate;
    _vehicleId = widget.existing?.vehicleId;
    _assignedToMemberId = widget.existing?.assignedToMemberId;
    _isUrgent = widget.existing?.isUrgent ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Task' : 'Edit Task'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TaskType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: TaskType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _type = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TaskPriority>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: TaskPriority.values
                    .map(
                      (priority) => DropdownMenuItem(
                        value: priority,
                        child: Text(priority.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _priority = value!),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  _dueDate != null
                      ? DateFormat('MMM dd, yyyy').format(_dueDate!)
                      : 'Set due date (optional)',
                ),
                trailing: _dueDate != null
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _dueDate = null),
                      )
                    : null,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _dueDate = picked);
                  }
                },
              ),
              SwitchListTile(
                title: const Text('Mark as urgent'),
                value: _isUrgent,
                onChanged: (value) => setState(() => _isUrgent = value),
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
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final device = deviceProvider.currentDevice;
    if (device == null) return;

    final members = await DatabaseService.instance.getFamilyMembers();
    final member = members.firstWhere(
      (m) => m.name == device.personName,
      orElse: () => members.first,
    );
    final memberId = member.id ?? 1;
    final memberName = member.name;

    final task = FamilyTask(
      id: widget.existing?.id,
      title: _titleController.text,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      vehicleId: _vehicleId,
      assignedToMemberId: _assignedToMemberId,
      dueDate: _dueDate,
      type: _type,
      priority: _priority,
      isUrgent: _isUrgent,
      createdByMemberId: widget.existing?.createdByMemberId ?? memberId,
      createdByName: widget.existing?.createdByName ?? memberName,
    );

    if (mounted) {
      Navigator.pop(context, task);
    }
  }
}
