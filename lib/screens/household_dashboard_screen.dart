import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/general_expense.dart';
import '../providers/expense_provider.dart';
import '../utils/app_localizations.dart';
import 'add_household_expense_screen.dart';
import 'household_history_screen.dart';
import 'household_settlement_screen.dart';
import 'payment_tracking_screen.dart';
import 'recurring_expenses_screen.dart';
import 'split_bill_screen.dart';

class HouseholdDashboardScreen extends StatefulWidget {
  const HouseholdDashboardScreen({super.key});

  @override
  State<HouseholdDashboardScreen> createState() =>
      _HouseholdDashboardScreenState();
}

class _HouseholdDashboardScreenState extends State<HouseholdDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    final expenseProvider =
        Provider.of<ExpenseProvider>(context, listen: false);
    await expenseProvider.loadHouseholdExpenses();
    await expenseProvider.loadFamilyMembers();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('household_expenses')),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HouseholdHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Settlements',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HouseholdSettlementScreen(),
                ),
              );
            },
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'split',
                child: Row(
                  children: [
                    Icon(Icons.call_split, size: 20),
                    SizedBox(width: 12),
                    Text('Split Bill'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'recurring',
                child: Row(
                  children: [
                    Icon(Icons.repeat, size: 20),
                    SizedBox(width: 12),
                    Text('Recurring Expenses'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'payments',
                child: Row(
                  children: [
                    Icon(Icons.payment, size: 20),
                    SizedBox(width: 12),
                    Text('Payment History'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'split') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SplitBillScreen(),),
                );
              } else if (value == 'recurring') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const RecurringExpensesScreen(),),
                );
              } else if (value == 'payments') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PaymentTrackingScreen(),),
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPeriodSelector(localizations),
              const SizedBox(height: 20),
              _buildSummaryCard(theme, localizations),
              const SizedBox(height: 20),
              _buildQuickActionsRow(),
              const SizedBox(height: 20),
              _buildMemberContributions(theme, localizations),
              const SizedBox(height: 20),
              _buildCategoryBreakdown(theme, localizations),
              const SizedBox(height: 20),
              _buildRecentExpenses(theme, localizations),
              const SizedBox(height: 80), // Bottom padding for FAB
            ],
          ),
        ),
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

  Widget _buildPeriodSelector(AppLocalizations localizations) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildPeriodChip('This Week', localizations),
            _buildPeriodChip('This Month', localizations),
            _buildPeriodChip('This Year', localizations),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String label, AppLocalizations localizations) {
    final isSelected = label == 'This Month'; // Default to month
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          // Update period logic here
        });
      },
      selectedColor:
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, AppLocalizations localizations) {
    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, child) {
        final expenses = expenseProvider.householdExpenses;
        final totalAmount = expenses.fold<double>(
          0,
          (sum, expense) => sum + expense.amount,
        );
        final thisMonthExpenses = expenses.where((e) {
          return e.date.year == DateTime.now().year &&
              e.date.month == DateTime.now().month;
        }).toList();
        final thisMonthTotal = thisMonthExpenses.fold<double>(
          0,
          (sum, expense) => sum + expense.amount,
        );
        // Fair share calculation for current month
        final members = expenseProvider.familyMembers;
        final fairShare =
            members.isEmpty ? 0.0 : thisMonthTotal / members.length;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'This Month',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${thisMonthExpenses.length} expenses',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  localizations.formatCurrency(thisMonthTotal),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Total: ${localizations.formatCurrency(totalAmount)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.people_outline,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Fair Share: ${localizations.formatCurrency(fairShare)} / person',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildQuickAction(
          icon: Icons.add,
          label: 'Add',
          color: Theme.of(context).colorScheme.primary,
          onTap: () async {
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
        ),
        _buildQuickAction(
          icon: Icons.call_split,
          label: 'Split',
          color: Colors.orange,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SplitBillScreen()),
            );
          },
        ),
        _buildQuickAction(
          icon: Icons.repeat,
          label: 'Recurring',
          color: Colors.purple,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const RecurringExpensesScreen(),),
            );
          },
        ),
        _buildQuickAction(
          icon: Icons.payment,
          label: 'Pay',
          color: Colors.green,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaymentTrackingScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 72,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberContributions(
    ThemeData theme,
    AppLocalizations localizations,
  ) {
    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, child) {
        final members = expenseProvider.familyMembers;
        final expenses = expenseProvider.householdExpenses;

        if (members.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.people_outline,
                      size: 64, color: Colors.grey,),
                  const SizedBox(height: 16),
                  const Text(
                    'No family members yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to add family member screen
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Family Member'),
                  ),
                ],
              ),
            ),
          );
        }

        // Calculate contributions per member
        final Map<int, double> memberContributions = {};
        for (final member in members) {
          memberContributions[member.id!] = expenses
              .where((e) => e.familyMemberId == member.id)
              .fold<double>(0, (sum, expense) => sum + expense.amount);
        }

        final totalContributions = memberContributions.values.fold<double>(
          0,
          (sum, amount) => sum + amount,
        );
        final fairShare =
            members.isEmpty ? 0.0 : totalContributions / members.length;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Member Contributions',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const HouseholdSettlementScreen(),
                          ),
                        );
                      },
                      child: const Text('Settle Up'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...members.map((member) {
                  final contribution = memberContributions[member.id] ?? 0.0;
                  final percentage = totalContributions > 0
                      ? (contribution / totalContributions) * 100
                      : 0.0;
                  final balance = contribution - fairShare;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Color(member.colorHex).withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [
                              Color(member.colorHex).withValues(alpha: 0.03),
                              Colors.transparent,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Color(member.colorHex),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(member.colorHex)
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        member.avatarIcon,
                                        style: const TextStyle(
                                          fontSize: 28,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member.name,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${percentage.toStringAsFixed(1)}% of total',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
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
                                            .formatCurrency(contribution),
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2,),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          color: balance > 0
                                              ? Colors.green
                                                  .withValues(alpha: 0.1)
                                              : balance < 0
                                                  ? Colors.red
                                                      .withValues(alpha: 0.1)
                                                  : Colors.grey
                                                      .withValues(alpha: 0.1),
                                        ),
                                        child: Text(
                                          balance > 0
                                              ? 'Owed ${localizations.formatCurrency(balance)}'
                                              : balance < 0
                                                  ? 'Owes ${localizations.formatCurrency(-balance)}'
                                                  : 'Settled',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            fontSize: 11,
                                            color: balance > 0
                                                ? Colors.green[700]
                                                : balance < 0
                                                    ? Colors.red[700]
                                                    : Colors.grey[700],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percentage / 100,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(member.colorHex),
                                  ),
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Fair Share per Person:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      localizations.formatCurrency(fairShare),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryBreakdown(
    ThemeData theme,
    AppLocalizations localizations,
  ) {
    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, child) {
        final expenses = expenseProvider.householdExpenses;
        final Map<ExpenseCategory, double> categoryTotals = {};

        for (final expense in expenses) {
          categoryTotals[expense.category] =
              (categoryTotals[expense.category] ?? 0) + expense.amount;
        }

        final sortedCategories = categoryTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final totalAmount = categoryTotals.values.fold<double>(
          0,
          (sum, amount) => sum + amount,
        );

        if (sortedCategories.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expense Breakdown',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...sortedCategories.take(5).map((entry) {
                  final percentage =
                      totalAmount > 0 ? (entry.value / totalAmount) * 100 : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getCategoryIcon(entry.key),
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  localizations.translate(entry.key.name),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${localizations.formatCurrency(entry.value)} (${percentage.toStringAsFixed(0)}%)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.grey[200],
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentExpenses(
    ThemeData theme,
    AppLocalizations localizations,
  ) {
    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, child) {
        final expenses = expenseProvider.householdExpenses;
        final recentExpenses = expenses.take(5).toList();

        if (recentExpenses.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Expenses',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const HouseholdHistoryScreen(),
                          ),
                        );
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...recentExpenses.map((expense) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Icon(_getCategoryIcon(expense.category)),
                    ),
                    title: Text(
                      expense.description,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${localizations.translate(expense.category.name)} • ${expense.familyMemberName ?? 'Unknown'}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          localizations.formatCurrency(expense.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _getTimeAgo(expense.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
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

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
