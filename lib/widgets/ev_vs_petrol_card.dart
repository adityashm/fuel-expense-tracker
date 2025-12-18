import 'package:flutter/material.dart';
import '../models/vehicle_comparison.dart';

class EVvsPetrolCard extends StatelessWidget {
  const EVvsPetrolCard({
    super.key,
    required this.comparison,
  });
  final EVvsPetrolComparison comparison;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[50]!, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.bolt, color: Colors.green[700], size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EV vs Petrol Savings',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          comparison.getComparisonSummary(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Cost per km comparison
              Row(
                children: [
                  Expanded(
                    child: _buildCostCard(
                      icon: Icons.electric_car,
                      label: comparison.electricVehicle.vehicle.name,
                      cost: comparison.electricCostPerKm,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCostCard(
                      icon: Icons.directions_car,
                      label: comparison.petrolVehicle.vehicle.name,
                      cost: comparison.petrolCostPerKm,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Savings breakdown
              _buildSavingsRow(
                label: 'Savings per km',
                value: '₹${comparison.savingsPerKm.toStringAsFixed(2)}',
                percentage: comparison.savingsPercentage,
              ),
              const Divider(height: 24),

              _buildSavingsRow(
                label: 'Monthly Savings',
                value: '₹${comparison.monthlySavings.toStringAsFixed(0)}',
              ),
              const Divider(height: 24),

              _buildSavingsRow(
                label: 'Annual Savings',
                value: '₹${comparison.annualSavings.toStringAsFixed(0)}',
              ),
              const Divider(height: 24),

              // Lifetime savings highlight
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.savings, color: Colors.green[700], size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '5-Year Savings',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '₹${comparison.lifetimeSavings.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.trending_up, color: Colors.green[700], size: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCostCard({
    required IconData icon,
    required String label,
    required double cost,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '₹${cost.toStringAsFixed(2)}/km',
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

  Widget _buildSavingsRow({
    required String label,
    required String value,
    double? percentage,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            if (percentage != null)
              Text(
                '${percentage.toStringAsFixed(0)}% cheaper',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green[600],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
