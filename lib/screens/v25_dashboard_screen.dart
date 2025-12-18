import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/fuel_expense.dart';
import '../models/general_expense.dart';
import '../providers/expense_provider.dart';
import '../services/smart_suggestions_service.dart';
import '../utils/v25_design_system.dart';
import 'add_expense_v2_screen.dart';
import 'receipt_scanner_screen.dart';
import 'voice_entry_screen.dart';

/// V2.5 Modern Dashboard with new design system
class V25DashboardScreen extends StatefulWidget {
  const V25DashboardScreen({super.key});

  @override
  State<V25DashboardScreen> createState() => _V25DashboardScreenState();
}

class _V25DashboardScreenState extends State<V25DashboardScreen> {
  final SmartSuggestionsService _suggestions = SmartSuggestionsService.instance;
  QuickFillSuggestion? _quickSuggestion;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _isLoading = true);
    final suggestion = await _suggestions.getQuickFillSuggestion();
    if (mounted) {
      setState(() {
        _quickSuggestion = suggestion;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? V25DesignSystem.backgroundDark
          : V25DesignSystem.backgroundLight,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(isDark),
          SliverPadding(
            padding: const EdgeInsets.all(V25DesignSystem.spacing16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildQuickActions(),
                const SizedBox(height: V25DesignSystem.spacing24),
                _buildSpendingSummary(isDark),
                const SizedBox(height: V25DesignSystem.spacing24),
                _buildSmartSuggestions(isDark),
                const SizedBox(height: V25DesignSystem.spacing24),
                _buildCategoryBreakdown(isDark),
                const SizedBox(height: V25DesignSystem.spacing24),
                _buildRecentExpenses(isDark),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: V25DesignSystem.primaryBlue,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Dashboard',
          style: V25DesignSystem.getTextTheme(isDark: true).headlineMedium,
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: V25DesignSystem.primaryGradient,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            showSearch(
              context: context,
              delegate: ExpenseSearchDelegate(),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Notifications'),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(Icons.info_outline, color: Colors.blue),
                      title: Text('Welcome!'),
                      subtitle: Text('Your expense tracker is ready'),
                    ),
                    ListTile(
                      leading:
                          Icon(Icons.tips_and_updates, color: Colors.orange),
                      title: Text('Tip'),
                      subtitle: Text(
                          'Mark full tank fill-ups for better fuel efficiency tracking',),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: V25DesignSystem.spacing8),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Container(
      decoration: V25DesignSystem.cardDecoration(),
      padding: const EdgeInsets.all(V25DesignSystem.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: V25DesignSystem.getTextTheme().titleMedium,
          ),
          const SizedBox(height: V25DesignSystem.spacing16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickActionButton(
                icon: Icons.add,
                label: 'Add',
                color: V25DesignSystem.primaryBlue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddExpenseV2Screen()),
                ),
              ),
              _buildQuickActionButton(
                icon: Icons.mic,
                label: 'Voice',
                color: V25DesignSystem.success,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VoiceEntryScreen()),
                ),
              ),
              _buildQuickActionButton(
                icon: Icons.camera_alt,
                label: 'Scan',
                color: V25DesignSystem.warning,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ReceiptScannerScreen(),),
                ),
              ),
              _buildQuickActionButton(
                icon: Icons.bar_chart,
                label: 'Reports',
                color: V25DesignSystem.info,
                onTap: () {
                  // TODO: Navigate to reports
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(V25DesignSystem.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: V25DesignSystem.spacing12,
          horizontal: V25DesignSystem.spacing16,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(V25DesignSystem.spacing12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(V25DesignSystem.radiusMedium),
              ),
              child: Icon(icon, color: color, size: V25DesignSystem.iconLarge),
            ),
            const SizedBox(height: V25DesignSystem.spacing8),
            Text(
              label,
              style: V25DesignSystem.getTextTheme().labelMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpendingSummary(bool isDark) {
    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, child) {
        return Container(
          decoration: V25DesignSystem.cardDecoration(isDark: isDark),
          padding: const EdgeInsets.all(V25DesignSystem.spacing20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'This Month',
                    style:
                        V25DesignSystem.getTextTheme(isDark: isDark).titleLarge,
                  ),
                  TextButton.icon(
                    onPressed: () {
                      // TODO: Show full breakdown
                    },
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Details'),
                    style: V25DesignSystem.textButtonStyle,
                  ),
                ],
              ),
              const SizedBox(height: V25DesignSystem.spacing24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem(
                    label: 'Total Spent',
                    value: '₹12,450',
                    icon: Icons.account_balance_wallet,
                    color: V25DesignSystem.primaryBlue,
                    isDark: isDark,
                  ),
                  _buildSummaryItem(
                    label: 'Budget Left',
                    value: '₹7,550',
                    icon: Icons.trending_up,
                    color: V25DesignSystem.success,
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(V25DesignSystem.spacing12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(V25DesignSystem.radiusMedium),
          ),
          child: Icon(icon, color: color, size: V25DesignSystem.iconMedium),
        ),
        const SizedBox(height: V25DesignSystem.spacing8),
        Text(
          value,
          style: V25DesignSystem.getTextTheme(isDark: isDark).headlineSmall,
        ),
        Text(
          label,
          style: V25DesignSystem.getTextTheme(isDark: isDark).bodySmall,
        ),
      ],
    );
  }

  Widget _buildSmartSuggestions(bool isDark) {
    if (_isLoading || _quickSuggestion == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: V25DesignSystem.cardDecoration(isDark: isDark),
      padding: const EdgeInsets.all(V25DesignSystem.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                color: V25DesignSystem.warning,
                size: V25DesignSystem.iconMedium,
              ),
              const SizedBox(width: V25DesignSystem.spacing8),
              Text(
                'Smart Suggestions',
                style: V25DesignSystem.getTextTheme(isDark: isDark).titleMedium,
              ),
            ],
          ),
          const SizedBox(height: V25DesignSystem.spacing12),
          if (_quickSuggestion!.lastExpense != null)
            _buildSuggestionChip(
              'Repeat: ${_quickSuggestion!.lastExpense!.displayText}',
              Icons.repeat,
              isDark,
            ),
          const SizedBox(height: V25DesignSystem.spacing8),
          if (_quickSuggestion!.recentMerchants.isNotEmpty)
            Wrap(
              spacing: V25DesignSystem.spacing8,
              runSpacing: V25DesignSystem.spacing8,
              children: _quickSuggestion!.recentMerchants
                  .take(3)
                  .map(
                    (merchant) => Chip(
                      label: Text(merchant.name),
                      avatar: const Icon(Icons.store, size: 16),
                      backgroundColor: V25DesignSystem.neutral100,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: V25DesignSystem.spacing12,
        vertical: V25DesignSystem.spacing8,
      ),
      decoration: BoxDecoration(
        color: V25DesignSystem.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(V25DesignSystem.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: V25DesignSystem.info),
          const SizedBox(width: V25DesignSystem.spacing8),
          Expanded(
            child: Text(
              text,
              style: V25DesignSystem.getTextTheme(isDark: isDark).bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(bool isDark) {
    return Container(
      decoration: V25DesignSystem.cardDecoration(isDark: isDark),
      padding: const EdgeInsets.all(V25DesignSystem.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending by Category',
            style: V25DesignSystem.getTextTheme(isDark: isDark).titleMedium,
          ),
          const SizedBox(height: V25DesignSystem.spacing16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: _buildPieChartSections(),
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    return [
      PieChartSectionData(
        value: 35,
        title: '35%',
        color: V25DesignSystem.getCategoryColor('Fuel'),
        radius: 50,
      ),
      PieChartSectionData(
        value: 25,
        title: '25%',
        color: V25DesignSystem.getCategoryColor('Food'),
        radius: 50,
      ),
      PieChartSectionData(
        value: 20,
        title: '20%',
        color: V25DesignSystem.getCategoryColor('Groceries'),
        radius: 50,
      ),
      PieChartSectionData(
        value: 20,
        title: '20%',
        color: V25DesignSystem.getCategoryColor('Other'),
        radius: 50,
      ),
    ];
  }

  Widget _buildRecentExpenses(bool isDark) {
    return Container(
      decoration: V25DesignSystem.cardDecoration(isDark: isDark),
      padding: const EdgeInsets.all(V25DesignSystem.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Expenses',
                style: V25DesignSystem.getTextTheme(isDark: isDark).titleMedium,
              ),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to all expenses
                },
                style: V25DesignSystem.textButtonStyle,
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: V25DesignSystem.spacing12),
          ...List.generate(3, (index) => _buildExpenseItem(isDark)),
        ],
      ),
    );
  }

  Widget _buildExpenseItem(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: V25DesignSystem.spacing12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(V25DesignSystem.spacing8),
            decoration: BoxDecoration(
              color: V25DesignSystem.getCategoryColor('Fuel')
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(V25DesignSystem.radiusSmall),
            ),
            child: Icon(
              Icons.local_gas_station,
              color: V25DesignSystem.getCategoryColor('Fuel'),
              size: V25DesignSystem.iconMedium,
            ),
          ),
          const SizedBox(width: V25DesignSystem.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fuel',
                  style: V25DesignSystem.getTextTheme(isDark: isDark).bodyLarge,
                ),
                Text(
                  'Shell Petrol Pump',
                  style: V25DesignSystem.getTextTheme(isDark: isDark).bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '₹2,000',
            style: V25DesignSystem.getTextTheme(isDark: isDark).titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddExpenseV2Screen()),
      ),
      icon: const Icon(Icons.add),
      label: const Text('Add Expense'),
      backgroundColor: V25DesignSystem.primaryBlue,
    );
  }
}

// Search delegate for expenses
class ExpenseSearchDelegate extends SearchDelegate {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        final allExpenses = <dynamic>[
          ...provider.fuelExpenses,
          ...provider.generalExpenses,
          ...provider.householdExpenses,
        ];

        final filteredExpenses = query.isEmpty
            ? allExpenses
            : allExpenses.where((expense) {
                final searchLower = query.toLowerCase();
                if (expense is FuelExpense) {
                  return (expense.location
                              ?.toLowerCase()
                              .contains(searchLower) ??
                          false) ||
                      (expense.pumpName?.toLowerCase().contains(searchLower) ??
                          false) ||
                      expense.amountPaid.toString().contains(searchLower);
                } else if (expense is GeneralExpense) {
                  return expense.description
                          .toLowerCase()
                          .contains(searchLower) ||
                      expense.category.name
                          .toLowerCase()
                          .contains(searchLower) ||
                      expense.amount.toString().contains(searchLower);
                }
                return false;
              }).toList();

        if (filteredExpenses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  query.isEmpty
                      ? 'Start typing to search'
                      : 'No expenses found',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredExpenses.length,
          itemBuilder: (context, index) {
            final expense = filteredExpenses[index];

            if (expense is FuelExpense) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  child:
                      const Icon(Icons.local_gas_station, color: Colors.blue),
                ),
                title: Text(expense.location ?? 'Fuel'),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(expense.date)),
                trailing: Text(
                  '\$${expense.amountPaid.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  close(context, expense);
                },
              );
            } else {
              final generalExpense = expense as GeneralExpense;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withValues(alpha: 0.1),
                  child: const Icon(Icons.category, color: Colors.green),
                ),
                title: Text(generalExpense.description),
                subtitle: Text(
                    DateFormat('MMM dd, yyyy').format(generalExpense.date),),
                trailing: Text(
                  '\$${generalExpense.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  close(context, expense);
                },
              );
            }
          },
        );
      },
    );
  }
}
