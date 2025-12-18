import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/family_member.dart';
import '../models/general_expense.dart';
import '../providers/device_provider.dart';
import '../providers/expense_provider.dart';
import '../utils/app_localizations.dart';
import 'receipt_scanner_screen.dart';

class AddHouseholdExpenseScreen extends StatefulWidget {
  const AddHouseholdExpenseScreen({super.key, this.existingExpense});

  final GeneralExpense? existingExpense;

  @override
  State<AddHouseholdExpenseScreen> createState() =>
      _AddHouseholdExpenseScreenState();
}

class _AddHouseholdExpenseScreenState extends State<AddHouseholdExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  ExpenseCategory _category = ExpenseCategory.groceries;
  String? _receiptImagePath;
  bool _isProcessing = false;
  bool _isSaving = false;
  FamilyMember? _selectedMember;

  @override
  void initState() {
    super.initState();
    if (widget.existingExpense != null) {
      // Pre-fill form with existing data
      _amountController.text = widget.existingExpense!.amount.toString();
      _descriptionController.text = widget.existingExpense!.description;
      _selectedDate = widget.existingExpense!.date;
      _category = widget.existingExpense!.category;
      _receiptImagePath = widget.existingExpense!.receiptImagePath;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFamilyMembers();
    });
  }

  Future<void> _loadFamilyMembers() async {
    final expenseProvider =
        Provider.of<ExpenseProvider>(context, listen: false);
    await expenseProvider.loadFamilyMembers();

    // Set selected member if editing - with safe null handling
    if (widget.existingExpense?.familyMemberId != null && mounted) {
      final members = expenseProvider.familyMembers;
      if (members.isNotEmpty) {
        final member = members.cast<FamilyMember?>().firstWhere(
              (m) => m?.id == widget.existingExpense!.familyMemberId,
              orElse: () => null,
            );
        if (member != null) {
          setState(() {
            _selectedMember = member;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isEditing = widget.existingExpense != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'Edit Household Expense'
              : localizations.translate('add_household_expense'),
        ),
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
              DropdownButtonFormField<ExpenseCategory>(
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: localizations.translate('category'),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: [
                  ExpenseCategory.groceries,
                  ExpenseCategory.utilities,
                  ExpenseCategory.healthcare,
                  ExpenseCategory.education,
                  ExpenseCategory.entertainment,
                  ExpenseCategory.shopping,
                  ExpenseCategory.food,
                  ExpenseCategory.transport,
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
              const SizedBox(height: 16),
              Consumer<ExpenseProvider>(
                builder: (context, provider, child) {
                  if (provider.familyMembers.isEmpty) {
                    return Card(
                      color: Colors.orange[50],
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange[700]),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'No family members yet. Add members to track who paid.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return DropdownButtonFormField<FamilyMember>(
                    initialValue: _selectedMember,
                    decoration: const InputDecoration(
                      labelText: 'Paid By (Optional)',
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: provider.familyMembers.map((member) {
                      return DropdownMenuItem(
                        value: member,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Color(member.colorHex),
                              child: Text(
                                member.avatarIcon,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(member.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedMember = value;
                      });
                    },
                  );
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
                        widget.existingExpense != null
                            ? 'Update Expense'
                            : localizations.translate('save'),
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

        final expense = GeneralExpense(
          id: widget.existingExpense?.id,
          deviceId: deviceProvider.currentDevice!.deviceId,
          date: _selectedDate,
          amount: double.parse(_amountController.text),
          category: _category,
          description: _descriptionController.text,
          receiptImagePath: _receiptImagePath,
          isHouseholdExpense: true, // Mark as household expense
          familyMemberId: _selectedMember?.id,
          familyMemberName: _selectedMember?.name,
        );

        if (widget.existingExpense != null) {
          // Update existing expense
          await expenseProvider.updateGeneralExpense(
            expense,
            deviceProvider.currentDeviceId,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Expense updated successfully!'),
                  ],
                ),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          }
        } else {
          // Create new expense
          final saved = await expenseProvider.createGeneralExpense(expense);

          // Ensure the expense has an ID
          if (saved.id == null) {
            throw Exception('Failed to save expense: No ID returned');
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Expense saved successfully!'),
                  ],
                ),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          }
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
