import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/fuel_expense.dart';
import '../models/general_expense.dart';
import '../models/vehicle.dart';
import '../services/database_service.dart';

class AdvancedAnalyticsScreen extends StatefulWidget {
  const AdvancedAnalyticsScreen({super.key});

  @override
  State<AdvancedAnalyticsScreen> createState() =>
      _AdvancedAnalyticsScreenState();
}

class _AdvancedAnalyticsScreenState extends State<AdvancedAnalyticsScreen> {
  final _db = DatabaseService.instance;
  final _currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  int? _selectedVehicleId;

  List<Vehicle> _vehicles = [];
  List<FuelExpense> _fuelExpenses = [];
  List<GeneralExpense> _generalExpenses = [];
  List<_CostPerKmData> _costPerKmData = [];
  List<_InsightMessage> _insights = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final vehicles = await _db.getAllVehicles();
      final fuelExpenses = await _db.getAllFuelExpenses();
      final generalExpenses = await _db.getAllGeneralExpenses();

      // Filter by date range
      final filteredFuel = fuelExpenses.where((e) {
        return e.date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
            e.date.isBefore(_endDate.add(const Duration(days: 1)));
      }).toList();

      final filteredGeneral = generalExpenses.where((e) {
        return e.date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
            e.date.isBefore(_endDate.add(const Duration(days: 1)));
      }).toList();

      // Filter by vehicle if selected
      final vehicleFilteredFuel = _selectedVehicleId != null
          ? filteredFuel
              .where((e) => e.vehicleId == _selectedVehicleId)
              .toList()
          : filteredFuel;

      final vehicleFilteredGeneral = _selectedVehicleId != null
          ? filteredGeneral
              .where((e) => e.vehicleId == _selectedVehicleId)
              .toList()
          : filteredGeneral;

      final costStats = await _fetchCostPerKmStats(vehicles);
      final insights = _generateInsights(
        fuelExpenses,
        generalExpenses,
        vehicleFilteredFuel,
        vehicleFilteredGeneral,
      );

      setState(() {
        _vehicles = vehicles;
        _fuelExpenses = vehicleFilteredFuel;
        _generalExpenses = vehicleFilteredGeneral;
        _costPerKmData = costStats;
        _insights = insights;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Share snapshot',
            onPressed: _shareAnalyticsSummary,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _fuelExpenses.isEmpty && _generalExpenses.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildFilterChips(),
                      const SizedBox(height: 16),
                      _buildSummaryCards(),
                      if (_insights.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildPredictiveInsightCard(),
                      ],
                      const SizedBox(height: 24),
                      _buildExpenseBreakdownPieChart(),
                      const SizedBox(height: 24),
                      _buildMonthlyTrendChart(),
                      const SizedBox(height: 24),
                      _buildFuelEfficiencyChart(),
                      if (_costPerKmData.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildCostPerKmCard(),
                      ],
                      const SizedBox(height: 24),
                      _buildCategorySpendingChart(),
                      const SizedBox(height: 24),
                      _buildVehicleComparisonChart(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No data for selected period',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your date range or filters',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          label: Text(
            '${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd').format(_endDate)}',
          ),
          onSelected: (_) => _showFilterDialog(),
          avatar: const Icon(Icons.calendar_today, size: 16),
        ),
        if (_selectedVehicleId != null)
          FilterChip(
            label: Text(
              _vehicles.firstWhere((v) => v.id == _selectedVehicleId).name,
            ),
            onSelected: (_) {
              setState(() => _selectedVehicleId = null);
              _loadData();
            },
            onDeleted: () {
              setState(() => _selectedVehicleId = null);
              _loadData();
            },
          ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final totalFuel =
        _fuelExpenses.fold<double>(0, (sum, e) => sum + e.amountPaid);
    final totalGeneral =
        _generalExpenses.fold<double>(0, (sum, e) => sum + e.amount);
    final totalExpense = totalFuel + totalGeneral;

    final totalLiters =
        _fuelExpenses.fold<double>(0, (sum, e) => sum + e.liters);
    final avgFuelPrice = totalLiters > 0 ? totalFuel / totalLiters : 0;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Expenses',
            '₹${totalExpense.toStringAsFixed(2)}',
            Icons.account_balance_wallet,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Avg Fuel Price',
            '₹${avgFuelPrice.toStringAsFixed(2)}/L',
            Icons.local_gas_station,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Future<void> _shareAnalyticsSummary() async {
    if (_fuelExpenses.isEmpty && _generalExpenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some expenses before sharing.')),
      );
      return;
    }

    final totalFuel =
        _fuelExpenses.fold<double>(0, (sum, e) => sum + e.amountPaid);
    final totalGeneral =
        _generalExpenses.fold<double>(0, (sum, e) => sum + e.amount);
    final totalExpense = totalFuel + totalGeneral;
    final totalLiters =
        _fuelExpenses.fold<double>(0, (sum, e) => sum + e.liters);
    final avgFuelPrice = totalLiters > 0 ? totalFuel / totalLiters : 0;
    final insight = _insights.isNotEmpty
        ? '${_insights.first.title}: ${_insights.first.description}'
        : 'Keep tracking to unlock insights!';

    final summary = StringBuffer()
      ..writeln('🚗 Fuel & Expense Snapshot')
      ..writeln(
        '${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd').format(_endDate)}',
      )
      ..writeln('Total spend: ₹${totalExpense.toStringAsFixed(0)}')
      ..writeln(
        'Fuel: ₹${totalFuel.toStringAsFixed(0)} · Other: ₹${totalGeneral.toStringAsFixed(0)}',
      )
      ..writeln('Avg fuel price: ₹${avgFuelPrice.toStringAsFixed(2)}/L')
      ..writeln('Insight: $insight');

    await Share.share(
      summary.toString(),
      subject: 'My vehicle expense summary',
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictiveInsightCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Predictive Insights',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ..._insights.map(
              (insight) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: insight.color.withValues(alpha: 0.15),
                  child: Icon(insight.icon, color: insight.color),
                ),
                title: Text(insight.title),
                subtitle: Text(insight.description),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostPerKmCard() {
    final topEntries = _costPerKmData.take(5).toList();
    if (topEntries.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cost per Kilometer (lower is better)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Includes recorded fuel and maintenance spending for each vehicle.',
            ),
            const SizedBox(height: 12),
            ...List.generate(topEntries.length, (index) {
              final entry = topEntries[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.blueGrey.shade50,
                  child: Text('${index + 1}'),
                ),
                title: Text(entry.vehicleName),
                subtitle: Text(
                  'Distance ${entry.distance.toStringAsFixed(0)} km · Spend ${_currencyFormat.format(entry.totalSpend)}',
                ),
                trailing: Text(
                  '${_currencyFormat.format(entry.costPerKm)} / km',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseBreakdownPieChart() {
    final totalFuel =
        _fuelExpenses.fold<double>(0, (sum, e) => sum + e.amountPaid);
    final totalGeneral =
        _generalExpenses.fold<double>(0, (sum, e) => sum + e.amount);

    if (totalFuel == 0 && totalGeneral == 0) return const SizedBox.shrink();

    final data = [
      _ChartData('Fuel', totalFuel, Colors.orange),
      _ChartData('General', totalGeneral, Colors.blue),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expense Breakdown',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: SfCircularChart(
                legend: const Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CircularSeries>[
                  PieSeries<_ChartData, String>(
                    dataSource: data,
                    xValueMapper: (data, _) => data.category,
                    yValueMapper: (data, _) => data.value,
                    pointColorMapper: (data, _) => data.color,
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                    ),
                    dataLabelMapper: (data, _) =>
                        '₹${data.value.toStringAsFixed(0)}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTrendChart() {
    if (_fuelExpenses.isEmpty && _generalExpenses.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group expenses by month
    final monthlyData = <DateTime, double>{};

    for (final expense in _fuelExpenses) {
      final month = DateTime(expense.date.year, expense.date.month);
      monthlyData[month] = (monthlyData[month] ?? 0) + expense.amountPaid;
    }

    for (final expense in _generalExpenses) {
      final month = DateTime(expense.date.year, expense.date.month);
      monthlyData[month] = (monthlyData[month] ?? 0) + expense.amount;
    }

    final sortedData = monthlyData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final data = sortedData.map((e) => _MonthlyData(e.key, e.value)).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Spending Trend',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: SfCartesianChart(
                primaryXAxis: DateTimeAxis(
                  dateFormat: DateFormat('MMM'),
                  intervalType: DateTimeIntervalType.months,
                ),
                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat.compact(),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries<dynamic, dynamic>>[
                  SplineAreaSeries<_MonthlyData, DateTime>(
                    dataSource: data,
                    xValueMapper: (data, _) => data.month,
                    yValueMapper: (data, _) => data.amount,
                    color: Colors.blue.withValues(alpha: 0.3),
                    borderColor: Colors.blue,
                    markerSettings: const MarkerSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFuelEfficiencyChart() {
    if (_fuelExpenses.isEmpty) return const SizedBox.shrink();

    // Group by vehicle and calculate efficiency
    final vehicleEfficiency = <int, List<FuelExpense>>{};

    for (final expense in _fuelExpenses) {
      vehicleEfficiency.putIfAbsent(expense.vehicleId, () => []).add(expense);
    }

    final data = <_FuelEfficiencyData>[];

    for (final entry in vehicleEfficiency.entries) {
      final vehicle = _vehicles.firstWhere(
        (v) => v.id == entry.key,
        orElse: () => _vehicles.first,
      );

      final expenses = entry.value..sort((a, b) => a.date.compareTo(b.date));

      for (int i = 1; i < expenses.length; i++) {
        final current = expenses[i];
        final previous = expenses[i - 1];

        final kmDriven = current.odometerReading - previous.odometerReading;
        final liters = current.liters;

        if (kmDriven > 0 && liters > 0) {
          final efficiency = kmDriven / liters;
          data.add(_FuelEfficiencyData(current.date, efficiency, vehicle.name));
        }
      }
    }

    if (data.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fuel Efficiency Over Time',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: SfCartesianChart(
                primaryXAxis: DateTimeAxis(
                  dateFormat: DateFormat('MMM dd'),
                ),
                primaryYAxis: const NumericAxis(
                  title: AxisTitle(text: 'km/L'),
                ),
                legend: const Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: _buildEfficiencySeriesByVehicle(data),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<CartesianSeries<dynamic, dynamic>> _buildEfficiencySeriesByVehicle(
    List<_FuelEfficiencyData> data,
  ) {
    final groupedData = <String, List<_FuelEfficiencyData>>{};

    for (final item in data) {
      groupedData.putIfAbsent(item.vehicleName, () => []).add(item);
    }

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];
    int colorIndex = 0;

    return groupedData.entries.map((entry) {
      final color = colors[colorIndex % colors.length];
      colorIndex++;

      return LineSeries<_FuelEfficiencyData, DateTime>(
        name: entry.key,
        dataSource: entry.value,
        xValueMapper: (data, _) => data.date,
        yValueMapper: (data, _) => data.efficiency,
        color: color,
        markerSettings: const MarkerSettings(isVisible: true),
      );
    }).toList();
  }

  Widget _buildCategorySpendingChart() {
    if (_generalExpenses.isEmpty) return const SizedBox.shrink();

    final categoryData = <ExpenseCategory, double>{};

    for (final expense in _generalExpenses) {
      categoryData[expense.category] =
          (categoryData[expense.category] ?? 0) + expense.amount;
    }

    final sortedData = categoryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final data = sortedData
        .take(5)
        .map(
          (e) => _CategoryData(e.key.name, e.value),
        )
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Spending Categories',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: SfCartesianChart(
                primaryXAxis: const CategoryAxis(),
                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat.compact(),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries<dynamic, dynamic>>[
                  ColumnSeries<_CategoryData, String>(
                    dataSource: data,
                    xValueMapper: (data, _) => data.category,
                    yValueMapper: (data, _) => data.amount,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.lightBlueAccent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
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

  Widget _buildVehicleComparisonChart() {
    if (_vehicles.length < 2 || _fuelExpenses.isEmpty) {
      return const SizedBox.shrink();
    }

    final vehicleData = <int, double>{};

    for (final expense in _fuelExpenses) {
      vehicleData[expense.vehicleId] =
          (vehicleData[expense.vehicleId] ?? 0) + expense.amountPaid;
    }

    for (final expense in _generalExpenses) {
      if (expense.vehicleId != null) {
        vehicleData[expense.vehicleId!] =
            (vehicleData[expense.vehicleId!] ?? 0) + expense.amount;
      }
    }

    final data = vehicleData.entries.map((e) {
      final vehicle = _vehicles.firstWhere(
        (v) => v.id == e.key,
        orElse: () => _vehicles.first,
      );
      return _VehicleData(vehicle.name, e.value);
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vehicle Comparison',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: SfCartesianChart(
                primaryXAxis: const CategoryAxis(),
                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat.compact(),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries<dynamic, dynamic>>[
                  BarSeries<_VehicleData, String>(
                    dataSource: data,
                    xValueMapper: (data, _) => data.vehicleName,
                    yValueMapper: (data, _) => data.amount,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                    gradient: const LinearGradient(
                      colors: [Colors.orange, Colors.deepOrange],
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

  Future<void> _showFilterDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _FilterDialog(
        startDate: _startDate,
        endDate: _endDate,
        vehicles: _vehicles,
        selectedVehicleId: _selectedVehicleId,
      ),
    );

    if (result != null) {
      setState(() {
        _startDate = result['startDate'];
        _endDate = result['endDate'];
        _selectedVehicleId = result['vehicleId'];
      });
      // Await to ensure data loaded before any subsequent UI operations
      await _loadData();
    }
  }

  Future<List<_CostPerKmData>> _fetchCostPerKmStats(
    List<Vehicle> vehicles,
  ) async {
    final stats = <_CostPerKmData>[];
    for (final vehicle in vehicles) {
      final id = vehicle.id;
      if (id == null) continue;
      final data = await _db.getVehicleCostStats(id);
      if (data == null) continue;
      final costPerKm = data['cost_per_km'] ?? 0.0;
      if (costPerKm <= 0) continue;
      stats.add(
        _CostPerKmData(
          vehicleName: vehicle.name,
          costPerKm: costPerKm,
          distance: data['distance'] ?? 0.0,
          totalSpend: data['total_spend'] ?? 0.0,
        ),
      );
    }
    stats.sort((a, b) => a.costPerKm.compareTo(b.costPerKm));
    return stats;
  }

  List<_InsightMessage> _generateInsights(
    List<FuelExpense> allFuel,
    List<GeneralExpense> allGeneral,
    List<FuelExpense> currentFuel,
    List<GeneralExpense> currentGeneral,
  ) {
    final insights = <_InsightMessage>[];
    final priceInsight = _buildFuelPriceInsight(allFuel);
    if (priceInsight != null) {
      insights.add(priceInsight);
    }
    final spendInsight = _buildSpendTrendInsight(
      allFuel,
      allGeneral,
      currentFuel,
      currentGeneral,
    );
    if (spendInsight != null) {
      insights.add(spendInsight);
    }
    return insights;
  }

  _InsightMessage? _buildFuelPriceInsight(List<FuelExpense> allFuel) {
    if (allFuel.length < 4) return null;
    final sorted = [...allFuel]..sort((a, b) => a.date.compareTo(b.date));
    final recent = sorted.sublist(sorted.length - 3);
    final previousEnd = sorted.length - 3;
    final previousStart = (previousEnd - 3).clamp(0, previousEnd);
    final previous = sorted.sublist(previousStart, previousEnd);
    if (previous.isEmpty) return null;

    final recentAvg = _averageFuelPrice(recent);
    final previousAvg = _averageFuelPrice(previous);
    if (previousAvg == 0) return null;

    final change = ((recentAvg - previousAvg) / previousAvg) * 100;
    if (change.abs() < 1) {
      return _InsightMessage(
        title: 'Fuel price stable',
        description:
            'Average price per liter stayed within 1% of previous fill-ups.',
        icon: Icons.show_chart,
        color: Colors.blueGrey,
      );
    }

    final rising = change > 0;
    return _InsightMessage(
      title: rising ? 'Fuel prices trending up' : 'Fuel prices easing',
      description: rising
          ? 'Average price increased by ${change.abs().toStringAsFixed(1)}%. Consider budgeting for higher refills.'
          : 'Average price dropped by ${change.abs().toStringAsFixed(1)}%. Good window to top up.',
      icon: rising ? Icons.trending_up : Icons.trending_down,
      color: rising ? Colors.red : Colors.green,
    );
  }

  _InsightMessage? _buildSpendTrendInsight(
    List<FuelExpense> allFuel,
    List<GeneralExpense> allGeneral,
    List<FuelExpense> currentFuel,
    List<GeneralExpense> currentGeneral,
  ) {
    final currentTotal =
        currentFuel.fold<double>(0, (sum, e) => sum + e.amountPaid) +
            currentGeneral.fold<double>(0, (sum, e) => sum + e.amount);

    final rangeDays = _endDate.difference(_startDate).inDays + 1;
    if (rangeDays <= 0) return null;

    final previousStart = _startDate.subtract(Duration(days: rangeDays));
    final previousEnd = _startDate.subtract(const Duration(days: 1));
    if (previousEnd.isBefore(previousStart)) return null;

    final previousFuelTotal = allFuel
        .where(
          (expense) => _isWithinRange(expense.date, previousStart, previousEnd),
        )
        .fold<double>(0, (sum, e) => sum + e.amountPaid);
    final previousGeneralTotal = allGeneral
        .where(
          (expense) => _isWithinRange(expense.date, previousStart, previousEnd),
        )
        .fold<double>(0, (sum, e) => sum + e.amount);
    final previousTotal = previousFuelTotal + previousGeneralTotal;

    if (previousTotal == 0) {
      if (currentTotal == 0) return null;
      return _InsightMessage(
        title: 'New spending pattern',
        description:
            '${_currencyFormat.format(currentTotal)} recorded for this window. Track another cycle to compare trends.',
        icon: Icons.new_releases_outlined,
        color: Colors.indigo,
      );
    }

    final change = ((currentTotal - previousTotal) / previousTotal) * 100;
    if (change.abs() < 5) {
      return _InsightMessage(
        title: 'Spending steady',
        description:
            'Current period (${_currencyFormat.format(currentTotal)}) is within ±5% of the previous (${_currencyFormat.format(previousTotal)}).',
        icon: Icons.balance,
        color: Colors.blueGrey,
      );
    }

    final increased = change > 0;
    return _InsightMessage(
      title: increased
          ? 'Spending up ${change.abs().toStringAsFixed(1)}%'
          : 'Spending down ${change.abs().toStringAsFixed(1)}%',
      description:
          'Now: ${_currencyFormat.format(currentTotal)} · Previous: ${_currencyFormat.format(previousTotal)}.',
      icon: increased ? Icons.warning_amber_rounded : Icons.savings_outlined,
      color: increased ? Colors.deepOrange : Colors.green,
    );
  }

  bool _isWithinRange(DateTime date, DateTime start, DateTime end) {
    return !date.isBefore(start) && !date.isAfter(end);
  }

  double _averageFuelPrice(List<FuelExpense> expenses) {
    if (expenses.isEmpty) return 0;
    final totalLiters = expenses.fold<double>(0, (sum, e) => sum + e.liters);
    if (totalLiters == 0) return 0;
    final totalAmount =
        expenses.fold<double>(0, (sum, e) => sum + e.amountPaid);
    return totalAmount / totalLiters;
  }
}

// Data classes for charts
class _ChartData {
  _ChartData(this.category, this.value, this.color);
  final String category;
  final double value;
  final Color color;
}

class _MonthlyData {
  _MonthlyData(this.month, this.amount);
  final DateTime month;
  final double amount;
}

class _FuelEfficiencyData {
  _FuelEfficiencyData(this.date, this.efficiency, this.vehicleName);
  final DateTime date;
  final double efficiency;
  final String vehicleName;
}

class _CategoryData {
  _CategoryData(this.category, this.amount);
  final String category;
  final double amount;
}

class _VehicleData {
  _VehicleData(this.vehicleName, this.amount);
  final String vehicleName;
  final double amount;
}

class _CostPerKmData {
  _CostPerKmData({
    required this.vehicleName,
    required this.costPerKm,
    required this.distance,
    required this.totalSpend,
  });
  final String vehicleName;
  final double costPerKm;
  final double distance;
  final double totalSpend;
}

class _InsightMessage {
  _InsightMessage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

// Filter dialog
class _FilterDialog extends StatefulWidget {
  const _FilterDialog({
    required this.startDate,
    required this.endDate,
    required this.vehicles,
    this.selectedVehicleId,
  });
  final DateTime startDate;
  final DateTime endDate;
  final List<Vehicle> vehicles;
  final int? selectedVehicleId;

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  int? _selectedVehicleId;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _selectedVehicleId = widget.selectedVehicleId;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Analytics'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Date Range',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Start Date'),
              subtitle: Text(DateFormat('MMM dd, yyyy').format(_startDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: _endDate,
                );
                if (date != null) {
                  setState(() => _startDate = date);
                }
              },
            ),
            ListTile(
              title: const Text('End Date'),
              subtitle: Text(DateFormat('MMM dd, yyyy').format(_endDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate,
                  firstDate: _startDate,
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _endDate = date);
                }
              },
            ),
            const Divider(),
            const Text(
              'Vehicle',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              initialValue: _selectedVehicleId,
              decoration: const InputDecoration(
                labelText: 'Select Vehicle',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(child: Text('All Vehicles')),
                ...widget.vehicles.map(
                  (v) => DropdownMenuItem(
                    value: v.id,
                    child: Text(v.name),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _selectedVehicleId = value);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _startDate =
                            DateTime.now().subtract(const Duration(days: 7));
                        _endDate = DateTime.now();
                      });
                    },
                    child: const Text('Last 7 days'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _startDate =
                            DateTime.now().subtract(const Duration(days: 30));
                        _endDate = DateTime.now();
                      });
                    },
                    child: const Text('Last 30 days'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'startDate': _startDate,
              'endDate': _endDate,
              'vehicleId': _selectedVehicleId,
            });
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
