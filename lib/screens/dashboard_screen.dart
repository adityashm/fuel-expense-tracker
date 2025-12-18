import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/device_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/user_provider.dart';
import '../providers/vehicle_provider.dart';
import '../utils/app_localizations.dart';
import 'analytics_screen.dart';
import 'comparison_dashboard_screen.dart';
import 'expenses_screen.dart';
import 'household_dashboard_screen.dart';
import 'settings_screen.dart';
import 'vehicles_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Avoid setState/notify during build by scheduling after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final vehicleProvider =
        Provider.of<VehicleProvider>(context, listen: false);
    final expenseProvider =
        Provider.of<ExpenseProvider>(context, listen: false);

    // Load using active device when available
    final deviceId = deviceProvider.currentDeviceId;
    if (deviceId != null) {
      await vehicleProvider.loadVehicles(deviceId);
      await expenseProvider.loadFuelExpenses();
      await expenseProvider.loadGeneralExpenses();
      await expenseProvider.loadHouseholdExpenses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final userProvider = Provider.of<UserProvider>(context);

    final screens = [
      const VehiclesScreen(),
      const ExpensesScreen(),
      const AnalyticsScreen(),
      const ComparisonDashboardScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('app_name')),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Household Expenses',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HouseholdDashboardScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              userProvider.clearCurrentUser();
            },
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.directions_car),
            label: localizations.translate('vehicles'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt_long),
            label: localizations.translate('expenses'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.analytics),
            label: localizations.translate('analytics'),
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.compare_arrows),
            label: 'Comparison',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: localizations.translate('settings'),
          ),
        ],
      ),
    );
  }
}
