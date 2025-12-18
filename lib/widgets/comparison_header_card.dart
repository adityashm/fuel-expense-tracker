import 'package:flutter/material.dart';
import '../models/vehicle_comparison.dart';

class ComparisonHeaderCard extends StatelessWidget {
  const ComparisonHeaderCard({
    super.key,
    required this.comparison,
  });
  final FamilyComparison comparison;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.family_restroom,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  'Family Fleet Summary',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Total vehicles
            _buildSummaryRow(
              icon: Icons.directions_car,
              label: 'Total Vehicles',
              value: '${comparison.vehicles.length}',
              color: Colors.blue,
            ),
            const Divider(height: 24),

            // Total distance
            _buildSummaryRow(
              icon: Icons.route,
              label: 'Total Distance',
              value: '${comparison.totalFamilyDistance.toStringAsFixed(0)} km',
              color: Colors.orange,
            ),
            const Divider(height: 24),

            // Total cost
            _buildSummaryRow(
              icon: Icons.account_balance_wallet,
              label: 'Total Cost',
              value: '₹${comparison.totalFamilyCost.toStringAsFixed(0)}',
              color: Colors.red,
            ),
            const Divider(height: 24),

            // Average cost per km
            _buildSummaryRow(
              icon: Icons.trending_down,
              label: 'Avg Cost/km',
              value: '₹${comparison.avgFamilyCostPerKm.toStringAsFixed(2)}',
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
