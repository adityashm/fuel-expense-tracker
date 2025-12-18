import '../models/charging_expense.dart';
import '../models/expense_template.dart';
import '../models/fuel_expense.dart';
import '../models/general_expense.dart';
import '../models/vehicle.dart';
import 'database_service.dart';

class TemplateService {
  TemplateService._init();
  static final TemplateService instance = TemplateService._init();
  final _dbService = DatabaseService.instance;

  // ==================== TEMPLATE MANAGEMENT ====================

  /// Create template from fuel expense
  Future<ExpenseTemplate> createTemplateFromFuelExpense(
    FuelExpense expense,
    String templateName,
    Vehicle vehicle,
  ) async {
    final template = ExpenseTemplate(
      name: templateName,
      vehicleId: vehicle.id!,
      vehicleName: vehicle.name,
      type: TemplateType.fuel,
      stationName: expense.pumpName,
      location: expense.location,
      liters: expense.liters,
      fuelType: expense.fuelType,
      amount: expense.amountPaid,
      notes: expense.notes,
    );

    final id = await _dbService.createExpenseTemplate(template.toMap());
    return template.copyWith(id: id);
  }

  /// Create template from charging expense
  Future<ExpenseTemplate> createTemplateFromChargingExpense(
    ChargingExpense expense,
    String templateName,
    Vehicle vehicle,
  ) async {
    final template = ExpenseTemplate(
      name: templateName,
      vehicleId: vehicle.id!,
      vehicleName: vehicle.name,
      type: TemplateType.charging,
      kwhAmount: expense.kwhCharged,
      chargingType: expense.chargingType,
      chargingStationName: expense.stationName,
      location: expense.address,
      amount: expense.totalCost,
      notes: expense.notes,
    );

    final id = await _dbService.createExpenseTemplate(template.toMap());
    return template.copyWith(id: id);
  }

  /// Create template from general expense
  Future<ExpenseTemplate> createTemplateFromGeneralExpense(
    GeneralExpense expense,
    String templateName,
    Vehicle vehicle,
  ) async {
    final template = ExpenseTemplate(
      name: templateName,
      vehicleId: vehicle.id!,
      vehicleName: vehicle.name,
      type: TemplateType.general,
      amount: expense.amount,
      category: expense.category.name,
      description: expense.description,
    );

    final id = await _dbService.createExpenseTemplate(template.toMap());
    return template.copyWith(id: id);
  }

  /// Get all templates for a vehicle
  Future<List<ExpenseTemplate>> getTemplatesForVehicle(int vehicleId) async {
    final maps = await _dbService.getTemplatesByVehicle(vehicleId);
    return maps.map((map) => ExpenseTemplate.fromMap(map)).toList();
  }

  /// Get all templates
  Future<List<ExpenseTemplate>> getAllTemplates() async {
    final maps = await _dbService.getAllTemplates();
    return maps.map((map) => ExpenseTemplate.fromMap(map)).toList();
  }

  /// Get most used templates
  Future<List<ExpenseTemplate>> getMostUsedTemplates({int limit = 5}) async {
    final maps = await _dbService.getMostUsedTemplates(limit: limit);
    return maps.map((map) => ExpenseTemplate.fromMap(map)).toList();
  }

  /// Update template
  Future<void> updateTemplate(ExpenseTemplate template) async {
    await _dbService.updateExpenseTemplate(template.id!, template.toMap());
  }

  /// Delete template
  Future<void> deleteTemplate(int templateId) async {
    await _dbService.deleteExpenseTemplate(templateId);
  }

  /// Use a template (increment usage)
  Future<void> useTemplate(int templateId) async {
    await _dbService.incrementTemplateUsage(templateId);
  }

  // ==================== SMART SUGGESTIONS ====================

  /// Get smart template suggestions based on patterns
  Future<List<TemplateSuggestion>> getSmartSuggestions(Vehicle vehicle) async {
    final templates = await getTemplatesForVehicle(vehicle.id!);
    if (templates.isEmpty) return [];

    final suggestions = <TemplateSuggestion>[];
    final now = DateTime.now();

    for (final template in templates) {
      if (template.useCount < 2) continue; // Need at least 2 uses to suggest

      // Day of week pattern
      if (template.lastUsedAt != null) {
        final lastUsedDay = template.lastUsedAt!.weekday;
        final todayDay = now.weekday;

        if (lastUsedDay == todayDay && template.useCount >= 3) {
          suggestions.add(
            TemplateSuggestion(
              template: template,
              reason:
                  'You usually use this template on ${_getDayName(todayDay)}s',
              confidence: 0.8,
              timeContext: _getTimeContext(now),
            ),
          );
        }
      }

      // High usage pattern (used 5+ times)
      if (template.useCount >= 5) {
        final daysSinceLastUse = template.lastUsedAt != null
            ? now.difference(template.lastUsedAt!).inDays
            : 999;

        if (daysSinceLastUse >= 6 && daysSinceLastUse <= 8) {
          suggestions.add(
            TemplateSuggestion(
              template: template,
              reason: 'Weekly pattern detected - due for refill',
              confidence: 0.75,
              timeContext: 'About a week since last ${template.name}',
            ),
          );
        }
      }

      // Morning/Evening pattern
      if (template.lastUsedAt != null) {
        final lastHour = template.lastUsedAt!.hour;
        final currentHour = now.hour;

        if ((lastHour >= 6 && lastHour <= 10) &&
            (currentHour >= 6 && currentHour <= 10)) {
          suggestions.add(
            TemplateSuggestion(
              template: template,
              reason: 'Morning refill pattern',
              confidence: 0.65,
              timeContext: 'You often use this in the morning',
            ),
          );
        } else if ((lastHour >= 17 && lastHour <= 21) &&
            (currentHour >= 17 && currentHour <= 21)) {
          suggestions.add(
            TemplateSuggestion(
              template: template,
              reason: 'Evening refill pattern',
              confidence: 0.65,
              timeContext: 'You often use this in the evening',
            ),
          );
        }
      }
    }

    // Sort by confidence
    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));

    return suggestions.take(3).toList();
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  String _getTimeContext(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) return 'Good morning! ';
    if (hour >= 12 && hour < 17) return 'Good afternoon! ';
    if (hour >= 17 && hour < 22) return 'Good evening! ';
    return '';
  }

  // ==================== FAVORITE STATIONS ====================

  /// Create or update favorite station
  Future<FavoriteStation> saveFavoriteStation(FavoriteStation station) async {
    if (station.id != null) {
      await _dbService.updateFavoriteStation(station.id!, station.toMap());
      return station;
    } else {
      final id = await _dbService.createFavoriteStation(station.toMap());
      return station.copyWith(id: id);
    }
  }

  /// Get all favorite stations
  Future<List<FavoriteStation>> getAllFavoriteStations() async {
    final maps = await _dbService.getAllFavoriteStations();
    return maps.map((map) => FavoriteStation.fromMap(map)).toList();
  }

  /// Get station by name
  Future<FavoriteStation?> getFavoriteStationByName(String name) async {
    final map = await _dbService.getFavoriteStationByName(name);
    return map != null ? FavoriteStation.fromMap(map) : null;
  }

  /// Get most used stations
  Future<List<FavoriteStation>> getMostUsedStations({int limit = 5}) async {
    final maps = await _dbService.getMostUsedStations(limit: limit);
    return maps.map((map) => FavoriteStation.fromMap(map)).toList();
  }

  /// Use a station (increment usage and update price if provided)
  Future<void> useStation(int stationId, {double? pricePerLiter}) async {
    await _dbService.incrementStationUsage(stationId);
    if (pricePerLiter != null) {
      await _dbService.updateStationPrice(stationId, pricePerLiter);
    }
  }

  /// Delete favorite station
  Future<void> deleteFavoriteStation(int stationId) async {
    await _dbService.deleteFavoriteStation(stationId);
  }

  /// Search stations
  Future<List<FavoriteStation>> searchStations(String query) async {
    final maps = await _dbService.searchStations(query);
    return maps.map((map) => FavoriteStation.fromMap(map)).toList();
  }

  /// Create favorite station from fuel expense
  Future<FavoriteStation> createStationFromExpense(FuelExpense expense) async {
    if (expense.pumpName == null) {
      throw Exception('Pump name is required');
    }

    // Check if station already exists
    final existing = await getFavoriteStationByName(expense.pumpName!);
    if (existing != null) {
      // Update price if this expense has newer price
      final pricePerLiter = expense.amountPaid / expense.liters;
      await useStation(existing.id!, pricePerLiter: pricePerLiter);
      return existing.copyWith(
        lastPricePerLiter: pricePerLiter,
        lastPriceUpdatedAt: expense.date,
      );
    }

    final pricePerLiter = expense.amountPaid / expense.liters;
    final station = FavoriteStation(
      name: expense.pumpName!,
      location: expense.location,
      lastPricePerLiter: pricePerLiter,
      lastPriceUpdatedAt: expense.date,
      fuelTypes: [expense.fuelType.name],
    );

    return saveFavoriteStation(station);
  }

  // ==================== QUICK FILL SUGGESTIONS ====================

  /// Get recent expense amounts for quick-fill
  Future<List<RecentExpenseQuickFill>> getQuickFillSuggestions(
    int vehicleId,
  ) async {
    final maps = await _dbService.getRecentExpensesForQuickFill(vehicleId);
    return maps.map((map) {
      final expense = FuelExpense.fromMap(map);
      return RecentExpenseQuickFill(
        amount: expense.amountPaid,
        quantity: expense.liters,
        stationName: expense.pumpName,
        date: expense.date,
      );
    }).toList();
  }

  /// Auto-detect and suggest creating template from repeated expenses
  Future<List<Map<String, dynamic>>> detectRepeatableExpenses(
    int vehicleId,
  ) async {
    // Get last 20 fuel expenses
    final db = await _dbService.database;
    final recentExpenses = await db.query(
      'fuel_expenses',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC',
      limit: 20,
    );

    if (recentExpenses.length < 3) return [];

    final suggestions = <Map<String, dynamic>>[];
    final expensesByStation = <String, List<Map<String, dynamic>>>{};

    // Group by station
    for (final expense in recentExpenses) {
      final station = expense['pump_name'] as String?;
      if (station == null) continue;

      expensesByStation.putIfAbsent(station, () => []);
      expensesByStation[station]!.add(expense);
    }

    // Find stations used 3+ times with similar amounts
    for (final entry in expensesByStation.entries) {
      if (entry.value.length >= 3) {
        final amounts =
            entry.value.map((e) => e['amount_paid'] as double).toList();
        final avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;

        // Check if amounts are consistent (within 20% variance)
        final variance = amounts
            .map((a) => (a - avgAmount).abs())
            .reduce((a, b) => a > b ? a : b);
        if (variance / avgAmount <= 0.2) {
          suggestions.add({
            'station': entry.key,
            'frequency': entry.value.length,
            'avgAmount': avgAmount,
            'suggestedName': '${entry.key} Usual Fill',
          });
        }
      }
    }

    return suggestions;
  }
}
