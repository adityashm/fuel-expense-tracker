import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._init();
  static final NotificationService instance = NotificationService._init();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Optional callback for notification taps
  Function(String?)? _onNotificationTapCallback;

  // Initialize notifications
  Future<void> initialize({Function(String?)? onNotificationTap}) async {
    if (_initialized) return;

    _onNotificationTapCallback = onNotificationTap;

    // Initialize timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    // Request permissions
    await _requestPermissions();

    // Android settings - using app_icon as fallback if ic_launcher doesn't exist
    const androidSettings = AndroidInitializationSettings('app_icon');

    // iOS settings
    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    debugPrint('Notification tapped: ${response.payload}');

    // Call custom callback if provided
    if (_onNotificationTapCallback != null) {
      _onNotificationTapCallback!(response.payload);
    }
  }

  // Schedule a reminder notification
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'reminders_channel',
      'Reminders',
      channelDescription: 'Vehicle maintenance and insurance reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'app_icon',
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  // Schedule recurring notification (for daily/weekly reminders)
  Future<void> scheduleRecurringReminder({
    required int id,
    required String title,
    required String body,
    required DateTime firstNotification,
    required Duration repeatInterval,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'recurring_reminders',
      'Recurring Reminders',
      channelDescription: 'Regular vehicle maintenance reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // For recurring, use periodically instead of zonedSchedule
    if (repeatInterval.inDays == 1) {
      await _notifications.periodicallyShow(
        id,
        title,
        body,
        RepeatInterval.daily,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } else if (repeatInterval.inDays == 7) {
      await _notifications.periodicallyShow(
        id,
        title,
        body,
        RepeatInterval.weekly,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    }
  }

  // Show immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    AndroidNotificationDetails? androidDetails,
    DarwinNotificationDetails? iosDetails,
  }) async {
    if (!_initialized) await initialize();

    final android = androidDetails ??
        const AndroidNotificationDetails(
          'instant_channel',
          'Instant Notifications',
          channelDescription: 'Immediate notifications for important events',
          importance: Importance.high,
          priority: Priority.high,
        );

    final ios = iosDetails ?? const DarwinNotificationDetails();

    final details = NotificationDetails(
      android: android,
      iOS: ios,
    );

    await _notifications.show(id, title, body, details, payload: payload);
  }

  // Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return _notifications.pendingNotificationRequests();
  }

  // Budget alert notification
  Future<void> showBudgetAlert({
    required String category,
    required double spent,
    required double limit,
  }) async {
    final percentage = (spent / limit * 100).toStringAsFixed(0);
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '⚠️ Budget Alert: $category',
      body:
          'You\'ve used $percentage% of your budget (₹${spent.toStringAsFixed(0)} / ₹${limit.toStringAsFixed(0)})',
    );
  }

  // Service reminder notification
  Future<void> scheduleServiceReminder({
    required int reminderId,
    required String vehicleName,
    required String serviceType,
    required DateTime dueDate,
  }) async {
    // Schedule 7 days before
    final reminderDate = dueDate.subtract(const Duration(days: 7));

    if (reminderDate.isAfter(DateTime.now())) {
      await scheduleReminder(
        id: reminderId,
        title: '🔧 Service Reminder: $vehicleName',
        body:
            '$serviceType is due on ${dueDate.day}/${dueDate.month}/${dueDate.year}',
        scheduledDate: reminderDate,
        payload: 'reminder_$reminderId',
      );
    }

    // Schedule on the day
    if (dueDate.isAfter(DateTime.now())) {
      await scheduleReminder(
        id: reminderId + 1000000, // Offset to avoid collision
        title: '🚨 Service Due Today: $vehicleName',
        body: '$serviceType is due today!',
        scheduledDate: dueDate,
        payload: 'reminder_$reminderId',
      );
    }
  }

  // Insurance renewal reminder
  Future<void> scheduleInsuranceReminder({
    required int reminderId,
    required String vehicleName,
    required DateTime expiryDate,
  }) async {
    // 30 days before
    final reminder30 = expiryDate.subtract(const Duration(days: 30));
    if (reminder30.isAfter(DateTime.now())) {
      await scheduleReminder(
        id: reminderId,
        title: '📋 Insurance Expiring Soon',
        body: '$vehicleName insurance expires in 30 days',
        scheduledDate: reminder30,
        payload: 'insurance_$reminderId',
      );
    }

    // 7 days before
    final reminder7 = expiryDate.subtract(const Duration(days: 7));
    if (reminder7.isAfter(DateTime.now())) {
      await scheduleReminder(
        id: reminderId + 100000,
        title: '⚠️ Insurance Expiring Soon!',
        body: '$vehicleName insurance expires in 7 days',
        scheduledDate: reminder7,
        payload: 'insurance_$reminderId',
      );
    }

    // 1 day before
    final reminder1 = expiryDate.subtract(const Duration(days: 1));
    if (reminder1.isAfter(DateTime.now())) {
      await scheduleReminder(
        id: reminderId + 200000,
        title: '🚨 Insurance Expires Tomorrow!',
        body: '$vehicleName insurance expires tomorrow',
        scheduledDate: reminder1,
        payload: 'insurance_$reminderId',
      );
    }
  }

  // Geofence enter notification with action buttons
  Future<void> showGeofenceEnterNotification({
    required int id,
    required String stationName,
    required String payload,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'geofence',
      'Location Triggers',
      channelDescription: 'Notifications when arriving at fuel stations',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'app_icon',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'quick_add',
          'Quick Add',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'dismiss',
          'Not Now',
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'geofence_category',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id,
      'At $stationName',
      'Log fuel expense?',
      details,
      payload: payload,
    );
  }

  // Geofence exit reminder notification
  Future<void> showGeofenceExitNotification({
    required int id,
    required String stationName,
    required String payload,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'geofence_reminder',
      'Exit Reminders',
      channelDescription:
          'Reminders to log expenses after leaving fuel stations',
      icon: 'app_icon',
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id,
      'Did you refuel?',
      'You left $stationName. Log your expense?',
      details,
      payload: payload,
    );
  }

  // Request notification permissions (for Android 13+)
  Future<bool> requestPermissions() async {
    if (await Permission.notification.isDenied) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return Permission.notification.isGranted;
  }
}
