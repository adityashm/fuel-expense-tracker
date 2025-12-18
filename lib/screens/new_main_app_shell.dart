import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vehicle.dart';
import '../providers/vehicle_provider.dart';
import '../utils/app_design_system.dart';
import '../utils/app_localizations.dart';
import '../widgets/unified_expense_form.dart';
import 'analytics_tab_shell_screen.dart';
import 'household_tab_shell_screen.dart';
import 'new_home_dashboard_screen.dart';
import 'receipt_scanner_screen.dart';
import 'settings_screen.dart';
import 'vehicles_screen.dart';
import 'voice_entry_screen.dart';

class NewMainAppShell extends StatefulWidget {
  const NewMainAppShell({super.key});

  @override
  State<NewMainAppShell> createState() => _NewMainAppShellState();
}

class _NewMainAppShellState extends State<NewMainAppShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isFabExpanded = false;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabRotation;
  late Animation<double> _fabBackdropOpacity;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabRotation =
        Tween<double>(begin: 0, end: 0.125).animate(_fabAnimationController);
    _fabBackdropOpacity =
        Tween<double>(begin: 0, end: 0.7).animate(_fabAnimationController);
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
      }
    });
  }

  void _closeFab() {
    if (_isFabExpanded) {
      setState(() {
        _isFabExpanded = false;
        _fabAnimationController.reverse();
      });
    }
  }

  void _refreshData() {
    // Trigger data reload in home dashboard
    setState(() {
      // This will cause the home dashboard to rebuild and fetch fresh data
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    final screens = <Widget>[
      const NewHomeDashboardScreen(),
      const VehiclesScreen(),
      const HouseholdTabShellScreen(),
      const AnalyticsTabShellScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          // Main content
          IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          // Accessibility: Announce current tab (basic semantics placeholder)
          Positioned(
            left: -9999,
            top: -9999,
            child: Semantics(
              label: 'Current tab index ${_currentIndex + 1}',
              container: true,
              child: const SizedBox.shrink(),
            ),
          ),

          // FAB backdrop
          if (_isFabExpanded)
            GestureDetector(
              onTap: _closeFab,
              child: AnimatedBuilder(
                animation: _fabBackdropOpacity,
                builder: (context, child) {
                  return Container(
                    color: Colors.black.withValues(alpha: _fabBackdropOpacity.value),
                  );
                },
              ),
            ),

          // FAB speed dial menu
          if (_isFabExpanded)
            Positioned(
              right: 16,
              bottom: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSpeedDialItem(
                    icon: Icons.local_gas_station,
                    label: localizations.translate('add_fuel'),
                    color: AppColors.fuelExpense,
                    onTap: () {
                      _closeFab();
                      _showVehicleSelectionSheet(ExpenseFormType.fuel);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSpeedDialItem(
                    icon: Icons.build,
                    label: localizations.translate('vehicle_expense'),
                    color: AppColors.generalExpense,
                    onTap: () {
                      _closeFab();
                      _showVehicleSelectionSheet(
                          ExpenseFormType.vehicleGeneral,);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSpeedDialItem(
                    icon: Icons.home,
                    label: localizations.translate('household_expense'),
                    color: AppColors.householdExpense,
                    onTap: () async {
                      _closeFab();
                      try {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UnifiedExpenseForm(
                                expenseType: ExpenseFormType.household,),
                          ),
                        );
                        // Refresh data if expense was saved
                        if (mounted && result == true) {
                          _refreshData();
                        }
                      } catch (e) {
                        if (mounted) {
                          debugPrint('Error navigating to household expense: $e');
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSpeedDialItem(
                    icon: Icons.mic,
                    label: localizations.translate('voice_entry'),
                    color: AppColors.success,
                    onTap: () async {
                      _closeFab();
                      try {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const VoiceEntryScreen(),
                          ),
                        );
                      } catch (e) {
                        if (mounted) {
                          debugPrint('Error navigating to voice entry: $e');
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSpeedDialItem(
                    icon: Icons.camera_alt,
                    label: localizations.translate('scan_receipt'),
                    color: AppColors.info,
                    onTap: () async {
                      _closeFab();
                      try {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReceiptScannerScreen(),
                          ),
                        );
                      } catch (e) {
                        if (mounted) {
                          debugPrint('Error navigating to receipt scanner: $e');
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          _closeFab();
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        destinations: [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            selectedIcon: Icon(
              Icons.home_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.directions_car_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            selectedIcon: Icon(
              Icons.directions_car_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: localizations.translate('vehicles'),
          ),
          NavigationDestination(
            icon: Icon(
              Icons.home_work_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            selectedIcon: Icon(
              Icons.home_work_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: 'Household',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.analytics_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            selectedIcon: Icon(
              Icons.analytics_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: localizations.translate('analytics'),
          ),
          NavigationDestination(
            icon: Icon(
              Icons.more_horiz_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            selectedIcon: Icon(
              Icons.more_horiz_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: 'More',
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _fabRotation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  spreadRadius: -2,
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: _toggleFab,
              backgroundColor: Theme.of(context).colorScheme.primary,
              elevation: 0,
              shape: const CircleBorder(),
              child: Transform.rotate(
                angle: _fabRotation.value * 3.14159 * 2,
                child: Icon(
                  _isFabExpanded ? Icons.close_rounded : Icons.add_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 28,
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildSpeedDialItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: label,
      hint: 'Double tap to $label',
      child: TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label with modern styling
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spacing14,
              vertical: AppSpacing.spacing10,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Modern FAB mini button with gradient
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  void _showVehicleSelectionSheet(ExpenseFormType type) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
    
    // Filter vehicles based on expense type
    final availableVehicles = type == ExpenseFormType.fuel
        ? vehicleProvider.vehicles.where((v) => !v.isElectric).toList()
        : vehicleProvider.vehicles;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                localizations.translate('select_vehicle'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                type == ExpenseFormType.fuel
                    ? localizations.translate('choose_fuel_vehicle_hint')
                    : localizations.translate('choose_vehicle_hint'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              // Check if there are available vehicles
              if (availableVehicles.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        type == ExpenseFormType.fuel
                            ? localizations.translate('no_fuel_vehicles_message')
                            : localizations.translate('no_vehicles_message'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                // List of available vehicles
                ...availableVehicles.map(
                  (vehicle) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          vehicle.vehicleType == VehicleType.bike
                              ? Icons.two_wheeler_rounded
                              : Icons.directions_car_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(
                        vehicle.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        vehicle.registrationNumber,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onTap: () async {
                        if (!mounted) return;
                        Navigator.pop(context);
                        try {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UnifiedExpenseForm(
                                expenseType: type,
                                preselectedVehicleId: vehicle.id,
                              ),
                            ),
                          );
                          if (mounted && result == true) {
                            _refreshData();
                          }
                        } catch (e) {
                          if (mounted) {
                            debugPrint('Error navigating to expense form: $e');
                          }
                        }
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(localizations.translate('cancel')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
