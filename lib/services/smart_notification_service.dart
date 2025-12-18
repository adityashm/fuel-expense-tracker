import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'advanced_analytics_service.dart';

/// Smart notification service for expense reminders and insights
class SmartNotificationService {
  SmartNotificationService._internal() {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    _analyticsService = AdvancedAnalyticsService.instance;
  }

  factory SmartNotificationService() {
    return _instance;
  }
  static final SmartNotificationService _instance =
      SmartNotificationService._internal();
  late final FlutterLocalNotificationsPlugin _notificationsPlugin;
  late final AdvancedAnalyticsService _analyticsService;
  bool _initialized = false;

  static SmartNotificationService get instance => _instance;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    await initialize();

    final android = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    final ios = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    return android ?? ios ?? false;
  }

  /// Schedule settlement reminder
  Future<void> scheduleSettlementReminder({
    required int householdId,
    required String memberName,
    required double amount,
    required DateTime reminderDate,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'settlement_reminders',
      'Settlement Reminders',
      channelDescription: 'Reminders for pending expense settlements',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notificationsPlugin.zonedSchedule(
      _generateNotificationId('settlement', householdId),
      'Payment Reminder',
      'You owe ₹${amount.toStringAsFixed(2)} to $memberName',
      tz.TZDateTime.from(reminderDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedule recurring expense reminder
  Future<void> scheduleRecurringExpenseReminder({
    required String expenseId,
    required String description,
    required double amount,
    required DateTime dueDate,
    int daysBefore = 2,
  }) async {
    await initialize();

    final reminderDate = dueDate.subtract(Duration(days: daysBefore));

    if (reminderDate.isBefore(DateTime.now())) {
      return; // Don't schedule past reminders
    }

    const androidDetails = AndroidNotificationDetails(
      'recurring_expense_reminders',
      'Recurring Expense Reminders',
      channelDescription: 'Reminders for upcoming recurring expenses',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notificationsPlugin.zonedSchedule(
      _generateNotificationId('recurring', expenseId.hashCode),
      'Recurring Expense Due Soon',
      '$description - ₹${amount.toStringAsFixed(2)} due on ${_formatDate(dueDate)}',
      tz.TZDateTime.from(reminderDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedule budget alert
  Future<void> scheduleBudgetAlert({
    required int householdId,
    required String category,
    required double spent,
    required double limit,
    required double percentage,
  }) async {
    await initialize();

    String title;
    String body;

    if (percentage >= 100) {
      title = '🚨 Budget Exceeded!';
      body =
          '$category budget exceeded! Spent ₹${spent.toStringAsFixed(2)} of ₹${limit.toStringAsFixed(2)}';
    } else if (percentage >= 90) {
      title = '⚠️ Budget Warning';
      body = '$category at ${percentage.toStringAsFixed(0)}% of budget';
    } else if (percentage >= 75) {
      title = '💡 Budget Alert';
      body =
          '$category spending: ₹${spent.toStringAsFixed(2)} / ₹${limit.toStringAsFixed(2)}';
    } else {
      return; // Don't alert below 75%
    }

    const androidDetails = AndroidNotificationDetails(
      'budget_alerts',
      'Budget Alerts',
      channelDescription: 'Alerts when approaching or exceeding budget limits',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notificationsPlugin.show(
      _generateNotificationId('budget', householdId),
      title,
      body,
      details,
    );
  }

  /// Send daily digest notification
  Future<void> scheduleDailyDigest({
    required int householdId,
    required int hour,
    required int minute,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'daily_digest',
      'Daily Digest',
      channelDescription: 'Daily summary of household expenses',
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notificationsPlugin.zonedSchedule(
      _generateNotificationId('digest', householdId),
      'Daily Expense Summary',
      'Tap to view today\'s expenses and insights',
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Send smart insight notification
  Future<void> sendSmartInsight({
    required int householdId,
    required String title,
    required String message,
    NotificationPriority priority = NotificationPriority.medium,
  }) async {
    await initialize();

    final androidDetails = AndroidNotificationDetails(
      'smart_insights',
      'Smart Insights',
      channelDescription: 'AI-powered expense insights and recommendations',
      importance: _getAndroidImportance(priority),
      priority: _getAndroidPriority(priority),
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notificationsPlugin.show(
      _generateNotificationId('insight', householdId),
      title,
      message,
      details,
    );
  }

  /// Auto-generate smart insights based on spending patterns
  Future<void> generateAndSendInsights(int householdId) async {
    final insights = await _analyticsService.getCategoryInsights(householdId);
    final suggestions =
        await _analyticsService.getOptimizationSuggestions(householdId);

    // Check for unusual spending
    for (final insight in insights) {
      if (insight.trend == 'increasing' && insight.changePercent > 25) {
        await sendSmartInsight(
          householdId: householdId,
          title: '📈 ${insight.category} Spending Up',
          message:
              '${insight.category} increased by ${insight.changePercent.toStringAsFixed(0)}% this period',
          priority: NotificationPriority.high,
        );
      }
    }

    // Send top optimization suggestion
    if (suggestions.isNotEmpty) {
      final topSuggestion = suggestions.first;
      if (topSuggestion.priority == 'high') {
        await sendSmartInsight(
          householdId: householdId,
          title: '💡 ${topSuggestion.title}',
          message: topSuggestion.description,
          priority: NotificationPriority.high,
        );
      }
    }
  }

  /// Schedule weekly summary notification
  Future<void> scheduleWeeklySummary({
    required int householdId,
    required int dayOfWeek, // 1 = Monday, 7 = Sunday
    required int hour,
    required int minute,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'weekly_summary',
      'Weekly Summary',
      channelDescription: 'Weekly expense summary and insights',
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

    // Find next occurrence of the specified day of week
    while (scheduledDate.weekday != dayOfWeek || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notificationsPlugin.zonedSchedule(
      _generateNotificationId('weekly', householdId),
      'Weekly Expense Summary',
      'Review your weekly spending and insights',
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel specific notification
  Future<void> cancelNotification(String type, int id) async {
    await _notificationsPlugin.cancel(_generateNotificationId(type, id));
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return _notificationsPlugin.pendingNotificationRequests();
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle navigation based on notification payload
    // This can be extended to navigate to specific screens
  }

  /// Generate unique notification ID
  int _generateNotificationId(String type, int id) {
    return '$type$id'.hashCode.abs() % 2147483647;
  }

  /// Format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Get Android importance from priority
  Importance _getAndroidImportance(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.high:
        return Importance.high;
      case NotificationPriority.medium:
        return Importance.defaultImportance;
      case NotificationPriority.low:
        return Importance.low;
    }
  }

  /// Get Android priority from priority
  Priority _getAndroidPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.high:
        return Priority.high;
      case NotificationPriority.medium:
        return Priority.defaultPriority;
      case NotificationPriority.low:
        return Priority.low;
    }
  }
}

/// Notification priority levels
enum NotificationPriority {
  high,
  medium,
  low,
}
