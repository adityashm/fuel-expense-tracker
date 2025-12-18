import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/charging_expense.dart';
import '../models/vehicle.dart';
import '../providers/charging_expense_provider.dart';

class EVVsPetrolComparisonWidget extends StatefulWidget {
  const EVVsPetrolComparisonWidget({
    super.key,
    required this.vehicle,
    required this.startDate,
    required this.endDate,
  });
  final Vehicle vehicle;
  final DateTime startDate;
  final DateTime endDate;

  @override
  State<EVVsPetrolComparisonWidget> createState() =>
      _EVVsPetrolComparisonWidgetState();
}

class _EVVsPetrolComparisonWidgetState
    extends State<EVVsPetrolComparisonWidget> {
  late Future<EVVsPetrolComparison> _comparisonFuture;

  @override
  void initState() {
    super.initState();
    _comparisonFuture =
        Provider.of<ChargingExpenseProvider>(context, listen: false)
            .getEVVsPetrolComparison(
      widget.vehicle.id!,
      widget.startDate,
      widget.endDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EVVsPetrolComparison>(
      future: _comparisonFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No data available'),
            ),
          );
        }

        final comparison = snapshot.data!;

        return Card(
          elevation: 4,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.shade700,
                  Colors.green.shade500,
                ],
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
                      const Icon(
                        Icons.compare_arrows,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'EV Savings Report',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_formatDate(widget.startDate)} - ${_formatDate(widget.endDate)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Main Savings Display
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.savings,
                              color: Colors.green.shade700,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You Saved',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '₹${comparison.monthlySavings.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${comparison.savingsPercent.toStringAsFixed(0)}% cheaper than petrol',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Comparison Details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildComparisonRow(
                          'Your EV Cost',
                          '₹${comparison.totalEvCost.toStringAsFixed(0)}',
                          Icons.electric_scooter,
                          Colors.white,
                        ),
                        const Divider(color: Colors.white30, height: 24),
                        _buildComparisonRow(
                          'Petrol Equivalent',
                          '₹${comparison.equivalentPetrolCost.toStringAsFixed(0)}',
                          Icons.local_gas_station,
                          Colors.white70,
                        ),
                        const Divider(color: Colors.white30, height: 24),
                        _buildComparisonRow(
                          'Cost per km (EV)',
                          '₹${comparison.evCostPerKm.toStringAsFixed(2)}',
                          Icons.route,
                          Colors.white,
                        ),
                        _buildComparisonRow(
                          'Cost per km (Petrol)',
                          '₹${comparison.petrolCostPerKm.toStringAsFixed(2)}',
                          Icons.route,
                          Colors.white70,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Environmental Impact
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.eco,
                          color: Colors.green.shade700,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Environmental Impact',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${comparison.co2Saved.toStringAsFixed(1)} kg CO₂ saved',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Equivalent to planting ${(comparison.co2Saved / 20).toStringAsFixed(0)} trees',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildComparisonRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
