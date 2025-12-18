import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/device_provider.dart';
import '../services/database_service.dart';
import '../utils/app_localizations.dart';

class BudgetSettingsScreen extends StatefulWidget {
  const BudgetSettingsScreen({super.key});

  @override
  State<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends State<BudgetSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fuelLimitController = TextEditingController();
  final _generalLimitController = TextEditingController();
  final _householdLimitController = TextEditingController();

  bool _isLoading = true;
  Map<String, dynamic>? _currentBudget;
  double _fuelSpent = 0;
  double _generalSpent = 0;

  final _currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadCurrentBudget();
  }

  Future<void> _loadCurrentBudget() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final budget = await DatabaseService.instance.getBudgetForMonth(
      deviceProvider.currentDeviceId!,
      month,
    );

    if (budget != null) {
      _fuelLimitController.text = budget['fuel_limit'].toString();
      _generalLimitController.text = budget['general_limit'].toString();
      _householdLimitController.text = budget['household_limit'].toString();
      _currentBudget = budget;
    }

    // Calculate current month spending
    final startOfMonth = DateTime(now.year, now.month);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final fuelExpenses = await DatabaseService.instance.getAllFuelExpenses();
    final generalExpenses =
        await DatabaseService.instance.getAllGeneralExpenses();

    _fuelSpent = fuelExpenses
        .where(
          (e) =>
              e.date.isAfter(startOfMonth) &&
              e.date.isBefore(endOfMonth.add(const Duration(days: 1))),
        )
        .fold<double>(0, (sum, e) => sum + e.amountPaid);

    _generalSpent = generalExpenses
        .where(
          (e) =>
              e.date.isAfter(startOfMonth) &&
              e.date.isBefore(endOfMonth.add(const Duration(days: 1))),
        )
        .fold<double>(0, (sum, e) => sum + e.amount);

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _fuelLimitController.dispose();
    _generalLimitController.dispose();
    _householdLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(now);

    return Scaffold(
      appBar: AppBar(
        title: Text('Budget - $monthName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Budget History'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Previous months budget summary:'),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: 3,
                            itemBuilder: (context, index) {
                              final months = [
                                'Last month',
                                '2 months ago',
                                '3 months ago',
                              ];
                              return ListTile(
                                leading: const Icon(Icons.calendar_month),
                                title: Text(months[index]),
                                subtitle: const Text('View details'),
                                trailing: const Icon(Icons.arrow_forward_ios,
                                    size: 16,),
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Opening ${months[index]} budget...',),),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'View History',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCurrentBudget,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Current Spending Overview
                    if (_currentBudget != null) ...[
                      _buildSpendingOverviewCard(),
                      const SizedBox(height: 24),
                    ],

                    // Info Card
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Set spending limits and receive alerts at 70%, 90%, and 100% thresholds.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Budget Form
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildBudgetInputCard(
                            'Fuel Expenses',
                            Icons.local_gas_station,
                            Colors.orange,
                            _fuelLimitController,
                            _fuelSpent,
                          ),
                          const SizedBox(height: 16),
                          _buildBudgetInputCard(
                            'General Expenses',
                            Icons.receipt_long,
                            Colors.blue,
                            _generalLimitController,
                            _generalSpent,
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: _saveBudget,
                            icon: const Icon(Icons.save),
                            label: Text(
                              localizations.translate('save'),
                              style: const TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              minimumSize: const Size(double.infinity, 56),
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
  }

  Widget _buildSpendingOverviewCard() {
    final fuelLimit = double.tryParse(_fuelLimitController.text) ?? 0;
    final generalLimit = double.tryParse(_generalLimitController.text) ?? 0;
    final totalLimit = fuelLimit + generalLimit;
    final totalSpent = _fuelSpent + _generalSpent;
    final totalPercentage = totalLimit > 0 ? (totalSpent / totalLimit) : 0;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Monthly Spending',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              width: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 180,
                    width: 180,
                    child: CircularProgressIndicator(
                      value: (totalPercentage as double).clamp(0.0, 1.0),
                      strokeWidth: 12,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getColorForPercentage(totalPercentage * 100),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currencyFormat.format(totalSpent),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  _getColorForPercentage(totalPercentage * 100),
                            ),
                      ),
                      Text(
                        'of ${_currencyFormat.format(totalLimit)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getColorForPercentage(totalPercentage * 100)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${(totalPercentage * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                _getColorForPercentage(totalPercentage * 100),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildSmallStatCard(
                    'Fuel',
                    _fuelSpent,
                    fuelLimit,
                    Colors.orange,
                    Icons.local_gas_station,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSmallStatCard(
                    'General',
                    _generalSpent,
                    generalLimit,
                    Colors.blue,
                    Icons.receipt_long,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallStatCard(
    String label,
    double spent,
    double limit,
    Color color,
    IconData icon,
  ) {
    final percentage = limit > 0 ? (spent / limit * 100) : 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
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
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _currencyFormat.format(spent),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetInputCard(
    String label,
    IconData icon,
    Color color,
    TextEditingController controller,
    double currentSpent,
  ) {
    final limit = double.tryParse(controller.text) ?? 0;
    final percentage = limit > 0 ? (currentSpent / limit * 100) : 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (limit > 0)
                        Text(
                          'Spent: ${_currencyFormat.format(currentSpent)} (${percentage.toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                _getColorForPercentage(percentage.toDouble()),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (limit > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (percentage / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getColorForPercentage(percentage.toDouble()),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Monthly Limit',
                prefixText: '₹ ',
                helperText: limit > 0
                    ? 'Remaining: ${_currencyFormat.format((limit - currentSpent).clamp(0, double.infinity))}'
                    : 'Set your monthly budget limit',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                }
                return null;
              },
              onChanged: (_) {}, // Form validation happens automatically
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForPercentage(double percentage) {
    if (percentage >= 100) {
      return Colors.red.shade700;
    } else if (percentage >= 90) {
      return Colors.red;
    } else if (percentage >= 70) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  Future<void> _saveBudget() async {
    if (_formKey.currentState!.validate()) {
      final deviceProvider =
          Provider.of<DeviceProvider>(context, listen: false);
      final now = DateTime.now();
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final fuelLimit = double.tryParse(_fuelLimitController.text) ?? 0;
      final generalLimit = double.tryParse(_generalLimitController.text) ?? 0;
      final householdLimit =
          double.tryParse(_householdLimitController.text) ?? 0;

      if (_currentBudget != null) {
        // Update existing budget
        await DatabaseService.instance.updateBudget(
          _currentBudget!['id'] as int,
          fuelLimit: fuelLimit,
          generalLimit: generalLimit,
          householdLimit: householdLimit,
        );
      } else {
        // Create new budget
        await DatabaseService.instance.createBudget(
          deviceId: deviceProvider.currentDeviceId!,
          month: month,
          fuelLimit: fuelLimit,
          generalLimit: generalLimit,
          householdLimit: householdLimit,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget saved successfully!')),
        );
        Navigator.pop(context);
      }
    }
  }
}
