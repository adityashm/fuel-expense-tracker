import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/maintenance_record.dart';
import '../models/vehicle.dart';
import '../providers/device_provider.dart';
import '../providers/maintenance_provider.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  // Pagination
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  final int _itemsPerPage = 20;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MaintenanceProvider>(context, listen: false)
          .loadRecords(widget.vehicle.id!);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.vehicle.name} maintenance'),
      ),
      body: Consumer<MaintenanceProvider>(
        builder: (context, provider, child) {
          final isLoading = provider.isLoading(widget.vehicle.id!);
          final records = provider.recordsForVehicle(widget.vehicle.id!);
          final summary = provider.summaryForVehicle(widget.vehicle.id!);

          if (isLoading && records.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Pagination: limit visible records
          final maxIndex =
              (_currentPage * _itemsPerPage).clamp(0, records.length);
          final visibleRecords = records.sublist(0, maxIndex);

          return RefreshIndicator(
            onRefresh: () => provider.loadRecords(widget.vehicle.id!),
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                if (summary != null) _buildSummaryCard(summary),
                if (visibleRecords.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.build, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No maintenance records yet'),
                        SizedBox(height: 4),
                        Text('Tap + to add your first record'),
                      ],
                    ),
                  )
                else
                  ...visibleRecords.map(_buildRecordTile),
                if (_isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRecordSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add record'),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> summary) {
    final lastService = summary['last_service'] as DateTime?;
    final nextService = summary['next_service'] as DateTime?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Maintenance summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryTile(
                    'Total spent',
                    _currency.format(summary['total_cost'] as double),
                    Icons.currency_rupee,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryTile(
                    'Records',
                    '${summary['total_records']}',
                    Icons.history,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryTile(
                    'Last service',
                    lastService != null
                        ? DateFormat('dd MMM').format(lastService)
                        : '—',
                    Icons.event_available,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryTile(
                    'Next due',
                    nextService != null
                        ? DateFormat('dd MMM').format(nextService)
                        : 'Set reminder',
                    Icons.alarm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildRecordTile(MaintenanceRecord record) {
    final dateText = DateFormat('MMM dd, yyyy').format(record.serviceDate);
    final typeLabel = record.type.name
        .replaceAllMapped(
          RegExp('([A-Z])'),
          (match) => ' ${match.group(0)}',
        )
        .trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(_iconForType(record.type), color: Colors.black87),
        ),
        title: Text(typeLabel),
        subtitle: Text(
          '${_currency.format(record.cost)} • $dateText'
          '${record.workshop != null ? '\n${record.workshop}' : ''}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showRecordSheet(existing: record);
            } else if (value == 'delete') {
              _confirmDelete(record);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(MaintenanceType type) {
    switch (type) {
      case MaintenanceType.service:
        return Icons.build_circle;
      case MaintenanceType.repair:
        return Icons.car_repair;
      case MaintenanceType.inspection:
        return Icons.fact_check;
      case MaintenanceType.partReplacement:
        return Icons.settings;
      case MaintenanceType.document:
        return Icons.description;
    }
  }

  Future<void> _showRecordSheet({MaintenanceRecord? existing}) async {
    final maintenanceProvider =
        Provider.of<MaintenanceProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final result = await showModalBottomSheet<MaintenanceRecord>(
      context: context,
      isScrollControlled: true,
      builder: (context) => MaintenanceRecordSheet(
        vehicleId: widget.vehicle.id!,
        existing: existing,
      ),
    );

    if (!mounted || result == null) return;

    if (existing == null) {
      await maintenanceProvider.addRecord(result);
    } else {
      await maintenanceProvider.updateRecord(result);
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          existing == null ? 'Maintenance record added' : 'Record updated',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(MaintenanceRecord record) async {
    final maintenanceProvider =
        Provider.of<MaintenanceProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete record'),
        content: const Text('Are you sure you want to delete this record?'),
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
      await maintenanceProvider.deleteRecord(record.vehicleId, record.id!);
    }
  }
}

class MaintenanceRecordSheet extends StatefulWidget {
  const MaintenanceRecordSheet({
    super.key,
    required this.vehicleId,
    this.existing,
  });
  final int vehicleId;
  final MaintenanceRecord? existing;

  @override
  State<MaintenanceRecordSheet> createState() => _MaintenanceRecordSheetState();
}

class _MaintenanceRecordSheetState extends State<MaintenanceRecordSheet> {
  final _formKey = GlobalKey<FormState>();
  late MaintenanceType _type;
  late DateTime _serviceDate;
  DateTime? _nextDueDate;
  final _costController = TextEditingController();
  final _odometerController = TextEditingController();
  final _workshopController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? MaintenanceType.service;
    _serviceDate = existing?.serviceDate ?? DateTime.now();
    _nextDueDate = existing?.nextDueDate;
    _costController.text = existing?.cost.toStringAsFixed(0) ?? '';
    _odometerController.text = existing?.odometer?.toStringAsFixed(0) ?? '';
    _workshopController.text = existing?.workshop ?? '';
    _notesController.text = existing?.notes ?? '';
  }

  @override
  void dispose() {
    _costController.dispose();
    _odometerController.dispose();
    _workshopController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Text(
                widget.existing == null
                    ? 'New maintenance record'
                    : 'Edit maintenance',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MaintenanceType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: MaintenanceType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _type = value!),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(DateFormat('dd MMM yyyy').format(_serviceDate)),
                subtitle: const Text('Service date'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _serviceDate,
                    firstDate: DateTime(2015),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _serviceDate = picked);
                  }
                },
              ),
              TextFormField(
                controller: _costController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cost',
                  prefixIcon: Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter cost';
                  }
                  return double.tryParse(value) != null
                      ? null
                      : 'Enter valid number';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _odometerController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Odometer (km)',
                  prefixIcon: Icon(Icons.speed),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _workshopController,
                decoration: const InputDecoration(
                  labelText: 'Service center',
                  prefixIcon: Icon(Icons.store_mall_directory),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.alarm),
                title: Text(
                  _nextDueDate != null
                      ? DateFormat('dd MMM yyyy').format(_nextDueDate!)
                      : 'Set next reminder',
                ),
                subtitle: const Text('Optional service reminder'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _nextDueDate == null
                      ? null
                      : () => setState(() => _nextDueDate = null),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _nextDueDate ??
                        DateTime.now().add(const Duration(days: 180)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (picked != null) {
                    setState(() => _nextDueDate = picked);
                  }
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: Text(
                    widget.existing == null ? 'Add record' : 'Update record',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final device =
        Provider.of<DeviceProvider>(context, listen: false).currentDevice;
    if (device == null) return;

    final record = MaintenanceRecord(
      id: widget.existing?.id,
      vehicleId: widget.vehicleId,
      deviceId: device.deviceId,
      type: _type,
      serviceDate: _serviceDate,
      cost: double.parse(_costController.text),
      odometer: _odometerController.text.isNotEmpty
          ? double.tryParse(_odometerController.text)
          : null,
      workshop:
          _workshopController.text.isNotEmpty ? _workshopController.text : null,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      nextDueDate: _nextDueDate,
    );

    Navigator.pop(context, record);
  }
}
