import 'package:flutter/material.dart';

import '../widgets/animated_fade_in.dart';
import 'family_management_screen.dart';
import 'household_dashboard_screen.dart';
import 'household_expenses_tab.dart';
import 'recurring_expenses_screen.dart';

/// Composite Household screen with 3 tabs focused on family expense tracking
/// (Dashboard, Expenses, Recurring) - no payment splitting, just tracking what family spent
class HouseholdTabShellScreen extends StatefulWidget {
  const HouseholdTabShellScreen({super.key});

  @override
  State<HouseholdTabShellScreen> createState() =>
      _HouseholdTabShellScreenState();
}

class _HouseholdTabShellScreenState extends State<HouseholdTabShellScreen>
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

  void _openFamilyManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FamilyManagementScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Expenses'),
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurface.withValues(alpha: .6),
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(text: 'Dashboard', icon: Icon(Icons.dashboard)),
            Tab(text: 'Expenses', icon: Icon(Icons.receipt_long)),
            Tab(text: 'Recurring', icon: Icon(Icons.autorenew)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Manage Family',
            onPressed: _openFamilyManagement,
            icon: const Icon(Icons.family_restroom),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AnimatedFadeIn(child: HouseholdDashboardScreen()),
          AnimatedFadeIn(child: HouseholdExpensesTab()),
          AnimatedFadeIn(child: RecurringExpensesScreen()),
        ],
      ),
    );
  }
}
