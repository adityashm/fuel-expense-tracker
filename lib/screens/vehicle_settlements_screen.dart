import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/settlement.dart';
import '../models/vehicle.dart';
import '../providers/collaboration_provider.dart';
import '../providers/device_provider.dart';

class VehicleSettlementsScreen extends StatefulWidget {
  const VehicleSettlementsScreen({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  State<VehicleSettlementsScreen> createState() =>
      _VehicleSettlementsScreenState();
}

class _VehicleSettlementsScreenState extends State<VehicleSettlementsScreen> {
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
  bool _loadingSuggestions = true;
  List<Map<String, dynamic>> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _refreshAll() async {
    final provider = Provider.of<CollaborationProvider>(context, listen: false);
    await provider.loadSettlements(widget.vehicle.id!);
    final suggestions =
        await provider.settlementSuggestions(widget.vehicle.id!);
    if (mounted) {
      setState(() {
        _suggestions = suggestions;
        _loadingSuggestions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.vehicle.name} settlements'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: Consumer<CollaborationProvider>(
          builder: (context, provider, _) {
            final settlements =
                provider.settlementsForVehicle(widget.vehicle.id!);
            final pending = settlements
                .where((s) => s.status == SettlementStatus.pending)
                .toList();
            final settled = settlements
                .where((s) => s.status == SettlementStatus.settled)
                .toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSuggestionsCard(),
                const SizedBox(height: 16),
                if (pending.isNotEmpty)
                  _buildSettlementSection(
                    'Pending settlements',
                    pending,
                    provider,
                  ),
                if (pending.isNotEmpty && settled.isNotEmpty)
                  const SizedBox(height: 16),
                if (settled.isNotEmpty)
                  _buildSettlementSection(
                    'History',
                    settled,
                    provider,
                    showMarkSettled: false,
                  ),
                if (pending.isEmpty && settled.isEmpty && !_loadingSuggestions)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Column(
                      children: [
                        Icon(Icons.fact_check, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No settlements yet'),
                        SizedBox(height: 4),
                        Text('Use the + button to record one.'),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSettlementSheet,
        icon: const Icon(Icons.add),
        label: const Text('Log settlement'),
      ),
    );
  }

  Widget _buildSuggestionsCard() {
    if (_loadingSuggestions) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Analyzing contributions...'),
            ],
          ),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Everyone is even. No settlements needed right now.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suggested settlements',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ..._suggestions.map(
              (suggestion) => ListTile(
                leading: const Icon(Icons.swap_horiz),
                title:
                    Text('${suggestion['fromName']} → ${suggestion['toName']}'),
                subtitle:
                    Text(_currency.format(suggestion['amount'] as double)),
                trailing: TextButton(
                  child: const Text('Record'),
                  onPressed: () => _showSettlementSheet(
                    payer: suggestion['fromDeviceId'] as String?,
                    payee: suggestion['toDeviceId'] as String?,
                    amount: suggestion['amount'] as double?,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementSection(
    String title,
    List<Settlement> settlements,
    CollaborationProvider provider, {
    bool showMarkSettled = true,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...settlements.map((settlement) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: settlement.status == SettlementStatus.pending
                      ? Colors.orange.shade100
                      : Colors.green.shade100,
                  child: Icon(
                    settlement.status == SettlementStatus.pending
                        ? Icons.hourglass_top
                        : Icons.check,
                    color: settlement.status == SettlementStatus.pending
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
                title: Text(_currency.format(settlement.amount)),
                subtitle: Text(
                  '${_deviceName(settlement.payerDeviceId)} → ${_deviceName(settlement.payeeDeviceId)}\n${DateFormat('MMM dd, hh:mm a').format(settlement.createdAt)}',
                ),
                isThreeLine: true,
                trailing: showMarkSettled
                    ? TextButton(
                        onPressed: () async {
                          await provider.markSettlementAsSettled(
                            widget.vehicle.id!,
                            settlement.id!,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Marked as settled'),
                              ),
                            );
                          }
                        },
                        child: const Text('Mark settled'),
                      )
                    : Text(
                        settlement.settledAt != null
                            ? DateFormat('MMM dd').format(settlement.settledAt!)
                            : 'Settled',
                        style: const TextStyle(color: Colors.green),
                      ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _deviceName(String deviceId) {
    final provider = Provider.of<DeviceProvider>(context, listen: false);
    final devices = provider.devices;
    for (final device in devices) {
      if (device.deviceId == deviceId) {
        return device.personName;
      }
    }
    if (provider.currentDevice?.deviceId == deviceId) {
      return provider.currentDevice!.personName;
    }
    return deviceId;
  }

  Future<void> _showSettlementSheet({
    String? payer,
    String? payee,
    double? amount,
  }) async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final collaborationProvider =
        Provider.of<CollaborationProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final devices = deviceProvider.devices;

    if (devices.length < 2) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Need at least two collaborators to record settlements.',
            ),
          ),
        );
      }
      return;
    }

    String? payerId = payer ?? deviceProvider.currentDeviceId;
    String? payeeId = payee;
    final amountController = TextEditingController(
      text: amount != null ? amount.toStringAsFixed(0) : '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Text(
                    'Record settlement',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: payerId,
                    decoration: const InputDecoration(
                      labelText: 'Paid by',
                      border: OutlineInputBorder(),
                    ),
                    items: devices
                        .map(
                          (device) => DropdownMenuItem(
                            value: device.deviceId,
                            child: Text(device.personName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => modalSetState(() => payerId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: payeeId,
                    decoration: const InputDecoration(
                      labelText: 'Paid to',
                      border: OutlineInputBorder(),
                    ),
                    items: devices
                        .map(
                          (device) => DropdownMenuItem(
                            value: device.deviceId,
                            child: Text(device.personName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => modalSetState(() => payeeId = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixIcon: Icon(Icons.currency_rupee),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final parsedAmount =
                            double.tryParse(amountController.text.trim());
                        if (payerId == null ||
                            payeeId == null ||
                            parsedAmount == null) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Please fill all fields.'),
                            ),
                          );
                          return;
                        }
                        if (payerId == payeeId) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Payer and payee cannot be same.'),
                            ),
                          );
                          return;
                        }

                        final settlement = Settlement(
                          vehicleId: widget.vehicle.id!,
                          payerDeviceId: payerId!,
                          payeeDeviceId: payeeId!,
                          amount: parsedAmount,
                        );
                        await collaborationProvider
                            .recordSettlement(settlement);
                        if (!mounted) return;
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Settlement recorded')),
                        );
                        await _refreshAll();
                      },
                      child: const Text('Save settlement'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
