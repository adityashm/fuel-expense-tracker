import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/expense_split.dart';
import '../models/family_member.dart';
import '../models/general_expense.dart';
import '../providers/device_provider.dart';
import '../providers/expense_provider.dart';
import '../utils/app_localizations.dart';

/// Screen for splitting bills among family members
class SplitBillScreen extends StatefulWidget {
  const SplitBillScreen({super.key, this.existingExpense});

  final GeneralExpense? existingExpense;

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  SplitType _selectedSplitType = SplitType.equal;
  ExpenseCategory _selectedCategory = ExpenseCategory.groceries;
  DateTime _selectedDate = DateTime.now();

  final Map<int, double> _customAmounts = {};
  final Map<int, double> _percentages = {};
  final Map<int, int> _shares = {};
  final Set<int> _selectedMembers = {};

  @override
  void initState() {
    super.initState();
    if (widget.existingExpense != null) {
      _descriptionController.text = widget.existingExpense!.description;
      _amountController.text = widget.existingExpense!.amount.toString();
      _selectedCategory = widget.existingExpense!.category;
      _selectedDate = widget.existingExpense!.date;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingExpense != null ? 'Edit Split Bill' : 'Split Bill',
        ),
      ),
      body: Form(
        key: _formKey,
        child: Consumer<ExpenseProvider>(
          builder: (context, expenseProvider, child) {
            if (expenseProvider.familyMembers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people_outline,
                        size: 80, color: Colors.grey,),
                    const SizedBox(height: 16),
                    const Text(
                      'No family members found',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Amount
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Total Amount',
                    prefixIcon: Icon(Icons.currency_rupee),
                    border: OutlineInputBorder(),
                    helperText: 'Total bill amount to split',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amount';
                    }
                    if (double.tryParse(value) == null ||
                        double.parse(value) <= 0) {
                      return 'Please enter valid amount';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      // Recalculate splits when amount changes
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Category
                DropdownButtonFormField<ExpenseCategory>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                  items: ExpenseCategory.values
                      .map(
                        (cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat.name[0].toUpperCase() +
                              cat.name.substring(1),),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Date
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Date'),
                  subtitle: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                    }
                  },
                ),
                const Divider(height: 32),

                // Split Type Selector
                Text(
                  'Split Method',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                ...SplitType.values
                    .map((type) => _buildSplitTypeCard(type, theme)),
                const SizedBox(height: 24),

                // Member Selection
                Text(
                  'Select Members (${_selectedMembers.length})',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                ...expenseProvider.familyMembers.map(
                  (member) => _buildMemberTile(member, theme),
                ),
                const SizedBox(height: 24),

                // Split Details
                if (_selectedMembers.isNotEmpty &&
                    _amountController.text.isNotEmpty)
                  _buildSplitDetails(theme, localizations),

                const SizedBox(height: 24),

                // Save Button
                ElevatedButton(
                  onPressed:
                      _selectedMembers.isNotEmpty ? _saveSplitBill : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save Split Bill',
                      style: TextStyle(fontSize: 16),),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSplitTypeCard(SplitType type, ThemeData theme) {
    final isSelected = _selectedSplitType == type;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      color: isSelected ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        leading: Icon(
          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: isSelected ? theme.colorScheme.primary : Colors.grey,
        ),
        title: Text(
          type.displayName,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(type.description),
        onTap: () {
          setState(() {
            _selectedSplitType = type;
            _customAmounts.clear();
            _percentages.clear();
            _shares.clear();
          });
        },
      ),
    );
  }

  Widget _buildMemberTile(FamilyMember member, ThemeData theme) {
    final isSelected = _selectedMembers.contains(member.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (selected) {
          setState(() {
            final memberId = member.id;
            if (memberId != null) {
              if (selected == true) {
                _selectedMembers.add(memberId);
              } else {
                _selectedMembers.remove(memberId);
                _customAmounts.remove(memberId);
                _percentages.remove(memberId);
                _shares.remove(memberId);
              }
            }
          });
        },
        secondary: CircleAvatar(
          backgroundColor: Color(member.colorHex).withValues(alpha: 0.2),
          child: Text(
            member.name[0].toUpperCase(),
            style: TextStyle(
              color: Color(member.colorHex),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(member.name),
        subtitle: _buildMemberSubtitle(member),
      ),
    );
  }

  Widget? _buildMemberSubtitle(FamilyMember member) {
    if (!_selectedMembers.contains(member.id)) return null;

    final totalAmount = double.tryParse(_amountController.text) ?? 0;

    switch (_selectedSplitType) {
      case SplitType.equal:
        final split = totalAmount / _selectedMembers.length;
        return Text('₹${split.toStringAsFixed(2)}');

      case SplitType.custom:
        return TextFormField(
          initialValue: _customAmounts[member.id]?.toString() ?? '',
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: '₹',
            isDense: true,
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final memberId = member.id;
            if (memberId != null) {
              _customAmounts[memberId] = double.tryParse(value) ?? 0;
              setState(() {});
            }
          },
        );

      case SplitType.percentage:
        return TextFormField(
          initialValue: _percentages[member.id]?.toString() ?? '',
          decoration: const InputDecoration(
            labelText: 'Percentage',
            suffixText: '%',
            isDense: true,
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final memberId = member.id;
            if (memberId != null) {
              _percentages[memberId] = double.tryParse(value) ?? 0;
              setState(() {});
            }
          },
        );

      case SplitType.shares:
        return TextFormField(
          initialValue: _shares[member.id]?.toString() ?? '',
          decoration: const InputDecoration(
            labelText: 'Shares',
            isDense: true,
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final memberId = member.id;
            if (memberId != null) {
              _shares[memberId] = int.tryParse(value) ?? 0;
              setState(() {});
            }
          },
        );

      case SplitType.single:
        return const Text('Single payer');
    }
  }

  Widget _buildSplitDetails(ThemeData theme, AppLocalizations localizations) {
    final totalAmount = double.tryParse(_amountController.text) ?? 0;
    final splits = _calculateSplits(totalAmount);

    return Card(
      elevation: 4,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Split Breakdown',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...splits.entries.map((entry) {
              final member = Provider.of<ExpenseProvider>(context,
                      listen: false,)
                  .familyMembers
                  .cast<FamilyMember?>()
                  .firstWhere((m) => m?.id == entry.key, orElse: () => null);
              if (member == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor:
                              Color(member.colorHex).withValues(alpha: 0.2),
                          child: Text(
                            member.name[0].toUpperCase(),
                            style: TextStyle(
                              color: Color(member.colorHex),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(member.name),
                      ],
                    ),
                    Text(
                      '₹${entry.value.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:',
                    style: TextStyle(fontWeight: FontWeight.bold),),
                Text(
                  '₹${splits.values.fold<double>(0, (sum, amt) => sum + amt).toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16,),
                ),
              ],
            ),
            if (_selectedSplitType == SplitType.custom ||
                _selectedSplitType == SplitType.percentage) ...[
              const SizedBox(height: 8),
              _buildValidationMessage(totalAmount, splits),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildValidationMessage(double totalAmount, Map<int, double> splits) {
    final splitTotal = splits.values.fold<double>(0, (sum, amt) => sum + amt);
    final difference = (totalAmount - splitTotal).abs();

    if (difference < 0.01) {
      return Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[700], size: 16),
          const SizedBox(width: 8),
          const Text('✓ Splits match total',
              style: TextStyle(color: Colors.green),),
        ],
      );
    } else {
      return Row(
        children: [
          Icon(Icons.warning, color: Colors.orange[700], size: 16),
          const SizedBox(width: 8),
          Text(
            'Difference: ₹${difference.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.orange),
          ),
        ],
      );
    }
  }

  Map<int, double> _calculateSplits(double totalAmount) {
    final splits = <int, double>{};

    switch (_selectedSplitType) {
      case SplitType.equal:
        final splitAmount = totalAmount / _selectedMembers.length;
        for (final memberId in _selectedMembers) {
          splits[memberId] = splitAmount;
        }
        break;

      case SplitType.custom:
        splits.addAll(_customAmounts);
        break;

      case SplitType.percentage:
        for (final entry in _percentages.entries) {
          splits[entry.key] = (totalAmount * entry.value) / 100;
        }
        break;

      case SplitType.shares:
        final totalShares =
            _shares.values.fold<int>(0, (sum, shares) => sum + shares);
        if (totalShares > 0) {
          for (final entry in _shares.entries) {
            splits[entry.key] = (totalAmount * entry.value) / totalShares;
          }
        }
        break;

      case SplitType.single:
        if (_selectedMembers.isNotEmpty) {
          final firstMemberId = _selectedMembers.first;
          splits[firstMemberId] = totalAmount;
        }
        break;
    }

    return splits;
  }

  Future<void> _saveSplitBill() async {
    if (!_formKey.currentState!.validate()) return;

    final totalAmount = double.parse(_amountController.text);
    final splits = _calculateSplits(totalAmount);

    // Validate splits
    if (_selectedSplitType == SplitType.custom ||
        _selectedSplitType == SplitType.percentage) {
      final splitTotal = splits.values.fold<double>(0, (sum, amt) => sum + amt);
      if ((totalAmount - splitTotal).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Split amounts must equal total amount'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    try {
      final deviceProvider =
          Provider.of<DeviceProvider>(context, listen: false);
      final expenseProvider =
          Provider.of<ExpenseProvider>(context, listen: false);

      // Create expense for each member's share
      for (final entry in splits.entries) {
        final expense = GeneralExpense(
          deviceId: deviceProvider.currentDeviceId ?? '',
          date: _selectedDate,
          amount: entry.value,
          category: _selectedCategory,
          description: '${_descriptionController.text} (Split)',
          isHouseholdExpense: true,
          familyMemberId: entry.key,
          createdAt: DateTime.now(),
        );

        await expenseProvider.createGeneralExpense(expense);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Split bill saved successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving split bill: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
