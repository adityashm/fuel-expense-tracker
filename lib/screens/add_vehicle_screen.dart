import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vehicle.dart';
import '../providers/device_provider.dart';
import '../providers/vehicle_provider.dart';
import '../services/database_service.dart';
import '../utils/app_localizations.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _registrationController = TextEditingController();
  final _odometerController = TextEditingController();
  VehicleType _vehicleType = VehicleType.bike;
  bool _isShared = false;

  @override
  void dispose() {
    _nameController.dispose();
    _registrationController.dispose();
    _odometerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('add_vehicle')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: localizations.translate('vehicle_name'),
                  prefixIcon: const Icon(Icons.directions_car),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter vehicle name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _registrationController,
                decoration: InputDecoration(
                  labelText: localizations.translate('registration_number'),
                  prefixIcon: const Icon(Icons.credit_card),
                  hintText: 'AA00AA0000',
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 15,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter registration number';
                  }
                  // Basic format validation
                  final regNumber = value.trim().toUpperCase();
                  if (regNumber.length < 6) {
                    return 'Registration number too short';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<VehicleType>(
                initialValue: _vehicleType,
                decoration: InputDecoration(
                  labelText: localizations.translate('vehicle_type'),
                  prefixIcon: const Icon(Icons.category),
                  helperText: 'Select vehicle type - Petrol or Electric',
                ),
                items: const [
                  DropdownMenuItem(
                    value: VehicleType.bike,
                    child: Row(
                      children: [
                        Icon(Icons.two_wheeler, size: 20),
                        SizedBox(width: 8),
                        Text('Petrol Bike'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: VehicleType.car,
                    child: Row(
                      children: [
                        Icon(Icons.directions_car, size: 20),
                        SizedBox(width: 8),
                        Text('Petrol Car'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: VehicleType.electricBike,
                    child: Row(
                      children: [
                        Icon(Icons.electric_scooter, size: 20),
                        SizedBox(width: 8),
                        Text('Electric Bike/Scooter'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: VehicleType.electricCar,
                    child: Row(
                      children: [
                        Icon(Icons.electric_car, size: 20),
                        SizedBox(width: 8),
                        Text('Electric Car'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _vehicleType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _odometerController,
                decoration: InputDecoration(
                  labelText: localizations.translate('current_odometer'),
                  prefixIcon: const Icon(Icons.speed),
                  suffixText: 'km',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter current odometer reading';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Card(
                child: SwitchListTile(
                  title: const Text('Shared Vehicle'),
                  subtitle:
                      const Text('Allow other devices to access this vehicle'),
                  value: _isShared,
                  onChanged: (value) {
                    setState(() {
                      _isShared = value;
                    });
                  },
                  secondary: const Icon(Icons.people),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveVehicle,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: Text(
                  localizations.translate('save'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveVehicle() async {
    if (_formKey.currentState!.validate()) {
      final deviceProvider =
          Provider.of<DeviceProvider>(context, listen: false);
      final vehicleProvider =
          Provider.of<VehicleProvider>(context, listen: false);

      try {
        // Re-initialize device if missing
        if (deviceProvider.currentDeviceId == null) {
          await deviceProvider.initialize();
          if (deviceProvider.currentDeviceId == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Unable to initialize device. Please restart the app.',
                  ),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
            }
            return;
          }
        }

        // Check for duplicate registration
        final regNumber = _registrationController.text.trim().toUpperCase();
        final existingVehicle =
            await DatabaseService.instance.getVehicleByRegistration(regNumber);

        if (existingVehicle != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Vehicle with registration $regNumber already exists'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        await vehicleProvider.createVehicle(
          deviceProvider.currentDeviceId!,
          _nameController.text.trim(),
          regNumber,
          _vehicleType,
          double.parse(_odometerController.text),
          isShared: _isShared,
        );

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving vehicle: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
