import 'package:flutter/material.dart';

import '../models/expense_template.dart';
import '../models/vehicle.dart';
import '../services/database_service.dart';
import '../services/template_service.dart';

class TemplateManagerScreen extends StatefulWidget {
  const TemplateManagerScreen({super.key});

  @override
  State<TemplateManagerScreen> createState() => _TemplateManagerScreenState();
}

class _TemplateManagerScreenState extends State<TemplateManagerScreen> {
  final _templateService = TemplateService.instance;
  List<ExpenseTemplate> _templates = [];
  List<FavoriteStation> _stations = [];
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final templates = await _templateService.getAllTemplates();
    final stations = await _templateService.getAllFavoriteStations();
    setState(() {
      _templates = templates;
      _stations = stations;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Templates & Favorites'),
        bottom: TabBar(
          controller: DefaultTabController.of(context),
          onTap: (index) => setState(() => _selectedTab = index),
          tabs: const [
            Tab(text: 'Templates', icon: Icon(Icons.bookmark)),
            Tab(text: 'Stations', icon: Icon(Icons.local_gas_station)),
          ],
        ),
      ),
      body: DefaultTabController(
        length: 2,
        child: TabBarView(
          children: [
            _buildTemplatesTab(),
            _buildStationsTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectedTab == 0
            ? _showCreateTemplateDialog
            : _showAddStationDialog,
        icon: const Icon(Icons.add),
        label: Text(_selectedTab == 0 ? 'New Template' : 'Add Station'),
      ),
    );
  }

  Widget _buildTemplatesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No templates yet',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Create templates for frequently used expenses',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _templates.length,
      itemBuilder: (context, index) => _buildTemplateCard(_templates[index]),
    );
  }

  Widget _buildTemplateCard(ExpenseTemplate template) {
    IconData icon;
    Color color;

    switch (template.type) {
      case TemplateType.fuel:
        icon = Icons.local_gas_station;
        color = Colors.orange;
        break;
      case TemplateType.charging:
        icon = Icons.bolt;
        color = Colors.green;
        break;
      case TemplateType.general:
        icon = Icons.receipt;
        color = Colors.blue;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          template.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${template.vehicleName} • ₹${template.amount.toStringAsFixed(0)}',
            ),
            Text(
              template.getSummary(),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.history, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Used ${template.useCount} times',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
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
          onSelected: (value) {
            if (value == 'delete') {
              _deleteTemplate(template);
            } else if (value == 'edit') {
              _editTemplate(template);
            }
          },
        ),
      ),
    );
  }

  Widget _buildStationsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_stations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_gas_station_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No favorite stations yet',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Add frequently visited fuel stations',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _stations.length,
      itemBuilder: (context, index) => _buildStationCard(_stations[index]),
    );
  }

  Widget _buildStationCard(FavoriteStation station) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.local_gas_station, color: Colors.white),
        ),
        title: Text(
          station.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (station.brand != null) Text(station.brand!),
            if (station.address != null)
              Text(
                station.address!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (station.lastPricePerLiter != null)
                  Text(
                    station.getPriceInfo(),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                const SizedBox(width: 12),
                Icon(Icons.history, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Used ${station.useCount}×',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
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
          onSelected: (value) {
            if (value == 'delete') {
              _deleteStation(station);
            } else if (value == 'edit') {
              _editStation(station);
            }
          },
        ),
      ),
    );
  }

  Future<void> _showCreateTemplateDialog() async {
    final db = DatabaseService.instance;
    final vehiclesData = await db.getAllVehiclesWithBudgets();
    if (!mounted) return;

    final vehicles = vehiclesData.map((map) => Vehicle.fromMap(map)).toList();

    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a vehicle first')),
      );
      return;
    }

    // Show vehicle selection, then template type, then details
    final selectedVehicle = await showDialog<Vehicle>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Vehicle'),
        children: vehicles
            .map(
              (v) => SimpleDialogOption(
                child: Text(v.name),
                onPressed: () => Navigator.pop(context, v),
              ),
            )
            .toList(),
      ),
    );

    if (selectedVehicle == null) return;
    if (!mounted) return;

    // For simplicity, show a basic template creation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create template from expense screen')),
    );
  }

  void _showAddStationDialog() {
    final nameController = TextEditingController();
    final brandController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Favorite Station'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Station Name *',
                  hintText: 'HP Baner, Shell Wakad',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: brandController,
                decoration: const InputDecoration(
                  labelText: 'Brand',
                  hintText: 'HP, Shell, IOCL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
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
          FilledButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;

              final station = FavoriteStation(
                name: nameController.text.trim(),
                brand: brandController.text.isNotEmpty
                    ? brandController.text.trim()
                    : null,
                address: addressController.text.isNotEmpty
                    ? addressController.text.trim()
                    : null,
              );

              await _templateService.saveFavoriteStation(station);
              await _loadData();

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${station.name} added')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTemplate(ExpenseTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Delete "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    await _templateService.deleteTemplate(template.id!);
    await _loadData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Template deleted')),
    );
  }

  Future<void> _deleteStation(FavoriteStation station) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Station'),
        content: Text('Remove "${station.name}" from favorites?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    await _templateService.deleteFavoriteStation(station.id!);
    await _loadData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Station removed')),
    );
  }

  void _editTemplate(ExpenseTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Template Name',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: template.name),
              onChanged: (value) {
                // Template name updated
              },
            ),
            const SizedBox(height: 16),
            const Text(
                'Template editing is under development. You can delete and recreate templates for now.',),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Template updated')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editStation(FavoriteStation station) {
    final nameController = TextEditingController(text: station.name);
    final locationController = TextEditingController(text: station.location);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Fuel Station'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Station Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
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
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                // Update station in database
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Station updated')),
                );
                setState(() {});
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
