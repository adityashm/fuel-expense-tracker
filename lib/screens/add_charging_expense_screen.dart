import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/charging_expense.dart';
import '../models/vehicle.dart';
import '../providers/charging_expense_provider.dart';
import '../providers/device_provider.dart';
import '../providers/family_member_provider.dart';
import '../services/budget_service.dart';
import '../services/collaboration_service.dart';
import '../utils/app_localizations.dart';
import '../widgets/family_member_selector.dart';

class AddChargingExpenseScreen extends StatefulWidget {
  const AddChargingExpenseScreen({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  State<AddChargingExpenseScreen> createState() =>
      _AddChargingExpenseScreenState();
}

class _AddChargingExpenseScreenState extends State<AddChargingExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _kwhController = TextEditingController();
  final _costPerUnitController = TextEditingController();
  final _totalCostController = TextEditingController();
  final _batteryBeforeController = TextEditingController();
  final _batteryAfterController = TextEditingController();
  final _durationController = TextEditingController();
  final _odometerController = TextEditingController();
  final _stationNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  ChargingLocationType _locationType = ChargingLocationType.home;
  ChargingType _chargingType = ChargingType.slow;
  bool _isSaving = false;
  int? _selectedMemberId;

  // Default electricity rates (₹/kWh)
  final Map<ChargingLocationType, double> _defaultRates = {
    ChargingLocationType.home: 6.5,
    ChargingLocationType.office: 8.0,
    ChargingLocationType.publicStation: 15.0,
    ChargingLocationType.other: 10.0,
  };

  @override
  void initState() {
    super.initState();
    _kwhController.addListener(_calculateCost);
    _costPerUnitController.addListener(_calculateCost);
    _batteryBeforeController.addListener(_updateChargingType);
    _batteryAfterController.addListener(_updateChargingType);
    _durationController.addListener(_updateChargingType);

    // Set default rate
    _costPerUnitController.text = _defaultRates[_locationType]!.toString();

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _prefillMemberSelection());
  }

  @override
  void dispose() {
    _kwhController.dispose();
    _costPerUnitController.dispose();
    _totalCostController.dispose();
    _batteryBeforeController.dispose();
    _batteryAfterController.dispose();
    _durationController.dispose();
    _odometerController.dispose();
    _stationNameController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _prefillMemberSelection() {
    final familyProvider = context.read<FamilyMemberProvider>();
    final vehicleId = widget.vehicle.id;
    if (vehicleId == null) return;

    int? preset = familyProvider.lastMemberForVehicle(vehicleId);
    if (preset == null) {
      for (final member in familyProvider.members) {
        if (member.primaryVehicleId == vehicleId && member.id != null) {
          preset = member.id;
          break;
        }
      }
    }

    if (preset != null && mounted) {
      setState(() => _selectedMemberId = preset);
    }
  }

  void _calculateCost() {
    final kwh = double.tryParse(_kwhController.text);
    final rate = double.tryParse(_costPerUnitController.text);

    if (kwh != null && rate != null && kwh > 0 && rate > 0) {
      final total = kwh * rate;
      _totalCostController.text = total.toStringAsFixed(2);
    }
  }

  void _updateChargingType() {
    final batteryBefore = int.tryParse(_batteryBeforeController.text);
    final batteryAfter = int.tryParse(_batteryAfterController.text);
    final duration = int.tryParse(_durationController.text);
    final kwh = double.tryParse(_kwhController.text);

    if (batteryBefore != null &&
        batteryAfter != null &&
        duration != null &&
        kwh != null &&
        duration > 0) {
      final averagePower = (kwh * 60) / duration; // kW

      setState(() {
        if (averagePower > 7) {
          _chargingType = ChargingType.rapid;
        } else if (averagePower >= 3) {
          _chargingType = ChargingType.fast;
        } else {
          _chargingType = ChargingType.slow;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Charging Session'),
        backgroundColor: Colors.green.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Vehicle Info Card
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.electric_scooter,
                        color: Colors.green.shade700,
                        size: 40,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.vehicle.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Electric Vehicle',
                              style: TextStyle(color: Colors.green.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Date
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(localizations.formatDate(_selectedDate)),
                subtitle: const Text('Date'),
                trailing: const Icon(Icons.edit),
                onTap: _selectDate,
              ),

              const SizedBox(height: 16),

              // Location Type
              DropdownButtonFormField<ChargingLocationType>(
                initialValue: _locationType,
                decoration: const InputDecoration(
                  labelText: 'Charging Location',
                  prefixIcon: Icon(Icons.location_on),
                ),
                items: [
                  DropdownMenuItem(
                    value: ChargingLocationType.home,
                    child: Row(
                      children: [
                        Icon(
                          Icons.home,
                          size: 20,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 8),
                        const Text('Home'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: ChargingLocationType.publicStation,
                    child: Row(
                      children: [
                        Icon(
                          Icons.ev_station,
                          size: 20,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        const Text('Public Station'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: ChargingLocationType.office,
                    child: Row(
                      children: [
                        Icon(
                          Icons.business,
                          size: 20,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        const Text('Office'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: ChargingLocationType.other,
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_pin,
                          size: 20,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 8),
                        const Text('Other'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _locationType = value!;
                    _costPerUnitController.text =
                        _defaultRates[_locationType]!.toString();
                  });
                },
              ),

              const SizedBox(height: 16),

              // Station Name (for public/office)
              if (_locationType != ChargingLocationType.home)
                TextFormField(
                  controller: _stationNameController,
                  decoration: const InputDecoration(
                    labelText: 'Station/Location Name',
                    prefixIcon: Icon(Icons.business),
                  ),
                ),

              if (_locationType != ChargingLocationType.home)
                const SizedBox(height: 16),

              // Address
              if (_locationType != ChargingLocationType.home)
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.place),
                  ),
                ),

              if (_locationType != ChargingLocationType.home)
                const SizedBox(height: 16),

              Consumer<FamilyMemberProvider>(
                builder: (context, familyProvider, _) {
                  if (familyProvider.isLoading &&
                      familyProvider.members.isEmpty) {
                    return const LinearProgressIndicator();
                  }

                  return FamilyMemberSelector(
                    members: familyProvider.members,
                    selectedMemberId: _selectedMemberId,
                    onChanged: (memberId) {
                      setState(() => _selectedMemberId = memberId);
                    },
                    onSplitChanged: (_) {},
                    label: 'Who charged the vehicle?',
                    helperText: familyProvider.members.isEmpty
                        ? 'Add family members under Settings > Family'
                        : null,
                  );
                },
              ),

              const SizedBox(height: 16),

              // Battery Before/After
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _batteryBeforeController,
                      decoration: const InputDecoration(
                        labelText: 'Battery Before',
                        prefixIcon: Icon(Icons.battery_3_bar),
                        suffixText: '%',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final battery = int.tryParse(value);
                        if (battery == null || battery < 0 || battery > 100) {
                          return '0-100';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _batteryAfterController,
                      decoration: const InputDecoration(
                        labelText: 'Battery After',
                        prefixIcon: Icon(Icons.battery_full),
                        suffixText: '%',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final battery = int.tryParse(value);
                        if (battery == null || battery < 0 || battery > 100) {
                          return '0-100';
                        }

                        final before =
                            int.tryParse(_batteryBeforeController.text);
                        if (before != null && battery < before) {
                          return 'Must be > before';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // kWh Charged
              TextFormField(
                controller: _kwhController,
                decoration: const InputDecoration(
                  labelText: 'Units Charged (kWh)',
                  prefixIcon: Icon(Icons.bolt),
                  suffixText: 'kWh',
                  helperText: 'Ola S1 Pro: ~3.97 kWh battery',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter kWh charged';
                  }
                  final kwh = double.tryParse(value);
                  if (kwh == null || kwh <= 0) {
                    return 'Must be greater than 0';
                  }
                  if (kwh > 10) {
                    return 'Value seems too high';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Cost Per Unit & Total Cost
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costPerUnitController,
                      decoration: InputDecoration(
                        labelText: 'Rate',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        suffixText: '₹/kWh',
                        helperText: _locationType == ChargingLocationType.home
                            ? 'Home electricity rate'
                            : 'Charging station rate',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final rate = double.tryParse(value);
                        if (rate == null || rate <= 0) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _totalCostController,
                      decoration: const InputDecoration(
                        labelText: 'Total Cost',
                        prefixIcon: Icon(Icons.account_balance_wallet),
                        suffixText: '₹',
                      ),
                      keyboardType: TextInputType.number,
                      readOnly: true,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Duration
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Charging Duration',
                  prefixIcon: Icon(Icons.timer),
                  suffixText: 'min',
                  helperText: 'Ola S1 Pro: 0-100% in ~5 hours (slow)',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter duration';
                  }
                  final duration = int.tryParse(value);
                  if (duration == null || duration <= 0) {
                    return 'Must be greater than 0';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Charging Type Display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getChargingTypeColor().withAlpha((255 * 0.1).round()),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getChargingTypeColor()),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getChargingTypeIcon(),
                      color: _getChargingTypeColor(),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_chargingType.name.toUpperCase()} Charging',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getChargingTypeColor(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Odometer Reading
              TextFormField(
                controller: _odometerController,
                decoration: const InputDecoration(
                  labelText: 'Odometer Reading',
                  prefixIcon: Icon(Icons.speed),
                  suffixText: 'km',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter odometer reading';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveChargingExpense,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green.shade700,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Charging Session',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getChargingTypeColor() {
    switch (_chargingType) {
      case ChargingType.slow:
        return Colors.green;
      case ChargingType.fast:
        return Colors.orange;
      case ChargingType.rapid:
        return Colors.red;
    }
  }

  IconData _getChargingTypeIcon() {
    switch (_chargingType) {
      case ChargingType.slow:
        return Icons.battery_charging_full;
      case ChargingType.fast:
        return Icons.flash_on;
      case ChargingType.rapid:
        return Icons.bolt;
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _saveChargingExpense() async {
    if (_formKey.currentState!.validate()) {
      if (_isSaving) return;
      setState(() => _isSaving = true);

      try {
        final deviceProvider =
            Provider.of<DeviceProvider>(context, listen: false);
        final chargingProvider =
            Provider.of<ChargingExpenseProvider>(context, listen: false);
        final familyProvider =
            Provider.of<FamilyMemberProvider>(context, listen: false);

        if (deviceProvider.currentDeviceId == null) {
          await deviceProvider.initialize();
          if (deviceProvider.currentDeviceId == null) {
            if (mounted) {
              setState(() => _isSaving = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Unable to initialize device. Please restart the app.',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }

        final selectedMember = familyProvider.memberById(_selectedMemberId);

        final expense = ChargingExpense(
          deviceId: deviceProvider.currentDevice!.deviceId,
          vehicleId: widget.vehicle.id!,
          date: _selectedDate,
          locationType: _locationType,
          kwhCharged: double.parse(_kwhController.text),
          costPerUnit: double.parse(_costPerUnitController.text),
          totalCost: double.parse(_totalCostController.text),
          batteryBefore: int.parse(_batteryBeforeController.text),
          batteryAfter: int.parse(_batteryAfterController.text),
          durationMinutes: int.parse(_durationController.text),
          odometerReading: double.parse(_odometerController.text),
          chargingType: _chargingType,
          stationName: _stationNameController.text.isNotEmpty
              ? _stationNameController.text
              : null,
          address: _addressController.text.isNotEmpty
              ? _addressController.text
              : null,
          notes:
              _notesController.text.isNotEmpty ? _notesController.text : null,
          familyMemberId: selectedMember?.id,
          familyMemberName: selectedMember?.name,
        );

        await chargingProvider.createChargingExpense(expense);

        await familyProvider.rememberMemberForVehicle(
          widget.vehicle.id!,
          selectedMember?.id,
        );

        final actorName =
            deviceProvider.currentDevice?.personName ?? 'A contributor';
        await CollaborationService.instance.logActivity(
          vehicleId: widget.vehicle.id!,
          deviceId: expense.deviceId,
          title: 'Charging session added',
          description:
              '$actorName logged ₹${expense.totalCost.toStringAsFixed(0)} charging for ${widget.vehicle.name}',
          type: 'charging_expense',
          referenceType: 'charging',
          referenceId: expense.id,
          notify: widget.vehicle.isShared,
        );

        // Check budget alerts after adding expense
        try {
          await BudgetService.instance.checkBudgetAlerts(widget.vehicle);
        } catch (e) {
          debugPrint('Budget alert check failed: $e');
        }

        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving charging expense: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isSaving = false);
        }
      }
    }
  }
}
