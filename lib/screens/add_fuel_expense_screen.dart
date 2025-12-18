import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fuel_expense.dart';
import '../models/vehicle.dart';
import '../providers/device_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/family_member_provider.dart';
import '../services/budget_service.dart';
import '../services/collaboration_service.dart';
import '../services/database_service.dart';
import '../services/geofence_service.dart';
import '../utils/app_localizations.dart';
import '../widgets/family_member_selector.dart';
import 'receipt_scanner_screen.dart';

class AddFuelExpenseScreen extends StatefulWidget {
  const AddFuelExpenseScreen({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  State<AddFuelExpenseScreen> createState() => _AddFuelExpenseScreenState();
}

class _AddFuelExpenseScreenState extends State<AddFuelExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _litersController = TextEditingController();
  final _odometerController = TextEditingController();
  final _pumpNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  FuelType _fuelType = FuelType.petrol;
  String? _receiptImagePath;
  bool _isProcessing = false;
  bool _isSaving = false;
  int? _selectedMemberId;
  List<int> _splitMemberIds = [];
  bool _isSplitExpense = false;
  bool _isFullTank = false;

  @override
  void initState() {
    super.initState();
    
    // Prevent fuel expenses for electric vehicles
    if (widget.vehicle.isElectric) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Electric Vehicle Detected'),
              content: const Text(
                'This is an electric vehicle. Please use "Add Charging" instead of "Add Fuel" for charging expenses.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close this screen
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      });
    }
    
    _amountController.addListener(_onAmountChanged);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _prefillMemberSelection());
  }

  @override
  void dispose() {
    _amountController
      ..removeListener(_onAmountChanged)
      ..dispose();
    _litersController.dispose();
    _odometerController.dispose();
    _pumpNameController.dispose();
    _locationController.dispose();
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

  void _onAmountChanged() {
    // UI updates automatically when amount text changes
    // setState only needed if calculating split amounts
  }

  Future<String?> _validateOdometerReading(String? value) async {
    if (value == null || value.isEmpty) {
      return 'Please enter odometer reading';
    }

    final reading = double.tryParse(value);
    if (reading == null) {
      return 'Please enter a valid number';
    }

    // Check against last expense
    final lastExpense =
        await DatabaseService.instance.getLastFuelExpense(widget.vehicle.id!);

    if (lastExpense != null && reading < lastExpense.odometerReading) {
      return 'Reading cannot be less than last reading (${lastExpense.odometerReading.toStringAsFixed(1)} km)';
    }

    // Warn about unusual jumps
    if (lastExpense != null) {
      final difference = reading - lastExpense.odometerReading;
      final maxJump =
          widget.vehicle.vehicleType == VehicleType.bike ? 500 : 1000;

      if (difference > maxJump) {
        // Show warning but don't block
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Unusual Odometer Jump'),
                content: Text(
                  'The odometer reading increased by ${difference.toStringAsFixed(1)} km since last fillup. '
                  'This seems unusually high. Please verify the reading is correct.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        });
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('add_fuel_expense')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Receipt Image
              if (_receiptImagePath != null)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_receiptImagePath!),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                      onPressed: () {
                        setState(() {
                          _receiptImagePath = null;
                        });
                      },
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              // Scan Receipt Button
              OutlinedButton.icon(
                onPressed: _isProcessing ? null : _scanReceipt,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(localizations.translate('scan_receipt')),
              ),

              const SizedBox(height: 24),

              // Date
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(localizations.formatDate(_selectedDate)),
                subtitle: Text(localizations.translate('date')),
                trailing: const Icon(Icons.edit),
                onTap: _selectDate,
              ),

              const SizedBox(height: 16),

              // Fuel Type
              DropdownButtonFormField<FuelType>(
                initialValue: _fuelType,
                decoration: InputDecoration(
                  labelText: localizations.translate('fuel_type'),
                  prefixIcon: const Icon(Icons.local_gas_station),
                ),
                items: [
                  DropdownMenuItem(
                    value: FuelType.petrol,
                    child: Text(localizations.translate('petrol')),
                  ),
                  DropdownMenuItem(
                    value: FuelType.diesel,
                    child: Text(localizations.translate('diesel')),
                  ),
                  DropdownMenuItem(
                    value: FuelType.cng,
                    child: Text(localizations.translate('cng')),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _fuelType = value!;
                  });
                },
              ),

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
                    enableSplitSelection: _isSplitExpense,
                    splitSelections: _splitMemberIds,
                    onSplitChanged: (ids) =>
                        setState(() => _splitMemberIds = ids),
                    helperText: familyProvider.members.isEmpty
                        ? 'Add family members under Settings > Family'
                        : null,
                  );
                },
              ),

              SwitchListTile.adaptive(
                value: _isSplitExpense,
                onChanged: (value) {
                  setState(() {
                    _isSplitExpense = value;
                    if (!value) {
                      _splitMemberIds = [];
                    }
                  });
                },
                title: const Text('Split this expense'),
                subtitle:
                    const Text('Share cost across selected family members'),
              ),

              _buildSplitShareHint(localizations),

              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: localizations.translate('amount'),
                  prefixIcon: const Icon(Icons.currency_rupee),
                  suffixText: '₹',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null) {
                    return 'Please enter a valid number';
                  }
                  if (amount <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  if (amount > 50000) {
                    return 'Amount seems unusually high (>₹50,000)';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Liters
              TextFormField(
                controller: _litersController,
                decoration: InputDecoration(
                  labelText: localizations.translate('liters'),
                  prefixIcon: const Icon(Icons.local_drink),
                  suffixText: 'L',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter liters';
                  }
                  final liters = double.tryParse(value);
                  if (liters == null) {
                    return 'Please enter a valid number';
                  }
                  if (liters <= 0) {
                    return 'Liters must be greater than 0';
                  }
                  if (liters > 200) {
                    return 'Quantity seems unusually high (>200L)';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Odometer Reading
              TextFormField(
                controller: _odometerController,
                decoration: InputDecoration(
                  labelText: localizations.translate('odometer_reading'),
                  prefixIcon: const Icon(Icons.speed),
                  suffixText: 'km',
                  helperText: 'Current kilometer reading',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter odometer reading';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  // Async validation done in saveFuelExpense
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Pump Name
              TextFormField(
                controller: _pumpNameController,
                decoration: InputDecoration(
                  labelText: localizations.translate('pump_name'),
                  prefixIcon: const Icon(Icons.business),
                ),
              ),

              const SizedBox(height: 16),

              // Location with GPS nearby stations
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: localizations.translate('location'),
                        prefixIcon: const Icon(Icons.location_on),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.my_location),
                    tooltip: 'Find nearby petrol pumps',
                    onPressed: _showNearbyStations,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: localizations.translate('notes'),
                  prefixIcon: const Icon(Icons.note),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Full Tank Fill-up Option
              CheckboxListTile(
                title: const Text('Full Tank Fill-up'),
                subtitle:
                    const Text('Mark as full tank to track fuel efficiency'),
                value: _isFullTank,
                onChanged: (value) {
                  setState(() {
                    _isFullTank = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveFuelExpense,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        localizations.translate('save'),
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildSplitShareHint(AppLocalizations localizations) {
    if (!_isSplitExpense) {
      return const SizedBox.shrink();
    }

    final participants = _splitParticipantCount();
    if (participants <= 1) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 8.0),
        child: Text('Select at least one other member to split the cost.'),
      );
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 8.0),
        child: Text('Enter the amount to see per-person share.'),
      );
    }

    final share = amount / participants;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        'Each pays ${localizations.formatCurrency(share)} ($participants people)',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  int _splitParticipantCount() {
    final ids = <int>{..._splitMemberIds};
    if (_selectedMemberId != null) {
      ids.add(_selectedMemberId!);
    }
    return ids.isEmpty ? (_selectedMemberId != null ? 1 : 0) : ids.length;
  }

  List<int> _buildSplitMemberList(int? payerId) {
    final ids = <int>{..._splitMemberIds};
    if (payerId != null) {
      ids.add(payerId);
    }
    return ids.toList();
  }

  Future<void> _scanReceipt() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final result = await Navigator.push<Map<String, dynamic>?>(
        context,
        MaterialPageRoute(
          builder: (context) => const ReceiptScannerScreen(),
        ),
      );

      if (!mounted) return;
      
      if (result == null) {
        return;
      }

      int fieldsPopulated = 0;

      final imagePath = result['imagePath'] as String?;
      if (imagePath != null && imagePath.isNotEmpty) {
        setState(() => _receiptImagePath = imagePath);
      }

      final amount = _parseDouble(result['amount']);
      if (amount != null) {
        _amountController.text = amount.toStringAsFixed(2);
        fieldsPopulated++;
      }

      final liters = _parseDouble(result['liters']);
      if (liters != null) {
        _litersController.text = liters.toStringAsFixed(2);
        fieldsPopulated++;
      }

      final date = result['date'];
      if (date is DateTime) {
        setState(() => _selectedDate = date);
        fieldsPopulated++;
      }

      final pumpName = result['pumpName'];
      if (pumpName is String && pumpName.isNotEmpty) {
        _pumpNameController.text = pumpName;
        fieldsPopulated++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              fieldsPopulated > 0
                  ? 'Receipt scanned! $fieldsPopulated field(s) filled automatically.'
                  : 'Receipt attached. Please fill the fields manually.',
            ),
            backgroundColor: fieldsPopulated > 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error scanning receipt: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  double? _parseDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<void> _saveFuelExpense() async {
    if (_formKey.currentState!.validate()) {
      if (_isSaving) return;
      setState(() => _isSaving = true);

      // Capture messenger early to avoid ancestor lookup if widget unmounts during awaits
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) {
        setState(() => _isSaving = false);
        return;
      }

      try {
        final deviceProvider =
            Provider.of<DeviceProvider>(context, listen: false);
        final expenseProvider =
            Provider.of<ExpenseProvider>(context, listen: false);
        final familyProvider =
            Provider.of<FamilyMemberProvider>(context, listen: false);

        // Re-initialize device if missing
        if (deviceProvider.currentDeviceId == null) {
          await deviceProvider.initialize();
          if (deviceProvider.currentDeviceId == null) {
            if (mounted) {
              setState(() => _isSaving = false);
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Unable to initialize device. Please restart the app.',
                  ),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
            }
            return;
          }
        }

        // Perform async odometer validation
        final odometerError =
            await _validateOdometerReading(_odometerController.text);
        if (odometerError != null) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(odometerError),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isSaving = false);
          return;
        }

        final selectedMember = familyProvider.memberById(_selectedMemberId);
        final splitMemberIds = _isSplitExpense
            ? _buildSplitMemberList(selectedMember?.id)
            : const <int>[];

        final expense = FuelExpense(
          deviceId: deviceProvider.currentDevice!.deviceId,
          vehicleId: widget.vehicle.id!,
          date: _selectedDate,
          fuelType: _fuelType,
          amountPaid: double.parse(_amountController.text),
          liters: double.parse(_litersController.text),
          odometerReading: double.parse(_odometerController.text),
          pumpName: _pumpNameController.text.isNotEmpty
              ? _pumpNameController.text
              : null,
          location: _locationController.text.isNotEmpty
              ? _locationController.text
              : null,
          receiptImagePath: _receiptImagePath,
          notes:
              _notesController.text.isNotEmpty ? _notesController.text : null,
          familyMemberId: selectedMember?.id,
          familyMemberName: selectedMember?.name,
          splitMemberIds: splitMemberIds,
          isFullTank: _isFullTank,
        );

        final createdExpense = await expenseProvider.createFuelExpense(expense);

        await familyProvider.rememberMemberForVehicle(
          widget.vehicle.id!,
          selectedMember?.id,
        );

        final actorName =
            deviceProvider.currentDevice?.personName ?? 'A contributor';
        await CollaborationService.instance.logActivity(
          vehicleId: widget.vehicle.id!,
          deviceId: expense.deviceId,
          title: 'Fuel expense added',
          description:
              '$actorName recorded ₹${expense.amountPaid.toStringAsFixed(0)} for ${widget.vehicle.name}',
          type: 'fuel_expense',
          referenceType: 'fuel',
          referenceId: createdExpense.id,
          notify: widget.vehicle.isShared,
        );

        // Check budget alerts after adding expense
        try {
          await BudgetService.instance.checkBudgetAlerts(widget.vehicle);
        } catch (e) {
          // Non-critical: log but don't fail expense save
          debugPrint('Budget alert check failed: $e');
        }

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error saving expense: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isSaving = false);
        }
      }
    }
  }

  Future<void> _showNearbyStations() async {
    try {
      final geofenceService = GeofenceService.instance;
      
      // Show loading indicator
      if (!mounted) return;
      unawaited(showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      ),);

      // Get nearby geofences (petrol pumps within 5km)
      final nearbyStations = await geofenceService.getNearbyGeofences();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (nearbyStations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No nearby petrol pumps found within 5km'),
          ),
        );
        return;
      }

      // Show nearby stations in a bottom sheet
      unawaited(showModalBottomSheet(
        context: context,
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nearby Petrol Pumps',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: nearbyStations.length,
                  itemBuilder: (context, index) {
                    final station = nearbyStations[index];
                    final currentPosition = geofenceService.getLastKnownPosition();
                    final distance = currentPosition != null
                        ? (station.distanceFrom(currentPosition) / 1000).toStringAsFixed(2)
                        : '?';

                    return ListTile(
                      leading: const Icon(Icons.local_gas_station),
                      title: Text(station.stationName),
                      subtitle: Text('$distance km away'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        setState(() {
                          _pumpNameController.text = station.stationName;
                          _locationController.text =
                              '${station.latitude.toStringAsFixed(6)}, ${station.longitude.toStringAsFixed(6)}';
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Selected: ${station.stationName}'),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),);
    } catch (e) {
      if (!mounted) return;
      // Close loading if still showing
      try {
        Navigator.pop(context);
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching nearby stations: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
