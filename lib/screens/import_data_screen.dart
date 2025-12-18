import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/fuel_expense.dart';
import '../models/general_expense.dart';
import '../providers/device_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/vehicle_provider.dart';

class ImportDataScreen extends StatefulWidget {
  const ImportDataScreen({super.key});

  @override
  State<ImportDataScreen> createState() => _ImportDataScreenState();
}

class _ImportDataScreenState extends State<ImportDataScreen> {
  bool _isImporting = false;
  String? _statusMessage;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import expenses'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supported format',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Use the CSV produced by the Export option. Expected columns:',
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Type, Date, Vehicle, Category, Description, Amount, Liters, Pump',
                  ),
                  SizedBox(height: 8),
                  Text('Dates must be in DD/MM/YYYY format.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_statusMessage != null)
            Card(
              color: Colors.blueGrey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_statusMessage!),
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: _isImporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
            label: Text(_isImporting ? 'Importing...' : 'Choose CSV file'),
            onPressed: _isImporting ? null : _pickAndImport,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.file_present),
            label: const Text('How to prepare the file'),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Import guide'),
                  content: const Text(
                      '1. Go to Settings → Data Management and export CSV.\n'
                      '2. Modify the exported file if needed (keep header intact).\n'
                      '3. Each row should have either "Fuel" or "General" in the Type column.\n'
                      '4. For fuel rows, specify vehicle name exactly as in the app.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (result == null || result.files.single.path == null) return;

      setState(() {
        _isImporting = true;
        _statusMessage = 'Parsing file...';
      });

      final file = File(result.files.single.path!);
      final raw = await file.readAsString();
      final rows = const CsvToListConverter().convert(raw);
      final outcome = await _importRows(rows);

      if (mounted) {
        setState(() {
          _statusMessage =
              'Imported ${outcome['fuel']} fuel entries and ${outcome['general']} general expenses. ${outcome['skipped']} rows skipped.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Import failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<Map<String, int>> _importRows(List<List<dynamic>> rows) async {
    final counts = {'fuel': 0, 'general': 0, 'skipped': 0};
    if (rows.isEmpty) return counts;

    final header =
        rows.first.map((cell) => cell.toString().toLowerCase()).toList();
    final hasHeader = header.contains('type');
    final dataRows = hasHeader ? rows.skip(1) : rows;

    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final expenseProvider =
        Provider.of<ExpenseProvider>(context, listen: false);
    final vehicleProvider =
        Provider.of<VehicleProvider>(context, listen: false);
    final currentDeviceId = deviceProvider.currentDeviceId;

    if (currentDeviceId == null) {
      throw Exception('Select or register a device first.');
    }

    if (vehicleProvider.vehicles.isEmpty) {
      await vehicleProvider.loadVehicles(currentDeviceId);
    }

    final vehiclesByName = {
      for (final vehicle in vehicleProvider.vehicles)
        vehicle.name.toLowerCase(): vehicle,
    };

    for (final row in dataRows) {
      if (row.length < 6) {
        counts['skipped'] = counts['skipped']! + 1;
        continue;
      }

      try {
        final type = row[0].toString().trim().toLowerCase();
        final date = _dateFormat.parse(row[1].toString().trim());
        final vehicleName = row[2].toString().trim().toLowerCase();
        final categoryOrFuel = row[3].toString().trim();
        final description = row[4].toString().trim();
        final amountRaw = double.tryParse(row[5].toString().trim()) ?? 0.0;

        if (type == 'fuel') {
          final liters = row.length > 6
              ? double.tryParse(row[6].toString().trim()) ?? 0.0
              : 0.0;
          final odometer = row.length > 7
              ? double.tryParse(row[7].toString().trim()) ?? 0.0
              : 0.0;
          final pumpName = row.length > 8 ? row[8].toString().trim() : null;
          final vehicle = vehiclesByName[vehicleName];
          if (vehicle == null) {
            counts['skipped'] = counts['skipped']! + 1;
            continue;
          }
          final fuelType = FuelType.values.firstWhere(
            (value) => value.name.toLowerCase() == categoryOrFuel.toLowerCase(),
            orElse: () => FuelType.petrol,
          );
          final expense = FuelExpense(
            deviceId: currentDeviceId,
            vehicleId: vehicle.id!,
            date: date,
            fuelType: fuelType,
            amountPaid: amountRaw,
            liters: liters,
            odometerReading: odometer > 0 ? odometer : vehicle.currentOdometer,
            pumpName: pumpName?.isNotEmpty == true ? pumpName : null,
            notes: description.isNotEmpty ? description : null,
          );
          await expenseProvider.createFuelExpense(expense);
          counts['fuel'] = counts['fuel']! + 1;
        } else {
          final category = ExpenseCategory.values.firstWhere(
            (value) => value.name.toLowerCase() == categoryOrFuel.toLowerCase(),
            orElse: () => ExpenseCategory.other,
          );
          final expense = GeneralExpense(
            deviceId: currentDeviceId,
            vehicleId: vehiclesByName[vehicleName]?.id,
            date: date,
            amount: amountRaw,
            category: category,
            description: description.isNotEmpty ? description : category.name,
            isHouseholdExpense: vehiclesByName[vehicleName] == null,
          );
          await expenseProvider.createGeneralExpense(expense);
          counts['general'] = counts['general']! + 1;
        }
      } catch (_) {
        counts['skipped'] = counts['skipped']! + 1;
      }
    }

    await expenseProvider.loadFuelExpenses();
    await expenseProvider.loadGeneralExpenses();

    return counts;
  }
}
