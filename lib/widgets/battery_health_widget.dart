import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/charging_expense.dart';
import '../models/vehicle.dart';
import '../providers/charging_expense_provider.dart';

class BatteryHealthWidget extends StatefulWidget {
  const BatteryHealthWidget({
    super.key,
    required this.vehicle,
  });
  final Vehicle vehicle;

  @override
  State<BatteryHealthWidget> createState() => _BatteryHealthWidgetState();
}

class _BatteryHealthWidgetState extends State<BatteryHealthWidget> {
  late Future<BatteryHealthData> _healthFuture;

  @override
  void initState() {
    super.initState();
    _healthFuture = Provider.of<ChargingExpenseProvider>(context, listen: false)
        .getBatteryHealthData(widget.vehicle.id!);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BatteryHealthData>(
      future: _healthFuture,
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
              child: Text('No charging data available'),
            ),
          );
        }

        final health = snapshot.data!;

        return Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.battery_charging_full,
                      color: _getHealthColor(health.estimatedHealthPercent),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Battery Health',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Ola S1 Pro • 3.97 kWh',
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

                const SizedBox(height: 24),

                // Health Percentage Display
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: CircularProgressIndicator(
                          value: health.estimatedHealthPercent / 100,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getHealthColor(health.estimatedHealthPercent),
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            '${health.estimatedHealthPercent.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: _getHealthColor(
                                health.estimatedHealthPercent,
                              ),
                            ),
                          ),
                          Text(
                            _getHealthStatus(health.estimatedHealthPercent),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Charging Cycles Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn(
                            'Total Cycles',
                            health.totalChargingCycles.toString(),
                            Icons.loop,
                            Colors.blue,
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.grey.shade300,
                          ),
                          _buildStatColumn(
                            'Avg/Month',
                            health.averageCyclesPerMonth.toStringAsFixed(0),
                            Icons.calendar_month,
                            Colors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn(
                            'Slow Charging',
                            health.slowChargingCycles.toString(),
                            Icons.battery_charging_full,
                            Colors.green,
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.grey.shade300,
                          ),
                          _buildStatColumn(
                            'Fast Charging',
                            health.fastChargingCycles.toString(),
                            Icons.bolt,
                            Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Fast Charging Warning
                if (health.fastChargingPercent > 30)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${health.fastChargingPercent.toStringAsFixed(0)}% fast charging. Use slow charging more often for better battery health.',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Battery Tips
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.tips_and_updates,
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Battery Care Tips',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildTip('Avoid charging to 100% daily'),
                      _buildTip('Keep battery between 20-80% for daily use'),
                      _buildTip('Use slow charging whenever possible'),
                      _buildTip('Avoid extreme temperatures'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Days in Use
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Days in Use'),
                      Text(
                        '${health.daysInUse} days',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Avg Battery Gain/Cycle'),
                      Text(
                        '${health.averageBatteryGainPerCycle.toStringAsFixed(0)}%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildStatColumn(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Color _getHealthColor(double healthPercent) {
    if (healthPercent >= 90) return Colors.green;
    if (healthPercent >= 80) return Colors.lightGreen;
    if (healthPercent >= 70) return Colors.orange;
    return Colors.red;
  }

  String _getHealthStatus(double healthPercent) {
    if (healthPercent >= 95) return 'Excellent';
    if (healthPercent >= 90) return 'Very Good';
    if (healthPercent >= 80) return 'Good';
    if (healthPercent >= 70) return 'Fair';
    return 'Poor';
  }
}
