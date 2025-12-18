import 'package:flutter/material.dart';
import '../models/vehicle_comparison.dart';

class UsagePatternCard extends StatelessWidget {
  const UsagePatternCard({
    super.key,
    required this.pattern,
  });
  final UsagePattern pattern;

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
                Icon(Icons.insights, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Usage Pattern - ${pattern.vehicle.name}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Average metrics
            _buildMetricRow(
              icon: Icons.route,
              label: 'Avg Monthly Distance',
              value: '${pattern.avgMonthlyDistance.toStringAsFixed(0)} km',
              color: Colors.blue,
            ),
            const SizedBox(height: 8),

            _buildMetricRow(
              icon: Icons.account_balance_wallet,
              label: 'Avg Monthly Cost',
              value: '₹${pattern.avgMonthlyCost.toStringAsFixed(0)}',
              color: Colors.orange,
            ),
            const SizedBox(height: 16),

            // Peak and lowest usage months
            Row(
              children: [
                Expanded(
                  child: _buildMonthCard(
                    icon: Icons.trending_up,
                    label: 'Peak Month',
                    month: pattern.getPeakMonthName(),
                    distance:
                        pattern.monthlyDistance[pattern.peakUsageMonth] ?? 0,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMonthCard(
                    icon: Icons.trending_down,
                    label: 'Lowest Month',
                    month: pattern.getLowestMonthName(),
                    distance:
                        pattern.monthlyDistance[pattern.lowestUsageMonth] ?? 0,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow({
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
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 15),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthCard({
    required IconData icon,
    required String label,
    required String month,
    required double distance,
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            month,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${distance.toStringAsFixed(0)} km',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
