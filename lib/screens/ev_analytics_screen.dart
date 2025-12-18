import 'package:flutter/material.dart';

import '../models/vehicle.dart';
import '../widgets/battery_health_widget.dart';
import '../widgets/charging_cost_calculator.dart';
import '../widgets/ev_vs_petrol_comparison.dart';

class EVAnalyticsScreen extends StatefulWidget {
  const EVAnalyticsScreen({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  State<EVAnalyticsScreen> createState() => _EVAnalyticsScreenState();
}

class _EVAnalyticsScreenState extends State<EVAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.vehicle.name} Analytics'),
        backgroundColor: Colors.green.shade700,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.calculate), text: 'Calculator'),
            Tab(icon: Icon(Icons.compare), text: 'Savings'),
            Tab(icon: Icon(Icons.battery_full), text: 'Battery'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Calculator Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const ChargingCostCalculatorWidget(),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'About Ola S1 Pro',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('Battery Capacity', '3.97 kWh'),
                        _buildInfoRow('Real-world Range', '~135 km'),
                        _buildInfoRow('Efficiency', '~2.94 kWh/100km'),
                        _buildInfoRow('Top Speed', '115 km/h'),
                        _buildInfoRow('0-40 km/h', '3.0 seconds'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Savings Comparison Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                EVVsPetrolComparisonWidget(
                  vehicle: widget.vehicle,
                  startDate: DateTime.now().subtract(const Duration(days: 30)),
                  endDate: DateTime.now(),
                ),
                const SizedBox(height: 16),
                _buildSavingsTips(),
              ],
            ),
          ),

          // Battery Health Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: BatteryHealthWidget(vehicle: widget.vehicle),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsTips() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Maximize Your Savings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTip('Charge at home during off-peak hours (11 PM - 6 AM)'),
            _buildTip('Use Eco mode for longer range'),
            _buildTip('Maintain tire pressure at 30 PSI'),
            _buildTip('Avoid frequent rapid charging'),
            _buildTip('Plan routes to minimize unnecessary stops'),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }
}
