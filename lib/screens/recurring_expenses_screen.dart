import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/family_member.dart';
import '../models/recurring_expense.dart';
import '../providers/device_provider.dart';
import '../providers/expense_provider.dart';

/// Screen for managing recurring expenses
class RecurringExpensesScreen extends StatefulWidget {
  const RecurringExpensesScreen({super.key});

  @override
  State<RecurringExpensesScreen> createState() =>
      _RecurringExpensesScreenState();
}

class _RecurringExpensesScreenState extends State<RecurringExpensesScreen> {
  bool _showPaused = false;
  bool _isLoading = true;

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
      Provider.of<ExpenseProvider>(context, listen: false)
          .loadRecurringExpenses()
          .then((_) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Expenses'),
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, child) {
          final expenses = provider.recurringExpenses;

          if (_isLoading) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (context, index) => _buildLoadingCard(theme),
            );
          }

          if (expenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.repeat, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No recurring expenses',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add monthly rent, utilities, etc.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddRecurringDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Recurring'),
                  ),
                ],
              ),
            );
          }

          final active = expenses.where((e) => e.isActive).toList();
          final paused = expenses.where((e) => !e.isActive).toList();
          final monthlyTotal =
              active.fold<double>(0, (sum, e) => sum + e.amount);

          // Pagination: limit visible items
          final maxActive =
              (_currentPage * _itemsPerPage).clamp(0, active.length);
          final visibleActive = active.sublist(0, maxActive);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _isLoading = true);
              await provider.loadRecurringExpenses();
              if (mounted) setState(() => _isLoading = false);
            },
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                _buildSummaryHeader(theme, active.length, monthlyTotal),
                const SizedBox(height: 12),
                ...visibleActive
                    .map((e) => _buildRecurringCard(e, provider, theme, true)),
                if (_isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                const SizedBox(height: 24),
                if (paused.isNotEmpty)
                  _buildPausedSection(theme, provider, paused),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRecurringDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Recurring'),
      ),
    );
  }

  Widget _buildRecurringCard(RecurringExpense expense, ExpenseProvider provider,
      ThemeData theme, bool isActive,) {
    final nextDue = expense.nextDue ?? expense.calculateNextDue();
    final daysDiff = nextDue.difference(DateTime.now()).inDays;
    final overdue = isActive && daysDiff < 0;
    final dueColor = overdue
        ? theme.colorScheme.error
        : daysDiff <= 0
            ? Colors.orange
            : daysDiff <= 3
                ? Colors.amber
                : theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.25),
        ),
        color: isActive ? theme.colorScheme.surface : Colors.grey[100],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showRecurringDetails(expense),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isActive
                          ? theme.colorScheme.primary.withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getCategoryIcon(expense.category),
                      color: isActive ? theme.colorScheme.primary : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? theme.colorScheme.onSurface
                                : Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${expense.amount.toStringAsFixed(0)} • ${expense.frequency.displayName}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                        if (expense.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            expense.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(isActive ? Icons.pause : Icons.play_arrow,
                                size: 20,),
                            const SizedBox(width: 12),
                            Text(isActive ? 'Pause' : 'Resume'),
                          ],
                        ),
                      ),
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
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == 'toggle') {
                        await provider.toggleRecurringExpense(expense.id);
                      } else if (value == 'edit') {
                        _showEditRecurringDialog(expense);
                      } else if (value == 'delete') {
                        _confirmDelete(expense);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6,),
                      decoration: BoxDecoration(
                        color: dueColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            overdue ? Icons.error_outline : Icons.schedule,
                            size: 16,
                            color: dueColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            overdue
                                ? 'Overdue'
                                : daysDiff <= 0
                                    ? 'Due today'
                                    : daysDiff == 1
                                        ? 'Due tomorrow'
                                        : 'Due in $daysDiff days',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: dueColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6,),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pause_circle_outline,
                              size: 16, color: Colors.grey,),
                          SizedBox(width: 6),
                          Text(
                            'Paused',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Text(
                    nextDue.year == DateTime.now().year
                        ? 'Next: ${nextDue.day}/${nextDue.month}'
                        : 'Next: ${nextDue.day}/${nextDue.month}/${nextDue.year}',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(
      ThemeData theme, int activeCount, double monthlyTotal,) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active ($activeCount)',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${monthlyTotal.toStringAsFixed(0)}/month',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.autorenew, color: Colors.white70, size: 18),
              SizedBox(width: 8),
              Text(
                'Recurring household obligations',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPausedSection(ThemeData theme, ExpenseProvider provider,
      List<RecurringExpense> paused,) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Paused (${paused.length})',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _showPaused = !_showPaused),
              icon: Icon(_showPaused ? Icons.expand_less : Icons.expand_more),
              label: Text(_showPaused ? 'Hide' : 'Expand'),
            ),
          ],
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: [
              const SizedBox(height: 12),
              ...paused
                  .map((e) => _buildRecurringCard(e, provider, theme, false)),
            ],
          ),
          crossFadeState: _showPaused
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _buildLoadingCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: const SizedBox(height: 92),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'groceries':
        return Icons.shopping_cart;
      case 'utilities':
        return Icons.bolt;
      case 'rent':
        return Icons.home;
      case 'insurance':
        return Icons.shield;
      case 'subscription':
        return Icons.subscriptions;
      default:
        return Icons.receipt;
    }
  }

  void _showAddRecurringDialog() {
    _showRecurringForm(null);
  }

  void _showEditRecurringDialog(RecurringExpense expense) {
    _showRecurringForm(expense);
  }

  void _showRecurringForm(RecurringExpense? existingExpense) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: existingExpense?.title);
    final amountController =
        TextEditingController(text: existingExpense?.amount.toString());
    final descController =
        TextEditingController(text: existingExpense?.description);
    // ignore: prefer_final_locals
    // ignore: prefer_final_locals
    String selectedCategory = existingExpense?.category ?? 'Groceries';
    // ignore: prefer_final_locals
    RecurrenceFrequency selectedFrequency =
        existingExpense?.frequency ?? RecurrenceFrequency.monthly;
    FamilyMember? selectedMember;
    final DateTime startDate = existingExpense?.startDate ?? DateTime.now();
    final DateTime? endDate = existingExpense?.endDate;
    int? dayOfMonth = existingExpense?.dayOfMonth ?? DateTime.now().day;
    int? dayOfWeek = existingExpense?.dayOfWeek;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existingExpense == null
              ? 'Add Recurring Expense'
              : 'Edit Recurring Expense',),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Consumer<ExpenseProvider>(
                builder: (context, provider, _) {
                  if (existingExpense != null &&
                      selectedMember == null &&
                      existingExpense.memberId != null) {
                    selectedMember = provider.familyMembers
                        .firstWhere((m) => m.id == existingExpense.memberId);
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (v) =>
                            v?.isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: amountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            v?.isEmpty == true || double.tryParse(v!) == null
                                ? 'Invalid'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: [
                          'Groceries',
                          'Utilities',
                          'Rent',
                          'Insurance',
                          'Subscription',
                          'Other',
                        ]
                            .map((cat) =>
                                DropdownMenuItem(value: cat, child: Text(cat)),)
                            .toList(),
                        onChanged: (value) =>
                            setState(() => selectedCategory = value!),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<RecurrenceFrequency>(
                        initialValue: selectedFrequency,
                        decoration: const InputDecoration(
                          labelText: 'Frequency',
                          prefixIcon: Icon(Icons.repeat),
                        ),
                        items: RecurrenceFrequency.values
                            .map(
                              (freq) => DropdownMenuItem(
                                value: freq,
                                child: Text(freq.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          selectedFrequency = value!;
                          if (value == RecurrenceFrequency.weekly) {
                            dayOfWeek = DateTime.now().weekday;
                            dayOfMonth = null;
                          } else if (value == RecurrenceFrequency.monthly) {
                            dayOfMonth = DateTime.now().day;
                            dayOfWeek = null;
                          } else {
                            dayOfMonth = null;
                            dayOfWeek = null;
                          }
                        }),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<FamilyMember?>(
                        initialValue: selectedMember,
                        decoration: const InputDecoration(
                          labelText: 'Paid By (Optional)',
                          prefixIcon: Icon(Icons.person),
                        ),
                        items: [
                          const DropdownMenuItem<FamilyMember?>(
                              child: Text('None'),),
                          ...provider.familyMembers.map(
                            (member) => DropdownMenuItem(
                              value: member,
                              child: Text(member.name),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => selectedMember = value),
                      ),
                      const SizedBox(height: 16),
                      if (selectedFrequency == RecurrenceFrequency.monthly)
                        DropdownButtonFormField<int>(
                          initialValue: dayOfMonth,
                          decoration: const InputDecoration(
                            labelText: 'Day of Month',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          items: List.generate(31, (i) => i + 1)
                              .map(
                                (day) => DropdownMenuItem(
                                  value: day,
                                  child: Text('$day'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => dayOfMonth = value),
                        ),
                      if (selectedFrequency == RecurrenceFrequency.weekly)
                        DropdownButtonFormField<int>(
                          initialValue: dayOfWeek ?? DateTime.now().weekday,
                          decoration: const InputDecoration(
                            labelText: 'Day of Week',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('Monday')),
                            DropdownMenuItem(value: 2, child: Text('Tuesday')),
                            DropdownMenuItem(
                                value: 3, child: Text('Wednesday'),),
                            DropdownMenuItem(value: 4, child: Text('Thursday')),
                            DropdownMenuItem(value: 5, child: Text('Friday')),
                            DropdownMenuItem(value: 6, child: Text('Saturday')),
                            DropdownMenuItem(value: 7, child: Text('Sunday')),
                          ],
                          onChanged: (value) =>
                              setState(() => dayOfWeek = value),
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descController,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final recurring = RecurringExpense(
                    id: existingExpense?.id ?? const Uuid().v4(),
                    title: titleController.text,
                    description: descController.text,
                    amount: double.parse(amountController.text),
                    category: selectedCategory,
                    memberId: selectedMember?.id,
                    frequency: selectedFrequency,
                    startDate: startDate,
                    endDate: endDate,
                    dayOfMonth: dayOfMonth,
                    dayOfWeek: dayOfWeek,
                    isActive: existingExpense?.isActive ?? true,
                    deviceId:
                        Provider.of<DeviceProvider>(context, listen: false)
                            .currentDeviceId,
                    createdAt: existingExpense?.createdAt ?? DateTime.now(),
                    updatedAt: DateTime.now(),
                    lastGenerated: existingExpense?.lastGenerated,
                    nextDue: existingExpense?.nextDue,
                  );

                  if (existingExpense == null) {
                    await Provider.of<ExpenseProvider>(context, listen: false)
                        .createRecurringExpense(recurring);
                  } else {
                    await Provider.of<ExpenseProvider>(context, listen: false)
                        .updateRecurringExpense(recurring);
                  }

                  if (context.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(existingExpense == null
                            ? 'Recurring expense added'
                            : 'Recurring expense updated',),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(RecurringExpense expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recurring Expense?'),
        content: Text('Are you sure you want to delete "${expense.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await Provider.of<ExpenseProvider>(context, listen: false)
                  .deleteRecurringExpense(expense.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Recurring expense deleted'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRecurringDetails(RecurringExpense expense) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(expense.title, style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            _detailRow('Amount', '₹${expense.amount.toStringAsFixed(2)}'),
            _detailRow('Frequency', expense.frequency.displayName),
            _detailRow('Category', expense.category),
            if (expense.description.isNotEmpty)
              _detailRow('Description', expense.description),
            _detailRow('Status', expense.isActive ? 'Active' : 'Paused'),
            if (expense.nextDue != null)
              _detailRow('Next Due',
                  '${expense.nextDue!.day}/${expense.nextDue!.month}/${expense.nextDue!.year}',),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey[600], fontWeight: FontWeight.w500,),),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
