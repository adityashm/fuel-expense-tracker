import 'package:flutter/material.dart';

import '../models/budget.dart';
import '../screens/budget_details_screen.dart';
import '../services/budget_service.dart';

class FamilyBudgetWidget extends StatefulWidget {
  const FamilyBudgetWidget({super.key});

  @override
  State<FamilyBudgetWidget> createState() => _FamilyBudgetWidgetState();
}

class _FamilyBudgetWidgetState extends State<FamilyBudgetWidget> {
  late Future<FamilyBudgetSummary> _budgetFuture;

  @override
  void initState() {
    super.initState();
    _budgetFuture = BudgetService.instance.getFamilyBudgetSummary();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FamilyBudgetSummary>(
      future: _budgetFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.vehicleBudgets.isEmpty) {
          return const SizedBox.shrink();
        }

        final summary = snapshot.data!;

        return Card(
          elevation: 4,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BudgetDetailsScreen(summary: summary),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: _getFamilyBudgetColor(summary.percentageUsed),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Family Budget',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'All Vehicles',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${summary.totalSpent.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color:
                                  _getFamilyBudgetColor(summary.percentageUsed),
                            ),
                          ),
                          Text(
                            'of ₹${summary.totalBudget.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Overall Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (summary.percentageUsed / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getFamilyBudgetColor(summary.percentageUsed),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Percentage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${summary.percentageUsed.toStringAsFixed(0)}% used',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      if (summary.totalRemaining >= 0)
                        Text(
                          '₹${summary.totalRemaining.toStringAsFixed(0)} left',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        )
                      else
                        Text(
                          'Over by ₹${summary.overBudgetAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Individual Vehicle Budgets
                  ...summary.vehicleBudgets
                      .map((status) => _buildVehicleBudget(context, status)),

                  const SizedBox(height: 8),

                  // Summary Stats
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat(
                          'On Track',
                          summary.vehiclesOnTrack.toString(),
                          Icons.check_circle,
                          Colors.green,
                        ),
                        Container(
                          height: 30,
                          width: 1,
                          color: Colors.grey.shade300,
                        ),
                        _buildStat(
                          'Over Budget',
                          summary.vehiclesOverBudget.toString(),
                          Icons.warning,
                          Colors.red,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehicleBudget(BuildContext context, BudgetStatus status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  status.vehicleName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '₹${status.spent.toStringAsFixed(0)} / ₹${status.budgetAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  color: _getBudgetColor(status.alertLevel),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (status.percentageUsed / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getBudgetColor(status.alertLevel),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
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

  Color _getFamilyBudgetColor(double percentage) {
    if (percentage >= 100) return Colors.red;
    if (percentage >= 90) return Colors.deepOrange;
    if (percentage >= 75) return Colors.orange;
    if (percentage >= 50) return Colors.amber;
    return Colors.green;
  }
}
