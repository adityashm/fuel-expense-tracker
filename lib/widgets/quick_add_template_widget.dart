import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/charging_expense.dart';
import '../models/expense_template.dart';
import '../models/fuel_expense.dart';
import '../models/vehicle.dart';
import '../providers/device_provider.dart';
import '../providers/expense_provider.dart';
import '../screens/template_manager_screen.dart';
import '../services/database_service.dart';
import '../services/template_service.dart';

class QuickAddTemplateWidget extends StatefulWidget {
  const QuickAddTemplateWidget({super.key});

  @override
  State<QuickAddTemplateWidget> createState() => _QuickAddTemplateWidgetState();
}

class _QuickAddTemplateWidgetState extends State<QuickAddTemplateWidget> {
  final _templateService = TemplateService.instance;
  List<ExpenseTemplate> _templates = [];
  final List<TemplateSuggestion> _suggestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final templates = await _templateService.getMostUsedTemplates(limit: 3);
    setState(() {
      _templates = templates;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_templates.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Quick Add',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      unawaited(Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TemplateManagerScreen(),
                        ),
                      ).then((_) {
                        if (mounted) {
                          _loadTemplates();
                        }
                      },),);
                    } catch (e) {
                      if (mounted) {
                        debugPrint('Error navigating to template manager: $e');
                      }
                    }
                  },
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Manage'),
                ),
              ],
            ),
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSuggestionBanner(_suggestions.first),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _templates
                  .map((template) => _buildTemplateChip(template))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionBanner(TemplateSuggestion suggestion) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.reason,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
                    fontSize: 13,
                  ),
                ),
                Text(
                  suggestion.timeContext,
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => _useTemplate(suggestion.template),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Log Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateChip(ExpenseTemplate template) {
    IconData icon;
    Color color;

    switch (template.type) {
      case TemplateType.fuel:
        icon = Icons.local_gas_station;
        color = Colors.orange;
        break;
      case TemplateType.charging:
        icon = Icons.bolt;
        color = Colors.green;
        break;
      case TemplateType.general:
        icon = Icons.receipt;
        color = Colors.blue;
        break;
    }

    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            template.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Text(
            '₹${template.amount.toStringAsFixed(0)} • ${template.getSummary()}',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
      onPressed: () => _useTemplate(template),
    );
  }

  Future<void> _useTemplate(ExpenseTemplate template) async {
    // Capture context-dependent objects before any async operations
    final messenger = ScaffoldMessenger.of(context);
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final expenseProvider =
        Provider.of<ExpenseProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Log ${template.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vehicle: ${template.vehicleName}'),
            Text('Amount: ₹${template.amount.toStringAsFixed(0)}'),
            if (template.stationName != null)
              Text('Station: ${template.stationName}'),
            if (template.liters != null)
              Text('Quantity: ${template.liters!.toStringAsFixed(1)}L'),
            const SizedBox(height: 12),
            Text(
              'This will log the expense with today\'s date.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Expense'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (deviceProvider.currentDeviceId == null) {
        throw Exception('Device not initialized');
      }

      switch (template.type) {
        case TemplateType.fuel:
          await _logFuelExpense(template, deviceProvider, expenseProvider);
          break;
        case TemplateType.charging:
          await _logChargingExpense(template, deviceProvider, expenseProvider);
          break;
        case TemplateType.general:
          // Handle general expense
          break;
      }

      // Increment template usage
      await _templateService.useTemplate(template.id!);

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('${template.name} logged successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadTemplates();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error logging expense: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _logFuelExpense(
    ExpenseTemplate template,
    DeviceProvider deviceProvider,
    ExpenseProvider expenseProvider,
  ) async {
    // Get current odometer from vehicle
    final db = DatabaseService.instance;
    final vehicleMap = await db.database.then(
      (db) => db.query(
        'vehicles',
        where: 'id = ?',
        whereArgs: [template.vehicleId],
        limit: 1,
      ),
    );

    if (vehicleMap.isEmpty) throw Exception('Vehicle not found');

    final vehicle = Vehicle.fromMap(vehicleMap.first);

    final expense = FuelExpense(
      deviceId: deviceProvider.currentDevice!.deviceId,
      vehicleId: template.vehicleId,
      date: DateTime.now(),
      fuelType: template.fuelType ?? FuelType.petrol,
      amountPaid: template.amount,
      liters: template.liters ?? 0,
      odometerReading: vehicle.currentOdometer,
      pumpName: template.stationName,
      location: template.location,
      notes: 'Quick-added from template: ${template.name}',
    );

    await expenseProvider.createFuelExpense(expense);
  }

  Future<void> _logChargingExpense(
    ExpenseTemplate template,
    DeviceProvider deviceProvider,
    ExpenseProvider expenseProvider,
  ) async {
    final db = DatabaseService.instance;
    final vehicleMap = await db.database.then(
      (db) => db.query(
        'vehicles',
        where: 'id = ?',
        whereArgs: [template.vehicleId],
        limit: 1,
      ),
    );

    if (vehicleMap.isEmpty) throw Exception('Vehicle not found');

    final vehicle = Vehicle.fromMap(vehicleMap.first);

    final isHomeCharging = template.chargingStationName == null ||
        template.chargingStationName!.isEmpty;
    final kwhCharged = template.kwhAmount ?? 0.0;
    final expense = ChargingExpense(
      deviceId: deviceProvider.currentDevice!.deviceId,
      vehicleId: template.vehicleId,
      date: DateTime.now(),
      locationType: isHomeCharging
          ? ChargingLocationType.home
          : ChargingLocationType.publicStation,
      kwhCharged: kwhCharged,
      costPerUnit: kwhCharged > 0 ? template.amount / kwhCharged : 0.0,
      totalCost: template.amount,
      batteryBefore: 20, // Default values - user can edit later
      batteryAfter: 80,
      durationMinutes: 60,
      odometerReading: vehicle.currentOdometer,
      chargingType: template.chargingType ?? ChargingType.slow,
      stationName: template.chargingStationName,
      address: template.location,
      notes: 'Quick-added from template: ${template.name}',
    );

    // Add to database directly since we don't have charging provider
    await db.database
        .then((db) => db.insert('charging_expenses', expense.toMap()));
  }
}
