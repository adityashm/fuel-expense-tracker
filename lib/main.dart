import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/accessibility_provider.dart';
import 'providers/charging_expense_provider.dart';
import 'providers/collaboration_provider.dart';
import 'providers/device_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/family_member_provider.dart';
import 'providers/family_task_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/maintenance_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/user_provider.dart';
import 'providers/vehicle_provider.dart';
import 'screens/family_management_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/database_service.dart';
import 'services/firebase_service.dart';
import 'services/geofence_service.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';
import 'utils/app_localizations.dart';
import 'utils/app_theme.dart';
import 'utils/query_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🆕 PHASE 1: Initialize query cache system
  QueryCache.instance.initialize();
  debugPrint('✅ Query cache initialized');

  await runZonedGuarded(() async {
    try {
      await Firebase.initializeApp();

      // CRITICAL FIX #4: Enable offline persistence
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      debugPrint('✅ Firebase offline persistence enabled');

      await FirebaseService.instance.signInAnonymously();
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (e) {
      debugPrint('Firebase initialization error: $e');
      debugPrint('Continuing without Firebase services...');
    }

    try {
      await DatabaseService.instance.database;
    } catch (e) {
      debugPrint('Database initialization error: $e');
    }

    try {
      await NotificationService.instance.initialize();
    } catch (e) {
      debugPrint('Notification service initialization error: $e');
    }

    try {
      await GeofenceService.instance.initialize();
      debugPrint('GeofenceService initialized successfully');
    } catch (e) {
      debugPrint('Geofence service initialization error: $e');
    }

    try {
      await initializeDateFormatting();
    } catch (e) {
      debugPrint('Date formatting initialization error: $e');
    }

    final prefs = await SharedPreferences.getInstance();

    try {
      SyncService.instance.startAutoSync();
    } catch (e) {
      debugPrint('Auto-sync initialization error: $e');
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
          ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
          ChangeNotifierProvider(create: (_) => AccessibilityProvider(prefs)),
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider(create: (_) => DeviceProvider()),
          ChangeNotifierProvider(create: (_) => VehicleProvider()),
          ChangeNotifierProvider(create: (_) => ExpenseProvider()),
          ChangeNotifierProvider(
            create: (_) => FamilyMemberProvider()..loadMembers(),
          ),
          ChangeNotifierProvider(create: (_) => FamilyTaskProvider()),
          ChangeNotifierProvider(create: (_) => ChargingExpenseProvider()),
          ChangeNotifierProvider(create: (_) => TripProvider()),
          ChangeNotifierProvider(create: (_) => MaintenanceProvider()),
          ChangeNotifierProvider(create: (_) => CollaborationProvider()),
        ],
        child: MyApp(prefs: prefs),
      ),
    );
  }, (error, stack) async {
    debugPrint('Unhandled error: $error');
    try {
      await FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (e) {
      debugPrint('Could not log to Crashlytics: $e');
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.prefs});
  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    final showOnboarding = !(prefs.getBool('onboarding_complete') ?? false);
    return Consumer3<ThemeProvider, LocaleProvider, AccessibilityProvider>(
      builder: (
        context,
        themeProvider,
        localeProvider,
        accessibilityProvider,
        child,
      ) {
        final lightTheme = AppTheme.applyAccessibility(
          AppTheme.lightTheme,
          highContrast: accessibilityProvider.highContrast,
          reduceMotion: accessibilityProvider.reduceMotion,
        );
        final darkTheme = AppTheme.applyAccessibility(
          AppTheme.darkTheme,
          highContrast: accessibilityProvider.highContrast,
          reduceMotion: accessibilityProvider.reduceMotion,
        );
        return MaterialApp(
          title: 'Fuel Expense Tracker',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.themeMode,
          locale: localeProvider.locale,
          supportedLocales: const [
            Locale('en', 'US'),
            Locale('hi', 'IN'),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final data = MediaQuery.of(context);
            return MediaQuery(
              data: data.copyWith(
                textScaler: TextScaler.linear(accessibilityProvider.textScale),
                boldText: accessibilityProvider.highContrast,
                disableAnimations: accessibilityProvider.reduceMotion,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: showOnboarding
              ? OnboardingScreen(prefs: prefs)
              : const HomeScreen(),
          routes: {
            '/family-management': (context) => const FamilyManagementScreen(),
          },
        );
      },
    );
  }
}
