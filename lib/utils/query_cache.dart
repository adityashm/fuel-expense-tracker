// ignore_for_file: unused_local_variable, prefer_foreach

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Entry in the query cache with TTL
class _CacheEntry<T> {
  _CacheEntry(this.value, this.ttl)
      : expiresAt = DateTime.now().add(ttl);

  final T value;
  final Duration ttl;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Query result cache with Time-To-Live
class QueryCache {
  QueryCache._();
  static final QueryCache instance = QueryCache._();

  final Map<String, _CacheEntry> _cache = {};
  Timer? _cleanupTimer;

  /// Default TTL for queries (5 minutes)
  static const Duration defaultTTL = Duration(minutes: 5);

  /// Start periodic cleanup
  void initialize() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _cleanupExpired();
    });
  }

  /// Get cached value or fetch from source
  Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetcher, {
    Duration? ttl,
  }) async {
    final entry = _cache[key];

    // Return cached value if valid
    if (entry != null && !entry.isExpired) {
      debugPrint('📦 Cache HIT: $key');
      return entry.value as T;
    }

    // Fetch fresh data
    debugPrint('🔄 Cache MISS: $key - fetching...');
    final value = await fetcher();

    // Cache the result
    _cache[key] = _CacheEntry(value, ttl ?? defaultTTL);

    return value;
  }

  /// Invalidate specific cache entry
  void invalidate(String key) {
    _cache.remove(key);
    debugPrint('🗑️ Cache invalidated: $key');
  }

  /// Invalidate entries matching pattern
  void invalidatePattern(String pattern) {
    final regex = RegExp(pattern);
    final keysToRemove = _cache.keys.where((k) => regex.hasMatch(k)).toList();

    for (final key in keysToRemove) {
      _cache.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      debugPrint('🗑️ Cache invalidated: ${keysToRemove.length} entries');
    }
  }

  /// Clear all cache
  void clearAll() {
    _cache.clear();
    debugPrint('🗑️ Cache cleared completely');
  }

  /// Remove expired entries
  void _cleanupExpired() {
    final expiredKeys =
        _cache.entries.where((e) => e.value.isExpired).map((e) => e.key).toList();

    for (final key in expiredKeys) {
      _cache.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      debugPrint('🧹 Cleaned ${expiredKeys.length} expired cache entries');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    final now = DateTime.now();
    final validEntries = _cache.values.where((e) => !e.isExpired).length;
    final expiredEntries = _cache.length - validEntries;

    return {
      'total_entries': _cache.length,
      'valid_entries': validEntries,
      'expired_entries': expiredEntries,
      'cache_keys': _cache.keys.toList(),
    };
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    _cache.clear();
  }
}

/// Cache key generators for common queries
class CacheKeys {
  static String fuelExpenses({int? vehicleId, int? offset}) =>
      'fuel_expenses_${vehicleId ?? 'all'}_$offset';

  static String generalExpenses({int? vehicleId, int? offset}) =>
      'general_expenses_${vehicleId ?? 'all'}_$offset';

  static String householdExpenses({int? offset}) =>
      'household_expenses_$offset';

  static String vehicles([String? deviceId]) =>
      'vehicles_${deviceId ?? 'all'}';

  static String vehicle(int id) => 'vehicle_$id';

  static String monthlyStats(int year, int month) => 'monthly_stats_${year}_$month';

  static String fuelAverage(int vehicleId) => 'fuel_average_$vehicleId';

  static String familyMembers() => 'family_members';

  static String recurringExpenses() => 'recurring_expenses';

  static String databaseStats() => 'database_stats';
}
