import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/vehicle_provider.dart';

/// Unified expense form for fuel, vehicle/general, and household expenses.
/// This is a scaffold placeholder consolidating common fields for future logic.
class UnifiedExpenseForm extends StatefulWidget {
  const UnifiedExpenseForm({
    super.key,
    required this.expenseType,
    this.preselectedVehicleId,
  });
  final ExpenseFormType expenseType;
  final int? preselectedVehicleId;

  @override
  State<UnifiedExpenseForm> createState() => _UnifiedExpenseFormState();
}

enum ExpenseFormType { fuel, vehicleGeneral, household }

class _UnifiedExpenseFormState extends State<UnifiedExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _isSplit = false;
  int? _selectedVehicleId;

  @override
  void initState() {
    super.initState();
    // Set preselected vehicle if provided
    _selectedVehicleId = widget.preselectedVehicleId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForType(widget.expenseType)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  v == null || v.isEmpty || double.tryParse(v) == null
                      ? 'Enter valid amount'
                      : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle: Text('${_date.day}/${_date.month}/${_date.year}'),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            if (widget.expenseType == ExpenseFormType.fuel ||
                widget.expenseType == ExpenseFormType.vehicleGeneral)
              Consumer<VehicleProvider>(
                builder: (context, provider, _) {
                  // Filter vehicles based on expense type
                  final allVehicles = provider.vehicles;
                  final vehicles = widget.expenseType == ExpenseFormType.fuel
                      ? allVehicles.where((v) => !v.isElectric).toList()
                      : allVehicles;
                      
                  if (_selectedVehicleId == null && vehicles.isNotEmpty) {
                    _selectedVehicleId = vehicles.first.id;
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text('Vehicle',
                          style: Theme.of(context).textTheme.titleSmall,),
                      const SizedBox(height: 8),
                      if (vehicles.isEmpty)
                        Text(
                          widget.expenseType == ExpenseFormType.fuel
                              ? 'No petrol/diesel vehicles available. Electric vehicles cannot have fuel expenses.'
                              : 'No vehicles available. Add a vehicle first.',
                          style: const TextStyle(color: Colors.red),
                        )
                      else
                        DropdownButtonFormField<int>(
                          initialValue: _selectedVehicleId,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.directions_car),
                          ),
                          items: vehicles
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v.id,
                                  child: Text(
                                      '${v.name} - ${v.registrationNumber}',),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedVehicleId = v),
                          validator: (v) =>
                              v == null ? 'Select a vehicle' : null,
                        ),
                    ],
                  );
                },
              ),
            if (widget.expenseType == ExpenseFormType.household)
              SwitchListTile(
                title: const Text('Split Bill'),
                subtitle: const Text('Enable bill splitting between members'),
                value: _isSplit,
                onChanged: (v) => setState(() => _isSplit = v),
              ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Expense saved (placeholder)'),),);
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _titleForType(ExpenseFormType type) {
    switch (type) {
      case ExpenseFormType.fuel:
        return 'Add Fuel Expense';
      case ExpenseFormType.vehicleGeneral:
        return 'Add Vehicle Expense';
      case ExpenseFormType.household:
        return 'Add Household Expense';
    }
  }
}
