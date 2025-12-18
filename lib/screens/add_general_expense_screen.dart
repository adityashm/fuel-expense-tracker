import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/general_expense.dart';
import '../providers/device_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/family_member_provider.dart';
import '../providers/vehicle_provider.dart';
import '../services/budget_service.dart';
import '../services/collaboration_service.dart';
import '../utils/app_localizations.dart';
import '../widgets/family_member_selector.dart';
import 'receipt_scanner_screen.dart';

class AddGeneralExpenseScreen extends StatefulWidget {
  const AddGeneralExpenseScreen({super.key});

  @override
  State<AddGeneralExpenseScreen> createState() =>
      _AddGeneralExpenseScreenState();
}

class _AddGeneralExpenseScreenState extends State<AddGeneralExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  ExpenseCategory _category = ExpenseCategory.maintenance;
  int? _selectedVehicleId;
  String? _receiptImagePath;
  bool _isProcessing = false;
  bool _isSaving = false;
  int? _selectedMemberId;
  List<int> _splitMemberIds = [];
  bool _isSplitExpense = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _prefillMemberSelection());
  }

  @override
  void dispose() {
    _amountController
      ..removeListener(_onAmountChanged)
      ..dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final vehicleProvider = Provider.of<VehicleProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('add_general_expense')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                      style:
                          IconButton.styleFrom(backgroundColor: Colors.black54),
                      onPressed: () => setState(() => _receiptImagePath = null),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
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
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(localizations.formatDate(_selectedDate)),
                subtitle: Text(localizations.translate('date')),
                trailing: const Icon(Icons.edit),
                onTap: _selectDate,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: _selectedVehicleId,
                decoration: const InputDecoration(
                  labelText: 'Vehicle (Optional)',
                  prefixIcon: Icon(Icons.directions_car),
                ),
                items: [
                  const DropdownMenuItem(child: Text('None')),
                  ...vehicleProvider.vehicles.map(
                    (vehicle) => DropdownMenuItem(
                      value: vehicle.id,
                      child: Text(vehicle.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _selectedVehicleId = value);
                  _prefillMemberSelection(vehicleId: value, force: true);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ExpenseCategory>(
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: localizations.translate('category'),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: [
                  ExpenseCategory.maintenance,
                  ExpenseCategory.insurance,
                  ExpenseCategory.parking,
                  ExpenseCategory.tolls,
                  ExpenseCategory.servicing,
                  ExpenseCategory.other,
                ]
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(localizations.translate(category.name)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _category = value!),
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
                    label: 'Who paid for this?',
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
                subtitle: const Text('Share cost across chosen family members'),
              ),
              _buildSplitShareHint(localizations),
              const SizedBox(height: 16),
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
                  if (amount == null) return 'Please enter a valid number';
                  if (amount <= 0) return 'Amount must be greater than 0';
                  if (amount > 1000000) return 'Amount seems too high';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: localizations.translate('description'),
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveExpense,
                style:
                    ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _prefillMemberSelection({int? vehicleId, bool force = false}) {
    final familyProvider = context.read<FamilyMemberProvider>();
    if (!force && _selectedMemberId != null) {
      return;
    }

    int? preset;
    final targetVehicleId = vehicleId ?? _selectedVehicleId;
    if (targetVehicleId != null) {
      preset = familyProvider.lastMemberForVehicle(targetVehicleId);
      if (preset == null) {
        for (final member in familyProvider.members) {
          if (member.primaryVehicleId == targetVehicleId && member.id != null) {
            preset = member.id;
            break;
          }
        }
      }
    }

    if (preset == null) {
      for (final member in familyProvider.members) {
        if (member.id != null) {
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

      if (!mounted || result == null) {
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

      final date = result['date'];
      if (date is DateTime) {
        setState(() => _selectedDate = date);
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning receipt: $e')),
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

  Future<void> _saveExpense() async {
    if (_formKey.currentState!.validate()) {
      if (_isSaving) return;
      setState(() => _isSaving = true);

      try {
        final deviceProvider =
            Provider.of<DeviceProvider>(context, listen: false);
        final expenseProvider =
            Provider.of<ExpenseProvider>(context, listen: false);
        final vehicleProvider =
            Provider.of<VehicleProvider>(context, listen: false);
        final familyProvider =
            Provider.of<FamilyMemberProvider>(context, listen: false);

        // Re-initialize device if missing
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
                  duration: Duration(seconds: 5),
                ),
              );
            }
            return;
          }
        }

        final selectedMember = familyProvider.memberById(_selectedMemberId);
        final splitMemberIds = _isSplitExpense
            ? _buildSplitMemberList(selectedMember?.id)
            : const <int>[];

        final expense = GeneralExpense(
          deviceId: deviceProvider.currentDevice!.deviceId,
          vehicleId: _selectedVehicleId,
          date: _selectedDate,
          amount: double.parse(_amountController.text),
          category: _category,
          description: _descriptionController.text,
          receiptImagePath: _receiptImagePath,
          familyMemberId: selectedMember?.id,
          familyMemberName: selectedMember?.name,
          splitMemberIds: splitMemberIds,
        );

        final saved = await expenseProvider.createGeneralExpense(expense);

        // Ensure the expense has an ID
        if (saved.id == null) {
          throw Exception('Failed to save expense: No ID returned');
        }

        if (_selectedVehicleId != null) {
          await familyProvider.rememberMemberForVehicle(
            _selectedVehicleId!,
            selectedMember?.id,
          );
        }

        if (_selectedVehicleId != null) {
          final vehicle = vehicleProvider.vehicles.firstWhere(
            (v) => v.id == _selectedVehicleId,
            orElse: () => vehicleProvider.vehicles.first,
          );
          final actorName =
              deviceProvider.currentDevice?.personName ?? 'A contributor';
          await CollaborationService.instance.logActivity(
            vehicleId: _selectedVehicleId!,
            deviceId: expense.deviceId,
            title: 'Expense added',
            description:
                '$actorName logged ₹${expense.amount.toStringAsFixed(0)} (${_category.name}) on ${vehicle.name}',
            type: 'general_expense',
            referenceType: 'general',
            referenceId: saved.id,
            notify: vehicle.isShared,
          );
        }
        // Check budget alerts if vehicle-specific expense
        if (_selectedVehicleId != null) {
          try {
            final vehicle = vehicleProvider.vehicles.firstWhere(
              (v) => v.id == _selectedVehicleId,
            );
            await BudgetService.instance.checkBudgetAlerts(vehicle);
          } catch (e) {
            debugPrint('Budget alert check failed: $e');
          }
        }

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
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
}
