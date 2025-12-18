import 'package:flutter/material.dart';

class ChargingCostCalculatorWidget extends StatefulWidget {
  const ChargingCostCalculatorWidget({super.key});

  @override
  State<ChargingCostCalculatorWidget> createState() =>
      _ChargingCostCalculatorWidgetState();
}

class _ChargingCostCalculatorWidgetState
    extends State<ChargingCostCalculatorWidget> {
  final _monthlyKmController = TextEditingController(text: '1000');
  final _homeRateController = TextEditingController(text: '6.5');
  final _publicRateController = TextEditingController(text: '15.0');
  final _homePercentageController = TextEditingController(text: '80');

  // Ola S1 Pro specs
  static const double batteryCapacity = 3.97; // kWh
  static const double rangePerCharge = 135.0; // km (realistic)
  static const double kwhPer100Km = batteryCapacity / rangePerCharge * 100;

  double _monthlyKm = 1000;
  double _homeRate = 6.5;
  double _publicRate = 15.0;
  double _homePercentage = 80;

  @override
  void initState() {
    super.initState();
    _monthlyKmController.addListener(_updateCalculation);
    _homeRateController.addListener(_updateCalculation);
    _publicRateController.addListener(_updateCalculation);
    _homePercentageController.addListener(_updateCalculation);
  }

  @override
  void dispose() {
    _monthlyKmController.dispose();
    _homeRateController.dispose();
    _publicRateController.dispose();
    _homePercentageController.dispose();
    super.dispose();
  }

  void _updateCalculation() {
    setState(() {
      _monthlyKm = double.tryParse(_monthlyKmController.text) ?? 1000;
      _homeRate = double.tryParse(_homeRateController.text) ?? 6.5;
      _publicRate = double.tryParse(_publicRateController.text) ?? 15.0;
      _homePercentage = double.tryParse(_homePercentageController.text) ?? 80;
    });
  }

  Map<String, double> _calculate() {
    // Total kWh needed
    final totalKwh = (_monthlyKm / 100) * kwhPer100Km;

    // Split between home and public
    final homeKwh = totalKwh * (_homePercentage / 100);
    final publicKwh = totalKwh * ((100 - _homePercentage) / 100);

    // Costs
    final homeCost = homeKwh * _homeRate;
    final publicCost = publicKwh * _publicRate;
    final totalEvCost = homeCost + publicCost;

    // Petrol equivalent (assuming 45 km/l at ₹105/l)
    final petrolLiters = _monthlyKm / 45;
    final petrolCost = petrolLiters * 105;

    // Savings
    final savings = petrolCost - totalEvCost;
    final savingsPercent = (savings / petrolCost) * 100;

    return {
      'total_kwh': totalKwh,
      'home_kwh': homeKwh,
      'public_kwh': publicKwh,
      'home_cost': homeCost,
      'public_cost': publicCost,
      'total_ev_cost': totalEvCost,
      'petrol_cost': petrolCost,
      'monthly_savings': savings,
      'savings_percent': savingsPercent,
      'cost_per_km': totalEvCost / _monthlyKm,
      'petrol_cost_per_km': petrolCost / _monthlyKm,
    };
  }

  @override
  Widget build(BuildContext context) {
    final results = _calculate();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calculate, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  'Charging Cost Calculator',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Input: Monthly KM
            TextField(
              controller: _monthlyKmController,
              decoration: const InputDecoration(
                labelText: 'Monthly Distance',
                suffixText: 'km',
                prefixIcon: Icon(Icons.route),
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 12),

            // Input: Home Charging %
            TextField(
              controller: _homePercentageController,
              decoration: const InputDecoration(
                labelText: 'Home Charging',
                suffixText: '%',
                prefixIcon: Icon(Icons.home),
                helperText: 'Rest will be public charging',
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 12),

            // Input: Home Rate
            TextField(
              controller: _homeRateController,
              decoration: const InputDecoration(
                labelText: 'Home Electricity Rate',
                suffixText: '₹/kWh',
                prefixIcon: Icon(Icons.bolt),
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 12),

            // Input: Public Rate
            TextField(
              controller: _publicRateController,
              decoration: const InputDecoration(
                labelText: 'Public Charging Rate',
                suffixText: '₹/kWh',
                prefixIcon: Icon(Icons.ev_station),
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Results Header
            Text(
              'Monthly Cost Estimate',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 16),

            // EV Cost Breakdown
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildResultRow(
                    'Total kWh Required',
                    '${results['total_kwh']!.toStringAsFixed(1)} kWh',
                    Icons.battery_charging_full,
                    Colors.green,
                  ),
                  const Divider(),
                  _buildResultRow(
                    'Home Charging (${_homePercentage.toStringAsFixed(0)}%)',
                    '₹${results['home_cost']!.toStringAsFixed(0)}',
                    Icons.home,
                    Colors.blue,
                  ),
                  _buildResultRow(
                    'Public Charging (${(100 - _homePercentage).toStringAsFixed(0)}%)',
                    '₹${results['public_cost']!.toStringAsFixed(0)}',
                    Icons.ev_station,
                    Colors.orange,
                  ),
                  const Divider(thickness: 2),
                  _buildResultRow(
                    'Total EV Cost',
                    '₹${results['total_ev_cost']!.toStringAsFixed(0)}',
                    Icons.electric_scooter,
                    Colors.green,
                    isBold: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Comparison with Petrol
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildResultRow(
                    'Equivalent Petrol Cost',
                    '₹${results['petrol_cost']!.toStringAsFixed(0)}',
                    Icons.local_gas_station,
                    Colors.red,
                  ),
                  const Divider(),
                  _buildResultRow(
                    'Monthly Savings',
                    '₹${results['monthly_savings']!.toStringAsFixed(0)} (${results['savings_percent']!.toStringAsFixed(0)}%)',
                    Icons.savings,
                    Colors.green,
                    isBold: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Cost per KM comparison
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'EV Cost/km',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                        Text(
                          '₹${results['cost_per_km']!.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Petrol Cost/km',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                          ),
                        ),
                        Text(
                          '₹${results['petrol_cost_per_km']!.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Annual Savings
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade700, Colors.green.shade500],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Annual Savings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '₹${(results['monthly_savings']! * 12).toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
