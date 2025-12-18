import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/budget.dart';
import '../models/vehicle.dart';
import '../providers/expense_provider.dart';
import '../services/budget_service.dart';
import '../services/database_service.dart';
import '../utils/app_localizations.dart';
import 'add_charging_expense_screen.dart';
import 'add_fuel_expense_screen.dart';
import 'budget_details_screen.dart';
import 'ev_analytics_screen.dart';
import 'maintenance_screen.dart';
import 'manage_vehicle_access_screen.dart';
import 'vehicle_activity_screen.dart';
import 'vehicle_settlements_screen.dart';

class VehicleDetailsScreen extends StatefulWidget {
  const VehicleDetailsScreen({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final expenseProvider =
        Provider.of<ExpenseProvider>(context, listen: false);
    await expenseProvider.loadFuelExpensesByVehicle(widget.vehicle.id!);
    await expenseProvider.loadGeneralExpensesByVehicle(widget.vehicle.id!);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicle.name),
        actions: [
          if (widget.vehicle.isElectric)
            IconButton(
              icon: const Icon(Icons.analytics_outlined),
              tooltip: 'EV Analytics',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EVAnalyticsScreen(vehicle: widget.vehicle),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.build_outlined),
            tooltip: 'Maintenance',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MaintenanceScreen(vehicle: widget.vehicle),
                ),
              );
            },
          ),
          if (widget.vehicle.isShared)
            IconButton(
              icon: const Icon(Icons.forum_outlined),
              tooltip: 'Activity feed',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        VehicleActivityScreen(vehicle: widget.vehicle),
                  ),
                );
              },
            ),
          if (widget.vehicle.isShared)
            IconButton(
              icon: const Icon(Icons.people),
              tooltip: 'Manage Access',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManageVehicleAccessScreen(
                      vehicle: widget.vehicle,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, expenseProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildVehicleInfoCard(context, localizations),
                const SizedBox(height: 16),
                _buildBudgetCard(context, localizations),
                const SizedBox(height: 16),
                _buildFuelAverageCard(context, localizations),
                const SizedBox(height: 16),
                _buildCostEfficiencyCard(context, localizations),
                const SizedBox(height: 16),
                _buildExpenseSummaryCard(
                  context,
                  localizations,
                  expenseProvider,
                ),
                if (widget.vehicle.isShared) ...[
                  const SizedBox(height: 16),
                  _buildContributionCard(context, localizations),
                ],
                const SizedBox(height: 16),
                _buildRecentExpensesList(
                  context,
                  localizations,
                  expenseProvider,
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: widget.vehicle.isElectric
          ? FloatingActionButton.extended(
              onPressed: () async {
                final navContext = context;
                final result = await Navigator.push(
                  navContext,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddChargingExpenseScreen(vehicle: widget.vehicle),
                  ),
                );
                if (result == true && mounted) {
                  if (navContext.mounted) {
                    setState(() {});
                  }
                }
              },
              icon: const Icon(Icons.bolt),
              label: const Text('Add Charging'),
              backgroundColor: Colors.green.shade700,
            )
          : FloatingActionButton(
              onPressed: () async {
                final navContext = context;
                final result = await Navigator.push(
                  navContext,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddFuelExpenseScreen(vehicle: widget.vehicle),
                  ),
                );
                if (result == true && mounted) {
                  if (!navContext.mounted) return;
                  await Provider.of<ExpenseProvider>(navContext, listen: false)
                      .loadFuelExpenses();
                  if (mounted) setState(() {});
                }
              },
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildVehicleInfoCard(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.vehicle.vehicleType == VehicleType.bike
                      ? Icons.two_wheeler
                      : Icons.directions_car,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.vehicle.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        widget.vehicle.registrationNumber,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(localizations.translate('current_odometer')),
                Text(
                  '${widget.vehicle.currentOdometer.toStringAsFixed(0)} km',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFuelAverageCard(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.translate('fuel_average'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, double>>(
              future: DatabaseService.instance
                  .calculateFuelAverages(widget.vehicle.id!),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  final averages = snapshot.data!;
                  final lifetimeAvg = averages['lifetime_average'] ?? 0;
                  final last5Avg = averages['last_5_average'] ?? 0;
                  final monthlyAvg = averages['monthly_average'] ?? 0;

                  return Column(
                    children: [
                      // Lifetime average - main display
                      if (lifetimeAvg > 0) ...[
                        Text(
                          '${lifetimeAvg.toStringAsFixed(2)} ${localizations.translate('km_per_liter')}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'Lifetime Average',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Last 5 and monthly averages
                      Row(
                        children: [
                          if (last5Avg > 0) ...[
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    last5Avg.toStringAsFixed(2),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  Text(
                                    'Last 5 Fillups',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (last5Avg > 0 && monthlyAvg > 0)
                            const VerticalDivider(),
                          if (monthlyAvg > 0) ...[
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    monthlyAvg.toStringAsFixed(2),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  Text(
                                    'Last 30 Days',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    Icon(
                      Icons.local_gas_station_outlined,
                      size: 40,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Not enough data',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add at least 2 fuel entries to see average',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseSummaryCard(
    BuildContext context,
    AppLocalizations localizations,
    ExpenseProvider expenseProvider,
  ) {
    final fuelTotal = expenseProvider.fuelExpenses
        .where((e) => e.vehicleId == widget.vehicle.id)
        .fold(0.0, (sum, e) => sum + e.amountPaid);

    final generalTotal = expenseProvider.generalExpenses
        .where((e) => e.vehicleId == widget.vehicle.id)
        .fold(0.0, (sum, e) => sum + e.amount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.translate('total_expenses'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(localizations.translate('fuel_expenses')),
                    Text(
                      localizations.formatCurrency(fuelTotal),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(localizations.translate('general_expenses')),
                    Text(
                      localizations.formatCurrency(generalTotal),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostEfficiencyCard(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cost Efficiency',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, double>?>(
              future: DatabaseService.instance
                  .getVehicleCostStats(widget.vehicle.id!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final data = snapshot.data;
                if (data == null) {
                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add at least 2 fuel entries with odometer readings to calculate cost per kilometer.',
                      ),
                    ],
                  );
                }

                final costPerKm = data['cost_per_km'] ?? 0;
                final distance = data['distance'] ?? 0;
                final fuelSpend = data['fuel_spend'] ?? 0;
                final generalSpend = data['general_spend'] ?? 0;
                final totalSpend = data['total_spend'] ?? 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.speed, color: Colors.white),
                      ),
                      title: const Text('Cost per kilometer'),
                      subtitle:
                          const Text('All recorded fuel + maintenance costs'),
                      trailing: Text(
                        '${localizations.formatCurrency(costPerKm)} / km',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Distance tracked'),
                              Text(
                                '${distance.toStringAsFixed(0)} km',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Total spend'),
                              Text(
                                localizations.formatCurrency(totalSpend),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Fuel ${localizations.formatCurrency(fuelSpend)} / Other ${localizations.formatCurrency(generalSpend)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.end,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContributionCard(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.groups,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Shared Contribution',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseService.instance
                  .getVehicleContributionSummary(widget.vehicle.id!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final contributions = snapshot.data ?? [];
                if (contributions.isEmpty) {
                  return const Text(
                    'No shared expenses recorded yet. Invite collaborators to start splitting costs.',
                  );
                }

                final totalSpent = contributions.fold<double>(
                  0,
                  (sum, row) =>
                      sum + ((row['total_spent'] as num?)?.toDouble() ?? 0.0),
                );
                final fairShare = contributions.isNotEmpty
                    ? totalSpent / contributions.length
                    : 0.0;

                return Column(
                  children: [
                    ...contributions.map((row) {
                      final name = (row['person_name'] as String?) ??
                          (row['device_id'] as String? ?? 'Unknown');
                      final fuelTotal =
                          (row['fuel_total'] as num?)?.toDouble() ?? 0.0;
                      final generalTotal =
                          (row['general_total'] as num?)?.toDouble() ?? 0.0;
                      final total = fuelTotal + generalTotal;
                      final delta = total - fairShare;

                      String status;
                      Color statusColor;
                      if (delta.abs() < 1) {
                        status = 'Settled';
                        statusColor = Colors.grey;
                      } else if (delta > 0) {
                        status =
                            'Should receive ${localizations.formatCurrency(delta)}';
                        statusColor = Colors.green;
                      } else {
                        status =
                            'Owes ${localizations.formatCurrency(delta.abs())}';
                        statusColor = Colors.red;
                      }

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                          ),
                        ),
                        title: Text(name),
                        subtitle: Text(
                          'Fuel ${localizations.formatCurrency(fuelTotal)} · Other ${localizations.formatCurrency(generalTotal)}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              localizations.formatCurrency(total),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              status,
                              style:
                                  TextStyle(color: statusColor, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Fair share: ${localizations.formatCurrency(fairShare)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Manage settlements'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VehicleSettlementsScreen(
                                vehicle: widget.vehicle,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentExpensesList(
    BuildContext context,
    AppLocalizations localizations,
    ExpenseProvider expenseProvider,
  ) {
    final recentFuelExpenses = expenseProvider.fuelExpenses
        .where((e) => e.vehicleId == widget.vehicle.id)
        .take(5)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Fuel Expenses',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (recentFuelExpenses.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text('No expenses yet'),
                ),
              )
            else
              ...recentFuelExpenses.map(
                (expense) => ListTile(
                  leading: const Icon(Icons.local_gas_station),
                  title: Text(localizations.formatCurrency(expense.amountPaid)),
                  subtitle: Text(
                    '${expense.liters.toStringAsFixed(2)} L - ${localizations.formatDate(expense.date)}',
                  ),
                  trailing:
                      Text('${expense.odometerReading.toStringAsFixed(0)} km'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetCard(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return FutureBuilder<BudgetStatus?>(
      future: _getBudgetStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final budgetStatus = snapshot.data;
        final hasBudget = budgetStatus != null && budgetStatus.budgetAmount > 0;

        return Card(
          child: InkWell(
            onTap: hasBudget
                ? () async {
                    final summary =
                        await BudgetService.instance.getFamilyBudgetSummary();
                    if (!context.mounted) return;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            BudgetDetailsScreen(summary: summary),
                      ),
                    );
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: hasBudget
                            ? _getBudgetColor(budgetStatus.alertLevel)
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Monthly Budget',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, size: 20),
                        onPressed: () => _showBudgetSettingsDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (hasBudget) ...[
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value:
                            (budgetStatus.percentageUsed / 100).clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getBudgetColor(budgetStatus.alertLevel),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${budgetStatus.percentageUsed.toStringAsFixed(0)}% used',
                          style: TextStyle(
                            color: _getBudgetColor(budgetStatus.alertLevel),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '₹${budgetStatus.spent.toStringAsFixed(0)} / ₹${budgetStatus.budgetAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Remaining',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              '₹${budgetStatus.remaining.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: budgetStatus.remaining >= 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Daily Budget',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              '₹${budgetStatus.dailyBudgetRemaining.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ] else ...[
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'No budget set',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => _showBudgetSettingsDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Set Monthly Budget'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<BudgetStatus?> _getBudgetStatus() async {
    final budget =
        await DatabaseService.instance.getVehicleBudget(widget.vehicle.id!);
    if (budget == null || budget <= 0) return null;

    return BudgetService.instance.getBudgetStatus(widget.vehicle);
  }

  Color _getBudgetColor(BudgetAlertLevel level) {
    switch (level) {
      case BudgetAlertLevel.safe:
        return Colors.green;
      case BudgetAlertLevel.warning:
        return Colors.orange;
      case BudgetAlertLevel.critical:
      case BudgetAlertLevel.exceeded:
        return Colors.deepOrange;
      case BudgetAlertLevel.overBudget:
        return Colors.red;
    }
  }

  void _showBudgetSettingsDialog(BuildContext context) {
    final currentBudget = widget.vehicle.monthlyBudget ?? 0;
    final controller = TextEditingController(
      text: currentBudget > 0 ? currentBudget.toStringAsFixed(0) : '',
    );
    // Capture messenger up front to avoid ancestor lookups after dialog closes
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      controller.dispose();
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set Monthly Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set a monthly spending budget for ${widget.vehicle.name}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Monthly Budget',
                prefixText: '₹',
                border: OutlineInputBorder(),
                helperText: 'Enter 0 to disable budget tracking',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll receive alerts at 50%, 75%, 90%, and 100% usage',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              controller.dispose();
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final budget = double.tryParse(controller.text) ?? 0;
              await DatabaseService.instance
                  .updateVehicleBudget(widget.vehicle.id!, budget);

              if (!dialogContext.mounted) {
                controller.dispose();
                return;
              }
              Navigator.pop(dialogContext);
              controller.dispose();

              if (!mounted) return;
              setState(() {});
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    budget > 0
                        ? 'Budget set to ₹${budget.toStringAsFixed(0)}/month'
                        : 'Budget tracking disabled',
                  ),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
