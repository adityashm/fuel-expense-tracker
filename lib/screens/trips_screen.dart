import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/trip.dart';
import '../providers/device_provider.dart';
import '../providers/trip_provider.dart';
import '../providers/vehicle_provider.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTrips();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreTrips();
    }
  }

  Future<void> _loadMoreTrips() async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadTrips() async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    await tripProvider.loadTrips();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _showStatistics,
          ),
        ],
      ),
      body: Consumer<TripProvider>(
        builder: (context, tripProvider, child) {
          if (tripProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              if (tripProvider.hasActiveTrip)
                _buildActiveTripCard(tripProvider.activeTrip!),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: FutureBuilder<Map<String, dynamic>>(
                  future: tripProvider.getTripStatistics(),
                  builder: (context, snapshot) {
                    final avg =
                        (snapshot.data?['avg_distance'] ?? 0.0) as double;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.straighten),
                        title: const Text('Average distance per trip'),
                        trailing: Text(
                          '${avg.toStringAsFixed(1)} km',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: tripProvider.trips.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.route,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Trips',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            const Text('Tap + to start tracking a trip'),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: tripProvider.trips.length +
                                  (_isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == tripProvider.trips.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                final trip = tripProvider.trips[index];
                                return _buildTripCard(trip);
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<TripProvider>(
        builder: (context, tripProvider, child) {
          return FloatingActionButton.extended(
            onPressed: tripProvider.hasActiveTrip ? null : _startNewTrip,
            icon: const Icon(Icons.add_location),
            label: const Text('Start Trip'),
            backgroundColor: tripProvider.hasActiveTrip ? Colors.grey : null,
          );
        },
      ),
    );
  }

  Widget _buildActiveTripCard(Trip trip) {
    final duration = DateTime.now().difference(trip.startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.green.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'ACTIVE TRIP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _endTrip(trip),
                  icon: const Icon(Icons.stop),
                  label: const Text('End Trip'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.startLocation,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text('${hours}h ${minutes}m'),
                const SizedBox(width: 16),
                Icon(
                  _getPurposeIcon(trip.purpose),
                  size: 20,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(trip.purpose.name.toUpperCase()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPurposeColor(trip.purpose),
          child: Icon(
            _getPurposeIcon(trip.purpose),
            color: Colors.white,
          ),
        ),
        title: Text(
          '${trip.startLocation} → ${trip.endLocation ?? "Ongoing"}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateFormat.format(trip.startTime)),
            if (trip.calculatedDistance != null)
              Text(
                '${trip.calculatedDistance!.toStringAsFixed(1)} km',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: trip.isActive
            ? const Icon(Icons.circle, color: Colors.green, size: 12)
            : IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteTrip(trip),
              ),
        onTap: () => _showTripDetails(trip),
      ),
    );
  }

  IconData _getPurposeIcon(TripPurpose purpose) {
    switch (purpose) {
      case TripPurpose.business:
        return Icons.business_center;
      case TripPurpose.commute:
        return Icons.commute;
      case TripPurpose.leisure:
        return Icons.beach_access;
      case TripPurpose.personal:
        return Icons.home;
      case TripPurpose.other:
        return Icons.place;
    }
  }

  Color _getPurposeColor(TripPurpose purpose) {
    switch (purpose) {
      case TripPurpose.business:
        return Colors.blue;
      case TripPurpose.commute:
        return Colors.orange;
      case TripPurpose.leisure:
        return Colors.purple;
      case TripPurpose.personal:
        return Colors.green;
      case TripPurpose.other:
        return Colors.grey;
    }
  }

  Future<void> _startNewTrip() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final vehicleProvider =
        Provider.of<VehicleProvider>(context, listen: false);

    if (deviceProvider.currentDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a device first')),
      );
      return;
    }

    if (vehicleProvider.vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a vehicle first')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => StartTripDialog(
        vehicles: vehicleProvider.vehicles,
        deviceId: deviceProvider.currentDevice!.deviceId,
        onTripStarted: _loadTrips,
      ),
    );
  }

  Future<void> _endTrip(Trip trip) async {
    await showDialog(
      context: context,
      builder: (context) => EndTripDialog(
        trip: trip,
        onTripEnded: _loadTrips,
      ),
    );
  }

  Future<void> _showTripDetails(Trip trip) async {
    await showDialog(
      context: context,
      builder: (context) => TripDetailsDialog(trip: trip),
    );
  }

  Future<void> _deleteTrip(Trip trip) async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: const Text('Are you sure you want to delete this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await tripProvider.deleteTrip(trip.id!);

      if (!mounted) return;
      if (success) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Trip deleted')),
        );
      }
    }
  }

  Future<void> _showStatistics() async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);

    final stats = await tripProvider.getTripStatistics();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trip Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow(
                'Total Trips', '${stats['total_trips'] as int? ?? 0}',),
            _buildStatRow(
              'Total Distance',
              '${((stats['total_distance'] as num?) ?? 0.0).toStringAsFixed(1)} km',
            ),
            _buildStatRow(
              'Average Distance',
              '${((stats['avg_distance'] as num?) ?? 0.0).toStringAsFixed(1)} km',
            ),
            const Divider(),
            _buildStatRow(
              'Business',
              '${((stats['business_distance'] as num?) ?? 0.0).toStringAsFixed(1)} km',
            ),
            _buildStatRow(
              'Personal',
              '${((stats['personal_distance'] as num?) ?? 0.0).toStringAsFixed(1)} km',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// Start Trip Dialog
class StartTripDialog extends StatefulWidget {
  const StartTripDialog({
    super.key,
    required this.vehicles,
    required this.deviceId,
    required this.onTripStarted,
  });
  final List<dynamic> vehicles;
  final String deviceId;
  final VoidCallback onTripStarted;

  @override
  State<StartTripDialog> createState() => _StartTripDialogState();
}

class _StartTripDialogState extends State<StartTripDialog> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _odometerController = TextEditingController();
  final _notesController = TextEditingController();

  int? _selectedVehicleId;
  TripPurpose _purpose = TripPurpose.personal;

  @override
  void dispose() {
    _locationController.dispose();
    _odometerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start New Trip'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _selectedVehicleId,
                decoration: const InputDecoration(
                  labelText: 'Select Vehicle',
                  prefixIcon: Icon(Icons.directions_car),
                ),
                items: widget.vehicles.map<DropdownMenuItem<int>>((vehicle) {
                  final v = vehicle as Map<String, dynamic>;
                  return DropdownMenuItem<int>(
                    value: v['id'] as int,
                    child: Text(v['name'] as String),
                  );
                }).toList(),
                onChanged: (int? value) =>
                    setState(() => _selectedVehicleId = value),
                validator: (int? value) =>
                    value == null ? 'Please select a vehicle' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Start Location',
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _odometerController,
                decoration: const InputDecoration(
                  labelText: 'Start Odometer (optional)',
                  prefixIcon: Icon(Icons.speed),
                  suffixText: 'km',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TripPurpose>(
                initialValue: _purpose,
                decoration: const InputDecoration(
                  labelText: 'Purpose',
                  prefixIcon: Icon(Icons.category),
                ),
                items: TripPurpose.values.map((purpose) {
                  return DropdownMenuItem(
                    value: purpose,
                    child: Text(purpose.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _purpose = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _startTrip,
          child: const Text('Start'),
        ),
      ],
    );
  }

  Future<void> _startTrip() async {
    if (_formKey.currentState!.validate()) {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);

      final tripId = await tripProvider.startTrip(
        vehicleId: _selectedVehicleId!,
        deviceId: widget.deviceId,
        startLocation: _locationController.text,
        startOdometer: _odometerController.text.isNotEmpty
            ? double.tryParse(_odometerController.text)
            : null,
        purpose: _purpose,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (tripId != null && mounted) {
        Navigator.pop(context);
        widget.onTripStarted();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip started!')),
        );
      }
    }
  }
}

// End Trip Dialog
class EndTripDialog extends StatefulWidget {
  const EndTripDialog({
    super.key,
    required this.trip,
    required this.onTripEnded,
  });
  final Trip trip;
  final VoidCallback onTripEnded;

  @override
  State<EndTripDialog> createState() => _EndTripDialogState();
}

class _EndTripDialogState extends State<EndTripDialog> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _odometerController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _locationController.dispose();
    _odometerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('End Trip'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'End Location',
                prefixIcon: Icon(Icons.location_on),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _odometerController,
              decoration: const InputDecoration(
                labelText: 'End Odometer',
                prefixIcon: Icon(Icons.speed),
                suffixText: 'km',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Required';
                final odometer = double.tryParse(value!);
                if (odometer == null) return 'Invalid number';
                if (widget.trip.startOdometer != null &&
                    odometer < widget.trip.startOdometer!) {
                  return 'Must be greater than start odometer';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 2,
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
          onPressed: _endTrip,
          child: const Text('End Trip'),
        ),
      ],
    );
  }

  Future<void> _endTrip() async {
    if (_formKey.currentState!.validate()) {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);

      final success = await tripProvider.endTrip(
        tripId: widget.trip.id!,
        endLocation: _locationController.text,
        endOdometer: double.parse(_odometerController.text),
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (success && mounted) {
        Navigator.pop(context);
        widget.onTripEnded();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ended!')),
        );
      }
    }
  }
}

// Trip Details Dialog
class TripDetailsDialog extends StatelessWidget {
  const TripDetailsDialog({super.key, required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return AlertDialog(
      title: Text(trip.purpose.name.toUpperCase()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(Icons.location_on, 'From', trip.startLocation),
          if (trip.endLocation != null)
            _buildDetailRow(Icons.location_on, 'To', trip.endLocation!),
          const Divider(),
          _buildDetailRow(
            Icons.calendar_today,
            'Started',
            dateFormat.format(trip.startTime),
          ),
          if (trip.endTime != null)
            _buildDetailRow(
              Icons.calendar_today,
              'Ended',
              dateFormat.format(trip.endTime!),
            ),
          if (trip.duration != null)
            _buildDetailRow(
              Icons.access_time,
              'Duration',
              '${trip.duration!.inHours}h ${trip.duration!.inMinutes.remainder(60)}m',
            ),
          const Divider(),
          if (trip.startOdometer != null)
            _buildDetailRow(
              Icons.speed,
              'Start Odometer',
              '${trip.startOdometer!.toStringAsFixed(1)} km',
            ),
          if (trip.endOdometer != null)
            _buildDetailRow(
              Icons.speed,
              'End Odometer',
              '${trip.endOdometer!.toStringAsFixed(1)} km',
            ),
          if (trip.calculatedDistance != null)
            _buildDetailRow(
              Icons.route,
              'Distance',
              '${trip.calculatedDistance!.toStringAsFixed(1)} km',
            ),
          if (trip.notes != null) ...[
            const Divider(),
            _buildDetailRow(Icons.note, 'Notes', trip.notes!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
