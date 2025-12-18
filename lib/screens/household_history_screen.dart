import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/general_expense.dart';
import '../providers/device_provider.dart';
import '../providers/expense_provider.dart';
import '../utils/app_localizations.dart';
import 'add_household_expense_screen.dart';

class HouseholdHistoryScreen extends StatefulWidget {
  const HouseholdHistoryScreen({super.key});

  @override
  State<HouseholdHistoryScreen> createState() => _HouseholdHistoryScreenState();
}

class _HouseholdHistoryScreenState extends State<HouseholdHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  late ScrollController _scrollController;
  String _searchQuery = '';
  ExpenseCategory? _selectedCategory;
  int? _selectedMemberId;
  DateTimeRange? _dateRange;
  int _currentPage = 0;
  final int _itemsPerPage = 20;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreExpenses();
    }
  }

  Future<void> _loadMoreExpenses() async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    // Add artificial delay for pagination effect
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadData() async {
    final expenseProvider =
        Provider.of<ExpenseProvider>(context, listen: false);
    await expenseProvider.loadHouseholdExpenses();
    await expenseProvider.loadFamilyMembers();
    _currentPage = 0;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Household Expense History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search expenses...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          // Active filters
          if (_selectedCategory != null ||
              _selectedMemberId != null ||
              _dateRange != null)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (_selectedCategory != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          localizations.translate(_selectedCategory!.name),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          setState(() {
                            _selectedCategory = null;
                          });
                        },
                      ),
                    ),
                  if (_selectedMemberId != null)
                    Consumer<ExpenseProvider>(
                      builder: (context, provider, child) {
                        final member = provider.familyMembers
                            .firstWhere((m) => m.id == _selectedMemberId);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            avatar: CircleAvatar(
                              backgroundColor: Color(member.colorHex),
                              child: Text(member.avatarIcon),
                            ),
                            label: Text(member.name),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setState(() {
                                _selectedMemberId = null;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  if (_dateRange != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          '${localizations.formatDate(_dateRange!.start)} - ${localizations.formatDate(_dateRange!.end)}',
                        ),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          setState(() {
                            _dateRange = null;
                          });
                        },
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = null;
                        _selectedMemberId = null;
                        _dateRange = null;
                      });
                    },
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear All'),
                  ),
                ],
              ),
            ),
          // Expense list
          Expanded(
            child: _buildExpenseList(localizations, theme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddHouseholdExpenseScreen(),
            ),
          );
          if (result == true && mounted) {
            await _loadData();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  Widget _buildExpenseList(
    AppLocalizations localizations,
    ThemeData theme,
  ) {
    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, child) {
        if (expenseProvider.isHouseholdLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        var expenses = expenseProvider.householdExpenses;

        // Apply filters
        if (_searchQuery.isNotEmpty) {
          expenses = expenses.where((expense) {
            final searchIn = [
              expense.description.toLowerCase(),
              expense.category.name.toLowerCase(),
              expense.amount.toString(),
              expense.familyMemberName?.toLowerCase() ?? '',
            ].join(' ');
            return searchIn.contains(_searchQuery);
          }).toList();
        }

        if (_selectedCategory != null) {
          expenses =
              expenses.where((e) => e.category == _selectedCategory).toList();
        }

        if (_selectedMemberId != null) {
          expenses = expenses
              .where((e) => e.familyMemberId == _selectedMemberId)
              .toList();
        }

        if (_dateRange != null) {
          expenses = expenses.where((e) {
            return e.date.isAfter(
                    _dateRange!.start.subtract(const Duration(days: 1)),) &&
                e.date.isBefore(_dateRange!.end.add(const Duration(days: 1)));
          }).toList();
        }

        if (expenses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _searchQuery.isNotEmpty ||
                          _selectedCategory != null ||
                          _selectedMemberId != null ||
                          _dateRange != null
                      ? Icons.search_off
                      : Icons.receipt_long_outlined,
                  size: 80,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty ||
                          _selectedCategory != null ||
                          _selectedMemberId != null ||
                          _dateRange != null
                      ? 'No results found'
                      : 'No household expenses yet',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
                if (_searchQuery.isEmpty &&
                    _selectedCategory == null &&
                    _selectedMemberId == null &&
                    _dateRange == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AddHouseholdExpenseScreen(),
                          ),
                        );
                        if (result == true && mounted) {
                          await _loadData();
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add First Expense'),
                    ),
                  ),
              ],
            ),
          );
        }

        // Group expenses by date
        final Map<String, List<GeneralExpense>> groupedExpenses = {};
        for (final expense in expenses) {
          final dateKey = localizations.formatDate(expense.date);
          groupedExpenses.putIfAbsent(dateKey, () => []).add(expense);
        }

        // Implement pagination - show only first N pages
        final sortedDates = groupedExpenses.keys.toList();
        final maxIndex = (_currentPage + 1) * _itemsPerPage < sortedDates.length
            ? (_currentPage + 1) * _itemsPerPage
            : sortedDates.length;
        final visibleDates = sortedDates.sublist(0, maxIndex);

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: visibleDates.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            // Show loading indicator at the end
            if (index == visibleDates.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              );
            }

            final dateKey = visibleDates[index];
            final dayExpenses = groupedExpenses[dateKey]!;
            final dayTotal = dayExpenses.fold<double>(
              0,
              (sum, expense) => sum + expense.amount,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateKey,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        localizations.formatCurrency(dayTotal),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                ...dayExpenses.map((expense) {
                  return Dismissible(
                    key: Key('household_${expense.id}'),
                    background: _buildSwipeBackground(
                      alignment: Alignment.centerLeft,
                      color: Colors.blue,
                      icon: Icons.edit,
                      label: 'Edit',
                    ),
                    secondaryBackground: _buildSwipeBackground(
                      alignment: Alignment.centerRight,
                      color: Colors.red,
                      icon: Icons.delete,
                      label: 'Delete',
                    ),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        // Edit
                        await _editExpense(expense);
                        return false;
                      } else {
                        // Delete
                        return _confirmDelete(expense);
                      }
                    },
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () => _showExpenseDetails(expense),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: theme.colorScheme.primary
                                    .withValues(alpha: 0.1),
                                child: Icon(
                                  _getCategoryIcon(expense.category),
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      expense.description,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          localizations.translate(
                                            expense.category.name,
                                          ),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        if (expense.familyMemberName !=
                                            null) ...[
                                          const Text(' • '),
                                          Icon(
                                            Icons.person,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            expense.familyMemberName!,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (expense.receiptImagePath != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.receipt,
                                              size: 14,
                                              color: theme.colorScheme.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Receipt attached',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    localizations
                                        .formatCurrency(expense.amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: Colors.grey[600],
                                    ),
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'edit':
                                          _editExpense(expense);
                                          break;
                                        case 'delete':
                                          _confirmDelete(expense)
                                              .then((confirmed) {
                                            if (confirmed == true) {
                                              _deleteExpense(expense);
                                            }
                                          });
                                          break;
                                        case 'view_receipt':
                                          _viewReceipt(expense);
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 12),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      if (expense.receiptImagePath != null)
                                        const PopupMenuItem(
                                          value: 'view_receipt',
                                          child: Row(
                                            children: [
                                              Icon(Icons.receipt, size: 20),
                                              SizedBox(width: 12),
                                              Text('View Receipt'),
                                            ],
                                          ),
                                        ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete,
                                              size: 20,
                                              color: Colors.red,
                                            ),
                                            SizedBox(width: 12),
                                            Text(
                                              'Delete',
                                              style:
                                                  TextStyle(color: Colors.red),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSwipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      alignment: alignment,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editExpense(GeneralExpense expense) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddHouseholdExpenseScreen(
          existingExpense: expense,
        ),
      ),
    );
    if (result == true && mounted) {
      await _loadData();
    }
  }

  Future<bool?> _confirmDelete(GeneralExpense expense) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this expense?'),
            const SizedBox(height: 16),
            Text(
              expense.description,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              AppLocalizations.of(context).formatCurrency(expense.amount),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExpense(GeneralExpense expense) async {
    try {
      final expenseProvider =
          Provider.of<ExpenseProvider>(context, listen: false);
      final deviceProvider =
          Provider.of<DeviceProvider>(context, listen: false);
      await expenseProvider.deleteGeneralExpense(
        expense.id!,
        deviceProvider.currentDeviceId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Expense deleted successfully'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting expense: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showExpenseDetails(GeneralExpense expense) {
    final localizations = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                expense.description,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                localizations.formatCurrency(expense.amount),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailRow(
                Icons.category,
                'Category',
                localizations.translate(expense.category.name),
              ),
              _buildDetailRow(
                Icons.calendar_today,
                'Date',
                localizations.formatDate(expense.date),
              ),
              if (expense.familyMemberName != null)
                _buildDetailRow(
                  Icons.person,
                  'Paid by',
                  expense.familyMemberName!,
                ),
              if (expense.receiptImagePath != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Receipt',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(expense.receiptImagePath!),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _editExpense(expense);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        final confirmed = await _confirmDelete(expense);
                        if (confirmed == true) {
                          await _deleteExpense(expense);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _viewReceipt(GeneralExpense expense) {
    if (expense.receiptImagePath == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Receipt'),
            backgroundColor: Colors.black,
          ),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              child: Image.file(File(expense.receiptImagePath!)),
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    final localizations = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Filter Expenses',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ExpenseCategory.groceries,
                    ExpenseCategory.utilities,
                    ExpenseCategory.healthcare,
                    ExpenseCategory.education,
                    ExpenseCategory.entertainment,
                    ExpenseCategory.shopping,
                    ExpenseCategory.food,
                    ExpenseCategory.transport,
                    ExpenseCategory.other,
                  ].map((category) {
                    final isSelected = _selectedCategory == category;
                    return FilterChip(
                      label: Text(localizations.translate(category.name)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setModalState(() {
                          _selectedCategory = selected ? category : null;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Family Member',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Consumer<ExpenseProvider>(
                  builder: (context, provider, child) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: provider.familyMembers.map((member) {
                        final isSelected = _selectedMemberId == member.id;
                        return FilterChip(
                          avatar: CircleAvatar(
                            backgroundColor: Color(member.colorHex),
                            child: Text(member.avatarIcon),
                          ),
                          label: Text(member.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              _selectedMemberId = selected ? member.id : null;
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Date Range',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDateRange: _dateRange,
                    );
                    if (picked != null) {
                      setModalState(() {
                        _dateRange = picked;
                      });
                    }
                  },
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _dateRange != null
                        ? '${localizations.formatDate(_dateRange!.start)} - ${localizations.formatDate(_dateRange!.end)}'
                        : 'Select Date Range',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedCategory = null;
                            _selectedMemberId = null;
                            _dateRange = null;
                          });
                          setState(() {
                            _selectedCategory = null;
                            _selectedMemberId = null;
                            _dateRange = null;
                          });
                        },
                        child: const Text('Clear All'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            // Filters already applied
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      setState(() {}); // Refresh the main screen
    });
  }

  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.groceries:
        return Icons.shopping_cart;
      case ExpenseCategory.utilities:
        return Icons.water_drop;
      case ExpenseCategory.healthcare:
        return Icons.medical_services;
      case ExpenseCategory.education:
        return Icons.school;
      case ExpenseCategory.entertainment:
        return Icons.movie;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag;
      case ExpenseCategory.food:
        return Icons.restaurant;
      case ExpenseCategory.transport:
        return Icons.train;
      default:
        return Icons.category;
    }
  }
}
