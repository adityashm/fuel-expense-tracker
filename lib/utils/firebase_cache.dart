import 'dart:async';

/// Simple cache entry with timestamp
class CachedData<T> {
  CachedData(this.data, this.timestamp);
  final T data;
  final DateTime timestamp;

  bool isExpired(Duration ttl) {
    return DateTime.now().difference(timestamp) > ttl;
  }
}

/// Firebase query result caching utility
/// Reduces Firebase reads by caching results for specified duration
class FirebaseCache {
  // Private constructor for singleton
  FirebaseCache._();
  static final FirebaseCache instance = FirebaseCache._();

  // Cache storage
  final Map<String, CachedData<dynamic>> _cache = {};

  // Default cache duration
  static const Duration defaultTTL = Duration(minutes: 5);

  /// Get cached data or fetch and cache if expired
  Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetchFunction, {
    Duration? ttl,
  }) async {
    final cacheDuration = ttl ?? defaultTTL;

    // Check if cached data exists and is not expired
    final cached = _cache[key];
    if (cached != null && !cached.isExpired(cacheDuration)) {
      return cached.data as T;
    }

    // Fetch fresh data
    final data = await fetchFunction();

    // Cache the result
    _cache[key] = CachedData(data, DateTime.now());

    return data;
  }

  /// Manually cache data
  void put<T>(String key, T data) {
    _cache[key] = CachedData(data, DateTime.now());
  }

  /// Invalidate specific cache entry
  void invalidate(String key) {
    _cache.remove(key);
  }

  /// Invalidate all cache entries matching pattern
  void invalidatePattern(String pattern) {
    final regex = RegExp(pattern);
    _cache.removeWhere((key, value) => regex.hasMatch(key));
  }

  /// Clear all cache
  void clearAll() {
    _cache.clear();
  }

  /// Clear expired entries
  void clearExpired(Duration ttl) {
    _cache.removeWhere((key, cached) => cached.isExpired(ttl));
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'totalEntries': _cache.length,
      'keys': _cache.keys.toList(),
      'oldestEntry': _cache.values.isEmpty
          ? null
          : _cache.values
              .map((c) => c.timestamp)
              .reduce((a, b) => a.isBefore(b) ? a : b),
    };
  }
}

/// Cache key generator utility
class CacheKeys {
  static String expenses(String deviceId) => 'expenses_$deviceId';
  static String fuelExpenses(String deviceId) => 'fuel_expenses_$deviceId';
  static String generalExpenses(String deviceId) =>
      'general_expenses_$deviceId';
  static String householdExpenses(String deviceId) =>
      'household_expenses_$deviceId';
  static String vehicles(String deviceId) => 'vehicles_$deviceId';
  static String vehicle(int vehicleId) => 'vehicle_$vehicleId';
  static String familyMembers(String deviceId) => 'family_members_$deviceId';
  static String budgets(String deviceId) => 'budgets_$deviceId';
  static String trips(int vehicleId) => 'trips_$vehicleId';
  static String reminders(String deviceId) => 'reminders_$deviceId';
}
