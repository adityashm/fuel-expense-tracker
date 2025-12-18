import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/fuel_expense.dart';
import '../models/general_expense.dart';
import '../providers/device_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/user_provider.dart';
import '../providers/vehicle_provider.dart';
import '../utils/app_design_system.dart';
import '../utils/app_localizations.dart';
import '../utils/haptic_helper.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/expense_card_widget.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/vehicle_summary_card.dart';
import 'add_household_expense_screen.dart';
import 'receipt_scanner_screen.dart';
import 'trips_screen.dart';
import 'vehicles_screen.dart';

class NewHomeDashboardScreen extends StatefulWidget {
  const NewHomeDashboardScreen({super.key});

  @override
  State<NewHomeDashboardScreen> createState() => _NewHomeDashboardScreenState();
}

class _NewHomeDashboardScreenState extends State<NewHomeDashboardScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final vehicleProvider =
        Provider.of<VehicleProvider>(context, listen: false);
    final expenseProvider =
        Provider.of<ExpenseProvider>(context, listen: false);

    final deviceId = deviceProvider.currentDeviceId;
    if (deviceId != null) {
      await Future.wait([
        vehicleProvider.loadVehicles(deviceId),
        expenseProvider.loadFuelExpenses(),
        expenseProvider.loadGeneralExpenses(),
        expenseProvider.loadHouseholdExpenses(),
      ]);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  Future<Map<String, double>> _getTotalsFromDatabase(ExpenseProvider provider) async {
    final fuel = await provider.getTotalFuelExpensesFromDb();
    final household = await provider.getTotalHouseholdExpensesFromDb();
    final general = await provider.getTotalGeneralExpensesFromDb();
    return {'fuel': fuel, 'household': household, 'general': general};
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final userProvider = Provider.of<UserProvider>(context);
    final theme = Theme.of(context);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : CustomRefreshIndicator(
                onRefresh: _refreshData,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Modern App Bar with user greeting
                    SliverAppBar(
                      floating: true,
                      snap: true,
                      backgroundColor: theme.scaffoldBackgroundColor,
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      expandedHeight: 80,
                      flexibleSpace: FlexibleSpaceBar(
                        background: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.person_rounded,
                                  color: theme.colorScheme.onPrimary,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hello, ${userProvider.currentUser?.name ?? "User"}! 👋',
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat('EEEE, MMM dd').format(now),
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: Badge(
                                    smallSize: 8,
                                    backgroundColor: AppColors.error,
                                    child: Icon(
                                      Icons.notifications_outlined,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  onPressed: () {
                                    // Navigate to notifications/reminders
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Notifications feature coming soon!',),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Content
                    SliverPadding(
                      padding: const EdgeInsets.all(AppSpacing.spacing16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Monthly Spending Summary Card
                          _buildMonthlySpendingCard(context, localizations),
                          const SizedBox(height: AppSpacing.spacing24),

                          // Quick Actions
                          _buildQuickActions(context, localizations),
                          const SizedBox(height: AppSpacing.spacing24),

                          // My Vehicles Section
                          _buildVehiclesSection(context, localizations),
                          const SizedBox(height: AppSpacing.spacing24),

                          // Recent Expenses Section
                          _buildRecentExpensesSection(context, localizations),
                          const SizedBox(height: AppSpacing.spacing24),

                          // Insights Section
                          _buildInsightsSection(context, localizations),
                          const SizedBox(height: AppSpacing.spacing48),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 80),
          // Shimmer for spending card
          ShimmerLoading(
            width: MediaQuery.of(context).size.width - 32,
            height: 220,
            borderRadius: AppBorderRadius.xxLarge,
          ),
          const SizedBox(height: 24),
          // Shimmer for quick actions
          const Row(
            children: [
              Expanded(
                child: ShimmerLoading(
                  width: double.infinity,
                  height: 100,
                  borderRadius: AppBorderRadius.large,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ShimmerLoading(
                  width: double.infinity,
                  height: 100,
                  borderRadius: AppBorderRadius.large,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ShimmerLoading(
                  width: double.infinity,
                  height: 100,
                  borderRadius: AppBorderRadius.large,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Shimmer for expense cards
          ...List.generate(
            3,
            (index) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: ExpenseCardShimmer(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySpendingCard(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    final theme = Theme.of(context);

    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, child) {
        return FutureBuilder<Map<String, double>>(
          future: _getTotalsFromDatabase(expenseProvider),
          builder: (context, snapshot) {
            final data = snapshot.data ?? {'fuel': 0, 'household': 0, 'general': 0};
            final fuelTotal = data['fuel'] ?? 0;
            final householdTotal = data['household'] ?? 0;
            final vehicleGeneralTotal = data['general'] ?? 0;
            final total = fuelTotal + vehicleGeneralTotal + householdTotal;

        return Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppBorderRadius.xxLarge),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 12),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -50,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(AppSpacing.spacing24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          "This Month's Spending",
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.spacing24),
                    Text(
                      localizations.formatCurrency(total),
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spacing8),
                    Text(
                      'Total across all categories',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spacing24),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.spacing16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppBorderRadius.large),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildExpenseTypeChip(
                            icon: Icons.local_gas_station_rounded,
                            label: 'Fuel',
                            amount: fuelTotal,
                            color: AppColors.fuelExpense,
                            localizations: localizations,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          _buildExpenseTypeChip(
                            icon: Icons.home_rounded,
                            label: 'Home',
                            amount: householdTotal,
                            color: AppColors.householdExpense,
                            localizations: localizations,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          _buildExpenseTypeChip(
                            icon: Icons.build_rounded,
                            label: 'Other',
                            amount: vehicleGeneralTotal,
                            color: AppColors.generalExpense,
                            localizations: localizations,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
          },
        );
      },
    );
  }

  Widget _buildExpenseTypeChip({
    required IconData icon,
    required String label,
    required double amount,
    required Color color,
    required AppLocalizations localizations,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          localizations.formatCurrency(amount),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppSpacing.spacing12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: QuickActionButton(
                icon: Icons.local_gas_station,
                label: 'Fuel',
                color: AppColors.fuelExpense,
                onTap: () {
                  HapticHelper.buttonTap();
                  // Navigate to vehicles screen to add fuel expense
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VehiclesScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.spacing12),
            Expanded(
              child: QuickActionButton(
                icon: Icons.home,
                label: 'Household',
                color: AppColors.householdExpense,
                onTap: () async {
                  HapticHelper.buttonTap();
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddHouseholdExpenseScreen(),
                    ),
                  );
                  // Refresh data if expense was saved
                  if (result == true && mounted) {
                    await _refreshData();
                  }
                },
              ),
            ),
            const SizedBox(width: AppSpacing.spacing12),
            Expanded(
              child: QuickActionButton(
                icon: Icons.camera_alt,
                label: 'Scan',
                color: AppColors.info,
                onTap: () {
                  HapticHelper.buttonTap();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReceiptScannerScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spacing12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: QuickActionButton(
                icon: Icons.route,
                label: 'Trips',
                color: Colors.blue,
                onTap: () {
                  HapticHelper.buttonTap();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TripsScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.spacing12),
            Expanded(
              child: QuickActionButton(
                icon: Icons.dashboard,
                label: 'Analytics',
                color: Colors.purple,
                onTap: () {
                  HapticHelper.buttonTap();
                  // Navigate to analytics - can switch to analytics tab or push screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Use the Analytics tab below for detailed insights',),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.spacing12),
            // Empty spacer to maintain grid
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildVehiclesSection(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return Consumer<VehicleProvider>(
      builder: (context, vehicleProvider, child) {
        final vehicles = vehicleProvider.vehicles.take(2).toList();

        if (vehicles.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Vehicles',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppSpacing.spacing12),
              _buildEmptyState(
                context,
                icon: Icons.directions_car,
                title: 'No vehicles yet',
                subtitle: 'Add your first vehicle to get started',
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Vehicles (${vehicleProvider.vehicles.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to vehicles tab
                    // This will be handled by parent navigation
                  },
                  child: const Text('View All →'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.spacing12),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: vehicles.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < vehicles.length - 1
                          ? AppSpacing.spacing12
                          : 0,
                    ),
                    child: VehicleSummaryCard(vehicle: vehicles[index]),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentExpensesSection(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, child) {
        // Combine recent expenses from all types
        final recentExpenses = _getCombinedRecentExpenses(expenseProvider);

        if (recentExpenses.isEmpty) {
          return _buildEmptyState(
            context,
            icon: Icons.receipt_long,
            title: 'No recent expenses',
            subtitle: 'Add your first expense to get started',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Expenses',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to expenses tab
                  },
                  child: const Text('View All →'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.spacing12),
            ...recentExpenses.asMap().entries.map(
                  (entry) => AnimatedCard(
                    delay: Duration(milliseconds: entry.key * 100),
                    child: Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.spacing8),
                      child: ExpenseCardWidget(expense: entry.value),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  List<dynamic> _getCombinedRecentExpenses(ExpenseProvider provider) {
    final allExpenses = <dynamic>[
      ...provider.fuelExpenses,
      ...provider.generalExpenses.where((e) => !e.isHouseholdExpense),
      ...provider.householdExpenses,
    ]..sort((a, b) {
        final dateA = a is FuelExpense ? a.date : (a as GeneralExpense).date;
        final dateB = b is FuelExpense ? b.date : (b as GeneralExpense).date;
        return dateB.compareTo(dateA);
      });

    return allExpenses.take(5).toList();
  }

  Widget _buildInsightsSection(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Insights for You',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppSpacing.spacing12),
        _buildInsightCard(
          context,
          icon: Icons.lightbulb_outline,
          title: 'Spending Tip',
          message:
              'Your fuel expenses are 15% higher than last month. Consider carpooling or using public transport.',
          color: AppColors.warning,
        ),
      ],
    );
  }

  Widget _buildInsightCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.spacing16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: AppSpacing.spacing14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.spacing32,
        horizontal: AppSpacing.spacing24,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.spacing20),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.spacing8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
