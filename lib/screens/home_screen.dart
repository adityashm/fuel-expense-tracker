import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/device_provider.dart';
import 'device_selection_screen.dart';
import 'new_main_app_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Schedule initialize after the current build completes to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDevice();
    });
  }

  Future<void> _initializeDevice() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    await deviceProvider.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        if (deviceProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If no device is selected, show device selection screen
        if (deviceProvider.currentDevice == null) {
          return const DeviceSelectionScreen();
        }

        // If device is selected, show dashboard
        return const NewMainAppShell();
      },
    );
  }
}
