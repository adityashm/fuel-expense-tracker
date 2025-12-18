import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/vehicle.dart';
import '../providers/collaboration_provider.dart';

class VehicleActivityScreen extends StatefulWidget {
  const VehicleActivityScreen({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  State<VehicleActivityScreen> createState() => _VehicleActivityScreenState();
}

class _VehicleActivityScreenState extends State<VehicleActivityScreen> {
  final _dateFormat = DateFormat('MMM dd, hh:mm a');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CollaborationProvider>(context, listen: false)
          .loadActivity(vehicleId: widget.vehicle.id);
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
        title: Text('${widget.vehicle.name} activity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<CollaborationProvider>(context, listen: false)
                  .loadActivity(vehicleId: widget.vehicle.id);
            },
          ),
        ],
      ),
      body: Consumer<CollaborationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingActivity && provider.activityLogs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.activityLogs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No collaboration activity yet'),
                  SizedBox(height: 4),
                  Text('Shared updates appear here automatically'),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: provider.activityLogs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final log = provider.activityLogs[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(_iconForType(log.type)),
                ),
                title: Text(log.title),
                subtitle: Text(
                  '${log.description}\n${_dateFormat.format(log.createdAt)}',
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'fuel_expense':
        return Icons.local_gas_station;
      case 'general_expense':
        return Icons.receipt;
      case 'maintenance':
        return Icons.build_circle;
      case 'comment':
        return Icons.chat_bubble_outline;
      case 'settlement':
        return Icons.currency_exchange;
      default:
        return Icons.notifications;
    }
  }
}
