import 'package:flutter/material.dart';
import '../models/vehicle_comparison.dart';

class RecommendationsCard extends StatelessWidget {
  const RecommendationsCard({
    super.key,
    required this.recommendations,
  });
  final List<VehicleRecommendation> recommendations;

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
                Icon(Icons.lightbulb, color: Colors.amber[700]),
                const SizedBox(width: 12),
                Text(
                  'Recommendations',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...recommendations
                .map((rec) => _buildRecommendationItem(rec, context)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationItem(
    VehicleRecommendation rec,
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _getTypeColor(rec.type).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getTypeColor(rec.type).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getTypeIcon(rec.type),
                  color: _getTypeColor(rec.type),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rec.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Priority indicator
                ...List.generate(rec.priority, (index) {
                  return Icon(
                    Icons.star,
                    color: Colors.amber[700],
                    size: 14,
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              rec.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            if (rec.potentialSavings > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.savings, color: Colors.green[700], size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Save ₹${rec.potentialSavings.toStringAsFixed(0)}/month',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(RecommendationType type) {
    switch (type) {
      case RecommendationType.switchVehicle:
        return Colors.blue;
      case RecommendationType.reduceUsage:
        return Colors.orange;
      case RecommendationType.maintenance:
        return Colors.red;
      case RecommendationType.efficiency:
        return Colors.purple;
      case RecommendationType.general:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(RecommendationType type) {
    switch (type) {
      case RecommendationType.switchVehicle:
        return Icons.swap_horiz;
      case RecommendationType.reduceUsage:
        return Icons.trending_down;
      case RecommendationType.maintenance:
        return Icons.build;
      case RecommendationType.efficiency:
        return Icons.speed;
      case RecommendationType.general:
        return Icons.info_outline;
    }
  }
}
