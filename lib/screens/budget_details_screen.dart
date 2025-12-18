import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import '../services/budget_service.dart';
import '../services/database_service.dart';

class BudgetDetailsScreen extends StatefulWidget {
  const BudgetDetailsScreen({super.key, required this.summary});
  final FamilyBudgetSummary summary;

  @override
  State<BudgetDetailsScreen> createState() => _BudgetDetailsScreenState();
}

class _BudgetDetailsScreenState extends State<BudgetDetailsScreen> {
  final budgetService = BudgetService.instance;
  final dbService = DatabaseService.instance;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = daysInMonth - now.day + 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Overview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showHistoryScreen(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Month Header
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMMM yyyy').format(now),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoChip(
                          'Days Left',
                          '$daysRemaining days',
                          Icons.event_available,
                          Colors.blue,
                        ),
                        _buildInfoChip(
                          'Budget Period',
                          '$daysInMonth days',
                          Icons.date_range,
                          Colors.blue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Family Summary
            const Text(
              'Family Total',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildBudgetRow(
                      'Total Budget',
                      widget.summary.totalBudget,
                      Icons.account_balance_wallet,
                      Colors.blue,
                    ),
                    const Divider(),
                    _buildBudgetRow(
                      'Total Spent',
                      widget.summary.totalSpent,
                      Icons.shopping_cart,
                      Colors.orange,
                    ),
                    const Divider(),
                    _buildBudgetRow(
                      widget.summary.totalRemaining >= 0
                          ? 'Remaining'
                          : 'Over Budget',
                      widget.summary.totalRemaining.abs(),
                      widget.summary.totalRemaining >= 0
                          ? Icons.savings
                          : Icons.warning,
                      widget.summary.totalRemaining >= 0
                          ? Colors.green
                          : Colors.red,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Individual Vehicles
            const Text(
              'Vehicle Budgets',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            ...widget.summary.vehicleBudgets
                .map((status) => _buildVehicleCard(status, daysRemaining)),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(BudgetStatus status, int daysRemaining) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    status.vehicleName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showBudgetEditDialog(
                    status.vehicleId,
                    status.vehicleName,
                    status.budgetAmount,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (status.percentageUsed / 100).clamp(0.0, 1.0),
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getBudgetColor(status.alertLevel),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Percentage & Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${status.percentageUsed.toStringAsFixed(0)}% used',
                  style: TextStyle(
                    color: _getBudgetColor(status.alertLevel),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '₹${status.spent.toStringAsFixed(0)} / ₹${status.budgetAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // Details Grid
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    'Remaining',
                    '₹${status.remaining.toStringAsFixed(0)}',
                    status.remaining >= 0
                        ? Icons.trending_up
                        : Icons.trending_down,
                    status.remaining >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    'Daily Budget',
                    '₹${status.dailyBudgetRemaining.toStringAsFixed(0)}',
                    Icons.today,
                    Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    'Projected',
                    '₹${status.projectedSpending.toStringAsFixed(0)}',
                    Icons.show_chart,
                    status.projectedSpending > status.budgetAmount
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    'Status',
                    status.isOnTrack ? 'On Track' : 'Over Pace',
                    status.isOnTrack ? Icons.check_circle : Icons.warning,
                    status.isOnTrack ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),

            // Spending Pace Indicator
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final pace = budgetService.getSpendingPace(status);
                final paceInfo = _getSpendingPaceInfo(pace);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: paceInfo.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: paceInfo.color),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        paceInfo.icon,
                        color: paceInfo.color,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        paceInfo.text,
                        style: TextStyle(
                          color: paceInfo.color,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetRow(
    String label,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  _SpendingPaceInfo _getSpendingPaceInfo(SpendingPace pace) {
    switch (pace) {
      case SpendingPace.underBudget:
        return const _SpendingPaceInfo(
          text: 'Great! Spending below pace',
          icon: Icons.emoji_emotions,
          color: Colors.green,
        );
      case SpendingPace.onTrack:
        return const _SpendingPaceInfo(
          text: 'On track with budget',
          icon: Icons.check_circle_outline,
          color: Colors.blue,
        );
      case SpendingPace.tooFast:
        return const _SpendingPaceInfo(
          text: 'Warning: Spending too fast',
          icon: Icons.speed,
          color: Colors.orange,
        );
    }
  }

  Color _getBudgetColor(BudgetAlertLevel level) {
    switch (level) {
      case BudgetAlertLevel.safe:
        return Colors.green;
      case BudgetAlertLevel.warning:
        return Colors.orange;
      case BudgetAlertLevel.critical:
      case BudgetAlertLevel.exceeded:
        return Colors.deepOrange;
      case BudgetAlertLevel.overBudget:
        return Colors.red;
    }
  }

  void _showBudgetEditDialog(
    int vehicleId,
    String vehicleName,
    double currentBudget,
  ) {
    final controller =
        TextEditingController(text: currentBudget.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Budget for $vehicleName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monthly Budget',
                prefixText: '₹',
                border: OutlineInputBorder(),
                helperText: 'Enter 0 to disable budget tracking',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final budget = double.tryParse(controller.text) ?? 0;
              await dbService.updateVehicleBudget(vehicleId, budget);
              if (context.mounted) {
                Navigator.pop(context);
                setState(() {}); // Refresh the screen
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Budget updated for $vehicleName')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showHistoryScreen(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Budget History'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              const Text('Historical budget performance:'),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    final monthsAgo = index + 1;
                    final month =
                        DateTime.now().subtract(Duration(days: 30 * monthsAgo));
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          child: Text('${month.month}'),
                        ),
                        title: Text(DateFormat('MMMM yyyy').format(month)),
                        subtitle: Text(monthsAgo == 1
                            ? 'Last month'
                            : '$monthsAgo months ago',),
                        trailing: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('View', style: TextStyle(color: Colors.blue)),
                            Icon(Icons.arrow_forward_ios, size: 12),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Opening ${DateFormat('MMMM yyyy').format(month)} budget...',),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _SpendingPaceInfo {
  const _SpendingPaceInfo({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;
}
