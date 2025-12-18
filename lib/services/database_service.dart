import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/allowance.dart';
import '../models/family_member.dart';
import '../models/fuel_expense.dart';
import '../models/general_expense.dart';
import '../models/payment.dart';
import '../models/recurring_expense.dart';
import '../models/user.dart';
import '../models/vehicle.dart';
import '../utils/constants.dart';
import '../utils/migration_safety.dart';
import '../utils/query_cache.dart';

class DatabaseService {
  DatabaseService._init();
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  void _logMigrationWarning(String message, Object error) {
    developer.log(message, name: 'DatabaseService', error: error);
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('fuel_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return openDatabase(
      path,
      version: 21,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // 🆕 PHASE 1: Wrap migrations with safety checks
    await MigrationSafetyWrapper.executeSafeMigration(
      db,
      oldVersion,
      newVersion,
      (txn) async {
        // All existing migration code wrapped in transaction
        await _performMigrations(txn, oldVersion, newVersion);
      },
    );
  }

  // 🆕 Extract migration logic for better organization
  Future<void> _performMigrations(
    Transaction txn,
    int oldVersion,
    int newVersion,
  ) async {
      // Version 2: Add sharing and collaboration features
      if (oldVersion < 2) {
        // Add is_shared column to vehicles
        await txn.execute(
          'ALTER TABLE vehicles ADD COLUMN is_shared INTEGER DEFAULT 0',
        );

        // Create vehicle_access table
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS vehicle_access (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            vehicle_id INTEGER NOT NULL,
            device_id TEXT NOT NULL,
            access_type TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
            FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
          )
        ''');

        // Create budgets table (device-based)
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS budgets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT NOT NULL,
            month TEXT NOT NULL,
            fuel_limit REAL DEFAULT 0,
            general_limit REAL DEFAULT 0,
            household_limit REAL DEFAULT 0,
            created_at TEXT NOT NULL,
            FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
          )
        ''');

        // Create reminders table (device-based)
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS reminders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            vehicle_id INTEGER NOT NULL,
            device_id TEXT NOT NULL,
            type TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT,
            due_date TEXT NOT NULL,
            is_completed INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
            FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
          )
        ''');

        // Create trips table
        await txn.execute('''
          CREATE TABLE trips (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            vehicle_id INTEGER NOT NULL,
            device_id TEXT NOT NULL,
            start_location TEXT NOT NULL,
            end_location TEXT,
            start_odometer REAL,
            end_odometer REAL,
            distance REAL,
            start_time TEXT NOT NULL,
            end_time TEXT,
            purpose TEXT NOT NULL,
            notes TEXT,
            fuel_expense_id INTEGER,
            is_active INTEGER DEFAULT 1,
            created_at TEXT NOT NULL,
            FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
            FOREIGN KEY (fuel_expense_id) REFERENCES fuel_expenses (id) ON DELETE SET NULL
          )
        ''');
      }

      // Version 4: Add devices table for device/person identification
      if (oldVersion < 4) {
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS devices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT UNIQUE NOT NULL,
            person_name TEXT NOT NULL,
            profile_picture_path TEXT,
            is_active INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        // Add device_id column to expenses tables if not exists
        try {
          await txn
              .execute('ALTER TABLE fuel_expenses ADD COLUMN device_id TEXT');
        } catch (e) {
          // Column might already exist
        }

        try {
          await txn.execute(
              'ALTER TABLE general_expenses ADD COLUMN device_id TEXT',);
        } catch (e) {
          // Column might already exist
        }

        try {
          await txn.execute(
            'ALTER TABLE household_expenses ADD COLUMN device_id TEXT',
          );
        } catch (e) {
          // Column might already exist
        }

        try {
          await txn.execute('ALTER TABLE trips ADD COLUMN device_id TEXT');
        } catch (e) {
          // Column might already exist
        }
      }

      // Version 5: migrate to device-based ownership/access and add indexes
      if (oldVersion < 5) {
        try {
          await txn
              .execute('ALTER TABLE vehicles ADD COLUMN owner_device_id TEXT');
        } catch (e) {
          _logMigrationWarning('vehicles.owner_device_id already exists', e);
        }
        try {
          await txn.execute('ALTER TABLE budgets ADD COLUMN device_id TEXT');
        } catch (e) {
          _logMigrationWarning('budgets.device_id already exists', e);
        }
        try {
          await txn.execute('ALTER TABLE reminders ADD COLUMN device_id TEXT');
        } catch (e) {
          _logMigrationWarning('reminders.device_id already exists', e);
        }
        try {
          await txn.execute(
            'CREATE INDEX IF NOT EXISTS idx_vehicles_owner_device_id ON vehicles (owner_device_id)',
          );
        } catch (e) {
          _logMigrationWarning(
              'idx_vehicles_owner_device_id creation failed', e,);
        }
        try {
          await txn.execute(
            'CREATE INDEX IF NOT EXISTS idx_fuel_expenses_device_id ON fuel_expenses (device_id)',
          );
        } catch (e) {
          _logMigrationWarning(
              'idx_fuel_expenses_device_id creation failed', e,);
        }
        try {
          await txn.execute(
            'CREATE INDEX IF NOT EXISTS idx_general_expenses_device_id ON general_expenses (device_id)',
          );
        } catch (e) {
          _logMigrationWarning(
            'idx_general_expenses_device_id creation failed',
            e,
          );
        }
        try {
          await txn.execute(
            'CREATE INDEX IF NOT EXISTS idx_budgets_device_id ON budgets (device_id)',
          );
        } catch (e) {
          _logMigrationWarning('idx_budgets_device_id creation failed', e);
        }
        try {
          await txn.execute(
            'CREATE INDEX IF NOT EXISTS idx_reminders_device_id ON reminders (device_id)',
          );
        } catch (e) {
          _logMigrationWarning('idx_reminders_device_id creation failed', e);
        }
      }

      // Version 6: Maintenance + collaboration tables
      if (oldVersion < 6) {
        await txn.execute('''
        CREATE TABLE IF NOT EXISTS maintenance_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          vehicle_id INTEGER NOT NULL,
          device_id TEXT NOT NULL,
          type TEXT NOT NULL,
          service_date TEXT NOT NULL,
          cost REAL NOT NULL,
          odometer REAL,
          workshop TEXT,
          notes TEXT,
          next_due_date TEXT,
          document_path TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
          FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
        )
      ''');

        await txn.execute('''
        CREATE TABLE IF NOT EXISTS activity_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          vehicle_id INTEGER NOT NULL,
          device_id TEXT NOT NULL,
          title TEXT NOT NULL,
          description TEXT NOT NULL,
          type TEXT NOT NULL,
          reference_type TEXT,
          reference_id INTEGER,
          created_at TEXT NOT NULL,
          FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
          FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
        )
      ''');

        await txn.execute('''
        CREATE TABLE IF NOT EXISTS expense_comments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          expense_type TEXT NOT NULL,
          expense_id INTEGER NOT NULL,
          device_id TEXT NOT NULL,
          message TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

        await txn.execute('''
        CREATE TABLE IF NOT EXISTS settlements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          vehicle_id INTEGER NOT NULL,
          payer_device_id TEXT NOT NULL,
          payee_device_id TEXT NOT NULL,
          amount REAL NOT NULL,
          status TEXT NOT NULL,
          created_at TEXT NOT NULL,
          settled_at TEXT,
          FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
        )
      ''');

        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_maintenance_vehicle ON maintenance_records (vehicle_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_activity_vehicle ON activity_logs (vehicle_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_comments_expense ON expense_comments (expense_type, expense_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_settlements_vehicle ON settlements (vehicle_id)',
        );
      }

      if (oldVersion < 7) {
        await txn.execute('''
        CREATE TABLE IF NOT EXISTS community_posts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id TEXT NOT NULL,
          author_name TEXT NOT NULL,
          title TEXT NOT NULL,
          message TEXT NOT NULL,
          location TEXT,
          fuel_price REAL,
          likes INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
        )
      ''');

        await txn.execute('''
        CREATE TABLE IF NOT EXISTS achievements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id TEXT NOT NULL,
          badge_key TEXT NOT NULL,
          label TEXT NOT NULL,
          description TEXT,
          points INTEGER DEFAULT 0,
          earned_at TEXT NOT NULL,
          FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
        )
      ''');

        await txn.execute('''
        CREATE TABLE IF NOT EXISTS automation_endpoints (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id TEXT NOT NULL,
          name TEXT NOT NULL,
          url TEXT NOT NULL,
          headers TEXT,
          is_enabled INTEGER DEFAULT 1,
          last_triggered TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
        )
      ''');

        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_posts_device_id ON community_posts (device_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_achievements_device_id ON achievements (device_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_automation_device_id ON automation_endpoints (device_id)',
        );
      }

      if (oldVersion < 8) {
        await txn.execute('''
        CREATE TABLE IF NOT EXISTS device_connections (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          owner_device_id TEXT NOT NULL,
          friend_device_id TEXT NOT NULL,
          friend_name TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (owner_device_id) REFERENCES devices (device_id) ON DELETE CASCADE
        )
      ''');
        await txn.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_connections_unique ON device_connections (owner_device_id, friend_device_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_connections_owner ON device_connections (owner_device_id)',
        );

        await txn.execute('''
        CREATE TABLE IF NOT EXISTS integration_tokens (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id TEXT NOT NULL,
          label TEXT NOT NULL,
          token TEXT NOT NULL,
          created_at TEXT NOT NULL,
          last_used TEXT,
          FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
        )
      ''');
        await txn.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_integration_token_value ON integration_tokens (token)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_integration_tokens_device ON integration_tokens (device_id)',
        );
      }

      // Version 9: Fix user_id to device_id migration for fuel_expenses and general_expenses
      if (oldVersion < 9) {
        // Migrate fuel_expenses if needed
        try {
          final fuelTableInfo =
              await txn.rawQuery('PRAGMA table_info(fuel_expenses)');
          final fuelHasUserId =
              fuelTableInfo.any((col) => col['name'] == 'user_id');

          if (fuelHasUserId) {
            debugPrint('Migrating fuel_expenses from user_id to device_id...');

            await txn.execute('''
            CREATE TABLE fuel_expenses_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              device_id TEXT NOT NULL,
              vehicle_id INTEGER NOT NULL,
              date TEXT NOT NULL,
              fuel_type TEXT NOT NULL,
              amount_paid REAL NOT NULL,
              liters REAL NOT NULL,
              odometer_reading REAL NOT NULL,
              pump_name TEXT,
              location TEXT,
              receipt_image_path TEXT,
              notes TEXT,
              created_at TEXT NOT NULL,
              FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
            )
          ''');

            await txn.execute('''
            INSERT INTO fuel_expenses_new 
            SELECT id, user_id, vehicle_id, date, fuel_type, amount_paid, liters, odometer_reading, 
                   pump_name, location, receipt_image_path, notes, created_at
            FROM fuel_expenses
          ''');

            await txn.execute('DROP TABLE fuel_expenses');
            await txn.execute(
                'ALTER TABLE fuel_expenses_new RENAME TO fuel_expenses',);
            await txn.execute(
              'CREATE INDEX IF NOT EXISTS idx_fuel_expenses_device_id ON fuel_expenses (device_id)',
            );
            await txn.execute(
              'CREATE INDEX IF NOT EXISTS idx_fuel_expenses_vehicle_id ON fuel_expenses (vehicle_id)',
            );

            debugPrint('fuel_expenses migration completed');
          }
        } catch (e) {
          debugPrint('Error migrating fuel_expenses: $e');
        }

        // Migrate general_expenses if needed
        try {
          final generalTableInfo =
              await txn.rawQuery('PRAGMA table_info(general_expenses)');
          final generalHasUserId =
              generalTableInfo.any((col) => col['name'] == 'user_id');

          if (generalHasUserId) {
            debugPrint(
                'Migrating general_expenses from user_id to device_id...',);

            await txn.execute('''
            CREATE TABLE general_expenses_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              device_id TEXT NOT NULL,
              vehicle_id INTEGER,
              date TEXT NOT NULL,
              amount REAL NOT NULL,
              category TEXT NOT NULL,
              description TEXT NOT NULL,
              receipt_image_path TEXT,
              is_household_expense INTEGER DEFAULT 0,
              created_at TEXT NOT NULL,
              FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE SET NULL
            )
          ''');

            await txn.execute('''
            INSERT INTO general_expenses_new 
            SELECT id, user_id, vehicle_id, date, amount, category, description, 
                   receipt_image_path, is_household_expense, created_at
            FROM general_expenses
          ''');

            await txn.execute('DROP TABLE general_expenses');
            await txn.execute(
              'ALTER TABLE general_expenses_new RENAME TO general_expenses',
            );
            await txn.execute(
              'CREATE INDEX IF NOT EXISTS idx_general_expenses_device_id ON general_expenses (device_id)',
            );
            await txn.execute(
              'CREATE INDEX IF NOT EXISTS idx_general_expenses_vehicle_id ON general_expenses (vehicle_id)',
            );

            debugPrint('general_expenses migration completed');
          }
        } catch (e) {
          debugPrint('Error migrating general_expenses: $e');
        }
      }

      if (oldVersion < 10) {
        await txn.execute('''
        CREATE TABLE IF NOT EXISTS family_members (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          avatar_icon TEXT NOT NULL,
          color_hex INTEGER NOT NULL,
          primary_vehicle_id INTEGER,
          created_at TEXT NOT NULL,
          FOREIGN KEY (primary_vehicle_id) REFERENCES vehicles (id) ON DELETE SET NULL
        )
      ''');

        await txn.execute('''
        CREATE TABLE IF NOT EXISTS vehicle_member_preferences (
          vehicle_id INTEGER PRIMARY KEY,
          member_id INTEGER,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
          FOREIGN KEY (member_id) REFERENCES family_members (id) ON DELETE SET NULL
        )
      ''');

        Future<void> addColumnIfMissing(
          String table,
          String column,
          String definition,
        ) async {
          final info = await txn.rawQuery('PRAGMA table_info($table)');
          final exists = info.any((col) => col['name'] == column);
          if (!exists) {
            await txn
                .execute('ALTER TABLE $table ADD COLUMN $column $definition');
          }
        }

        await addColumnIfMissing('fuel_expenses', 'member_id', 'INTEGER');
        await addColumnIfMissing('fuel_expenses', 'member_name', 'TEXT');
        await addColumnIfMissing('fuel_expenses', 'split_member_ids', 'TEXT');

        await addColumnIfMissing('general_expenses', 'member_id', 'INTEGER');
        await addColumnIfMissing('general_expenses', 'member_name', 'TEXT');
        await addColumnIfMissing(
            'general_expenses', 'split_member_ids', 'TEXT',);

        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_fuel_expenses_member_id ON fuel_expenses (member_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_general_expenses_member_id ON general_expenses (member_id)',
        );

        await _ensureDefaultFamilyMembers(txn);
      }

      // Version 11: Add charging_expenses table for electric vehicles
      if (oldVersion < 11) {
        await txn.execute('''
        CREATE TABLE IF NOT EXISTS charging_expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id TEXT NOT NULL,
          vehicle_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          location_type TEXT NOT NULL,
          kwh_charged REAL NOT NULL,
          cost_per_unit REAL NOT NULL,
          total_cost REAL NOT NULL,
          battery_before INTEGER NOT NULL,
          battery_after INTEGER NOT NULL,
          duration_minutes INTEGER NOT NULL,
          odometer_reading REAL NOT NULL,
          charging_type TEXT NOT NULL,
          station_name TEXT,
          address TEXT,
          notes TEXT,
          member_id INTEGER,
          member_name TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
          FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE,
          FOREIGN KEY (member_id) REFERENCES family_members (id) ON DELETE SET NULL
        )
      ''');

        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_charging_expenses_vehicle_id ON charging_expenses (vehicle_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_charging_expenses_device_id ON charging_expenses (device_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_charging_expenses_member_id ON charging_expenses (member_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_charging_expenses_date ON charging_expenses (date)',
        );

        debugPrint('✅ charging_expenses table created successfully');
      }

      // Version 12: Add monthly budget tracking
      if (oldVersion < 12) {
        // Add monthly_budget column to vehicles table
        try {
          await txn
              .execute('ALTER TABLE vehicles ADD COLUMN monthly_budget REAL');
          debugPrint('✅ Added monthly_budget column to vehicles table');
        } catch (e) {
          debugPrint('⚠️ monthly_budget column may already exist: $e');
        }

        // Create budget_history table
        await txn.execute('''
        CREATE TABLE IF NOT EXISTS budget_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          vehicle_id INTEGER NOT NULL,
          month TEXT NOT NULL,
          budget_amount REAL NOT NULL,
          actual_spent REAL NOT NULL,
          difference REAL NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
        )
      ''');

        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_budget_history_vehicle_id ON budget_history (vehicle_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_budget_history_month ON budget_history (month)',
        );
        await txn.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_budget_history_vehicle_month ON budget_history (vehicle_id, month)',
        );

        debugPrint('✅ budget_history table created successfully');
      }

      // Version 13: Add expense templates and favorite stations
      if (oldVersion < 13) {
        // Create expense_templates table
        await txn.execute('''
        CREATE TABLE IF NOT EXISTS expense_templates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          vehicle_id INTEGER NOT NULL,
          vehicle_name TEXT NOT NULL,
          type TEXT NOT NULL,
          station_name TEXT,
          location TEXT,
          liters REAL,
          fuel_type TEXT,
          kwh_amount REAL,
          charging_type TEXT,
          charging_station_name TEXT,
          amount REAL NOT NULL,
          category TEXT,
          description TEXT,
          notes TEXT,
          use_count INTEGER DEFAULT 0,
          last_used_at TEXT,
          created_at TEXT NOT NULL,
          auto_fill_odometer INTEGER DEFAULT 1,
          auto_fill_date INTEGER DEFAULT 1,
          FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
        )
      ''');

        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_templates_vehicle_id ON expense_templates (vehicle_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_templates_type ON expense_templates (type)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_templates_use_count ON expense_templates (use_count DESC)',
        );

        // Create favorite_stations table
        await txn.execute('''
        CREATE TABLE IF NOT EXISTS favorite_stations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          address TEXT,
          location TEXT,
          last_price_per_liter REAL,
          last_price_updated_at TEXT,
          use_count INTEGER DEFAULT 0,
          last_used_at TEXT,
          created_at TEXT NOT NULL,
          brand TEXT,
          fuel_types TEXT,
          has_air_pump INTEGER DEFAULT 0,
          has_washing_facility INTEGER DEFAULT 0
        )
      ''');

        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_stations_use_count ON favorite_stations (use_count DESC)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_stations_name ON favorite_stations (name)',
        );

        debugPrint(
          '✅ expense_templates and favorite_stations tables created successfully',
        );
      }

      // Version 14: Add geofencing and location features
      if (oldVersion < 14) {
        // Create station_geofences table
        await txn.execute('''
        CREATE TABLE IF NOT EXISTS station_geofences (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          station_id INTEGER NOT NULL,
          station_name TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          radius_meters REAL DEFAULT 100.0,
          is_enabled INTEGER DEFAULT 1,
          created_at TEXT NOT NULL,
          last_triggered_at TEXT,
          trigger_count INTEGER DEFAULT 0,
          FOREIGN KEY (station_id) REFERENCES favorite_stations (id) ON DELETE CASCADE
        )
      ''');

        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_geofences_station_id ON station_geofences (station_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_geofences_enabled ON station_geofences (is_enabled)',
        );

        // Create geofence_events table
        await txn.execute('''
        CREATE TABLE IF NOT EXISTS geofence_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          geofence_id INTEGER NOT NULL,
          station_name TEXT NOT NULL,
          event_type INTEGER NOT NULL,
          timestamp TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          notification_shown INTEGER DEFAULT 0,
          expense_logged INTEGER DEFAULT 0,
          expense_id INTEGER,
          FOREIGN KEY (geofence_id) REFERENCES station_geofences (id) ON DELETE CASCADE
        )
      ''');

        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_events_geofence_id ON geofence_events (geofence_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_events_timestamp ON geofence_events (timestamp DESC)',
        );

        // Create location_settings table
        await txn.execute('''
        CREATE TABLE IF NOT EXISTS location_settings (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          geofencing_enabled INTEGER DEFAULT 1,
          background_location_enabled INTEGER DEFAULT 0,
          notifications_enabled INTEGER DEFAULT 1,
          exit_reminders_enabled INTEGER DEFAULT 1,
          exit_reminder_delay_minutes INTEGER DEFAULT 5,
          debounce_hours INTEGER DEFAULT 2,
          quiet_hour_start INTEGER DEFAULT 22,
          quiet_hour_end INTEGER DEFAULT 6,
          default_radius_meters REAL DEFAULT 100.0
        )
      ''');

        // Insert default settings
        await txn.insert('location_settings', {
          'id': 1,
          'geofencing_enabled': 1,
          'background_location_enabled': 0,
          'notifications_enabled': 1,
          'exit_reminders_enabled': 1,
          'exit_reminder_delay_minutes': 5,
          'debounce_hours': 2,
          'quiet_hour_start': 22,
          'quiet_hour_end': 6,
          'default_radius_meters': 100.0,
        });

        // Add latitude and longitude to favorite_stations if not exists
        try {
          await txn.execute(
              'ALTER TABLE favorite_stations ADD COLUMN latitude REAL',);
          await txn.execute(
              'ALTER TABLE favorite_stations ADD COLUMN longitude REAL',);
        } catch (e) {
          // Columns may already exist
          debugPrint('Latitude/Longitude columns may already exist');
        }

        debugPrint('✅ Geofencing tables created successfully');
      }

      // Version 15: Add family tasks and shopping list
      if (oldVersion < 15) {
        // Create family_tasks table
        await txn.execute('''
        CREATE TABLE IF NOT EXISTS family_tasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          description TEXT,
          vehicle_id INTEGER,
          vehicle_name TEXT,
          assigned_to_member_id INTEGER,
          assigned_to_name TEXT,
          due_date TEXT,
          type TEXT NOT NULL DEFAULT 'other',
          priority TEXT NOT NULL DEFAULT 'normal',
          is_urgent INTEGER DEFAULT 0,
          is_completed INTEGER DEFAULT 0,
          completed_at TEXT,
          completed_by_member_id INTEGER,
          completed_by_name TEXT,
          created_by_member_id INTEGER NOT NULL,
          created_by_name TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          recurrence_pattern TEXT DEFAULT 'none',
          recurrence_interval INTEGER,
          recurrence_end_date TEXT,
          parent_task_id INTEGER,
          is_shopping_task INTEGER DEFAULT 0,
          shopping_items_json TEXT,
          firebase_id TEXT UNIQUE,
          is_synced INTEGER DEFAULT 0,
          FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE SET NULL,
          FOREIGN KEY (assigned_to_member_id) REFERENCES family_members (id) ON DELETE SET NULL,
          FOREIGN KEY (created_by_member_id) REFERENCES family_members (id) ON DELETE CASCADE,
          FOREIGN KEY (completed_by_member_id) REFERENCES family_members (id) ON DELETE SET NULL,
          FOREIGN KEY (parent_task_id) REFERENCES family_tasks (id) ON DELETE CASCADE
        )
      ''');

        // Create indexes for performance
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_tasks_assigned_to ON family_tasks (assigned_to_member_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_tasks_vehicle ON family_tasks (vehicle_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON family_tasks (due_date)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_tasks_completed ON family_tasks (is_completed)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_tasks_urgent ON family_tasks (is_urgent)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_tasks_created_by ON family_tasks (created_by_member_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_tasks_type ON family_tasks (type)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_tasks_firebase_id ON family_tasks (firebase_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_tasks_parent ON family_tasks (parent_task_id)',
        );

        debugPrint('✅ Family tasks table created successfully');
      }

      // Version 16: Fix vehicles table schema (remove user_id constraint)
      if (oldVersion < 16) {
        // We don't catch errors here so that if it fails, the transaction rolls back.
        final tableInfo = await txn.rawQuery('PRAGMA table_info(vehicles)');
        final hasUserId = tableInfo.any((col) => col['name'] == 'user_id');

        if (hasUserId) {
          debugPrint('Migrating vehicles table to remove user_id...');

          // Create new table without user_id
          await txn.execute('''
          CREATE TABLE vehicles_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            owner_device_id TEXT,
            name TEXT NOT NULL,
            registration_number TEXT NOT NULL,
            vehicle_type TEXT NOT NULL,
            current_odometer REAL NOT NULL,
            is_shared INTEGER DEFAULT 0,
            monthly_budget REAL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (owner_device_id) REFERENCES devices (device_id) ON DELETE CASCADE
          )
        ''');

          // Copy data
          // Check for existence of all source columns to be safe
          final existingColumns =
              tableInfo.map((c) => c['name'] as String).toSet();

          final targetColumns = <String>[];
          // Core columns that should exist
          if (existingColumns.contains('id')) targetColumns.add('id');
          if (existingColumns.contains('name')) targetColumns.add('name');
          if (existingColumns.contains('registration_number')) {
            targetColumns.add('registration_number');
          }
          if (existingColumns.contains('vehicle_type')) {
            targetColumns.add('vehicle_type');
          }
          if (existingColumns.contains('current_odometer')) {
            targetColumns.add('current_odometer');
          }
          if (existingColumns.contains('created_at')) {
            targetColumns.add('created_at');
          }

          // Optional columns
          if (existingColumns.contains('owner_device_id')) {
            targetColumns.add('owner_device_id');
          }
          if (existingColumns.contains('is_shared')) {
            targetColumns.add('is_shared');
          }
          if (existingColumns.contains('monthly_budget')) {
            targetColumns.add('monthly_budget');
          }

          if (targetColumns.isNotEmpty) {
            final columnsStr = targetColumns.join(', ');
            await txn.execute('''
              INSERT INTO vehicles_new ($columnsStr)
              SELECT $columnsStr FROM vehicles
            ''');
          }

          // Drop old table and rename new
          await txn.execute('DROP TABLE vehicles');
          await txn.execute('ALTER TABLE vehicles_new RENAME TO vehicles');

          // Recreate index
          await txn.execute(
              'CREATE INDEX IF NOT EXISTS idx_vehicles_owner_device_id ON vehicles (owner_device_id)',);

          debugPrint('vehicles table migration completed');
        }
      }

      // Version 17: Add missing indexes for performance optimization
      if (oldVersion < 17) {
        // Add composite indexes for common queries
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_fuel_expenses_vehicle_date ON fuel_expenses (vehicle_id, date DESC)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_general_expenses_date ON general_expenses (date DESC)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_maintenance_records_next_due ON maintenance_records (next_due_date)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_reminders_due_completed ON reminders (due_date, is_completed)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_expense_comments_created ON expense_comments (created_at DESC)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_activity_logs_created ON activity_logs (created_at DESC)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_community_posts_created ON community_posts (created_at DESC)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_trips_active ON trips (is_active, vehicle_id)',
        );

        debugPrint('✅ Additional performance indexes created successfully');
      }

      // Ensure allowances table exists for upgrades from older installs
      if (oldVersion < 20) {
        await txn.execute('''
        CREATE TABLE IF NOT EXISTS allowances (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          member_id INTEGER NOT NULL,
          given_by TEXT NOT NULL,
          amount REAL NOT NULL,
          given_date TEXT NOT NULL,
          purpose TEXT,
          notes TEXT,
          created_at TEXT,
          FOREIGN KEY (member_id) REFERENCES family_members (id) ON DELETE CASCADE
        )
      ''');
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_allowances_member ON allowances (member_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_allowances_date ON allowances (given_date)',
        );
      }

      // Version 21: Add full tank tracking and fuel efficiency optimization
      if (oldVersion < 21) {
        try {
          // Add full tank flag to fuel_expenses
          await txn.execute(
            'ALTER TABLE fuel_expenses ADD COLUMN is_full_tank INTEGER DEFAULT 0',
          );

          // Add fuel efficiency calculation fields
          await txn.execute(
            'ALTER TABLE fuel_expenses ADD COLUMN fuel_efficiency REAL',
          );

          // Add cost per liter calculation field
          await txn.execute(
            'ALTER TABLE fuel_expenses ADD COLUMN cost_per_liter REAL',
          );

          // Create optimization indexes for full tank queries
          await txn.execute(
            'CREATE INDEX IF NOT EXISTS idx_fuel_expenses_is_full_tank ON fuel_expenses (is_full_tank, vehicle_id)',
          );

          // Index for fuel efficiency calculations
          await txn.execute(
            'CREATE INDEX IF NOT EXISTS idx_fuel_expenses_efficiency ON fuel_expenses (vehicle_id, is_full_tank, date DESC)',
          );

          debugPrint('✅ Full tank tracking columns added successfully');
        } catch (e) {
          _logMigrationWarning('Full tank tracking migration failed', e);
        }
      }

      // Version 18: Add V2 features - Split bills, recurring expenses, payments
      if (oldVersion < 18) {
        // Create expense_splits table for tracking how expenses are divided
        await txn.execute('''
        CREATE TABLE IF NOT EXISTS expense_splits (
          id TEXT PRIMARY KEY,
          expense_id TEXT NOT NULL,
          member_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          split_type TEXT NOT NULL,
          percentage REAL,
          shares INTEGER,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          FOREIGN KEY (member_id) REFERENCES family_members (id) ON DELETE CASCADE
        )
      ''');

        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_splits_expense_id ON expense_splits (expense_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_splits_member_id ON expense_splits (member_id)',
        );

        // Create recurring_expenses table for auto-generating expenses
        await txn.execute('''
        CREATE TABLE IF NOT EXISTS recurring_expenses (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          description TEXT,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          member_id INTEGER,
          frequency TEXT NOT NULL,
          start_date TEXT NOT NULL,
          end_date TEXT,
          day_of_month INTEGER,
          day_of_week INTEGER,
          is_active INTEGER NOT NULL DEFAULT 1,
          device_id TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          last_generated TEXT,
          next_due TEXT,
          FOREIGN KEY (member_id) REFERENCES family_members (id) ON DELETE SET NULL
        )
      ''');

        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_recurring_active ON recurring_expenses (is_active, next_due)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_recurring_member ON recurring_expenses (member_id)',
        );

        // Create payments table for settlement tracking
        await txn.execute('''
        CREATE TABLE IF NOT EXISTS payments (
          id TEXT PRIMARY KEY,
          from_member_id INTEGER NOT NULL,
          to_member_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          payment_method TEXT NOT NULL,
          status TEXT NOT NULL,
          payment_date TEXT NOT NULL,
          notes TEXT,
          receipt_path TEXT,
          reference_number TEXT,
          device_id TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          FOREIGN KEY (from_member_id) REFERENCES family_members (id) ON DELETE CASCADE,
          FOREIGN KEY (to_member_id) REFERENCES family_members (id) ON DELETE CASCADE
        )
      ''');

        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_payments_from_member ON payments (from_member_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_payments_to_member ON payments (to_member_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_payments_status ON payments (status)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_payments_date ON payments (payment_date DESC)',
        );

        debugPrint(
            '✅ V2 tables (expense_splits, recurring_expenses, payments) created successfully',);
      }

      // Version 19: Add OCR Receipt Management
      if (oldVersion < 19) {
        // Create receipts table for storing OCR-processed receipt data
        await txn.execute('''
        CREATE TABLE IF NOT EXISTS receipts (
          id TEXT PRIMARY KEY,
          expense_id TEXT,
          image_path TEXT NOT NULL,
          merchant_name TEXT,
          amount REAL,
          receipt_date TEXT,
          tax_amount REAL,
          ocr_confidence REAL NOT NULL DEFAULT 0.0,
          status TEXT NOT NULL DEFAULT 'pending',
          processed_data TEXT,
          multi_language_texts TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          device_id TEXT,
          FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
        )
      ''');

        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_receipts_expense_id ON receipts (expense_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_receipts_status ON receipts (status)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_receipts_date ON receipts (created_at DESC)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_receipts_confidence ON receipts (ocr_confidence DESC)',
        );

        // Create receipt_ocr_data table for tracking multiple OCR processing attempts
        await txn.execute('''
        CREATE TABLE IF NOT EXISTS receipt_ocr_data (
          id TEXT PRIMARY KEY,
          receipt_id TEXT NOT NULL,
          raw_text TEXT NOT NULL,
          confidence REAL NOT NULL,
          field_confidences TEXT,
          items TEXT,
          processing_model TEXT,
          language_detected TEXT,
          processed_at TEXT NOT NULL,
          FOREIGN KEY (receipt_id) REFERENCES receipts (id) ON DELETE CASCADE
        )
      ''');

        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_ocr_data_receipt_id ON receipt_ocr_data (receipt_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_ocr_data_processed_at ON receipt_ocr_data (processed_at DESC)',
        );

        debugPrint('✅ Receipt OCR tables created successfully');
      }
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';
    const integerType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';

    // Devices table
    await db.execute('''
      CREATE TABLE devices (
        id $idType,
        device_id $textType UNIQUE,
        person_name $textType,
        profile_picture_path $textTypeNullable,
        is_active INTEGER DEFAULT 0,
        created_at $textType,
        updated_at $textType
      )
    ''');

    // Users table
    await db.execute('''
      CREATE TABLE users (
        id $idType,
        name $textType,
        profile_picture_path $textTypeNullable,
        created_at $textType
      )
    ''');

    // Vehicles table (device-based ownership)
    await db.execute('''
      CREATE TABLE vehicles (
        id $idType,
        owner_device_id $textType,
        name $textType,
        registration_number $textType,
        vehicle_type $textType,
        current_odometer $realType,
        is_shared INTEGER DEFAULT 0,
        monthly_budget REAL,
        created_at $textType,
        FOREIGN KEY (owner_device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');

    // Family members table (Created early because other tables reference it)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS family_members (
        id $idType,
        name $textType,
        avatar_icon $textType,
        color_hex INTEGER NOT NULL,
        primary_vehicle_id INTEGER,
        created_at $textType,
        FOREIGN KEY (primary_vehicle_id) REFERENCES vehicles (id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_family_members_primary_vehicle ON family_members (primary_vehicle_id)',
    );

    // Allowances table - track money given to family members
    await db.execute('''
      CREATE TABLE IF NOT EXISTS allowances (
        id $idType,
        member_id INTEGER NOT NULL,
        given_by $textType,
        amount $realType,
        given_date $textType,
        purpose $textTypeNullable,
        notes $textTypeNullable,
        created_at $textType,
        FOREIGN KEY (member_id) REFERENCES family_members (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_allowances_member ON allowances (member_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_allowances_date ON allowances (given_date)',
    );

    // Fuel expenses table
    await db.execute('''
      CREATE TABLE fuel_expenses (
        id $idType,
        device_id $textType,
        vehicle_id $integerType,
        date $textType,
        fuel_type $textType,
        amount_paid $realType,
        liters $realType,
        odometer_reading $realType,
        pump_name $textTypeNullable,
        location $textTypeNullable,
        receipt_image_path $textTypeNullable,
        notes $textTypeNullable,
        member_id INTEGER,
        member_name $textTypeNullable,
        split_member_ids $textTypeNullable,
        created_at $textType,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');

    // General expenses table
    await db.execute('''
      CREATE TABLE general_expenses (
        id $idType,
        device_id $textType,
        vehicle_id INTEGER,
        date $textType,
        amount $realType,
        category $textType,
        description $textType,
        receipt_image_path $textTypeNullable,
        is_household_expense INTEGER DEFAULT 0,
        member_id INTEGER,
        member_name $textTypeNullable,
        split_member_ids $textTypeNullable,
        created_at $textType,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE SET NULL,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better query performance
    await db.execute(
      'CREATE INDEX idx_vehicles_owner_device_id ON vehicles (owner_device_id)',
    );
    await db.execute(
      'CREATE INDEX idx_fuel_expenses_device_id ON fuel_expenses (device_id)',
    );
    await db.execute(
      'CREATE INDEX idx_fuel_expenses_vehicle_id ON fuel_expenses (vehicle_id)',
    );
    await db.execute(
      'CREATE INDEX idx_general_expenses_device_id ON general_expenses (device_id)',
    );
    await db.execute(
      'CREATE INDEX idx_general_expenses_vehicle_id ON general_expenses (vehicle_id)',
    );

    // Add indexes for date-based queries to improve performance
    await db.execute(
      'CREATE INDEX idx_fuel_expenses_date ON fuel_expenses (date)',
    );
    await db.execute(
      'CREATE INDEX idx_fuel_expenses_created_at ON fuel_expenses (created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_general_expenses_date ON general_expenses (date)',
    );
    await db.execute(
      'CREATE INDEX idx_general_expenses_created_at ON general_expenses (created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_general_expenses_is_household ON general_expenses (is_household_expense)',
    );

    // Vehicle-member preference table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vehicle_member_preferences (
        vehicle_id INTEGER PRIMARY KEY,
        member_id INTEGER,
        updated_at $textType,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
        FOREIGN KEY (member_id) REFERENCES family_members (id) ON DELETE SET NULL
      )
    ''');

    // Budgets (device-based)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id $idType,
        device_id $textType,
        month $textType,
        fuel_limit REAL DEFAULT 0,
        general_limit REAL DEFAULT 0,
        household_limit REAL DEFAULT 0,
        created_at $textType,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_budgets_device_id ON budgets (device_id)',
    );

    // Reminders (device-based)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reminders (
        id $idType,
        vehicle_id $integerType,
        device_id $textType,
        type $textType,
        title $textType,
        description $textTypeNullable,
        due_date $textType,
        is_completed INTEGER DEFAULT 0,
        created_at $textType,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reminders_device_id ON reminders (device_id)',
    );

    // Vehicle access table (device-based)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vehicle_access (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id INTEGER NOT NULL,
        device_id TEXT NOT NULL,
        access_type TEXT NOT NULL,
        created_at $textType,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');

    // Trips table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trips (
        id $idType,
        vehicle_id $integerType,
        device_id $textType,
        start_location $textType,
        end_location $textTypeNullable,
        start_odometer REAL,
        end_odometer REAL,
        distance REAL,
        start_time $textType,
        end_time $textTypeNullable,
        purpose $textType,
        notes $textTypeNullable,
        fuel_expense_id INTEGER,
        is_active INTEGER DEFAULT 1,
        created_at $textType,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
        FOREIGN KEY (fuel_expense_id) REFERENCES fuel_expenses (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS community_posts (
        id $idType,
        device_id $textType,
        author_name $textType,
        title $textType,
        message $textType,
        location $textTypeNullable,
        fuel_price REAL,
        likes INTEGER DEFAULT 0,
        created_at $textType,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_posts_device_id ON community_posts (device_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS achievements (
        id $idType,
        device_id $textType,
        badge_key $textType,
        label $textType,
        description $textTypeNullable,
        points INTEGER DEFAULT 0,
        earned_at $textType,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_achievements_device_id ON achievements (device_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS automation_endpoints (
        id $idType,
        device_id $textType,
        name $textType,
        url $textType,
        headers $textTypeNullable,
        is_enabled INTEGER DEFAULT 1,
        last_triggered $textTypeNullable,
        created_at $textType,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_automation_device_id ON automation_endpoints (device_id)',
    );

    // Charging expenses table for electric vehicles
    await db.execute('''
      CREATE TABLE IF NOT EXISTS charging_expenses (
        id $idType,
        device_id $textType,
        vehicle_id $integerType,
        date $textType,
        location_type $textType,
        kwh_charged $realType,
        cost_per_unit $realType,
        total_cost $realType,
        battery_before INTEGER NOT NULL,
        battery_after INTEGER NOT NULL,
        duration_minutes INTEGER NOT NULL,
        odometer_reading $realType,
        charging_type $textType,
        station_name $textTypeNullable,
        address $textTypeNullable,
        notes $textTypeNullable,
        member_id INTEGER,
        member_name $textTypeNullable,
        created_at $textType,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE,
        FOREIGN KEY (member_id) REFERENCES family_members (id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_charging_expenses_vehicle_id ON charging_expenses (vehicle_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_charging_expenses_device_id ON charging_expenses (device_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_charging_expenses_member_id ON charging_expenses (member_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_charging_expenses_date ON charging_expenses (date)',
    );

    // Budget history table for vehicle budget tracking
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budget_history (
        id $idType,
        vehicle_id $integerType,
        month $textType,
        budget_amount $realType,
        actual_spent $realType,
        difference $realType,
        created_at $textType,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_budget_history_vehicle_id ON budget_history (vehicle_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_budget_history_month ON budget_history (month)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_budget_history_vehicle_month ON budget_history (vehicle_id, month)',
    );

    // Expense templates table for quick logging
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_templates (
        id $idType,
        name $textType,
        vehicle_id $integerType,
        vehicle_name $textType,
        type $textType,
        station_name $textTypeNullable,
        location $textTypeNullable,
        liters REAL,
        fuel_type $textTypeNullable,
        kwh_amount REAL,
        charging_type $textTypeNullable,
        charging_station_name $textTypeNullable,
        amount $realType,
        category $textTypeNullable,
        description $textTypeNullable,
        notes $textTypeNullable,
        use_count INTEGER DEFAULT 0,
        last_used_at $textTypeNullable,
        created_at $textType,
        auto_fill_odometer INTEGER DEFAULT 1,
        auto_fill_date INTEGER DEFAULT 1,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_templates_vehicle_id ON expense_templates (vehicle_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_templates_type ON expense_templates (type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_templates_use_count ON expense_templates (use_count DESC)',
    );

    // Favorite stations table for quick station selection
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_stations (
        id $idType,
        name $textType,
        address $textTypeNullable,
        location $textTypeNullable,
        latitude REAL,
        longitude REAL,
        last_price_per_liter REAL,
        last_price_updated_at $textTypeNullable,
        use_count INTEGER DEFAULT 0,
        last_used_at $textTypeNullable,
        created_at $textType,
        brand $textTypeNullable,
        fuel_types $textTypeNullable,
        has_air_pump INTEGER DEFAULT 0,
        has_washing_facility INTEGER DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stations_use_count ON favorite_stations (use_count DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stations_name ON favorite_stations (name)',
    );

    // Station geofences for location-based triggers
    await db.execute('''
      CREATE TABLE IF NOT EXISTS station_geofences (
        id $idType,
        station_id $integerType,
        station_name $textType,
        latitude $realType,
        longitude $realType,
        radius_meters REAL DEFAULT 100.0,
        is_enabled INTEGER DEFAULT 1,
        created_at $textType,
        last_triggered_at $textTypeNullable,
        trigger_count INTEGER DEFAULT 0,
        FOREIGN KEY (station_id) REFERENCES favorite_stations (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_geofences_station_id ON station_geofences (station_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_geofences_enabled ON station_geofences (is_enabled)',
    );

    // Geofence events log
    await db.execute('''
      CREATE TABLE IF NOT EXISTS geofence_events (
        id $idType,
        geofence_id $integerType,
        station_name $textType,
        event_type $integerType,
        timestamp $textType,
        latitude $realType,
        longitude $realType,
        notification_shown INTEGER DEFAULT 0,
        expense_logged INTEGER DEFAULT 0,
        expense_id INTEGER,
        FOREIGN KEY (geofence_id) REFERENCES station_geofences (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_events_geofence_id ON geofence_events (geofence_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_events_timestamp ON geofence_events (timestamp DESC)',
    );

    // Location settings
    await db.execute('''
      CREATE TABLE IF NOT EXISTS location_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        geofencing_enabled INTEGER DEFAULT 1,
        background_location_enabled INTEGER DEFAULT 0,
        notifications_enabled INTEGER DEFAULT 1,
        exit_reminders_enabled INTEGER DEFAULT 1,
        exit_reminder_delay_minutes INTEGER DEFAULT 5,
        debounce_hours INTEGER DEFAULT 2,
        quiet_hour_start INTEGER DEFAULT 22,
        quiet_hour_end INTEGER DEFAULT 6,
        default_radius_meters REAL DEFAULT 100.0
      )
    ''');
    await db.insert('location_settings', {
      'id': 1,
      'geofencing_enabled': 1,
      'background_location_enabled': 0,
      'notifications_enabled': 1,
      'exit_reminders_enabled': 1,
      'exit_reminder_delay_minutes': 5,
      'debounce_hours': 2,
      'quiet_hour_start': 22,
      'quiet_hour_end': 6,
      'default_radius_meters': 100.0,
    });

    // Family tasks table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS family_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        vehicle_id INTEGER,
        vehicle_name TEXT,
        assigned_to_member_id INTEGER,
        assigned_to_name TEXT,
        due_date TEXT,
        type TEXT NOT NULL DEFAULT 'other',
        priority TEXT NOT NULL DEFAULT 'normal',
        is_urgent INTEGER DEFAULT 0,
        is_completed INTEGER DEFAULT 0,
        completed_at TEXT,
        completed_by_member_id INTEGER,
        completed_by_name TEXT,
        created_by_member_id INTEGER NOT NULL,
        created_by_name TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        recurrence_pattern TEXT DEFAULT 'none',
        recurrence_interval INTEGER,
        recurrence_end_date TEXT,
        parent_task_id INTEGER,
        is_shopping_task INTEGER DEFAULT 0,
        shopping_items_json TEXT,
        firebase_id TEXT UNIQUE,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE SET NULL,
        FOREIGN KEY (assigned_to_member_id) REFERENCES family_members (id) ON DELETE SET NULL,
        FOREIGN KEY (created_by_member_id) REFERENCES family_members (id) ON DELETE CASCADE,
        FOREIGN KEY (completed_by_member_id) REFERENCES family_members (id) ON DELETE SET NULL,
        FOREIGN KEY (parent_task_id) REFERENCES family_tasks (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_assigned_to ON family_tasks (assigned_to_member_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_vehicle ON family_tasks (vehicle_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON family_tasks (due_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_completed ON family_tasks (is_completed)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_urgent ON family_tasks (is_urgent)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_created_by ON family_tasks (created_by_member_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_type ON family_tasks (type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_firebase_id ON family_tasks (firebase_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_parent ON family_tasks (parent_task_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS device_connections (
        id $idType,
        owner_device_id $textType,
        friend_device_id $textType,
        friend_name $textType,
        created_at $textType,
        FOREIGN KEY (owner_device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_connections_unique ON device_connections (owner_device_id, friend_device_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_connections_owner ON device_connections (owner_device_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS integration_tokens (
        id $idType,
        device_id $textType,
        label $textType,
        token $textType,
        created_at $textType,
        last_used $textTypeNullable,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_integration_token_value ON integration_tokens (token)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_integration_tokens_device ON integration_tokens (device_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS maintenance_records (
        id $idType,
        vehicle_id $integerType,
        device_id $textType,
        type $textType,
        service_date $textType,
        cost $realType,
        odometer REAL,
        workshop $textTypeNullable,
        notes $textTypeNullable,
        next_due_date $textTypeNullable,
        document_path $textTypeNullable,
        created_at $textType,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_maintenance_vehicle ON maintenance_records (vehicle_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity_logs (
        id $idType,
        vehicle_id $integerType,
        device_id $textType,
        title $textType,
        description $textType,
        type $textType,
        reference_type $textTypeNullable,
        reference_id INTEGER,
        created_at $textType,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_activity_vehicle ON activity_logs (vehicle_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_comments (
        id $idType,
        expense_type $textType,
        expense_id INTEGER,
        device_id $textType,
        message $textType,
        created_at $textType
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_comments_expense ON expense_comments (expense_type, expense_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settlements (
        id $idType,
        vehicle_id $integerType,
        payer_device_id $textType,
        payee_device_id $textType,
        amount $realType,
        status $textType,
        created_at $textType,
        settled_at $textTypeNullable,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_settlements_vehicle ON settlements (vehicle_id)',
    );

    await _ensureDefaultFamilyMembers(db);
  }

  // ==================== USER OPERATIONS ====================

  Future<User> createUser(User user) async {
    final db = await database;
    final id = await db.insert('users', user.toMap());
    return user.copyWith(id: id);
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final result = await db.query('users', orderBy: 'created_at DESC');
    return result.map((json) => User.fromMap(json)).toList();
  }

  Future<List<Map<String, dynamic>>> getAllUsersAsMap() async {
    final db = await database;
    return db.query('users', orderBy: 'name');
  }

  Future<User?> getUser(int id) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== VEHICLE OPERATIONS ====================

  Future<Vehicle> createVehicle(Vehicle vehicle) async {
    try {
      final db = await database;
      debugPrint('Creating vehicle with data: ${vehicle.toMap()}');
      final id = await db.insert('vehicles', vehicle.toMap());
      debugPrint('Vehicle created successfully with id: $id');
      return vehicle.copyWith(id: id);
    } catch (e) {
      debugPrint('Error creating vehicle: $e');
      rethrow;
    }
  }

  Future<List<Vehicle>> getVehiclesByOwnerDevice(String deviceId) async {
    final db = await database;
    final result = await db.query(
      'vehicles',
      where: 'owner_device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'created_at DESC',
    );
    return result.map((json) => Vehicle.fromMap(json)).toList();
  }

  // 🆕 PHASE 2: Added query caching
  Future<List<Vehicle>> getAllVehicles() async {
    return QueryCache.instance.getOrFetch(
      CacheKeys.vehicles(),
      () async {
        final db = await database;
        final result = await db.query('vehicles', orderBy: 'created_at DESC');
        return result.map((json) => Vehicle.fromMap(json)).toList();
      },
      ttl: const Duration(minutes: 5),
    );
  }

  Future<Vehicle?> getVehicle(int id) async {
    final db = await database;
    final maps = await db.query(
      'vehicles',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Vehicle.fromMap(maps.first);
    }
    return null;
  }

  Future<Vehicle?> getVehicleByRegistration(String registrationNumber) async {
    final db = await database;
    final maps = await db.query(
      'vehicles',
      where: 'UPPER(registration_number) = ?',
      whereArgs: [registrationNumber.toUpperCase()],
    );
    if (maps.isNotEmpty) {
      return Vehicle.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateVehicle(Vehicle vehicle, String? deviceId) async {
    // Permission check: only owner can update vehicle
    if (deviceId != null && vehicle.ownerDeviceId != deviceId) {
      // Check if user has contributor or owner access
      final access = await getVehicleAccess(vehicle.id!, deviceId);
      if (access == null || access['access_type'] != 'owner') {
        throw Exception(
          'Permission denied: Only owner can update vehicle details',
        );
      }
    }

    final db = await database;
    return db.update(
      'vehicles',
      vehicle.toMap(),
      where: 'id = ?',
      whereArgs: [vehicle.id],
    );
  }

  Future<int> deleteVehicle(int id, String? deviceId) async {
    // Permission check: only owner can delete vehicle
    if (deviceId != null) {
      final vehicle = await getVehicle(id);
      if (vehicle == null) {
        throw Exception('Vehicle not found');
      }
      if (vehicle.ownerDeviceId != deviceId) {
        throw Exception('Permission denied: Only owner can delete vehicle');
      }
    }

    final db = await database;
    return db.delete(
      'vehicles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== FUEL EXPENSE OPERATIONS ====================

  Future<FuelExpense> createFuelExpense(FuelExpense expense) async {
    final db = await database;
    try {
      // Use transaction for data integrity
      final id = await db.transaction((txn) async {
        return txn.insert('fuel_expenses', expense.toMap());
      });
      return expense.copyWith(id: id);
    } catch (e) {
      debugPrint('Error creating fuel expense: $e');
      rethrow;
    }
  }

  Future<List<FuelExpense>> getFuelExpensesByVehicle(int vehicleId) async {
    final db = await database;
    final result = await db.query(
      'fuel_expenses',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC',
    );
    return result.map((json) => FuelExpense.fromMap(json)).toList();
  }

  // Get all fuel expenses (single account, all devices)
  // 🆕 PHASE 2: Added query caching
  Future<List<FuelExpense>> getAllFuelExpenses() async {
    return QueryCache.instance.getOrFetch(
      CacheKeys.fuelExpenses(),
      () async {
        final db = await database;
        final result = await db.query(
          'fuel_expenses',
          orderBy: 'date DESC',
        );
        return result.map((json) => FuelExpense.fromMap(json)).toList();
      },
      ttl: const Duration(minutes: 5),
    );
  }

  // Get fuel expenses by device
  Future<List<FuelExpense>> getFuelExpensesByDevice(String deviceId) async {
    final db = await database;
    final result = await db.query(
      'fuel_expenses',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'date DESC',
    );
    return result.map((json) => FuelExpense.fromMap(json)).toList();
  }

  Future<List<FuelExpense>> getFuelExpensesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final result = await db.query(
      'fuel_expenses',
      where: 'date >= ? AND date <= ?',
      whereArgs: [
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'date DESC',
    );
    return result.map((json) => FuelExpense.fromMap(json)).toList();
  }

  Future<int> updateFuelExpense(FuelExpense expense, String? deviceId) async {
    // Permission check: user must have contributor or owner access to vehicle
    if (deviceId != null) {
      final vehicle = await getVehicle(expense.vehicleId);
      if (vehicle == null) {
        throw Exception('Vehicle not found');
      }

      // Allow if user is vehicle owner
      if (vehicle.ownerDeviceId != deviceId) {
        // Check for contributor/owner access
        final access = await getVehicleAccess(expense.vehicleId, deviceId);
        if (access == null ||
            (access['access_type'] != 'owner' &&
                access['access_type'] != 'contributor')) {
          throw Exception(
            'Permission denied: Need contributor or owner access to update expenses',
          );
        }
      }
    }

    final db = await database;
    // 🆕 PHASE 2: Invalidate cache after update
    final result = await db.update(
      'fuel_expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
    QueryCache.instance.invalidatePattern('fuel_expenses');
    QueryCache.instance.invalidatePattern('vehicle_${expense.vehicleId}');
    return result;
  }

  Future<int> deleteFuelExpense(int id, String? deviceId) async {
    // Permission check: user must have contributor or owner access to vehicle
    if (deviceId != null) {
      final expense = await getFuelExpense(id);
      if (expense == null) {
        throw Exception('Expense not found');
      }

      final vehicle = await getVehicle(expense.vehicleId);
      if (vehicle == null) {
        throw Exception('Vehicle not found');
      }

      // Allow if user is vehicle owner
      if (vehicle.ownerDeviceId != deviceId) {
        // Check for contributor/owner access
        final access = await getVehicleAccess(expense.vehicleId, deviceId);
        if (access == null ||
            (access['access_type'] != 'owner' &&
                access['access_type'] != 'contributor')) {
          throw Exception(
            'Permission denied: Need contributor or owner access to delete expenses',
          );
        }
      }
    }

    final db = await database;
    // 🆕 PHASE 2: Invalidate cache after delete
    // Get expense first to know which vehicle cache to invalidate
    final expense = await getFuelExpense(id);
    final result = await db.delete(
      'fuel_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
    QueryCache.instance.invalidatePattern('fuel_expenses');
    if (expense != null) {
      QueryCache.instance.invalidatePattern('vehicle_${expense.vehicleId}');
    }
    return result;

  Future<FuelExpense?> getLastFuelExpense(int vehicleId) async {
    final db = await database;
    final result = await db.query(
      'fuel_expenses',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC, odometer_reading DESC',
      limit: 1,
    );
    if (result.isEmpty) return null;
    return FuelExpense.fromMap(result.first);
  }

  Future<FuelExpense?> getFuelExpense(int id) async {
    final db = await database;
    final maps = await db.query(
      'fuel_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return FuelExpense.fromMap(maps.first);
    }
    return null;
  }

  Future<List<FuelExpense>> getFuelExpensesPaginated({
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final result = await db.query(
      'fuel_expenses',
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
    return result.map((json) => FuelExpense.fromMap(json)).toList();
  }

  Future<List<FuelExpense>> searchFuelExpenses(String query) async {
    final db = await database;
    final maps = await db.query(
      'fuel_expenses',
      where: 'pump_name LIKE ? OR location LIKE ? OR notes LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'date DESC',
      limit: AppConstants.paginationBatchSize,
    );
    return maps.map((json) => FuelExpense.fromMap(json)).toList();
  }

  Future<Map<String, double>> calculateFuelAverages(int vehicleId) async {
    final expenses = await getFuelExpensesByVehicle(vehicleId);

    if (expenses.length < 2) return {};

    // Sort by odometer reading
    expenses.sort((a, b) => a.odometerReading.compareTo(b.odometerReading));

    double totalDistance = 0;
    double totalLiters = 0;

    // Calculate overall average
    for (int i = 1; i < expenses.length; i++) {
      final distance =
          expenses[i].odometerReading - expenses[i - 1].odometerReading;
      final liters = expenses[i].liters;

      if (distance > 0 && liters > 0) {
        totalDistance += distance;
        totalLiters += liters;
      }
    }

    // Calculate last 5 fillups average
    double last5Distance = 0;
    double last5Liters = 0;
    final last5Count = expenses.length < 6 ? expenses.length : 6;

    for (int i = expenses.length - 1;
        i >= expenses.length - last5Count + 1;
        i--) {
      final distance =
          expenses[i].odometerReading - expenses[i - 1].odometerReading;
      final liters = expenses[i].liters;

      if (distance > 0 && liters > 0) {
        last5Distance += distance;
        last5Liters += liters;
      }
    }

    // Calculate monthly average (last 30 days)
    final now = DateTime.now();
    final monthAgo = now.subtract(const Duration(days: 30));
    double monthlyDistance = 0;
    double monthlyLiters = 0;

    final recentExpenses =
        expenses.where((e) => e.date.isAfter(monthAgo)).toList();
    if (recentExpenses.length >= 2) {
      recentExpenses
          .sort((a, b) => a.odometerReading.compareTo(b.odometerReading));

      for (int i = 1; i < recentExpenses.length; i++) {
        final distance = recentExpenses[i].odometerReading -
            recentExpenses[i - 1].odometerReading;
        final liters = recentExpenses[i].liters;

        if (distance > 0 && liters > 0) {
          monthlyDistance += distance;
          monthlyLiters += liters;
        }
      }
    }

    return {
      'lifetime_average': totalLiters > 0 ? totalDistance / totalLiters : 0.0,
      'last_5_average': last5Liters > 0 ? last5Distance / last5Liters : 0.0,
      'monthly_average':
          monthlyLiters > 0 ? monthlyDistance / monthlyLiters : 0.0,
    };
  }

  // ==================== GENERAL EXPENSE OPERATIONS ====================

  Future<GeneralExpense> createGeneralExpense(GeneralExpense expense) async {
    try {
      final db = await database;
      debugPrint('Creating general expense with data: ${expense.toMap()}');

      // Use transaction for data integrity
      final id = await db.transaction((txn) async {
        return txn.insert('general_expenses', expense.toMap());
      });

      debugPrint('General expense created successfully with id: $id');
      return expense.copyWith(id: id);
    } catch (e) {
      debugPrint('Error creating general expense: $e');
      debugPrint('Expense data: ${expense.toMap()}');
      rethrow;
    }
  }

  // Get all general expenses (single account, all devices)
  // 🆕 PHASE 2: Added query caching
  Future<List<GeneralExpense>> getAllGeneralExpenses() async {
    return QueryCache.instance.getOrFetch(
      CacheKeys.generalExpenses(),
      () async {
        final db = await database;
        final result = await db.query(
          'general_expenses',
          orderBy: 'date DESC',
        );
        return result.map((json) => GeneralExpense.fromMap(json)).toList();
      },
      ttl: const Duration(minutes: 5),
    );
  }

  Future<List<GeneralExpense>> getGeneralExpensesPaginated({
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final result = await db.query(
      'general_expenses',
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
    return result.map((json) => GeneralExpense.fromMap(json)).toList();
  }

  // Get general expenses by device
  Future<List<GeneralExpense>> getGeneralExpensesByDevice(
    String deviceId,
  ) async {
    final db = await database;
    final result = await db.query(
      'general_expenses',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'date DESC',
    );
    return result.map((json) => GeneralExpense.fromMap(json)).toList();
  }

  Future<List<GeneralExpense>> getGeneralExpensesByVehicle(
    int vehicleId,
  ) async {
    final db = await database;
    final result = await db.query(
      'general_expenses',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC',
    );
    return result.map((json) => GeneralExpense.fromMap(json)).toList();
  }

  // Get all household expenses (single account, all devices)
  Future<List<GeneralExpense>> getAllHouseholdExpenses() async {
    final db = await database;
    final result = await db.query(
      'general_expenses',
      where: 'is_household_expense = 1',
      orderBy: 'date DESC',
    );
    return result.map((json) => GeneralExpense.fromMap(json)).toList();
  }

  // Get household expenses by device
  Future<List<GeneralExpense>> getHouseholdExpensesByDevice(
    String deviceId,
  ) async {
    final db = await database;
    final result = await db.query(
      'general_expenses',
      where: 'device_id = ? AND is_household_expense = 1',
      whereArgs: [deviceId],
      orderBy: 'date DESC',
    );
    return result.map((json) => GeneralExpense.fromMap(json)).toList();
  }

  // Get all general expenses in date range (single account, all devices)
  Future<List<GeneralExpense>> getGeneralExpensesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final result = await db.query(
      'general_expenses',
      where: 'date >= ? AND date <= ?',
      whereArgs: [
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'date DESC',
    );
    return result.map((json) => GeneralExpense.fromMap(json)).toList();
  }

  Future<GeneralExpense?> getGeneralExpense(int id) async {
    final db = await database;
    final maps = await db.query(
      'general_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return GeneralExpense.fromMap(maps.first);
    }
    return null;
  }

  Future<List<GeneralExpense>> searchGeneralExpenses(String query) async {
    final db = await database;
    final maps = await db.query(
      'general_expenses',
      where: 'description LIKE ? OR category LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'date DESC',
      limit: AppConstants.paginationBatchSize,
    );
    return maps.map((json) => GeneralExpense.fromMap(json)).toList();
  }

  Future<int> updateGeneralExpense(
    GeneralExpense expense,
    String? deviceId,
  ) async {
    // Permission check: user must have contributor or owner access to vehicle (if vehicle expense)
    if (deviceId != null && expense.vehicleId != null) {
      final vehicle = await getVehicle(expense.vehicleId!);
      if (vehicle == null) {
        throw Exception('Vehicle not found');
      }

      // Allow if user is vehicle owner
      if (vehicle.ownerDeviceId != deviceId) {
        // Check for contributor/owner access
        final access = await getVehicleAccess(expense.vehicleId!, deviceId);
        if (access == null ||
            (access['access_type'] != 'owner' &&
                access['access_type'] != 'contributor')) {
          throw Exception(
            'Permission denied: Need contributor or owner access to update expenses',
          );
        }
      }
    }

    final db = await database;
    // 🆕 PHASE 2: Invalidate cache after update
    final result = await db.update(
      'general_expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
    QueryCache.instance.invalidatePattern('general_expenses');
    if (expense.vehicleId != null) {
      QueryCache.instance.invalidatePattern('vehicle_${expense.vehicleId}');
    }
    return result;
  }

  Future<int> deleteGeneralExpense(int id, String? deviceId) async {
    // Permission check: user must have contributor or owner access to vehicle (if vehicle expense)
    if (deviceId != null) {
      final expense = await getGeneralExpense(id);
      if (expense == null) {
        throw Exception('Expense not found');
      }

      if (expense.vehicleId != null) {
        final vehicle = await getVehicle(expense.vehicleId!);
        if (vehicle == null) {
          throw Exception('Vehicle not found');
        }

        // Allow if user is vehicle owner
        if (vehicle.ownerDeviceId != deviceId) {
          // Check for contributor/owner access
          final access = await getVehicleAccess(expense.vehicleId!, deviceId);
          if (access == null ||
              (access['access_type'] != 'owner' &&
                  access['access_type'] != 'contributor')) {
            throw Exception(
              'Permission denied: Need contributor or owner access to delete expenses',
            );
          }
        }
      }
    }

    final db = await database;
    // 🆕 PHASE 2: Invalidate cache after delete
    final result = await db.delete(
      'general_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
    QueryCache.instance.invalidatePattern('general_expenses');
    if (deviceId != null) {
      final expense = await getGeneralExpense(id);
      if (expense?.vehicleId != null) {
        QueryCache.instance.invalidatePattern('vehicle_${expense!.vehicleId}');
      }
    }
    return result;
  }

  // ==================== ANALYTICS OPERATIONS ====================

  Future<double> calculateFuelAverage(int vehicleId) async {
    final expenses = await getFuelExpensesByVehicle(vehicleId);

    if (expenses.length < 2) return 0.0;

    // Sort by odometer reading
    expenses.sort((a, b) => a.odometerReading.compareTo(b.odometerReading));

    double totalDistance = 0.0;
    double totalLiters = 0.0;

    for (int i = 1; i < expenses.length; i++) {
      final distance =
          expenses[i].odometerReading - expenses[i - 1].odometerReading;
      if (distance > 0) {
        totalDistance += distance;
        totalLiters += expenses[i].liters;
      }
    }

    return totalLiters > 0 ? totalDistance / totalLiters : 0.0;
  }

  Future<Map<String, double>> getMonthlyExpenseSummary(
    DateTime month,
  ) async {
    final startDate = DateTime(month.year, month.month);
    final endDate = DateTime(month.year, month.month + 1, 0);

    final fuelExpenses = await getFuelExpensesByDateRange(startDate, endDate);
    final generalExpenses =
        await getGeneralExpensesByDateRange(startDate, endDate);

    final double totalFuel =
        fuelExpenses.fold(0.0, (sum, e) => sum + e.amountPaid);
    final double totalGeneral =
        generalExpenses.fold(0.0, (sum, e) => sum + e.amount);

    return {
      'fuel': totalFuel,
      'general': totalGeneral,
      'total': totalFuel + totalGeneral,
    };
  }

  Future<Map<String, double>?> getVehicleCostStats(int vehicleId) async {
    final db = await database;

    final fuelStats = await db.rawQuery(
      '''
      SELECT
        MIN(odometer_reading) AS min_odometer,
        MAX(odometer_reading) AS max_odometer,
        COUNT(*) AS entry_count,
        SUM(amount_paid) AS fuel_spend,
        SUM(liters) AS total_liters
      FROM fuel_expenses
      WHERE vehicle_id = ?
    ''',
      [vehicleId],
    );

    if (fuelStats.isEmpty) return null;

    final fuelRow = fuelStats.first;
    final entryCount = (fuelRow['entry_count'] as int?) ??
        (fuelRow['entry_count'] as num?)?.toInt() ??
        0;

    if (entryCount < 2) {
      return null;
    }

    final minOdometer = (fuelRow['min_odometer'] as num?)?.toDouble();
    final maxOdometer = (fuelRow['max_odometer'] as num?)?.toDouble();

    if (minOdometer == null ||
        maxOdometer == null ||
        maxOdometer <= minOdometer) {
      return null;
    }

    final distanceCovered = maxOdometer - minOdometer;
    final fuelSpend = (fuelRow['fuel_spend'] as num?)?.toDouble() ?? 0.0;
    final totalLiters = (fuelRow['total_liters'] as num?)?.toDouble() ?? 0.0;

    final generalStats = await db.rawQuery(
      '''
      SELECT SUM(amount) AS general_spend
      FROM general_expenses
      WHERE vehicle_id = ?
    ''',
      [vehicleId],
    );

    final generalSpend = generalStats.isNotEmpty
        ? (generalStats.first['general_spend'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    final totalSpend = fuelSpend + generalSpend;
    final costPerKm = distanceCovered > 0 ? totalSpend / distanceCovered : null;

    if (costPerKm == null) {
      return null;
    }

    return {
      'distance': distanceCovered,
      'fuel_spend': fuelSpend,
      'general_spend': generalSpend,
      'total_spend': totalSpend,
      'cost_per_km': costPerKm,
      'avg_fuel_price': totalLiters > 0 ? fuelSpend / totalLiters : 0.0,
    };
  }

  Future<List<Map<String, dynamic>>> getVehicleContributionSummary(
    int vehicleId,
  ) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      WITH fuel_totals AS (
        SELECT device_id, SUM(amount_paid) AS fuel_total
        FROM fuel_expenses
        WHERE vehicle_id = ?
        GROUP BY device_id
      ),
      general_totals AS (
        SELECT device_id, SUM(amount) AS general_total
        FROM general_expenses
        WHERE vehicle_id = ?
        GROUP BY device_id
      ),
      contributors AS (
        SELECT device_id FROM fuel_totals
        UNION
        SELECT device_id FROM general_totals
      )
      SELECT
        c.device_id,
        COALESCE(d.person_name, c.device_id) AS person_name,
        IFNULL(f.fuel_total, 0) AS fuel_total,
        IFNULL(g.general_total, 0) AS general_total,
        IFNULL(f.fuel_total, 0) + IFNULL(g.general_total, 0) AS total_spent
      FROM contributors c
      LEFT JOIN devices d ON d.device_id = c.device_id
      LEFT JOIN fuel_totals f ON f.device_id = c.device_id
      LEFT JOIN general_totals g ON g.device_id = c.device_id
      ORDER BY total_spent DESC
    ''',
      [vehicleId, vehicleId],
    );

    return result;
  }

  // ==================== VEHICLE ACCESS OPERATIONS ====================

  Future<int> grantVehicleAccess(
    int vehicleId,
    String deviceId,
    String accessType,
  ) async {
    final db = await database;
    return db.insert('vehicle_access', {
      'vehicle_id': vehicleId,
      'device_id': deviceId,
      'access_type': accessType,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> revokeVehicleAccess(int vehicleId, String deviceId) async {
    final db = await database;
    return db.delete(
      'vehicle_access',
      where: 'vehicle_id = ? AND device_id = ?',
      whereArgs: [vehicleId, deviceId],
    );
  }

  Future<Map<String, dynamic>?> getVehicleAccess(
    int vehicleId,
    String deviceId,
  ) async {
    final db = await database;
    final result = await db.query(
      'vehicle_access',
      where: 'vehicle_id = ? AND device_id = ?',
      whereArgs: [vehicleId, deviceId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<String>> getDevicesWithAccessToVehicle(int vehicleId) async {
    final db = await database;
    final result = await db.query(
      'vehicle_access',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
    );
    return result.map((row) => row['device_id'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> getDevicesWithAccessDetails(
    int vehicleId,
  ) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT 
        va.device_id,
        va.access_type,
        d.person_name as device_name
      FROM vehicle_access va
      INNER JOIN devices d ON va.device_id = d.device_id
      WHERE va.vehicle_id = ?
      ORDER BY 
        CASE va.access_type
          WHEN 'owner' THEN 1
          WHEN 'contributor' THEN 2
          WHEN 'viewer' THEN 3
        END
    ''',
      [vehicleId],
    );
    return result;
  }

  Future<List<int>> getAccessibleVehiclesForDevice(String deviceId) async {
    final db = await database;

    // Get vehicles owned by device
    final owned = await db.query(
      'vehicles',
      where: 'owner_device_id = ?',
      whereArgs: [deviceId],
    );

    // Get shared vehicles device has access to
    final shared = await db.rawQuery(
      '''
      SELECT DISTINCT v.id FROM vehicles v
      INNER JOIN vehicle_access va ON v.id = va.vehicle_id
      WHERE va.device_id = ? OR v.is_shared = 1
    ''',
      [deviceId],
    );

    final ownedIds = owned.map((row) => row['id'] as int).toSet();
    final sharedIds = shared.map((row) => row['id'] as int).toSet();

    return [...ownedIds, ...sharedIds].toList();
  }

  // ==================== BUDGET OPERATIONS ====================

  Future<int> createBudget({
    required String deviceId,
    required String month,
    double fuelLimit = 0,
    double generalLimit = 0,
    double householdLimit = 0,
  }) async {
    final db = await database;
    return db.insert('budgets', {
      'device_id': deviceId,
      'month': month,
      'fuel_limit': fuelLimit,
      'general_limit': generalLimit,
      'household_limit': householdLimit,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getBudgetForMonth(
    String deviceId,
    String month,
  ) async {
    final db = await database;
    final result = await db.query(
      'budgets',
      where: 'device_id = ? AND month = ?',
      whereArgs: [deviceId, month],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateBudget(
    int budgetId, {
    double? fuelLimit,
    double? generalLimit,
    double? householdLimit,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{};

    if (fuelLimit != null) updates['fuel_limit'] = fuelLimit;
    if (generalLimit != null) updates['general_limit'] = generalLimit;
    if (householdLimit != null) updates['household_limit'] = householdLimit;

    return db.update(
      'budgets',
      updates,
      where: 'id = ?',
      whereArgs: [budgetId],
    );
  }

  // ==================== REMINDER OPERATIONS ====================

  Future<int> createReminder({
    required int vehicleId,
    required String deviceId,
    required String type,
    required String title,
    String? description,
    required DateTime dueDate,
  }) async {
    final db = await database;
    return db.insert('reminders', {
      'vehicle_id': vehicleId,
      'device_id': deviceId,
      'type': type,
      'title': title,
      'description': description,
      'due_date': dueDate.toIso8601String(),
      'is_completed': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getRemindersForDevice(
    String deviceId,
  ) async {
    final db = await database;
    return db.query(
      'reminders',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'due_date ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getUpcomingRemindersForDevice(
    String deviceId,
  ) async {
    final db = await database;
    final now = DateTime.now();
    final nextMonth = now.add(const Duration(days: 30));

    return db.query(
      'reminders',
      where: 'device_id = ? AND is_completed = 0 AND due_date BETWEEN ? AND ?',
      whereArgs: [deviceId, now.toIso8601String(), nextMonth.toIso8601String()],
      orderBy: 'due_date ASC',
    );
  }

  Future<int> completeReminder(int reminderId) async {
    final db = await database;
    return db.update(
      'reminders',
      {'is_completed': 1},
      where: 'id = ?',
      whereArgs: [reminderId],
    );
  }

  Future<int> deleteReminder(int reminderId) async {
    final db = await database;
    return db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [reminderId],
    );
  }

  // ==================== Trip Operations ====================

  Future<int> createTrip({
    required int vehicleId,
    required String deviceId,
    required String startLocation,
    String? endLocation,
    double? startOdometer,
    double? endOdometer,
    double? distance,
    required DateTime startTime,
    DateTime? endTime,
    required String purpose,
    String? notes,
    int? fuelExpenseId,
    bool isActive = true,
  }) async {
    final db = await database;
    return db.insert('trips', {
      'vehicle_id': vehicleId,
      'device_id': deviceId,
      'start_location': startLocation,
      'end_location': endLocation,
      'start_odometer': startOdometer,
      'end_odometer': endOdometer,
      'distance': distance,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'purpose': purpose,
      'notes': notes,
      'fuel_expense_id': fuelExpenseId,
      'is_active': isActive ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateTrip(int tripId, Map<String, dynamic> updates) async {
    final db = await database;
    return db.update(
      'trips',
      updates,
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  Future<int> endTrip({
    required int tripId,
    required String endLocation,
    required double endOdometer,
    double? distance,
    DateTime? endTime,
    String? notes,
  }) async {
    final db = await database;
    return db.update(
      'trips',
      {
        'end_location': endLocation,
        'end_odometer': endOdometer,
        'distance': distance,
        'end_time': (endTime ?? DateTime.now()).toIso8601String(),
        'notes': notes,
        'is_active': 0,
      },
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  Future<List<Map<String, dynamic>>> getAllTrips() async {
    final db = await database;
    return db.query(
      'trips',
      orderBy: 'start_time DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getTripsForDevice(String deviceId) async {
    final db = await database;
    return db.query(
      'trips',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'start_time DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getTripsForVehicle(int vehicleId) async {
    final db = await database;
    return db.query(
      'trips',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'start_time DESC',
    );
  }

  Future<Map<String, dynamic>?> getActiveTripForDevice(String deviceId) async {
    final db = await database;
    final result = await db.query(
      'trips',
      where: 'device_id = ? AND is_active = 1',
      whereArgs: [deviceId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getBusinessTripsForDevice(
    String deviceId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    return db.query(
      'trips',
      where: 'device_id = ? AND purpose = ? AND start_time BETWEEN ? AND ?',
      whereArgs: [
        deviceId,
        'business',
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'start_time DESC',
    );
  }

  Future<int> deleteTrip(int tripId) async {
    final db = await database;
    return db.delete(
      'trips',
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  Future<Map<String, dynamic>> getTripStatisticsForDevice(
    String deviceId,
  ) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as total_trips,
        SUM(distance) as total_distance,
        AVG(distance) as avg_distance,
        SUM(CASE WHEN purpose = 'business' THEN distance ELSE 0 END) as business_distance,
        SUM(CASE WHEN purpose = 'personal' THEN distance ELSE 0 END) as personal_distance
      FROM trips
      WHERE device_id = ? AND is_active = 0
    ''',
      [deviceId],
    );

    return result.isNotEmpty
        ? result.first
        : {
            'total_trips': 0,
            'total_distance': 0.0,
            'avg_distance': 0.0,
            'business_distance': 0.0,
            'personal_distance': 0.0,
          };
  }

  // ==================== COMMUNITY OPERATIONS ====================

  Future<int> createCommunityPost(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('community_posts', data);
  }

  Future<List<Map<String, dynamic>>> getCommunityPostsForDevice(
    String deviceId,
  ) async {
    final db = await database;
    return db.query(
      'community_posts',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> updateCommunityPost(
    int postId,
    Map<String, dynamic> updates,
  ) async {
    final db = await database;
    return db.update(
      'community_posts',
      updates,
      where: 'id = ?',
      whereArgs: [postId],
    );
  }

  Future<int> deleteCommunityPost(int postId) async {
    final db = await database;
    return db.delete(
      'community_posts',
      where: 'id = ?',
      whereArgs: [postId],
    );
  }

  Future<int> createAchievement(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('achievements', data);
  }

  Future<List<Map<String, dynamic>>> getAchievementsForDevice(
    String deviceId,
  ) async {
    final db = await database;
    return db.query(
      'achievements',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'earned_at DESC',
    );
  }

  Future<int> deleteAchievement(int achievementId) async {
    final db = await database;
    return db.delete(
      'achievements',
      where: 'id = ?',
      whereArgs: [achievementId],
    );
  }

  // ==================== AUTOMATION OPERATIONS ====================

  Future<int> createAutomationEndpoint(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('automation_endpoints', data);
  }

  Future<List<Map<String, dynamic>>> getAutomationEndpoints(
    String deviceId,
  ) async {
    final db = await database;
    return db.query(
      'automation_endpoints',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> updateAutomationEndpoint(
    int id,
    Map<String, dynamic> updates,
  ) async {
    final db = await database;
    return db.update(
      'automation_endpoints',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAutomationEndpoint(int id) async {
    final db = await database;
    return db.delete(
      'automation_endpoints',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateAutomationTriggerTime(int id, DateTime triggeredAt) async {
    final db = await database;
    return db.update(
      'automation_endpoints',
      {
        'last_triggered': triggeredAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== FRIEND CONNECTION OPERATIONS ====================

  Future<int> createDeviceConnection(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert(
      'device_connections',
      data,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, dynamic>>> getDeviceConnections(
    String ownerDeviceId,
  ) async {
    final db = await database;
    return db.query(
      'device_connections',
      where: 'owner_device_id = ?',
      whereArgs: [ownerDeviceId],
      orderBy: 'created_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getDeviceConnection(
    String ownerDeviceId,
    String friendDeviceId,
  ) async {
    final db = await database;
    final result = await db.query(
      'device_connections',
      where: 'owner_device_id = ? AND friend_device_id = ?',
      whereArgs: [ownerDeviceId, friendDeviceId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> deleteDeviceConnection(int connectionId) async {
    final db = await database;
    return db.delete(
      'device_connections',
      where: 'id = ?',
      whereArgs: [connectionId],
    );
  }

  // ==================== INTEGRATION TOKEN OPERATIONS ====================

  Future<int> createIntegrationToken(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('integration_tokens', data);
  }

  Future<List<Map<String, dynamic>>> getIntegrationTokens(
    String deviceId,
  ) async {
    final db = await database;
    return db.query(
      'integration_tokens',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> updateIntegrationToken(
    int id,
    Map<String, dynamic> updates,
  ) async {
    final db = await database;
    return db.update(
      'integration_tokens',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteIntegrationToken(int id) async {
    final db = await database;
    return db.delete(
      'integration_tokens',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Device Operations ====================

  Future<String> registerDevice(
    String personName, {
    String? profilePicturePath,
  }) async {
    final db = await database;

    // Generate unique device ID
    final deviceId = DateTime.now().millisecondsSinceEpoch.toString();

    await db.insert('devices', {
      'device_id': deviceId,
      'person_name': personName,
      'profile_picture_path': profilePicturePath,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    return deviceId;
  }

  Future<Map<String, dynamic>?> getDeviceByDeviceId(String deviceId) async {
    final db = await database;
    final result = await db.query(
      'devices',
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllDevices() async {
    final db = await database;
    return db.query('devices', orderBy: 'created_at ASC');
  }

  Future<int> updateDevice(
    String deviceId,
    Map<String, dynamic> updates,
  ) async {
    final db = await database;
    updates['updated_at'] = DateTime.now().toIso8601String();
    return db.update(
      'devices',
      updates,
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  Future<void> setActiveDevice(String deviceId) async {
    final db = await database;

    // Deactivate all devices
    await db.update('devices', {'is_active': 0});

    // Activate the selected device
    await db.update(
      'devices',
      {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  Future<Map<String, dynamic>?> getActiveDevice() async {
    final db = await database;
    final result = await db.query(
      'devices',
      where: 'is_active = 1',
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> deleteDevice(String deviceId) async {
    final db = await database;
    return db.delete(
      'devices',
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  // ==================== FAMILY MEMBER OPERATIONS ====================

  Future<void> seedDefaultFamilyMembers() async {
    final db = await database;
    await _ensureDefaultFamilyMembers(db);
  }

  Future<List<FamilyMember>> getFamilyMembers() async {
    final db = await database;
    final rows = await db.query(
      'family_members',
      orderBy: 'created_at ASC',
    );
    return rows.map(FamilyMember.fromMap).toList();
  }

  Future<FamilyMember> createFamilyMember(FamilyMember member) async {
    final db = await database;
    final data = Map<String, dynamic>.from(member.toMap())..remove('id');
    final id = await db.insert('family_members', data);
    return member.copyWith(id: id);
  }

  Future<void> updateFamilyMember(FamilyMember member) async {
    if (member.id == null) {
      throw ArgumentError('Family member must have an id to update');
    }
    final db = await database;
    final data = Map<String, dynamic>.from(member.toMap())..remove('id');
    await db.update(
      'family_members',
      data,
      where: 'id = ?',
      whereArgs: [member.id],
    );
  }

  Future<void> deleteFamilyMember(int memberId) async {
    final db = await database;
    await db.delete(
      'family_members',
      where: 'id = ?',
      whereArgs: [memberId],
    );
    await db.delete(
      'vehicle_member_preferences',
      where: 'member_id = ?',
      whereArgs: [memberId],
    );
  }

  Future<Map<int, int>> getVehicleMemberPreferences() async {
    final db = await database;
    final rows = await db.query('vehicle_member_preferences');
    final Map<int, int> prefs = {};
    for (final row in rows) {
      final vehicleId = row['vehicle_id'] as int;
      final memberId = row['member_id'] as int?;
      if (memberId != null) {
        prefs[vehicleId] = memberId;
      }
    }
    return prefs;
  }

  Future<void> setVehicleMemberPreference(int vehicleId, int memberId) async {
    final db = await database;
    await db.insert(
      'vehicle_member_preferences',
      {
        'vehicle_id': vehicleId,
        'member_id': memberId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearVehicleMemberPreference(int vehicleId) async {
    final db = await database;
    await db.delete(
      'vehicle_member_preferences',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
    );
  }

  /// Optimized: Uses batch operations instead of sequential inserts
  Future<void> _ensureDefaultFamilyMembers(Object db) async {
    // Both Database and Transaction support rawQuery
    final dbOrTxn = db as Database;
    final count = Sqflite.firstIntValue(
          await dbOrTxn.rawQuery('SELECT COUNT(*) FROM family_members'),
        ) ??
        0;
    if (count > 0) return;

    final now = DateTime.now();
    final defaults = [
      {
        'name': 'Dad',
        'avatar_icon': '👨',
        'color_hex': 0xFF1E88E5,
      },
      {
        'name': 'Mom',
        'avatar_icon': '👩',
        'color_hex': 0xFFD81B60,
      },
      {
        'name': 'You',
        'avatar_icon': '🧑',
        'color_hex': 0xFF6A1B9A,
      },
      {
        'name': 'Brother',
        'avatar_icon': '👦',
        'color_hex': 0xFF00897B,
      },
      {
        'name': 'Sister',
        'avatar_icon': '👧',
        'color_hex': 0xFFFF7043,
      },
    ];

    // Use batch operations for Database, individual inserts for Transaction
    if (db is Transaction) {
      // Transaction - use individual inserts
      for (final member in defaults) {
        await db.insert('family_members', {
          'name': member['name'],
          'avatar_icon': member['avatar_icon'],
          'color_hex': member['color_hex'],
          'primary_vehicle_id': null,
          'created_at': now.toIso8601String(),
        });
      }
    } else {
      // Database - use batch operations
      // ignore: unnecessary_cast
      final batch = (db as Database).batch();
      for (final member in defaults) {
        batch.insert('family_members', {
          'name': member['name'],
          'avatar_icon': member['avatar_icon'],
          'color_hex': member['color_hex'],
          'primary_vehicle_id': null,
          'created_at': now.toIso8601String(),
        });
      }
      await batch.commit(noResult: true);
    }
  }

  // ==================== CHARGING EXPENSE OPERATIONS ====================

  Future<int> createChargingExpense(Map<String, dynamic> chargingData) async {
    final db = await database;
    return db.insert('charging_expenses', chargingData);
  }

  Future<List<Map<String, dynamic>>> getChargingExpenses(int vehicleId) async {
    final db = await database;
    return db.query(
      'charging_expenses',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllChargingExpenses() async {
    final db = await database;
    return db.query(
      'charging_expenses',
      orderBy: 'date DESC',
    );
  }

  Future<Map<String, dynamic>?> getLastChargingExpense(int vehicleId) async {
    final db = await database;
    final results = await db.query(
      'charging_expenses',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC, id DESC',
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getChargingExpensesByDateRange(
    int vehicleId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    return db.query(
      'charging_expenses',
      where: 'vehicle_id = ? AND date >= ? AND date <= ?',
      whereArgs: [
        vehicleId,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getChargingExpensesByLocation(
    int vehicleId,
    String locationType,
  ) async {
    final db = await database;
    return db.query(
      'charging_expenses',
      where: 'vehicle_id = ? AND location_type = ?',
      whereArgs: [vehicleId, locationType],
      orderBy: 'date DESC',
    );
  }

  Future<Map<String, dynamic>?> getChargingExpenseById(int id) async {
    final db = await database;
    final results = await db.query(
      'charging_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateChargingExpense(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update(
      'charging_expenses',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteChargingExpense(int id) async {
    final db = await database;
    await db.delete(
      'charging_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // EV-specific analytics
  Future<Map<String, dynamic>> getEVEfficiencyMetrics(
    int vehicleId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;

    final charges = await db.query(
      'charging_expenses',
      where: 'vehicle_id = ? AND date >= ? AND date <= ?',
      whereArgs: [
        vehicleId,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'date ASC',
    );

    if (charges.isEmpty) {
      return {
        'total_kwh': 0.0,
        'total_cost': 0.0,
        'total_km': 0.0,
        'charging_cycles': 0,
        'home_cost': 0.0,
        'public_cost': 0.0,
        'office_cost': 0.0,
        'avg_cost_per_kwh': 0.0,
      };
    }

    double totalKwh = 0;
    double totalCost = 0;
    double homeCost = 0;
    double publicCost = 0;
    double officeCost = 0;
    final int cycles = charges.length;

    for (final charge in charges) {
      final kwh = (charge['kwh_charged'] as num).toDouble();
      final cost = (charge['total_cost'] as num).toDouble();
      final locationType = charge['location_type'] as String;

      totalKwh += kwh;
      totalCost += cost;

      switch (locationType) {
        case 'home':
          homeCost += cost;
          break;
        case 'publicStation':
          publicCost += cost;
          break;
        case 'office':
          officeCost += cost;
          break;
      }
    }

    // Calculate distance driven
    final firstOdometer = (charges.first['odometer_reading'] as num).toDouble();
    final lastOdometer = (charges.last['odometer_reading'] as num).toDouble();
    final totalKm = (lastOdometer - firstOdometer).abs();

    return {
      'total_kwh': totalKwh,
      'total_cost': totalCost,
      'total_km': totalKm,
      'charging_cycles': cycles,
      'home_cost': homeCost,
      'public_cost': publicCost,
      'office_cost': officeCost,
      'avg_cost_per_kwh': totalKwh > 0 ? totalCost / totalKwh : 0.0,
    };
  }

  Future<Map<String, dynamic>> getBatteryHealthData(int vehicleId) async {
    final db = await database;

    final charges = await db.query(
      'charging_expenses',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date ASC',
    );

    if (charges.isEmpty) {
      return {
        'total_cycles': 0,
        'fast_cycles': 0,
        'slow_cycles': 0,
        'avg_battery_gain': 0.0,
        'first_charge': null,
        'last_charge': null,
      };
    }

    final int totalCycles = charges.length;
    int fastCycles = 0;
    int slowCycles = 0;
    double totalBatteryGain = 0;

    for (final charge in charges) {
      final before = charge['battery_before'] as int;
      final after = charge['battery_after'] as int;
      final chargingType = charge['charging_type'] as String;

      totalBatteryGain += after - before;

      if (chargingType == 'fast' || chargingType == 'rapid') {
        fastCycles++;
      } else {
        slowCycles++;
      }
    }

    return {
      'total_cycles': totalCycles,
      'fast_cycles': fastCycles,
      'slow_cycles': slowCycles,
      'avg_battery_gain':
          totalCycles > 0 ? totalBatteryGain / totalCycles : 0.0,
      'first_charge': charges.first['date'],
      'last_charge': charges.last['date'],
    };
  }

  // ==================== BUDGET OPERATIONS ====================

  /// Get vehicle's monthly budget
  Future<double?> getVehicleBudget(int vehicleId) async {
    final db = await database;
    final results = await db.query(
      'vehicles',
      columns: ['monthly_budget'],
      where: 'id = ?',
      whereArgs: [vehicleId],
    );

    if (results.isEmpty) return null;
    final budget = results.first['monthly_budget'];
    return budget != null ? (budget as num).toDouble() : null;
  }

  /// Update vehicle's monthly budget
  Future<void> updateVehicleBudget(int vehicleId, double? budget) async {
    final db = await database;
    await db.update(
      'vehicles',
      {'monthly_budget': budget},
      where: 'id = ?',
      whereArgs: [vehicleId],
    );
  }

  /// Save budget history for a month
  Future<void> saveBudgetHistory(Map<String, dynamic> historyData) async {
    final db = await database;
    await db.insert(
      'budget_history',
      historyData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get budget history for a vehicle
  Future<List<Map<String, dynamic>>> getBudgetHistory(
    int vehicleId, {
    int? limit,
  }) async {
    final db = await database;
    return db.query(
      'budget_history',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'month DESC',
      limit: limit,
    );
  }

  /// Get budget history for a specific month
  Future<Map<String, dynamic>?> getBudgetHistoryForMonth(
    int vehicleId,
    String month,
  ) async {
    final db = await database;
    final results = await db.query(
      'budget_history',
      where: 'vehicle_id = ? AND month = ?',
      whereArgs: [vehicleId, month],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Get spending for a vehicle in a specific month
  Future<double> getVehicleSpendingForMonth(
    int vehicleId,
    DateTime month,
  ) async {
    final db = await database;
    final startDate = DateTime(month.year, month.month);
    final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    // Sum fuel expenses
    final fuelResult = await db.rawQuery(
      'SELECT SUM(amount_paid) as total FROM fuel_expenses WHERE vehicle_id = ? AND date >= ? AND date <= ?',
      [vehicleId, startDate.toIso8601String(), endDate.toIso8601String()],
    );
    final fuelTotal = (fuelResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // Sum general expenses
    final generalResult = await db.rawQuery(
      'SELECT SUM(amount) as total FROM general_expenses WHERE vehicle_id = ? AND date >= ? AND date <= ? AND is_household_expense = 0',
      [vehicleId, startDate.toIso8601String(), endDate.toIso8601String()],
    );
    final generalTotal =
        (generalResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // Sum charging expenses
    final chargingResult = await db.rawQuery(
      'SELECT SUM(total_cost) as total FROM charging_expenses WHERE vehicle_id = ? AND date >= ? AND date <= ?',
      [vehicleId, startDate.toIso8601String(), endDate.toIso8601String()],
    );
    final chargingTotal =
        (chargingResult.first['total'] as num?)?.toDouble() ?? 0.0;

    return fuelTotal + generalTotal + chargingTotal;
  }

  /// Get all vehicles with their budgets
  Future<List<Map<String, dynamic>>> getAllVehiclesWithBudgets() async {
    final db = await database;
    return db.query('vehicles', orderBy: 'name ASC');
  }

  // ==================== EXPENSE TEMPLATES ====================

  /// Create a new expense template
  Future<int> createExpenseTemplate(Map<String, dynamic> template) async {
    final db = await database;
    return db.insert('expense_templates', template);
  }

  /// Get all templates for a vehicle
  Future<List<Map<String, dynamic>>> getTemplatesByVehicle(
    int vehicleId,
  ) async {
    final db = await database;
    return db.query(
      'expense_templates',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'use_count DESC, last_used_at DESC',
    );
  }

  /// Get templates by type
  Future<List<Map<String, dynamic>>> getTemplatesByType(String type) async {
    final db = await database;
    return db.query(
      'expense_templates',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'use_count DESC',
    );
  }

  /// Get all templates
  Future<List<Map<String, dynamic>>> getAllTemplates() async {
    final db = await database;
    return db.query(
      'expense_templates',
      orderBy: 'use_count DESC, last_used_at DESC',
    );
  }

  /// Get most used templates (top N)
  Future<List<Map<String, dynamic>>> getMostUsedTemplates({
    int limit = 5,
  }) async {
    final db = await database;
    return db.query(
      'expense_templates',
      orderBy: 'use_count DESC, last_used_at DESC',
      limit: limit,
    );
  }

  /// Update template
  Future<int> updateExpenseTemplate(
    int id,
    Map<String, dynamic> template,
  ) async {
    final db = await database;
    return db.update(
      'expense_templates',
      template,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Increment template use count and update last used
  Future<void> incrementTemplateUsage(int templateId) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE expense_templates 
      SET use_count = use_count + 1, 
          last_used_at = ? 
      WHERE id = ?
    ''',
      [DateTime.now().toIso8601String(), templateId],
    );
  }

  /// Delete template
  Future<int> deleteExpenseTemplate(int id) async {
    final db = await database;
    return db.delete(
      'expense_templates',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get templates used in last N days
  Future<List<Map<String, dynamic>>> getRecentlyUsedTemplates({
    int days = 7,
  }) async {
    final db = await database;
    final cutoffDate =
        DateTime.now().subtract(Duration(days: days)).toIso8601String();
    return db.query(
      'expense_templates',
      where: 'last_used_at >= ?',
      whereArgs: [cutoffDate],
      orderBy: 'last_used_at DESC',
    );
  }

  // ==================== FAVORITE STATIONS ====================

  /// Create a new favorite station
  Future<int> createFavoriteStation(Map<String, dynamic> station) async {
    final db = await database;
    return db.insert('favorite_stations', station);
  }

  /// Get all favorite stations
  Future<List<Map<String, dynamic>>> getAllFavoriteStations() async {
    final db = await database;
    return db.query(
      'favorite_stations',
      orderBy: 'use_count DESC, last_used_at DESC',
    );
  }

  /// Get station by name
  Future<Map<String, dynamic>?> getFavoriteStationByName(String name) async {
    final db = await database;
    final results = await db.query(
      'favorite_stations',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Update favorite station
  Future<int> updateFavoriteStation(
    int id,
    Map<String, dynamic> station,
  ) async {
    final db = await database;
    return db.update(
      'favorite_stations',
      station,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Increment station use count and update last used
  Future<void> incrementStationUsage(int stationId) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE favorite_stations 
      SET use_count = use_count + 1, 
          last_used_at = ? 
      WHERE id = ?
    ''',
      [DateTime.now().toIso8601String(), stationId],
    );
  }

  /// Update station price
  Future<void> updateStationPrice(int stationId, double pricePerLiter) async {
    final db = await database;
    await db.update(
      'favorite_stations',
      {
        'last_price_per_liter': pricePerLiter,
        'last_price_updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [stationId],
    );
  }

  /// Delete favorite station
  Future<int> deleteFavoriteStation(int id) async {
    final db = await database;
    return db.delete(
      'favorite_stations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get most used stations (top N)
  Future<List<Map<String, dynamic>>> getMostUsedStations({
    int limit = 5,
  }) async {
    final db = await database;
    return db.query(
      'favorite_stations',
      orderBy: 'use_count DESC, last_used_at DESC',
      limit: limit,
    );
  }

  /// Search stations by name or brand
  Future<List<Map<String, dynamic>>> searchStations(String query) async {
    final db = await database;
    return db.query(
      'favorite_stations',
      where: 'name LIKE ? OR brand LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'use_count DESC',
    );
  }

  /// Get recent fuel expenses for quick-fill suggestions
  Future<List<Map<String, dynamic>>> getRecentExpensesForQuickFill(
    int vehicleId, {
    int limit = 3,
  }) async {
    final db = await database;
    return db.query(
      'fuel_expenses',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC',
      limit: limit,
    );
  }

  // ==================== FAMILY TASKS OPERATIONS ====================

  /// Create a new family task
  Future<int> createFamilyTask(Map<String, dynamic> task) async {
    final db = await database;
    return db.insert('family_tasks', task);
  }

  /// Get all family tasks
  Future<List<Map<String, dynamic>>> getAllFamilyTasks() async {
    final db = await database;
    return db.query(
      'family_tasks',
      orderBy: 'CASE WHEN is_completed = 0 THEN 0 ELSE 1 END, due_date ASC',
    );
  }

  /// Get tasks assigned to a specific member
  Future<List<Map<String, dynamic>>> getTasksAssignedTo(int memberId) async {
    final db = await database;
    return db.query(
      'family_tasks',
      where: 'assigned_to_member_id = ? AND is_completed = 0',
      whereArgs: [memberId],
      orderBy: 'due_date ASC',
    );
  }

  /// Get tasks for a specific vehicle
  Future<List<Map<String, dynamic>>> getTasksForVehicle(int vehicleId) async {
    final db = await database;
    return db.query(
      'family_tasks',
      where: 'vehicle_id = ? AND is_completed = 0',
      whereArgs: [vehicleId],
      orderBy: 'due_date ASC',
    );
  }

  /// Get urgent/overdue tasks
  Future<List<Map<String, dynamic>>> getUrgentTasks() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.query(
      'family_tasks',
      where: '(is_urgent = 1 OR due_date < ?) AND is_completed = 0',
      whereArgs: [now],
      orderBy: 'due_date ASC',
    );
  }

  /// Get shopping tasks
  Future<List<Map<String, dynamic>>> getShoppingTasks() async {
    final db = await database;
    return db.query(
      'family_tasks',
      where: 'is_shopping_task = 1 AND is_completed = 0',
      orderBy: 'created_at DESC',
    );
  }

  /// Get completed tasks (for history)
  Future<List<Map<String, dynamic>>> getCompletedTasks({int limit = 50}) async {
    final db = await database;
    return db.query(
      'family_tasks',
      where: 'is_completed = 1',
      orderBy: 'completed_at DESC',
      limit: limit,
    );
  }

  /// Get tasks due within X days
  Future<List<Map<String, dynamic>>> getTasksDueWithin(int days) async {
    final db = await database;
    final deadline = DateTime.now().add(Duration(days: days)).toIso8601String();
    final now = DateTime.now().toIso8601String();
    return db.query(
      'family_tasks',
      where: 'due_date <= ? AND due_date >= ? AND is_completed = 0',
      whereArgs: [deadline, now],
      orderBy: 'due_date ASC',
    );
  }

  /// Get tasks by type
  Future<List<Map<String, dynamic>>> getTasksByType(String type) async {
    final db = await database;
    return db.query(
      'family_tasks',
      where: 'type = ? AND is_completed = 0',
      whereArgs: [type],
      orderBy: 'due_date ASC',
    );
  }

  /// Get a single task by ID
  Future<Map<String, dynamic>?> getFamilyTask(int id) async {
    final db = await database;
    final results = await db.query(
      'family_tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Update a family task
  Future<int> updateFamilyTask(int id, Map<String, dynamic> task) async {
    final db = await database;
    task['updated_at'] = DateTime.now().toIso8601String();
    return db.update(
      'family_tasks',
      task,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark task as completed
  Future<int> completeTask(
    int id,
    int completedByMemberId,
    String? completedByName,
  ) async {
    final db = await database;
    return db.update(
      'family_tasks',
      {
        'is_completed': 1,
        'completed_at': DateTime.now().toIso8601String(),
        'completed_by_member_id': completedByMemberId,
        'completed_by_name': completedByName,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark task as incomplete
  Future<int> uncompleteTask(int id) async {
    final db = await database;
    return db.update(
      'family_tasks',
      {
        'is_completed': 0,
        'completed_at': null,
        'completed_by_member_id': null,
        'completed_by_name': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete a family task
  Future<int> deleteFamilyTask(int id) async {
    final db = await database;
    return db.delete(
      'family_tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get recurring tasks that need new instances created
  Future<List<Map<String, dynamic>>> getRecurringTasksDue() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.query(
      'family_tasks',
      where: '''
        recurrence_pattern != 'none' 
        AND (recurrence_end_date IS NULL OR recurrence_end_date > ?)
        AND is_completed = 1
      ''',
      whereArgs: [now],
    );
  }

  /// Get task statistics
  Future<Map<String, int>> getTaskStatistics() async {
    final db = await database;

    final total = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM family_tasks WHERE is_completed = 0',
          ),
        ) ??
        0;

    final urgent = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM family_tasks WHERE is_urgent = 1 AND is_completed = 0',
          ),
        ) ??
        0;

    final overdue = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM family_tasks WHERE due_date < ? AND is_completed = 0',
            [DateTime.now().toIso8601String()],
          ),
        ) ??
        0;

    final dueToday = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM family_tasks WHERE DATE(due_date) = DATE(?) AND is_completed = 0',
            [DateTime.now().toIso8601String()],
          ),
        ) ??
        0;

    final completed = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM family_tasks WHERE is_completed = 1',
          ),
        ) ??
        0;

    return {
      'total': total,
      'urgent': urgent,
      'overdue': overdue,
      'dueToday': dueToday,
      'completed': completed,
    };
  }

  /// Update task Firebase sync status
  Future<int> updateTaskSyncStatus(
    int id,
    String firebaseId,
    bool isSynced,
  ) async {
    final db = await database;
    return db.update(
      'family_tasks',
      {
        'firebase_id': firebaseId,
        'is_synced': isSynced ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get unsynced tasks
  Future<List<Map<String, dynamic>>> getUnsyncedTasks() async {
    final db = await database;
    return db.query(
      'family_tasks',
      where: 'is_synced = 0',
      orderBy: 'created_at DESC',
    );
  }

  // ==================== V2: RECURRING EXPENSES ====================

  Future<List<dynamic>> getRecurringExpenses() async {
    final db = await database;
    final maps = await db.query('recurring_expenses', orderBy: 'next_due ASC');
    // Return as dynamic list since we haven't imported the model here
    return maps;
  }

  Future<void> createRecurringExpense(RecurringExpense recurring) async {
    final db = await database;
    await db.insert('recurring_expenses', recurring.toMap());
  }

  Future<void> updateRecurringExpense(RecurringExpense recurring) async {
    final db = await database;
    await db.update(
      'recurring_expenses',
      recurring.toMap(),
      where: 'id = ?',
      whereArgs: [recurring.id],
    );
  }

  Future<void> deleteRecurringExpense(String id) async {
    final db = await database;
    await db.delete('recurring_expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== V2: PAYMENTS ====================

  Future<List<dynamic>> getPayments() async {
    final db = await database;
    final maps = await db.query('payments', orderBy: 'payment_date DESC');
    return maps;
  }

  Future<void> createPayment(Payment payment) async {
    final db = await database;
    await db.insert('payments', payment.toMap());
  }

  Future<void> updatePayment(Payment payment) async {
    final db = await database;
    await db.update(
      'payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  Future<void> deletePayment(String paymentId) async {
    final db = await database;
    await db.delete('payments', where: 'id = ?', whereArgs: [paymentId]);
  }

  // ==================== ALLOWANCES ====================

  /// Get all allowances, optionally filtered by member
  Future<List<Allowance>> getAllowances({int? memberId}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps;

    if (memberId != null) {
      maps = await db.query(
        'allowances',
        where: 'member_id = ?',
        whereArgs: [memberId],
        orderBy: 'given_date DESC',
      );
    } else {
      maps = await db.query('allowances', orderBy: 'given_date DESC');
    }

    return maps.map(Allowance.fromMap).toList();
  }

  /// Create a new allowance record
  Future<Allowance> createAllowance(Allowance allowance) async {
    final db = await database;
    final data = Map<String, dynamic>.from(allowance.toMap())..remove('id');
    final id = await db.insert('allowances', data);
    return allowance.copyWith(id: id);
  }

  /// Update an existing allowance
  Future<void> updateAllowance(Allowance allowance) async {
    if (allowance.id == null) {
      throw ArgumentError('Allowance must have an id to update');
    }
    final db = await database;
    final data = Map<String, dynamic>.from(allowance.toMap())..remove('id');
    await db.update(
      'allowances',
      data,
      where: 'id = ?',
      whereArgs: [allowance.id],
    );
  }

  /// Delete an allowance
  Future<void> deleteAllowance(int allowanceId) async {
    final db = await database;
    await db.delete('allowances', where: 'id = ?', whereArgs: [allowanceId]);
  }

  /// Get total allowance given to a member within date range
  Future<double> getTotalAllowanceForMember(
    int memberId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    String whereClause = 'member_id = ?';
    final List<dynamic> whereArgs = [memberId];

    if (startDate != null) {
      whereClause += ' AND given_date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClause += ' AND given_date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM allowances WHERE $whereClause',
      whereArgs,
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get total spending by member from household expenses within date range
  Future<double> getTotalSpendingByMember(
    int memberId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    String whereClause = 'member_id = ? AND is_household_expense = 1';
    final List<dynamic> whereArgs = [memberId];

    if (startDate != null) {
      whereClause += ' AND date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClause += ' AND date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM general_expenses WHERE $whereClause',
      whereArgs,
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // ==================== Receipt Management ====================

  /// Insert a new receipt
  Future<void> insertReceipt(Map<String, dynamic> receiptData) async {
    final db = await database;
    await db.insert('receipts', receiptData,
        conflictAlgorithm: ConflictAlgorithm.replace,);
  }

  /// Get receipt by ID
  Future<Map<String, dynamic>?> getReceipt(String receiptId) async {
    final db = await database;
    final result = await db.query(
      'receipts',
      where: 'id = ?',
      whereArgs: [receiptId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Get receipt by ID (synchronous version)
  Map<String, dynamic>? getReceiptSync(String receiptId) {
    // Note: This would require a synchronous database access
    // For now, return null - should be called from async context
    return null;
  }

  /// Get all receipts
  Future<List<Map<String, dynamic>>> getAllReceipts() async {
    final db = await database;
    return db.query(
      'receipts',
      orderBy: 'created_at DESC',
    );
  }

  /// Get receipts by expense ID
  Future<List<Map<String, dynamic>>> getReceiptsByExpense(
      String expenseId,) async {
    final db = await database;
    return db.query(
      'receipts',
      where: 'expense_id = ?',
      whereArgs: [expenseId],
      orderBy: 'created_at DESC',
    );
  }

  /// Update receipt
  Future<void> updateReceipt(Map<String, dynamic> receiptData) async {
    final db = await database;
    final id = receiptData['id'];
    await db.update(
      'receipts',
      receiptData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete receipt
  Future<void> deleteReceipt(String receiptId) async {
    final db = await database;
    await db.delete(
      'receipts',
      where: 'id = ?',
      whereArgs: [receiptId],
    );
  }

  /// Insert OCR data for a receipt
  Future<void> insertReceiptOCRData(Map<String, dynamic> ocrData) async {
    final db = await database;
    await db.insert('receipt_ocr_data', ocrData,
        conflictAlgorithm: ConflictAlgorithm.replace,);
  }

  /// Get OCR history for a receipt
  Future<List<Map<String, dynamic>>> getReceiptOCRHistory(
      String receiptId,) async {
    final db = await database;
    return db.query(
      'receipt_ocr_data',
      where: 'receipt_id = ?',
      whereArgs: [receiptId],
      orderBy: 'processed_at DESC',
    );
  }

  /// Get receipt statistics
  Future<Map<String, dynamic>> getReceiptStatistics() async {
    final db = await database;
    final totalCount =
        await db.rawQuery('SELECT COUNT(*) as count FROM receipts');
    final processedCount = await db.rawQuery(
      "SELECT COUNT(*) as count FROM receipts WHERE status = 'processed'",
    );
    final verifiedCount = await db.rawQuery(
      "SELECT COUNT(*) as count FROM receipts WHERE status = 'verified'",
    );
    final avgConfidence = await db.rawQuery(
      'SELECT AVG(ocr_confidence) as avg FROM receipts',
    );
    final totalAmount = await db.rawQuery(
      'SELECT SUM(amount) as total FROM receipts WHERE amount IS NOT NULL',
    );

    return {
      'totalReceipts': (totalCount.first['count'] as int?) ?? 0,
      'processedReceipts': (processedCount.first['count'] as int?) ?? 0,
      'verifiedReceipts': (verifiedCount.first['count'] as int?) ?? 0,
      'averageOCRConfidence':
          ((avgConfidence.first['avg'] as num?)?.toDouble() ?? 0.0),
      'totalAmount': ((totalAmount.first['total'] as num?)?.toDouble() ?? 0.0),
    };
  }

  /// Search receipts by merchant
  Future<List<Map<String, dynamic>>> searchReceiptsByMerchant(
      String query,) async {
    final db = await database;
    return db.query(
      'receipts',
      where: 'merchant_name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'created_at DESC',
    );
  }

  /// Get receipts by status
  Future<List<Map<String, dynamic>>> getReceiptsByStatus(String status) async {
    final db = await database;
    return db.query(
      'receipts',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
  }

  /// Get receipts with OCR confidence >= threshold
  Future<List<Map<String, dynamic>>> getReceiptsByConfidence(
      double minConfidence,) async {
    final db = await database;
    return db.query(
      'receipts',
      where: 'ocr_confidence >= ?',
      whereArgs: [minConfidence],
      orderBy: 'ocr_confidence DESC',
    );
  }

  /// Delete old receipts (older than specified days)
  Future<int> deleteOldReceipts(int olderThanDays) async {
    final db = await database;
    final cutoffDate = DateTime.now()
        .subtract(Duration(days: olderThanDays))
        .toIso8601String();
    return db.delete(
      'receipts',
      where: 'created_at < ?',
      whereArgs: [cutoffDate],
    );
  }

  // ==================== DATABASE INTEGRITY CHECKS ====================

  /// Check and report database statistics
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await database;

    final fuelCount =
        await db.rawQuery('SELECT COUNT(*) as count FROM fuel_expenses');
    final generalCount =
        await db.rawQuery('SELECT COUNT(*) as count FROM general_expenses');
    final householdCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM general_expenses WHERE is_household_expense = 1',
    );

    final fuelTotal = await db
        .rawQuery('SELECT SUM(amount_paid) as total FROM fuel_expenses');
    final generalTotal = await db.rawQuery(
      'SELECT SUM(amount) as total FROM general_expenses WHERE is_household_expense = 0',
    );
    final householdTotal = await db.rawQuery(
      'SELECT SUM(amount) as total FROM general_expenses WHERE is_household_expense = 1',
    );

    return {
      'fuel_expenses_count': (fuelCount[0]['count'] as int?) ?? 0,
      'general_expenses_count': (generalCount[0]['count'] as int?) ?? 0,
      'household_expenses_count': (householdCount[0]['count'] as int?) ?? 0,
      'fuel_total': (fuelTotal[0]['total'] as num?)?.toDouble() ?? 0.0,
      'general_total': (generalTotal[0]['total'] as num?)?.toDouble() ?? 0.0,
      'household_total':
          (householdTotal[0]['total'] as num?)?.toDouble() ?? 0.0,
    };
  }

  /// Remove duplicate expenses (by date, amount, category within same device)
  Future<int> removeDuplicateExpenses() async {
    final db = await database;
    int removedCount = 0;

    try {
      await db.transaction((txn) async {
        // For fuel expenses: remove if same vehicle, date, amount, fuelType
        final fuelDuplicates = await txn.rawQuery('''
          SELECT id FROM fuel_expenses 
          WHERE id NOT IN (
            SELECT MIN(id) FROM fuel_expenses
            GROUP BY vehicle_id, date, amount_paid, fuel_type
          )
        ''');

        for (final dup in fuelDuplicates) {
          await txn
              .delete('fuel_expenses', where: 'id = ?', whereArgs: [dup['id']]);
          removedCount++;
        }

        // For general expenses: remove if same device, date, amount, category
        final generalDuplicates = await txn.rawQuery('''
          SELECT id FROM general_expenses 
          WHERE id NOT IN (
            SELECT MIN(id) FROM general_expenses
            GROUP BY device_id, date, amount, category
          )
        ''');

        for (final dup in generalDuplicates) {
          await txn.delete('general_expenses',
              where: 'id = ?', whereArgs: [dup['id']],);
          removedCount++;
        }
      });

      debugPrint('Removed $removedCount duplicate expenses');
    } catch (e) {
      debugPrint('Error removing duplicates: $e');
    }

    return removedCount;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
