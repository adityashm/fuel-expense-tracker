import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/expense_provider.dart';
import '../widgets/animated_fade_in.dart';
import '../widgets/donut_chart.dart';
import 'advanced_analytics_screen.dart';
import 'analytics_screen.dart';
import 'budget_settings_screen.dart';

/// Composite Analytics screen with 4 tabs (Overview, Trends, Categories, Budgets)
class AnalyticsTabShellScreen extends StatefulWidget {
  const AnalyticsTabShellScreen({super.key});

  @override
  State<AnalyticsTabShellScreen> createState() =>
      _AnalyticsTabShellScreenState();
}

class _AnalyticsTabShellScreenState extends State<AnalyticsTabShellScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurface.withValues(alpha: .6),
          indicatorColor: scheme.primary,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.insights)),
            Tab(text: 'Trends', icon: Icon(Icons.show_chart)),
            Tab(text: 'Categories', icon: Icon(Icons.category)),
            Tab(text: 'Budgets', icon: Icon(Icons.account_balance_wallet)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AnimatedFadeIn(child: AnalyticsScreen()),
          AnimatedFadeIn(child: AdvancedAnalyticsScreen()),
          AnimatedFadeIn(child: CategoriesAnalyticsTab()),
          AnimatedFadeIn(child: BudgetSettingsScreen()),
        ],
      ),
    );
  }
}

class CategoriesAnalyticsTab extends StatefulWidget {
  const CategoriesAnalyticsTab({super.key});

  @override
  State<CategoriesAnalyticsTab> createState() => _CategoriesAnalyticsTabState();
}

class _CategoriesAnalyticsTabState extends State<CategoriesAnalyticsTab> {
  bool _loading = true;
  List<DonutSlice> _slices = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    await Future.wait([
      provider.loadFuelExpenses(refresh: true),
      provider.loadGeneralExpenses(refresh: true),
      provider.loadHouseholdExpenses(refresh: true),
    ]);
    if (!mounted) return;

    final fuelTotal =
        provider.fuelExpenses.fold<double>(0, (sum, e) => sum + e.amountPaid);
    final generalTotal = provider.generalExpenses
        .where((e) => !e.isHouseholdExpense)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final householdExpenses = provider.householdExpenses;

    final categoryTotals = <String, double>{};
    for (final expense in householdExpenses) {
      final categoryName = expense.category.name;
      categoryTotals[categoryName] =
          (categoryTotals[categoryName] ?? 0) + expense.amount;
    }

    final slices = <DonutSlice>[
      if (fuelTotal > 0)
        DonutSlice(label: 'Fuel', value: fuelTotal, color: Colors.orange),
      if (generalTotal > 0)
        DonutSlice(
            label: 'Vehicle Expenses',
            value: generalTotal,
            color: const Color(0xFF2196F3),),
    ];

    const colors = <Color>[
      Colors.green,
      Colors.teal,
      Colors.purple,
      Colors.blue,
      Colors.redAccent,
      Colors.amber,
    ];
    int colorIndex = 0;
    for (final entry in categoryTotals.entries) {
      slices.add(
        DonutSlice(
          label: entry.key,
          value: entry.value,
          color: colors[colorIndex % colors.length],
        ),
      );
      colorIndex++;
    }

    setState(() {
      _slices = slices.isEmpty
          ? [DonutSlice(label: 'No data', value: 1, color: Colors.grey)]
          : slices;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Categories Breakdown',
            style: Theme.of(context).textTheme.titleLarge,),
        const SizedBox(height: 12),
        if (_loading)
          Container(
            height: 260,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
            ),
          )
        else
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  DonutChart(slices: _slices, centerLabel: 'Total'),
                  const SizedBox(height: 24),
                  ..._slices.map(_buildSliceRow),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSliceRow(DonutSlice slice) {
    final total = _slices.fold<double>(0, (sum, s) => sum + s.value);
    final pct = (slice.value / total) * 100;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
                color: slice.color, borderRadius: BorderRadius.circular(4),),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(slice.label,
                style: const TextStyle(fontWeight: FontWeight.w600),),
          ),
          Text('₹${slice.value.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w500),),
          const SizedBox(width: 12),
          Text('${pct.toStringAsFixed(1)}%',
              style: TextStyle(color: Colors.grey[600]),),
        ],
      ),
    );
  }
}
