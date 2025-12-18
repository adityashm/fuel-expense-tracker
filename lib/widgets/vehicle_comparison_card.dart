import 'package:flutter/material.dart';
import '../models/vehicle_comparison.dart';

class VehicleComparisonCard extends StatelessWidget {
  const VehicleComparisonCard({
    super.key,
    required this.comparison,
    this.isWinner = false,
  });
  final VehicleComparison comparison;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isWinner ? 6 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isWinner
            ? BorderSide(color: Colors.green[600]!, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle header
            Row(
              children: [
                Icon(
                  comparison.isElectric
                      ? Icons.electric_car
                      : Icons.directions_car,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comparison.vehicle.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        comparison.vehicle.registrationNumber,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isWinner)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Cost per km - MAIN METRIC
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isWinner ? Colors.green[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'Cost per km',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${comparison.costPerKm.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isWinner ? Colors.green[700] : Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Distance & Trips
            _buildMetricRow(
              icon: Icons.route,
              label: 'Distance',
              value: '${comparison.totalDistance.toStringAsFixed(0)} km',
            ),
            const SizedBox(height: 8),
            _buildMetricRow(
              icon: Icons.trip_origin,
              label: 'Trips',
              value: '${comparison.totalTrips}',
            ),
            const SizedBox(height: 8),

            // Monthly cost
            _buildMetricRow(
              icon: Icons.calendar_today,
              label: 'Monthly Cost',
              value: '₹${comparison.costPerMonth.toStringAsFixed(0)}',
            ),
            const SizedBox(height: 8),

            // Annual projection
            _buildMetricRow(
              icon: Icons.trending_up,
              label: 'Annual (est.)',
              value: '₹${comparison.projectedAnnualCost.toStringAsFixed(0)}',
            ),
            const SizedBox(height: 16),

            // Efficiency
            if (comparison.isElectric && comparison.chargingEfficiency != null)
              _buildEfficiencyChip(
                icon: Icons.bolt,
                label:
                    '${comparison.chargingEfficiency!.toStringAsFixed(1)} km/kWh',
                color: Colors.green,
              )
            else if (!comparison.isElectric &&
                comparison.fuelEfficiency != null)
              _buildEfficiencyChip(
                icon: Icons.local_gas_station,
                label: '${comparison.fuelEfficiency!.toStringAsFixed(1)} km/L',
                color: Colors.orange,
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
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEfficiencyChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
