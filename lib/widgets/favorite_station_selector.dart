import 'package:flutter/material.dart';
import '../models/expense_template.dart';
import '../services/template_service.dart';

class FavoriteStationSelector extends StatefulWidget {
  const FavoriteStationSelector({
    super.key,
    required this.onStationSelected,
    this.initialStation,
  });
  final Function(FavoriteStation) onStationSelected;
  final String? initialStation;

  @override
  State<FavoriteStationSelector> createState() =>
      _FavoriteStationSelectorState();
}

class _FavoriteStationSelectorState extends State<FavoriteStationSelector> {
  final _templateService = TemplateService.instance;
  List<FavoriteStation> _stations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    final stations = await _templateService.getAllFavoriteStations();
    setState(() {
      _stations = stations;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_stations.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(
                Icons.local_gas_station_outlined,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 8),
              const Text(
                'No favorite stations yet',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _showAddStationDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Favorite Station'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Favorite Stations',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showAddStationDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _stations.length,
            itemBuilder: (context, index) {
              final station = _stations[index];
              return _buildStationCard(station);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStationCard(FavoriteStation station) {
    final isSelected = widget.initialStation == station.name;

    return Card(
      color: isSelected ? Colors.blue.shade50 : null,
      child: InkWell(
        onTap: () => widget.onStationSelected(station),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_gas_station,
                    color: isSelected ? Colors.blue : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      station.name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (station.brand != null) ...[
                const SizedBox(height: 4),
                Text(
                  station.brand!,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
              const Spacer(),
              if (station.lastPricePerLiter != null) ...[
                Text(
                  station.getPriceInfo(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              Row(
                children: [
                  Icon(Icons.history, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 2),
                  Text(
                    'Used ${station.useCount}×',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Station Name',
                hintText: 'HP Baner',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: brandController,
              decoration: const InputDecoration(
                labelText: 'Brand (Optional)',
                hintText: 'HP, Shell, IOCL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Address (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
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
              await _loadStations();

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${station.name} added to favorites')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
