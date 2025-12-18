import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/general_expense.dart';
import '../providers/expense_provider.dart';
import '../providers/user_provider.dart';
import '../utils/app_design_system.dart';
import '../utils/app_localizations.dart';
import 'advanced_analytics_screen.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              'Analytics',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          // Advanced Analytics Button - Modern Card
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdvancedAnalyticsScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.trending_up_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Advanced Analytics',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Detailed charts and insights with filters',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildTotalExpensesCard(context, localizations),
          const SizedBox(height: 16),
          _buildExpenseCategoryChart(context, localizations),
          const SizedBox(height: 16),
          _buildMonthlyExpenseChart(context, localizations),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTotalExpensesCard(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    final theme = Theme.of(context);

    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, child) {
        final fuelTotal = expenseProvider.getTotalFuelExpenses();
        final generalTotal = expenseProvider.getTotalGeneralExpenses();
        final householdTotal = expenseProvider.getTotalHouseholdExpenses();
        final vehicleGeneralTotal = math.max(0, generalTotal - householdTotal);
        final total = fuelTotal + vehicleGeneralTotal + householdTotal;

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      localizations.translate('total_expenses'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  localizations.formatCurrency(total),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                  ),
                  child: Column(
                    children: [
                      _buildExpenseItem(
                        context,
                        localizations.translate('fuel_expenses'),
                        fuelTotal,
                        AppColors.fuelExpense,
                        localizations,
                      ),
                      const SizedBox(height: 12),
                      _buildExpenseItem(
                        context,
                        localizations.translate('general_expenses'),
                        vehicleGeneralTotal,
                        AppColors.generalExpense,
                        localizations,
                      ),
                      const SizedBox(height: 12),
                      _buildExpenseItem(
                        context,
                        localizations.translate('household_expenses'),
                        householdTotal,
                        AppColors.householdExpense,
                        localizations,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpenseItem(
    BuildContext context,
    String label,
    num amount,
    Color color,
    AppLocalizations localizations,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getExpenseIcon(label),
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          localizations.formatCurrency(amount.toDouble()),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  IconData _getExpenseIcon(String label) {
    if (label.toLowerCase().contains('fuel')) {
      return Icons.local_gas_station_rounded;
    } else if (label.toLowerCase().contains('household')) {
      return Icons.home_rounded;
    } else {
      return Icons.build_rounded;
    }
  }

  Widget _buildExpenseCategoryChart(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, child) {
        final categoryExpenses = expenseProvider.getExpensesByCategory();

        if (categoryExpenses.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expenses by Category',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: categoryExpenses.entries.map((entry) {
                        final category = entry.key;
                        final amount = entry.value;
                        final percentage = (amount /
                                expenseProvider.getTotalGeneralExpenses()) *
                            100;

                        return PieChartSectionData(
                          value: amount,
                          title: '${percentage.toStringAsFixed(1)}%',
                          color: _getCategoryColor(category),
                          radius: 80,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: categoryExpenses.entries.map((entry) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getCategoryColor(entry.key),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(localizations.translate(entry.key.name)),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthlyExpenseChart(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return Consumer2<ExpenseProvider, UserProvider>(
      builder: (context, expenseProvider, userProvider, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.translate('monthly_expenses'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getMonthlyData(userProvider, expenseProvider),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('No data available'));
                      }

                      final data = snapshot.data ?? <Map<String, dynamic>>[];
                      return BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: data
                                  .map((e) => e['total'] as double)
                                  .reduce((a, b) => a > b ? a : b) *
                              1.2,
                          barGroups: data.asMap().entries.map((entry) {
                            return BarChartGroupData(
                              x: entry.key,
                              barRods: [
                                BarChartRodData(
                                  toY: entry.value['total'] as double,
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 16,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(),
                            topTitles: const AxisTitles(),
                            rightTitles: const AxisTitles(),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() < data.length) {
                                    return Text(
                                      data[value.toInt()]['month'] as String,
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getMonthlyData(
    UserProvider userProvider,
    ExpenseProvider expenseProvider,
  ) async {
    final now = DateTime.now();
    final data = <Map<String, dynamic>>[];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      final summary = await expenseProvider.getMonthlyExpenseSummary(
        month,
      );

      data.add({
        'month': '${month.month}/${month.year.toString().substring(2)}',
        'total': summary['total'] ?? 0.0,
      });
    }

    return data;
  }

  Color _getCategoryColor(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.maintenance:
        return Colors.orange;
      case ExpenseCategory.insurance:
        return Colors.blue;
      case ExpenseCategory.parking:
        return Colors.purple;
      case ExpenseCategory.tolls:
        return Colors.teal;
      case ExpenseCategory.servicing:
        return Colors.red;
      case ExpenseCategory.groceries:
        return Colors.green;
      case ExpenseCategory.utilities:
        return Colors.cyan;
      case ExpenseCategory.healthcare:
        return Colors.pink;
      case ExpenseCategory.education:
        return Colors.indigo;
      case ExpenseCategory.entertainment:
        return Colors.amber;
      case ExpenseCategory.shopping:
        return Colors.deepPurple;
      case ExpenseCategory.food:
        return Colors.lime;
      case ExpenseCategory.transport:
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}
