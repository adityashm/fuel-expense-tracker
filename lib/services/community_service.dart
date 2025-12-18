import '../models/achievement.dart';
import '../models/community_post.dart';
import '../models/device_connection.dart';
import '../services/database_service.dart';

class LeaderboardEntry {
  LeaderboardEntry({
    required this.deviceId,
    required this.label,
    required this.score,
    required this.spend,
  });
  final String deviceId;
  final String label;
  final double score;
  final double spend;
}

class FriendLeaderboardEntry {
  FriendLeaderboardEntry({
    required this.deviceId,
    required this.friendName,
    required this.score,
    required this.spend,
    required this.liters,
    required this.fillCount,
    required this.lastFill,
  });
  final String deviceId;
  final String friendName;
  final double score;
  final double spend;
  final double liters;
  final int fillCount;
  final DateTime? lastFill;
}

class PumpPriceInsight {
  PumpPriceInsight({
    required this.location,
    required this.price,
    required this.contributor,
    required this.updatedAt,
  });
  final String location;
  final double price;
  final String contributor;
  final DateTime updatedAt;
}

class CommunityService {
  CommunityService._();

  static final CommunityService instance = CommunityService._();
  final DatabaseService _db = DatabaseService.instance;

  Future<List<CommunityPost>> fetchLatestPosts({int limit = 30}) async {
    final database = await _db.database;
    final rows = await database.query(
      'community_posts',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(CommunityPost.fromMap).toList();
  }

  Future<CommunityPost> createPost({
    required String deviceId,
    required String authorName,
    required String title,
    required String message,
    String? location,
    double? fuelPrice,
  }) async {
    final database = await _db.database;
    final id = await database.insert('community_posts', {
      'device_id': deviceId,
      'author_name': authorName,
      'title': title,
      'message': message,
      'location': location,
      'fuel_price': fuelPrice,
      'likes': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
    final row = await database.query(
      'community_posts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return CommunityPost.fromMap(row.first);
  }

  Future<void> appreciatePost(int postId) async {
    final database = await _db.database;
    await database.rawUpdate(
      'UPDATE community_posts SET likes = likes + 1 WHERE id = ?',
      [postId],
    );
  }

  Future<List<Achievement>> syncAchievements(String deviceId) async {
    final database = await _db.database;
    final existingRows = await database.query(
      'achievements',
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
    final achievements = existingRows.map(Achievement.fromMap).toList();
    final haveBadge = achievements.map((a) => a.badgeKey).toSet();

    Future<void> grantBadge(
      String badgeKey,
      String label,
      String description,
      bool condition,
    ) async {
      if (!condition || haveBadge.contains(badgeKey)) return;
      await database.insert('achievements', {
        'device_id': deviceId,
        'badge_key': badgeKey,
        'label': label,
        'description': description,
        'points': 50,
        'earned_at': DateTime.now().toIso8601String(),
      });
      haveBadge.add(badgeKey);
    }

    final fuelExpenses = await _db.getFuelExpensesByDevice(deviceId);
    await grantBadge(
      'consistent_logger',
      'Consistent Logger',
      'Logged 10+ fuel receipts',
      fuelExpenses.length >= 10,
    );

    final now = DateTime.now();
    final last30 = now.subtract(const Duration(days: 30));
    final prev30 = now.subtract(const Duration(days: 60));

    double sumForRange(DateTime start, DateTime end) {
      double total = 0;
      for (final expense in fuelExpenses) {
        if (expense.date.isAfter(start) && expense.date.isBefore(end)) {
          total += expense.amountPaid;
        }
      }
      return total;
    }

    final recent = sumForRange(last30, now);
    final previous = sumForRange(prev30, last30);
    await grantBadge(
      'budget_guardian',
      'Budget Guardian',
      'Reduced spend compared to last month',
      previous > 0 && recent < previous,
    );

    return (await database.query(
      'achievements',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'earned_at DESC',
    ))
        .map(Achievement.fromMap)
        .toList();
  }

  Future<List<LeaderboardEntry>> buildLeaderboard() async {
    final database = await _db.database;
    final rows = await database.rawQuery('''
      SELECT device_id, SUM(amount_paid) AS spend, SUM(liters) AS liters
      FROM fuel_expenses
      GROUP BY device_id
      HAVING spend IS NOT NULL
    ''');

    final devices = await _db.getAllDevices();
    final names = {
      for (final d in devices)
        d['device_id'] as String: d['person_name'] as String,
    };

    final entries = rows.map((row) {
      final spend = (row['spend'] as num?)?.toDouble() ?? 0;
      final liters = (row['liters'] as num?)?.toDouble() ?? 0;
      final score = liters == 0 ? spend : spend / liters;
      return LeaderboardEntry(
        deviceId: row['device_id'] as String,
        label: names[row['device_id']] ?? 'Anonymous',
        score: score,
        spend: spend,
      );
    }).toList()
      ..sort((a, b) => a.score.compareTo(b.score));
    return entries.take(5).toList();
  }

  Future<List<DeviceConnection>> fetchConnections(String ownerDeviceId) async {
    final rows = await _db.getDeviceConnections(ownerDeviceId);
    return rows.map(DeviceConnection.fromMap).toList();
  }

  Future<DeviceConnection> addConnection({
    required String ownerDeviceId,
    required String friendDeviceId,
    required String friendName,
  }) async {
    final existing =
        await _db.getDeviceConnection(ownerDeviceId, friendDeviceId);
    if (existing != null) {
      return DeviceConnection.fromMap(existing);
    }

    final payload = DeviceConnection(
      ownerDeviceId: ownerDeviceId,
      friendDeviceId: friendDeviceId,
      friendName: friendName,
      createdAt: DateTime.now(),
    );
    final id = await _db.createDeviceConnection(payload.toMap());
    if (id == 0) {
      final fallback =
          await _db.getDeviceConnection(ownerDeviceId, friendDeviceId);
      if (fallback != null) {
        return DeviceConnection.fromMap(fallback);
      }
    }
    return payload.copyWith(id: id == 0 ? null : id);
  }

  Future<void> removeConnection(int connectionId) async {
    await _db.deleteDeviceConnection(connectionId);
  }

  Future<List<FriendLeaderboardEntry>> buildFriendLeaderboard(
    String ownerDeviceId,
  ) async {
    final connections = await fetchConnections(ownerDeviceId);
    final entries = <FriendLeaderboardEntry>[];
    for (final connection in connections) {
      final expenses =
          await _db.getFuelExpensesByDevice(connection.friendDeviceId);
      double totalSpend = 0;
      double totalLiters = 0;
      for (final expense in expenses) {
        totalSpend += expense.amountPaid;
        totalLiters += expense.liters;
      }

      final score = totalLiters == 0 ? totalSpend : totalSpend / totalLiters;
      entries.add(
        FriendLeaderboardEntry(
          deviceId: connection.friendDeviceId,
          friendName: connection.friendName,
          score: score,
          spend: totalSpend,
          liters: totalLiters,
          fillCount: expenses.length,
          lastFill: expenses.isNotEmpty ? expenses.first.date : null,
        ),
      );
    }
    entries.sort((a, b) => a.score.compareTo(b.score));
    return entries;
  }

  Future<List<PumpPriceInsight>> buildPumpPriceInsights({int limit = 5}) async {
    final database = await _db.database;
    final rows = await database.query(
      'community_posts',
      columns: ['location', 'fuel_price', 'author_name', 'created_at'],
      where:
          'fuel_price IS NOT NULL AND location IS NOT NULL AND TRIM(location) <> ""',
      orderBy: 'created_at DESC',
      limit: limit * 4,
    );

    final seenLocations = <String>{};
    final insights = <PumpPriceInsight>[];
    for (final row in rows) {
      final location = (row['location'] as String?)?.trim();
      final price = (row['fuel_price'] as num?)?.toDouble();
      if (location == null || location.isEmpty || price == null) {
        continue;
      }
      if (!seenLocations.add(location.toLowerCase())) {
        continue;
      }
      insights.add(
        PumpPriceInsight(
          location: location,
          price: price,
          contributor: (row['author_name'] as String?) ?? 'Community',
          updatedAt: DateTime.parse(row['created_at'] as String),
        ),
      );
      if (insights.length >= limit) {
        break;
      }
    }

    insights.sort((a, b) => a.price.compareTo(b.price));
    return insights;
  }
}
