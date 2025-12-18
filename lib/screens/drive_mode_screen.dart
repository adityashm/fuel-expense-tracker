import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vehicle.dart';
import '../providers/device_provider.dart';
import '../services/database_service.dart';
import 'add_fuel_expense_screen.dart';
import 'trips_screen.dart';

class DriveModeScreen extends StatefulWidget {
  const DriveModeScreen({super.key});

  @override
  State<DriveModeScreen> createState() => _DriveModeScreenState();
}

class _DriveModeScreenState extends State<DriveModeScreen> {
  late Future<_DriveSnapshot> _snapshotFuture;
  String? _deviceId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<DeviceProvider>();
    _deviceId = provider.currentDeviceId;
    _snapshotFuture = _loadSnapshot();
  }

  Future<_DriveSnapshot> _loadSnapshot() async {
    final db = DatabaseService.instance;
    final vehicles = await db.getAllVehicles();
    vehicles.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final primary = vehicles.isNotEmpty ? vehicles.first : null;

    Map<String, double> averages = {};
    final primaryId = primary?.id;
    if (primaryId != null) {
      averages = await db.calculateFuelAverages(primaryId);
    }

    double todaysSpend = 0;
    final today = DateTime.now();
    final fuelExpenses = await db.getAllFuelExpenses();
    for (final expense in fuelExpenses) {
      if (_isSameDay(expense.date, today)) {
        todaysSpend += expense.amountPaid;
      }
    }
    final generalExpenses = await db.getAllGeneralExpenses();
    for (final expense in generalExpenses) {
      if (_isSameDay(expense.date, today)) {
        todaysSpend += expense.amount;
      }
    }

    Map<String, dynamic>? nextReminder;
    Map<String, dynamic>? activeTrip;
    if (_deviceId != null) {
      final reminders = await db.getRemindersForDevice(_deviceId!);
      reminders.sort(
        (a, b) => (a['due_date'] as String).compareTo(b['due_date'] as String),
      );
      nextReminder = reminders.firstWhere(
        (r) => (r['is_completed'] as int) == 0,
        orElse: () => <String, dynamic>{},
      );
      if (nextReminder.isEmpty) {
        nextReminder = null;
      }
      activeTrip = await db.getActiveTripForDevice(_deviceId!);
    }

    return _DriveSnapshot(
      primaryVehicle: primary,
      averages: averages,
      todaysSpend: todaysSpend,
      nextReminder: nextReminder,
      activeTrip: activeTrip,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _refresh() async {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drive Mode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<_DriveSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  data.primaryVehicle != null
                      ? data.primaryVehicle!.name
                      : 'No vehicle registered',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                _MetricTile(
                  label: 'Today\'s spend',
                  value: data.todaysSpend > 0
                      ? '₹${data.todaysSpend.toStringAsFixed(0)}'
                      : 'No expenses yet',
                  icon: Icons.currency_rupee,
                ),
                const SizedBox(height: 12),
                _MetricTile(
                  label: 'Lifetime average',
                  value: data.averages['lifetime_average'] != null
                      ? '${data.averages['lifetime_average']!.toStringAsFixed(1)} km/L'
                      : 'Need more fillups',
                  icon: Icons.speed,
                ),
                const SizedBox(height: 12),
                _MetricTile(
                  label: 'Next reminder',
                  value: data.nextReminder != null
                      ? '${data.nextReminder!['title']} on ${_formatDate(data.nextReminder!['due_date'] as String)}'
                      : 'You are all caught up',
                  icon: Icons.alarm,
                ),
                const SizedBox(height: 12),
                if (data.activeTrip != null)
                  _MetricTile(
                    label: 'Active trip',
                    value:
                        '${data.activeTrip!['start_location'] ?? 'Unknown'} → ${data.activeTrip!['end_location'] ?? '—'}',
                    icon: Icons.route,
                  ),
                const SizedBox(height: 24),
                Text(
                  'Quick actions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: data.primaryVehicle == null
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddFuelExpenseScreen(
                                      vehicle: data.primaryVehicle!,
                                    ),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.local_gas_station),
                        label: const Text('Log fuel'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TripsScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.alt_route),
                        label: const Text('Trips'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String date) {
    try {
      final parsed = DateTime.parse(date);
      return '${parsed.day}/${parsed.month}';
    } catch (_) {
      return date;
    }
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriveSnapshot {
  _DriveSnapshot({
    required this.primaryVehicle,
    required this.averages,
    required this.todaysSpend,
    this.nextReminder,
    this.activeTrip,
  });
  final Vehicle? primaryVehicle;
  final Map<String, double> averages;
  final double todaysSpend;
  final Map<String, dynamic>? nextReminder;
  final Map<String, dynamic>? activeTrip;
}
