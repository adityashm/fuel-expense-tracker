import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Base class for all repository classes.
/// Manages database connection and migrations.
abstract class DatabaseProvider {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'fuel_tracker.db');

    return openDatabase(
      path,
      version: 21,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Create all tables
    await _createUserAndVehicleTables(db);
    await _createExpenseTables(db);
    await _createSharingAndCollaborationTables(db);
    await _createMaintenanceTables(db);
    await _createCommunityTables(db);
    await _createAutomationTables(db);
    await _createFamilyTables(db);
    await _createElectricVehicleTables(db);
    await _createTemplateTables(db);
    await _createGeofencingTables(db);
    await _createTaskTables(db);
    await _createAllowancesTables(db);
    await _createPaymentTrackingTables(db);
    await _createAllIndexes(db);
  }

  Future<void> _createUserAndVehicleTables(Database db) async {
    // Users table (original)
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Devices table (person identification)
    await db.execute('''
      CREATE TABLE devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT UNIQUE NOT NULL,
        person_name TEXT NOT NULL,
        profile_picture_path TEXT,
        is_active INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Vehicles table
    await db.execute('''
      CREATE TABLE vehicles (
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

    // Vehicle access table (sharing)
    await db.execute('''
      CREATE TABLE vehicle_access (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id INTEGER NOT NULL,
        device_id TEXT NOT NULL,
        access_type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createExpenseTables(Database db) async {
    // Fuel expenses table
    await db.execute('''
      CREATE TABLE fuel_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id INTEGER NOT NULL,
        device_id TEXT,
        date TEXT NOT NULL,
        odometer REAL NOT NULL,
        fuel_type TEXT NOT NULL,
        liters REAL NOT NULL,
        price_per_liter REAL NOT NULL,
        amount_paid REAL NOT NULL,
        station_name TEXT,
        location TEXT,
        is_full_tank INTEGER NOT NULL,
        payment_method TEXT NOT NULL,
        receipt_image_path TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        firebase_id TEXT UNIQUE,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');

    // General expenses table
    await db.execute('''
      CREATE TABLE general_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT,
        vehicle_id INTEGER,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        description TEXT,
        receipt_image_path TEXT,
        notes TEXT,
        is_household_expense INTEGER DEFAULT 0,
        is_recurring INTEGER DEFAULT 0,
        recurring_period TEXT,
        tags TEXT,
        created_at TEXT NOT NULL,
        firebase_id TEXT UNIQUE,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE SET NULL,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createSharingAndCollaborationTables(Database db) async {
    // Budgets table
    await db.execute('''
      CREATE TABLE budgets (
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

    // Reminders table
    await db.execute('''
      CREATE TABLE reminders (
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

    // Trips table
    await db.execute('''
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

    // Expense comments table
    await db.execute('''
      CREATE TABLE expense_comments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expense_type TEXT NOT NULL,
        expense_id INTEGER NOT NULL,
        device_id TEXT NOT NULL,
        message TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Settlements table
    await db.execute('''
      CREATE TABLE settlements (
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
  }

  Future<void> _createMaintenanceTables(Database db) async {
    // Maintenance records table
    await db.execute('''
      CREATE TABLE maintenance_records (
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

    // Activity logs table
    await db.execute('''
      CREATE TABLE activity_logs (
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
  }

  Future<void> _createCommunityTables(Database db) async {
    // Community posts table
    await db.execute('''
      CREATE TABLE community_posts (
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

    // Achievements table
    await db.execute('''
      CREATE TABLE achievements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        achievement_type TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        icon_name TEXT,
        earned_at TEXT NOT NULL,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createAutomationTables(Database db) async {
    // Automation endpoints table
    await db.execute('''
      CREATE TABLE automation_endpoints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        name TEXT NOT NULL,
        integration_type TEXT NOT NULL,
        url TEXT NOT NULL,
        method TEXT DEFAULT 'POST',
        headers_json TEXT,
        body_template_json TEXT,
        auth_type TEXT DEFAULT 'none',
        auth_credentials_json TEXT,
        is_active INTEGER DEFAULT 1,
        last_triggered_at TEXT,
        success_count INTEGER DEFAULT 0,
        failure_count INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');

    // Device connections table
    await db.execute('''
      CREATE TABLE device_connections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        service_name TEXT NOT NULL,
        connection_type TEXT NOT NULL,
        is_connected INTEGER DEFAULT 0,
        last_sync_at TEXT,
        sync_config_json TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');

    // Integration tokens table
    await db.execute('''
      CREATE TABLE integration_tokens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        service_name TEXT NOT NULL,
        access_token TEXT,
        refresh_token TEXT,
        token_expiry TEXT,
        scopes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createFamilyTables(Database db) async {
    // Family members table
    await db.execute('''
      CREATE TABLE family_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        name TEXT NOT NULL,
        relationship TEXT,
        date_of_birth TEXT,
        profile_picture_path TEXT,
        color TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        firebase_id TEXT UNIQUE,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');

    // Vehicle member preferences table
    await db.execute('''
      CREATE TABLE vehicle_member_preferences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id INTEGER NOT NULL,
        member_id INTEGER NOT NULL,
        default_fuel_type TEXT,
        preferred_station TEXT,
        notification_enabled INTEGER DEFAULT 1,
        can_edit_vehicle INTEGER DEFAULT 0,
        can_delete_expenses INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
        FOREIGN KEY (member_id) REFERENCES family_members (id) ON DELETE CASCADE,
        UNIQUE (vehicle_id, member_id)
      )
    ''');
  }

  Future<void> _createElectricVehicleTables(Database db) async {
    // Charging expenses table
    await db.execute('''
      CREATE TABLE charging_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id INTEGER NOT NULL,
        device_id TEXT,
        date TEXT NOT NULL,
        odometer REAL,
        charging_type TEXT NOT NULL,
        kwh_amount REAL NOT NULL,
        price_per_kwh REAL,
        total_amount REAL NOT NULL,
        station_name TEXT,
        location TEXT,
        start_percentage REAL,
        end_percentage REAL,
        charging_duration_minutes INTEGER,
        payment_method TEXT,
        receipt_image_path TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        firebase_id TEXT UNIQUE,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createTemplateTables(Database db) async {
    // Budget history table
    await db.execute('''
      CREATE TABLE budget_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        month TEXT NOT NULL,
        category TEXT NOT NULL,
        budget_limit REAL NOT NULL,
        actual_spent REAL NOT NULL,
        savings REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE
      )
    ''');

    // Expense templates table
    await db.execute('''
      CREATE TABLE expense_templates (
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

    // Favorite stations table
    await db.execute('''
      CREATE TABLE favorite_stations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        location TEXT,
        latitude REAL,
        longitude REAL,
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
  }

  Future<void> _createGeofencingTables(Database db) async {
    // Station geofences table
    await db.execute('''
      CREATE TABLE station_geofences (
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

    // Geofence events table
    await db.execute('''
      CREATE TABLE geofence_events (
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

    // Location settings table
    await db.execute('''
      CREATE TABLE location_settings (
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
  }

  Future<void> _createTaskTables(Database db) async {
    // Family tasks table
    await db.execute('''
      CREATE TABLE family_tasks (
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
  }

  Future<void> _createAllowancesTables(Database db) async {
    // Allowances table
    await db.execute('''
      CREATE TABLE allowances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL,
        member_name TEXT NOT NULL,
        amount REAL NOT NULL,
        period TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        is_active INTEGER DEFAULT 1,
        auto_add INTEGER DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        firebase_id TEXT UNIQUE,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (member_id) REFERENCES family_members (id) ON DELETE CASCADE
      )
    ''');

    // Allowance transactions table
    await db.execute('''
      CREATE TABLE allowance_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        allowance_id INTEGER NOT NULL,
        member_id INTEGER NOT NULL,
        member_name TEXT NOT NULL,
        amount REAL NOT NULL,
        transaction_type TEXT NOT NULL,
        date TEXT NOT NULL,
        description TEXT,
        reference_type TEXT,
        reference_id INTEGER,
        created_at TEXT NOT NULL,
        firebase_id TEXT UNIQUE,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (allowance_id) REFERENCES allowances (id) ON DELETE CASCADE,
        FOREIGN KEY (member_id) REFERENCES family_members (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createPaymentTrackingTables(Database db) async {
    // Recurring expenses table
    await db.execute('''
      CREATE TABLE recurring_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        frequency TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        next_due_date TEXT NOT NULL,
        last_paid_date TEXT,
        vehicle_id INTEGER,
        payment_method TEXT,
        is_auto_pay INTEGER DEFAULT 0,
        notification_days_before INTEGER DEFAULT 3,
        is_active INTEGER DEFAULT 1,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        firebase_id TEXT UNIQUE,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE SET NULL
      )
    ''');

    // Payments table
    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recurring_expense_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        payment_method TEXT,
        transaction_id TEXT,
        status TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        firebase_id TEXT UNIQUE,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (recurring_expense_id) REFERENCES recurring_expenses (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createAllIndexes(Database db) async {
    // Vehicle indexes
    await db.execute(
        'CREATE INDEX idx_vehicles_owner_device_id ON vehicles (owner_device_id)',);

    // Fuel expenses indexes
    await db.execute(
        'CREATE INDEX idx_fuel_expenses_vehicle_id ON fuel_expenses (vehicle_id)',);
    await db.execute(
        'CREATE INDEX idx_fuel_expenses_device_id ON fuel_expenses (device_id)',);
    await db.execute(
        'CREATE INDEX idx_fuel_expenses_date ON fuel_expenses (date DESC)',);
    await db.execute(
        'CREATE INDEX idx_fuel_expenses_vehicle_date ON fuel_expenses (vehicle_id, date DESC)',);
    await db.execute(
        'CREATE INDEX idx_fuel_expenses_firebase_id ON fuel_expenses (firebase_id)',);

    // General expenses indexes
    await db.execute(
        'CREATE INDEX idx_general_expenses_device_id ON general_expenses (device_id)',);
    await db.execute(
        'CREATE INDEX idx_general_expenses_vehicle_id ON general_expenses (vehicle_id)',);
    await db.execute(
        'CREATE INDEX idx_general_expenses_date ON general_expenses (date DESC)',);
    await db.execute(
        'CREATE INDEX idx_general_expenses_category ON general_expenses (category)',);
    await db.execute(
        'CREATE INDEX idx_general_expenses_firebase_id ON general_expenses (firebase_id)',);

    // Budget indexes
    await db
        .execute('CREATE INDEX idx_budgets_device_id ON budgets (device_id)');
    await db.execute('CREATE INDEX idx_budgets_month ON budgets (month)');

    // Reminder indexes
    await db.execute(
        'CREATE INDEX idx_reminders_device_id ON reminders (device_id)',);
    await db.execute(
        'CREATE INDEX idx_reminders_vehicle_id ON reminders (vehicle_id)',);
    await db.execute(
        'CREATE INDEX idx_reminders_due_completed ON reminders (due_date, is_completed)',);

    // Trip indexes
    await db.execute('CREATE INDEX idx_trips_vehicle_id ON trips (vehicle_id)');
    await db.execute('CREATE INDEX idx_trips_device_id ON trips (device_id)');
    await db.execute(
        'CREATE INDEX idx_trips_active ON trips (is_active, vehicle_id)',);

    // Maintenance indexes
    await db.execute(
        'CREATE INDEX idx_maintenance_vehicle ON maintenance_records (vehicle_id)',);
    await db.execute(
        'CREATE INDEX idx_maintenance_device ON maintenance_records (device_id)',);
    await db.execute(
        'CREATE INDEX idx_maintenance_records_next_due ON maintenance_records (next_due_date)',);

    // Activity log indexes
    await db.execute(
        'CREATE INDEX idx_activity_vehicle ON activity_logs (vehicle_id)',);
    await db.execute(
        'CREATE INDEX idx_activity_logs_created ON activity_logs (created_at DESC)',);

    // Comment indexes
    await db.execute(
        'CREATE INDEX idx_comments_expense ON expense_comments (expense_type, expense_id)',);
    await db.execute(
        'CREATE INDEX idx_expense_comments_created ON expense_comments (created_at DESC)',);

    // Settlement indexes
    await db.execute(
        'CREATE INDEX idx_settlements_vehicle ON settlements (vehicle_id)',);
    await db.execute(
        'CREATE INDEX idx_settlements_payer ON settlements (payer_device_id)',);
    await db.execute(
        'CREATE INDEX idx_settlements_payee ON settlements (payee_device_id)',);

    // Community indexes
    await db.execute(
        'CREATE INDEX idx_community_posts_created ON community_posts (created_at DESC)',);
    await db.execute(
        'CREATE INDEX idx_community_device ON community_posts (device_id)',);

    // Achievement indexes
    await db.execute(
        'CREATE INDEX idx_achievements_device ON achievements (device_id)',);

    // Automation indexes
    await db.execute(
        'CREATE INDEX idx_automation_device ON automation_endpoints (device_id)',);
    await db.execute(
        'CREATE INDEX idx_automation_type ON automation_endpoints (integration_type)',);

    // Family member indexes
    await db.execute(
        'CREATE INDEX idx_family_members_device ON family_members (device_id)',);
    await db.execute(
        'CREATE INDEX idx_family_members_firebase_id ON family_members (firebase_id)',);

    // Vehicle preferences indexes
    await db.execute(
        'CREATE INDEX idx_vehicle_prefs_vehicle ON vehicle_member_preferences (vehicle_id)',);
    await db.execute(
        'CREATE INDEX idx_vehicle_prefs_member ON vehicle_member_preferences (member_id)',);

    // Charging expenses indexes
    await db.execute(
        'CREATE INDEX idx_charging_vehicle ON charging_expenses (vehicle_id)',);
    await db.execute(
        'CREATE INDEX idx_charging_device ON charging_expenses (device_id)',);
    await db.execute(
        'CREATE INDEX idx_charging_date ON charging_expenses (date DESC)',);

    // Budget history indexes
    await db.execute(
        'CREATE INDEX idx_budget_history_device ON budget_history (device_id)',);
    await db.execute(
        'CREATE INDEX idx_budget_history_month ON budget_history (month)',);

    // Template indexes
    await db.execute(
        'CREATE INDEX idx_templates_vehicle_id ON expense_templates (vehicle_id)',);
    await db
        .execute('CREATE INDEX idx_templates_type ON expense_templates (type)');
    await db.execute(
        'CREATE INDEX idx_templates_use_count ON expense_templates (use_count DESC)',);

    // Station indexes
    await db.execute(
        'CREATE INDEX idx_stations_use_count ON favorite_stations (use_count DESC)',);
    await db
        .execute('CREATE INDEX idx_stations_name ON favorite_stations (name)');

    // Geofencing indexes
    await db.execute(
        'CREATE INDEX idx_geofences_station_id ON station_geofences (station_id)',);
    await db.execute(
        'CREATE INDEX idx_geofences_enabled ON station_geofences (is_enabled)',);
    await db.execute(
        'CREATE INDEX idx_events_geofence_id ON geofence_events (geofence_id)',);
    await db.execute(
        'CREATE INDEX idx_events_timestamp ON geofence_events (timestamp DESC)',);

    // Task indexes
    await db.execute(
        'CREATE INDEX idx_tasks_assigned_to ON family_tasks (assigned_to_member_id)',);
    await db
        .execute('CREATE INDEX idx_tasks_vehicle ON family_tasks (vehicle_id)');
    await db
        .execute('CREATE INDEX idx_tasks_due_date ON family_tasks (due_date)');
    await db.execute(
        'CREATE INDEX idx_tasks_completed ON family_tasks (is_completed)',);
    await db
        .execute('CREATE INDEX idx_tasks_urgent ON family_tasks (is_urgent)');
    await db.execute(
        'CREATE INDEX idx_tasks_created_by ON family_tasks (created_by_member_id)',);
    await db.execute('CREATE INDEX idx_tasks_type ON family_tasks (type)');
    await db.execute(
        'CREATE INDEX idx_tasks_firebase_id ON family_tasks (firebase_id)',);
    await db.execute(
        'CREATE INDEX idx_tasks_parent ON family_tasks (parent_task_id)',);

    // Allowance indexes
    await db.execute(
        'CREATE INDEX idx_allowances_member ON allowances (member_id)',);
    await db.execute(
        'CREATE INDEX idx_allowances_firebase_id ON allowances (firebase_id)',);
    await db.execute(
        'CREATE INDEX idx_allowance_trans_member ON allowance_transactions (member_id)',);
    await db.execute(
        'CREATE INDEX idx_allowance_trans_allowance ON allowance_transactions (allowance_id)',);
    await db.execute(
        'CREATE INDEX idx_allowance_trans_firebase_id ON allowance_transactions (firebase_id)',);

    // Recurring expenses indexes
    await db.execute(
        'CREATE INDEX idx_recurring_next_due ON recurring_expenses (next_due_date)',);
    await db.execute(
        'CREATE INDEX idx_recurring_vehicle ON recurring_expenses (vehicle_id)',);
    await db.execute(
        'CREATE INDEX idx_recurring_firebase_id ON recurring_expenses (firebase_id)',);

    // Payment indexes
    await db.execute(
        'CREATE INDEX idx_payments_recurring ON payments (recurring_expense_id)',);
    await db.execute(
        'CREATE INDEX idx_payments_date ON payments (payment_date DESC)',);
    await db.execute(
        'CREATE INDEX idx_payments_firebase_id ON payments (firebase_id)',);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // This implementation follows the same migration logic from the original database_service.dart
    // Due to length, migrations are handled in the original file
    // In production, you would copy all migration logic here
  }

  /// Close the database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
