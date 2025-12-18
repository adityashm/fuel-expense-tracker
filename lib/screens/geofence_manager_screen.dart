import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../models/expense_template.dart';
import '../models/station_geofence.dart';
import '../services/geofence_service.dart';
import '../services/places_service.dart';
import '../services/template_service.dart';

class GeofenceManagerScreen extends StatefulWidget {
  const GeofenceManagerScreen({super.key});

  @override
  State<GeofenceManagerScreen> createState() => _GeofenceManagerScreenState();
}

class _GeofenceManagerScreenState extends State<GeofenceManagerScreen>
    with SingleTickerProviderStateMixin {
  final _geofenceService = GeofenceService.instance;
  final _templateService = TemplateService.instance;
  final _placesService = PlacesService.instance;

  late TabController _tabController;
  List<StationGeofence> _geofences = [];
  List<FavoriteStation> _favoriteStations = [];
  GeofenceSettings _settings = GeofenceSettings();
  bool _isLoading = true;
  geo.Position? _currentPosition;

  // Loading states for individual operations
  final Set<String> _togglingGeofenceIds = {};
  final Set<String> _deletingGeofenceIds = {};

  // Cache for nearby stations
  List<NearbyStation>? _cachedNearbyStations;
  DateTime? _nearbyStationsCacheTime;
  static const _cacheDuration = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final geofences = await _geofenceService.getAllGeofences();
      final stations = await _templateService.getAllFavoriteStations();
      final settings = _geofenceService.getSettings();
      final position = await _geofenceService.getCurrentPosition();

      setState(() {
        _geofences = geofences;
        _favoriteStations = stations;
        _settings = settings;
        _currentPosition = position;
        _isLoading = false;
      });
    } catch (e) {
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
        title: const Text('Geofence Manager'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Geofences', icon: Icon(Icons.location_on)),
            Tab(text: 'Nearby', icon: Icon(Icons.radar)),
            Tab(text: 'Settings', icon: Icon(Icons.settings)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeofencesTab(),
          _buildNearbyTab(),
          _buildSettingsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGeofenceDialog,
        tooltip: 'Add Geofence',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGeofencesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_geofences.isEmpty) {
      return _buildEmptyState(
        icon: Icons.location_off,
        title: 'No Geofences',
        message: 'Add geofences to monitor fuel stations',
        actionLabel: 'Add Geofence',
        onAction: _showAddGeofenceDialog,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _geofences.length,
      itemBuilder: (context, index) {
        final geofence = _geofences[index];
        return _buildGeofenceCard(geofence);
      },
    );
  }

  Widget _buildGeofenceCard(StationGeofence geofence) {
    final distance = _currentPosition != null
        ? geofence.distanceFrom(_currentPosition!)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: geofence.isEnabled ? Colors.green[100] : Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            geofence.isEnabled ? Icons.location_on : Icons.location_off,
            color: geofence.isEnabled ? Colors.green[700] : Colors.grey[600],
          ),
        ),
        title: Text(
          geofence.stationName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.radar, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${geofence.radiusMeters.toInt()}m radius'),
                if (distance != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.near_me, size: 14, color: Colors.blue[600]),
                  const SizedBox(width: 4),
                  Text(
                    distance < 1000
                        ? '${distance.toInt()}m away'
                        : '${(distance / 1000).toStringAsFixed(1)}km away',
                    style: TextStyle(color: Colors.blue[600]),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Triggered ${geofence.triggerCount} times',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: _togglingGeofenceIds.contains(geofence.id.toString()) ||
                _deletingGeofenceIds.contains(geofence.id.toString())
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : PopupMenuButton<String>(
                onSelected: (value) => _handleGeofenceAction(value, geofence),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: geofence.isEnabled ? 'disable' : 'enable',
                    child: Row(
                      children: [
                        Icon(geofence.isEnabled
                            ? Icons.pause
                            : Icons.play_arrow,),
                        const SizedBox(width: 8),
                        Text(geofence.isEnabled ? 'Disable' : 'Enable'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'history',
                    child: Row(
                      children: [
                        Icon(Icons.history),
                        SizedBox(width: 8),
                        Text('View History'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _handleGeofenceAction(
      String action, StationGeofence geofence,) async {
    switch (action) {
      case 'enable':
      case 'disable':
        await _toggleGeofence(geofence);
        break;
      case 'edit':
        _showEditGeofenceDialog(geofence);
        break;
      case 'history':
        await _showGeofenceHistory(geofence);
        break;
      case 'delete':
        await _deleteGeofence(geofence);
        break;
    }
  }

  Future<void> _toggleGeofence(StationGeofence geofence) async {
    setState(() => _togglingGeofenceIds.add(geofence.id.toString()));
    try {
      final updated = geofence.copyWith(isEnabled: !geofence.isEnabled);
      await _geofenceService.updateGeofence(updated);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updated.isEnabled ? 'Geofence enabled' : 'Geofence disabled',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to toggle geofence', e);
      }
    } finally {
      if (mounted) {
        setState(() => _togglingGeofenceIds.remove(geofence.id.toString()));
      }
    }
  }

  Future<void> _deleteGeofence(StationGeofence geofence) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Geofence?'),
        content: Text('Remove geofence for ${geofence.stationName}?'),
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

    if (confirmed == true) {
      setState(() => _deletingGeofenceIds.add(geofence.id.toString()));
      try {
        await _geofenceService.deleteGeofence(geofence.id!);
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Geofence deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('Failed to delete geofence', e);
        }
      } finally {
        if (mounted) {
          setState(() => _deletingGeofenceIds.remove(geofence.id.toString()));
        }
      }
    }
  }

  Future<void> _showGeofenceHistory(StationGeofence geofence) async {
    final events = await _geofenceService.getRecentEvents(limit: 50);
    final geofenceEvents =
        events.where((e) => e.geofenceId == geofence.id).toList();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('History - ${geofence.stationName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: geofenceEvents.isEmpty
              ? const Text('No events recorded')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: geofenceEvents.length,
                  itemBuilder: (context, index) {
                    final event = geofenceEvents[index];
                    return ListTile(
                      leading: Icon(
                        event.eventType == GeofenceEventType.enter
                            ? Icons.login
                            : Icons.logout,
                      ),
                      title: Text(
                        event.eventType == GeofenceEventType.enter
                            ? 'Entered'
                            : 'Exited',
                      ),
                      subtitle: Text(
                        event.timestamp.toString().substring(0, 16),
                      ),
                      trailing: event.expenseLogged
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                    );
                  },
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
  }

  // ==================== NEARBY TAB ====================

  Widget _buildNearbyTab() {
    if (_currentPosition == null) {
      return _buildEmptyState(
        icon: Icons.location_disabled,
        title: 'Location Not Available',
        message: 'Enable location services to see nearby fuel stations',
        actionLabel: 'Enable Location',
        onAction: () async {
          await _geofenceService.getCurrentPosition();
          await _loadData();
        },
      );
    }

    return FutureBuilder<List<NearbyStation>>(
      future: _getCachedOrFetchNearbyStations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final stations = snapshot.data ?? [];

        if (stations.isEmpty) {
          return const Center(child: Text('No nearby stations found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: stations.length,
          itemBuilder: (context, index) {
            final station = stations[index];
            return _buildNearbyStationCard(station);
          },
        );
      },
    );
  }

  Widget _buildNearbyStationCard(NearbyStation station) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: station.isFavorite ? Colors.amber[100] : Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            station.isFavorite ? Icons.star : Icons.local_gas_station,
            color: station.isFavorite ? Colors.amber[700] : Colors.blue[700],
          ),
        ),
        title: Text(
          station.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(station.address),
            const SizedBox(height: 4),
            Text(
              station.distanceDisplay,
              style: TextStyle(
                  color: Colors.blue[600], fontWeight: FontWeight.w600,),
            ),
          ],
        ),
        trailing: station.isFavorite
            ? IconButton(
                icon: const Icon(Icons.near_me),
                tooltip: 'View Geofence',
                onPressed: () {
                  _tabController.animateTo(0);
                },
              )
            : IconButton(
                icon: const Icon(Icons.add_location_alt),
                tooltip: 'Add Geofence',
                onPressed: () => _addGeofenceForNearbyStation(station),
              ),
      ),
    );
  }

  // ==================== SETTINGS TAB ====================

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Geofencing',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Enable Geofencing'),
                  subtitle:
                      const Text('Trigger notifications when near stations'),
                  value: _settings.geofencingEnabled,
                  onChanged: (value) async {
                    final newSettings = _settings.copyWith(
                      geofencingEnabled: value,
                    );
                    await _geofenceService.updateSettings(newSettings);
                    setState(() => _settings = newSettings);
                  },
                ),
                SwitchListTile(
                  title: const Text('Background Location'),
                  subtitle: const Text('Monitor location when app is closed'),
                  value: _settings.backgroundLocationEnabled,
                  onChanged: (value) async {
                    if (value) {
                      final confirmed = await _showBackgroundLocationDialog();
                      if (confirmed != true) return;
                    }
                    final newSettings = _settings.copyWith(
                      backgroundLocationEnabled: value,
                    );
                    await _geofenceService.updateSettings(newSettings);
                    setState(() => _settings = newSettings);
                  },
                ),
                SwitchListTile(
                  title: const Text('Notifications'),
                  subtitle:
                      const Text('Show notifications for geofence events'),
                  value: _settings.notificationsEnabled,
                  onChanged: (value) async {
                    final newSettings = _settings.copyWith(
                      notificationsEnabled: value,
                    );
                    await _geofenceService.updateSettings(newSettings);
                    setState(() => _settings = newSettings);
                  },
                ),
                SwitchListTile(
                  title: const Text('Exit Reminders'),
                  subtitle:
                      const Text('Remind to log expense when leaving station'),
                  value: _settings.exitRemindersEnabled,
                  onChanged: (value) async {
                    final newSettings = _settings.copyWith(
                      exitRemindersEnabled: value,
                    );
                    await _geofenceService.updateSettings(newSettings);
                    setState(() => _settings = newSettings);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Timing',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Exit Reminder Delay'),
                  subtitle:
                      Text('${_settings.exitReminderDelayMinutes} minutes'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showDelayPicker(),
                ),
                ListTile(
                  title: const Text('Debounce Period'),
                  subtitle: Text('${_settings.debounceHours} hours'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showDebouncePicker(),
                ),
                ListTile(
                  title: const Text('Quiet Hours'),
                  subtitle: Text(
                    '${_settings.quietHourStart}:00 - ${_settings.quietHourEnd}:00',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showQuietHoursPicker(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Location data is only used for geofencing and never shared with third parties. '
                  'You can disable location features at any time.',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _updateSettings(GeofenceSettings settings) async {
    try {
      await _geofenceService.updateSettings(settings);
      setState(() => _settings = settings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // ==================== DIALOGS ====================

  void _showAddGeofenceDialog() {
    // Show dialog to select from favorite stations
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Geofence'),
        content: SizedBox(
          width: double.maxFinite,
          child: _favoriteStations.isEmpty
              ? const Text('No favorite stations available')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _favoriteStations.length,
                  itemBuilder: (context, index) {
                    final station = _favoriteStations[index];
                    final hasGeofence = station.id != null &&
                        _geofences.any(
                          (g) => g.stationId == station.id,
                        );

                    return ListTile(
                      leading: Icon(
                        hasGeofence ? Icons.location_on : Icons.location_off,
                      ),
                      title: Text(station.stationName),
                      subtitle: Text(station.location ?? 'No location'),
                      enabled: !hasGeofence && station.latitude != null,
                      trailing: hasGeofence
                          ? const Text('Already added')
                          : station.latitude == null
                              ? const Text('No location')
                              : null,
                      onTap: hasGeofence || station.latitude == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              _createGeofence(station);
                            },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showEditGeofenceDialog(StationGeofence geofence) {
    final radiusController = TextEditingController(
      text: geofence.radiusMeters.toInt().toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${geofence.stationName}'),
        content: TextField(
          controller: radiusController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Radius (meters)',
            suffixText: 'm',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final radius = double.tryParse(radiusController.text);
              if (radius == null || radius < 10 || radius > 1000) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Radius must be between 10 and 1000 meters'),
                  ),
                );
                return;
              }
              await _geofenceService.updateGeofence(
                geofence.copyWith(radiusMeters: radius),
              );
              await _loadData();
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _createGeofence(FavoriteStation station) async {
    try {
      final geofence = StationGeofence(
        stationId: station.id!,
        stationName: station.stationName,
        latitude: station.latitude!,
        longitude: station.longitude!,
        radiusMeters: _settings.defaultRadiusMeters,
        createdAt: DateTime.now(),
      );

      await _geofenceService.createGeofence(geofence);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Geofence created for ${station.stationName}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _addGeofenceForNearbyStation(NearbyStation station) async {
    // First add as favorite, then create geofence
    try {
      final favorite = FavoriteStation(
        name: station.name,
        address: station.address,
        location: '${station.latitude},${station.longitude}',
        createdAt: DateTime.now(),
      );

      final savedStation = await _templateService.saveFavoriteStation(favorite);

      final geofence = StationGeofence(
        stationId: savedStation.id!,
        stationName: savedStation.stationName,
        latitude: savedStation.latitude!,
        longitude: savedStation.longitude!,
        radiusMeters: _settings.defaultRadiusMeters,
        createdAt: DateTime.now(),
      );

      await _geofenceService.createGeofence(geofence);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Geofence created for ${station.name}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showDelayPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Reminder Delay'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [5, 10, 15, 30].map((minutes) {
            // ignore: deprecated_member_use
            return RadioListTile<int>(
              title: Text('$minutes minutes'),
              value: minutes,
              // ignore: deprecated_member_use
              groupValue: _settings.exitReminderDelayMinutes,
              // ignore: deprecated_member_use
              onChanged: (value) {
                if (value != null) {
                  _updateSettings(
                    _settings.copyWith(
                      exitReminderDelayMinutes: value,
                    ),
                  );
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showDebouncePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debounce Period'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [1, 2, 4, 6, 12].map((hours) {
            // ignore: deprecated_member_use
            return RadioListTile<int>(
              title: Text('$hours hours'),
              value: hours,
              // ignore: deprecated_member_use
              groupValue: _settings.debounceHours,
              // ignore: deprecated_member_use
              onChanged: (value) {
                if (value != null) {
                  _updateSettings(
                    _settings.copyWith(
                      debounceHours: value,
                    ),
                  );
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _showQuietHoursPicker() async {
    TimeOfDay startTime = TimeOfDay(
      hour: _settings.quietHourStart,
      minute: 0,
    );
    TimeOfDay endTime = TimeOfDay(
      hour: _settings.quietHourEnd,
      minute: 0,
    );

    String formatTime(TimeOfDay time) {
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Quiet Hours'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notifications will be silenced during these hours:'),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.bedtime),
                title: const Text('Start Time'),
                subtitle: Text(formatTime(startTime)),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: startTime,
                  );
                  if (picked != null) {
                    setState(() => startTime = picked);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.wb_sunny),
                title: const Text('End Time'),
                subtitle: Text(formatTime(endTime)),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: endTime,
                  );
                  if (picked != null) {
                    setState(() => endTime = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateSettings(
                  _settings.copyWith(
                    quietHourStart: startTime.hour,
                    quietHourEnd: endTime.hour,
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== COMMON WIDGETS ====================

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== HELPER METHODS ====================

  Future<List<NearbyStation>> _getCachedOrFetchNearbyStations() async {
    final now = DateTime.now();

    // Return cached data if valid
    if (_cachedNearbyStations != null &&
        _nearbyStationsCacheTime != null &&
        now.difference(_nearbyStationsCacheTime!) < _cacheDuration) {
      return _cachedNearbyStations!;
    }

    // Fetch fresh data
    final stations = await _placesService.searchNearbyStations(
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      favoriteStations: _favoriteStations,
    );

    // Update cache
    _cachedNearbyStations = stations;
    _nearbyStationsCacheTime = now;

    return stations;
  }

  Future<bool?> _showBackgroundLocationDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Background Location?'),
        content: const Text(
          'This will allow the app to track your location even when closed, '
          r'enabling automatic geofence triggers.\n\n'
          'Your location data is only used locally and never shared with third parties.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message, Object error,
      {VoidCallback? retryAction,}) {
    final errorMessage = error.toString().replaceAll('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$message: $errorMessage'),
        backgroundColor: Colors.red,
        action: retryAction != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: retryAction,
              )
            : null,
      ),
    );
  }
}
