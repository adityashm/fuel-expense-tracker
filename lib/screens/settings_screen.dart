import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/accessibility_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../services/report_service.dart';
import '../services/sync_service.dart';
import '../utils/app_localizations.dart';
import 'accessibility_settings_screen.dart';
import 'budget_settings_screen.dart';
import 'community_hub_screen.dart';
import 'drive_mode_screen.dart';
import 'family_tasks_screen.dart';
import 'geofence_manager_screen.dart';
import 'import_data_screen.dart';
import 'integration_hub_screen.dart';
import 'receipt_scanner_screen.dart';
import 'reminders_screen.dart';
import 'smart_insights_screen.dart';
import 'storage_test_screen.dart';
import 'trips_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SyncService? _syncService;
  ReportService? _reportService;
  BackupService? _backupService;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  void _initServices() {
    try {
      _syncService = SyncService.instance;
      _reportService = ReportService.instance;
      _backupService = BackupService.instance;
      _servicesInitialized = true;
    } catch (e) {
      debugPrint('Error initializing settings services: $e');
      // Continue without sync services - they're optional
      _servicesInitialized = true;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_servicesInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'Settings',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Subtitle
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    'Manage sync, features, accessibility, appearance, data and more.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                _buildSyncSection(context),
                const SizedBox(height: 16),
                _buildFeaturesSection(context),
                const SizedBox(height: 16),
                _buildAccessibilitySection(context),
                const SizedBox(height: 16),
                _buildThemeSection(context),
                const SizedBox(height: 16),
                _buildLanguageSection(context),
                const SizedBox(height: 16),
                _buildDataSection(context),
                const SizedBox(height: 16),
                _buildAboutSection(context),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibilitySection(BuildContext context) {
    return Consumer<AccessibilityProvider>(
      builder: (context, provider, child) {
        final subtitle = [
          if (provider.highContrast) 'High contrast',
          if (provider.textScale != 1.0)
            '${(provider.textScale * 100).round()}% text',
          if (provider.reduceMotion) 'Reduced motion',
        ].join(' • ');

        return Card(
          child: ListTile(
            leading:
                const Icon(Icons.accessibility_new, color: Colors.pinkAccent),
            title: const Text('Accessibility & comfort'),
            subtitle: Text(
              subtitle.isEmpty
                  ? 'Personalize contrast, text size, and animations'
                  : subtitle,
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccessibilitySettingsScreen(),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSyncSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Cloud Sync',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_syncService != null)
              const ListTile(
                leading: Icon(Icons.cloud_done, color: Colors.green),
                title: Text('Sync Status'),
                subtitle: Text('Data synced automatically'),
              )
            else
              const ListTile(
                leading: Icon(Icons.cloud_off, color: Colors.grey),
                title: Text('Sync Unavailable'),
                subtitle:
                    Text('Firebase not configured. Data is stored locally.'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Features',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.family_restroom, color: Colors.blue),
              title: const Text('Family Management'),
              subtitle: const Text('Manage members and track allowances'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pushNamed(context, '/family-management');
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.account_balance_wallet, color: Colors.green),
              title: const Text('Budget Settings'),
              subtitle: const Text('Set monthly expense limits'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BudgetSettingsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.notifications_active, color: Colors.orange),
              title: const Text('Reminders'),
              subtitle: const Text('Manage vehicle reminders'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RemindersScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.route, color: Colors.blue),
              title: const Text('Trip Tracker'),
              subtitle: const Text('Track and manage trips'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TripsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.task_alt, color: Colors.indigo),
              title: const Text('Family Tasks'),
              subtitle: const Text('Manage shared tasks and shopping lists'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FamilyTasksScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.red),
              title: const Text('Location Triggers'),
              subtitle: const Text('Auto-detect fuel stations'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GeofenceManagerScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_graph, color: Colors.purple),
              title: const Text('Smart Insights'),
              subtitle:
                  const Text('Predictive guidance for savings & maintenance'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SmartInsightsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.groups_3, color: Colors.teal),
              title: const Text('Community Hub'),
              subtitle: const Text('Share pump tips, compare efficiency'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CommunityHubScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_car, color: Colors.indigo),
              title: const Text('Drive Mode'),
              subtitle: const Text('Car-friendly dashboard for the road'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DriveModeScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return SwitchListTile(
                  title: Text(localizations.translate('dark_mode')),
                  subtitle: const Text('Enable dark theme'),
                  value: themeProvider.themeMode == ThemeMode.dark,
                  onChanged: (value) {
                    themeProvider.setThemeMode(
                      value ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                  secondary: const Icon(Icons.dark_mode),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSection(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.translate('language'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Consumer<LocaleProvider>(
              builder: (context, localeProvider, child) {
                return ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Language'),
                  subtitle: Text(
                    localeProvider.locale.languageCode == 'en'
                        ? 'English'
                        : 'हिन्दी',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _showLanguageDialog(context, localeProvider);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storage, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Data Management',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Export to PDF'),
              subtitle: const Text('Generate detailed PDF report'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showExportDialog(context, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.grid_on, color: Colors.green),
              title: const Text('Export to Excel'),
              subtitle: const Text('Generate Excel spreadsheet'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showExportDialog(context, 'excel'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.blue),
              title: const Text('Export to CSV'),
              subtitle: const Text('Export as comma-separated values'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showExportDialog(context, 'csv'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.orange),
              title: const Text('Import Data'),
              subtitle: const Text('Bring in CSV exports from other apps'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ImportDataScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.hub, color: Colors.indigo),
              title: const Text('Integration Hub'),
              subtitle: const Text(
                'Export JSON for Google Sheets, webhooks, dashboards',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IntegrationHubScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline, color: Colors.black87),
              title: const Text('Encrypted Backup'),
              subtitle: const Text(
                'Create a zero-knowledge backup to share or store safely',
              ),
              trailing: _isBackingUp
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _isBackingUp ? null : _handleEncryptedBackup,
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.brown),
              title: const Text('Restore Backup'),
              subtitle:
                  const Text('Select a .backup file to restore encrypted data'),
              trailing: _isRestoring
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _isRestoring ? null : _handleRestoreBackup,
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.teal),
              title: const Text('Test Receipt Scanner'),
              subtitle: const Text('Try OCR receipt scanning'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReceiptScannerScreen(),
                  ),
                );
                if (!mounted || result == null) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                        'Extracted: ₹${(result as Map<String, dynamic>)['amount']?.toString() ?? 'N/A'}',),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_done, color: Colors.deepPurple),
              title: const Text('Test Firebase Storage'),
              subtitle: const Text('Debug storage upload issues'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StorageTestScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExportDialog(BuildContext context, String format) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month);
    final endDate = now;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Export to ${format.toUpperCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Period: ${DateFormat('MMM dd').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}',
            ),
            const SizedBox(height: 16),
            const Text('This will export all expenses for the current month.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _handleExport(format, startDate, endDate);
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport(
    String format,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Show loading
      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Generating report...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      // Fetch data from database
      final db = DatabaseService.instance;
      final fuelExpenses = await db.getAllFuelExpenses();
      final generalExpenses = await db.getAllGeneralExpenses();
      final vehicles = await db.getAllVehicles();

      // Filter by date range
      final filteredFuel = fuelExpenses.where((e) {
        return e.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
            e.date.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();

      final filteredGeneral = generalExpenses.where((e) {
        return e.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
            e.date.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();

      // Generate report
      if (_reportService == null) {
        throw Exception('Report service not available');
      }
      dynamic file;
      switch (format) {
        case 'pdf':
          file = await _reportService!.generatePDFReport(
            title: 'Expense Report',
            startDate: startDate,
            endDate: endDate,
            fuelExpenses: filteredFuel,
            generalExpenses: filteredGeneral,
            vehicles: vehicles,
          );
          break;
        case 'excel':
          file = await _reportService!.generateExcelReport(
            fuelExpenses: filteredFuel,
            generalExpenses: filteredGeneral,
            vehicles: vehicles,
          );
          break;
        case 'csv':
          file = await _reportService!.generateCSVReport(
            fuelExpenses: filteredFuel,
            generalExpenses: filteredGeneral,
            vehicles: vehicles,
          );
          break;
        default:
          throw Exception('Unsupported format: $format');
      }

      // Close loading snackbar
      if (!mounted) return;
      messenger.hideCurrentSnackBar();

      // Show success with share option
      final share = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Complete'),
          content: Text('${format.toUpperCase()} file generated successfully!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('OK'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ],
        ),
      );

      if (share == true && file != null) {
        await _reportService!.sharePDF(file); // Works for all file types
      }
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  Future<void> _handleEncryptedBackup() async {
    if (!mounted || _backupService == null) return;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isBackingUp = true);
    try {
      final file = await _backupService!.createEncryptedBackup();
      if (!mounted) return;

      final fileName = file.path.split(Platform.pathSeparator).last;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Encrypted backup saved: $fileName'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      if (!mounted) return;
      final share = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Backup created'),
          content: const Text(
            'Share the backup now or keep it in your secure storage.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Later'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ],
        ),
      );

      if (share == true) {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Fuel tracker backup',
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Backup failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isBackingUp = false);
      }
    }
  }

  Future<void> _handleRestoreBackup() async {
    if (!mounted || _backupService == null) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['backup', 'enc'],
      );

      if (picked == null || picked.files.single.path == null) {
        return;
      }

      setState(() => _isRestoring = true);

      final file = File(picked.files.single.path!);
      await _backupService!.restoreEncryptedBackup(file);

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Backup restored successfully. Restart the app to reload data.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Restore failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  Widget _buildAboutSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const ListTile(
              leading: Icon(Icons.info),
              title: Text('Version'),
              subtitle: Text('1.0.0'),
            ),
            const ListTile(
              leading: Icon(Icons.description),
              title: Text('About App'),
              subtitle:
                  Text('Personal Fuel & Expense Tracker for Indian users'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(
    BuildContext context,
    LocaleProvider localeProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LanguageOptionTile(
              label: 'English',
              code: 'en',
              selectedCode: localeProvider.locale.languageCode,
              onSelected: () {
                localeProvider.setLocale(const Locale('en', 'US'));
                Navigator.pop(context);
              },
            ),
            _LanguageOptionTile(
              label: 'हिन्दी',
              code: 'hi',
              selectedCode: localeProvider.locale.languageCode,
              onSelected: () {
                localeProvider.setLocale(const Locale('hi', 'IN'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    required this.label,
    required this.code,
    required this.selectedCode,
    required this.onSelected,
  });

  final String label;
  final String code;
  final String selectedCode;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final isSelected = code == selectedCode;
    return ListTile(
      title: Text(label),
      trailing: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
      ),
      onTap: onSelected,
    );
  }
}
