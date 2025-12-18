import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/achievement.dart';
import '../models/community_post.dart';
import '../models/device_connection.dart';
import '../providers/device_provider.dart';
import '../services/community_service.dart';

enum LeaderboardScope { global, friends }

class CommunityHubScreen extends StatefulWidget {
  const CommunityHubScreen({super.key});

  @override
  State<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends State<CommunityHubScreen> {
  final _service = CommunityService.instance;
  bool _loading = true;
  List<CommunityPost> _posts = const [];
  List<LeaderboardEntry> _leaderboard = const [];
  List<Achievement> _achievements = const [];
  List<DeviceConnection> _connections = const [];
  List<FriendLeaderboardEntry> _friendLeaderboard = const [];
  List<PumpPriceInsight> _priceInsights = const [];
  LeaderboardScope _leaderboardScope = LeaderboardScope.global;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadData);
  }

  Future<void> _loadData() async {
    final deviceProvider = context.read<DeviceProvider>();
    final hasDevice = deviceProvider.hasDevice;
    final deviceId = deviceProvider.currentDeviceId;

    setState(() => _loading = true);

    final results = await Future.wait([
      _service.fetchLatestPosts(),
      _service.buildLeaderboard(),
      _service.buildPumpPriceInsights(),
      if (hasDevice)
        _service.syncAchievements(deviceId!)
      else
        Future.value(const <Achievement>[]),
      if (hasDevice)
        _service.fetchConnections(deviceId!)
      else
        Future.value(const <DeviceConnection>[]),
      if (hasDevice)
        _service.buildFriendLeaderboard(deviceId!)
      else
        Future.value(const <FriendLeaderboardEntry>[]),
    ]);
    if (!mounted) return;
    setState(() {
      _posts = results[0] as List<CommunityPost>;
      _leaderboard = results[1] as List<LeaderboardEntry>;
      _priceInsights = results[2] as List<PumpPriceInsight>;
      _achievements = results[3] as List<Achievement>;
      _connections = results[4] as List<DeviceConnection>;
      _friendLeaderboard = results[5] as List<FriendLeaderboardEntry>;
      _loading = false;
    });
  }

  Future<void> _refreshFriendData() async {
    final deviceId = context.read<DeviceProvider>().currentDeviceId;
    if (deviceId == null) return;
    final connections = await _service.fetchConnections(deviceId);
    final friendBoard = await _service.buildFriendLeaderboard(deviceId);
    if (!mounted) return;
    setState(() {
      _connections = connections;
      _friendLeaderboard = friendBoard;
    });
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: deviceProvider.hasDevice
          ? FloatingActionButton.extended(
              onPressed: _openComposer,
              icon: const Icon(Icons.edit),
              label: const Text('Share tip'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!deviceProvider.hasDevice)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Register your device in Settings to unlock posting, badges, and friend leaderboards.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  if (deviceProvider.hasDevice) ...[
                    _buildConnectionsCard(deviceProvider),
                    const SizedBox(height: 16),
                  ],
                  _buildLeaderboardCard(
                    canToggleFriends:
                        deviceProvider.hasDevice && _connections.isNotEmpty,
                  ),
                  const SizedBox(height: 16),
                  _buildPumpPriceCard(),
                  const SizedBox(height: 16),
                  if (deviceProvider.hasDevice && _achievements.isNotEmpty) ...[
                    _buildAchievements(),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Community tips',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ..._posts.map(_buildPostCard),
                  if (_posts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Center(
                        child: Text(
                          'Be the first to drop a pump recommendation or efficiency pro-tip!',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildLeaderboardCard({required bool canToggleFriends}) {
    final showingFriends =
        _leaderboardScope == LeaderboardScope.friends && canToggleFriends;
    final entries = showingFriends ? _friendLeaderboard : _leaderboard;

    if (entries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            showingFriends
                ? 'Add a friend connection to compare efficiency stats privately.'
                : 'Log a few fuel entries to appear on the efficiency leaderboard.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  showingFriends ? 'Friends leaderboard' : 'Global leaderboard',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (canToggleFriends)
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Global'),
                        selected: !showingFriends,
                        onSelected: (_) {
                          setState(
                            () => _leaderboardScope = LeaderboardScope.global,
                          );
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Friends'),
                        selected: showingFriends,
                        onSelected: (_) {
                          setState(
                            () => _leaderboardScope = LeaderboardScope.friends,
                          );
                        },
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...entries.asMap().entries.map(
              (entry) {
                final index = entry.key + 1;
                if (showingFriends) {
                  final item = entry.value as FriendLeaderboardEntry;
                  return _buildFriendLeaderboardTile(index, item);
                }
                final item = entry.value as LeaderboardEntry;
                return _buildGlobalLeaderboardTile(index, item);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievements() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Badges earned',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _achievements
                  .map(
                    (a) => Chip(
                      avatar:
                          const Icon(Icons.emoji_events, color: Colors.amber),
                      label: Text(a.label),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionsCard(DeviceProvider deviceProvider) {
    final deviceId = deviceProvider.currentDeviceId ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Friend connections',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Add friend',
                  onPressed: _openAddFriendSheet,
                  icon: const Icon(Icons.person_add_alt_1),
                ),
              ],
            ),
            Text(
              'Share code: $deviceId',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_connections.isEmpty)
              Text(
                'Build your private leaderboard by connecting trusted drivers.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ..._connections.map((connection) {
                final stats = _lookupFriendStat(connection.friendDeviceId);
                final subtitle = stats == null
                    ? 'No shared stats yet'
                    : '₹${stats.spend.toStringAsFixed(0)} spent • ${stats.fillCount} fills';
                final trailing = stats?.lastFill == null
                    ? 'Never'
                    : _formatRelativeTime(stats!.lastFill);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(connection.friendName),
                  subtitle: Text('$subtitle • last fill $trailing'),
                  trailing: IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close),
                    onPressed: () => _confirmRemoveConnection(connection),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPumpPriceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Pump price board',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                const Icon(Icons.local_gas_station, color: Colors.deepOrange),
              ],
            ),
            const SizedBox(height: 12),
            if (_priceInsights.isEmpty)
              Text(
                'Share today’s prices when you post so everyone benefits.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ..._priceInsights.map(
                (insight) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.withValues(alpha: 0.15),
                    child: Text('₹${insight.price.toStringAsFixed(0)}'),
                  ),
                  title: Text(insight.location),
                  subtitle: Text(
                    '${insight.contributor} • ${_formatRelativeTime(insight.updatedAt)}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalLeaderboardTile(int index, LeaderboardEntry entry) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.amber.withValues(alpha: 0.25),
        child: Text(index.toString()),
      ),
      title: Text(entry.label),
      subtitle: Text(
        '₹${entry.spend.toStringAsFixed(0)} spent • score ${entry.score.toStringAsFixed(2)}',
      ),
    );
  }

  Widget _buildFriendLeaderboardTile(int index, FriendLeaderboardEntry entry) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue.withValues(alpha: 0.25),
        child: Text(index.toString()),
      ),
      title: Text(entry.friendName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Score ${entry.score.toStringAsFixed(2)} ₹/L • ₹${entry.spend.toStringAsFixed(0)} spent',
          ),
          Text(
            '${entry.fillCount} fills • last ${_formatRelativeTime(entry.lastFill)}',
          ),
        ],
      ),
    );
  }

  Future<void> _openAddFriendSheet() async {
    final deviceProvider = context.read<DeviceProvider>();
    final deviceId = deviceProvider.currentDeviceId;
    if (deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please register a device first.')),
      );
      return;
    }

    final availableDevices =
        deviceProvider.devices.where((d) => d.deviceId != deviceId).toList();
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    String? selectedDeviceId;

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add friend connection',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    if (availableDevices.isNotEmpty)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Pick from local profiles',
                        ),
                        initialValue: selectedDeviceId,
                        items: availableDevices
                            .map(
                              (device) => DropdownMenuItem(
                                value: device.deviceId,
                                child: Text(device.personName),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          modalSetState(() => selectedDeviceId = value);
                          if (value != null) {
                            final selected = availableDevices.firstWhere(
                              (device) => device.deviceId == value,
                            );
                            nameController.text = selected.personName;
                            codeController.text = selected.deviceId;
                          }
                        },
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration:
                          const InputDecoration(labelText: 'Friend name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeController,
                      decoration:
                          const InputDecoration(labelText: 'Friend code'),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (nameController.text.trim().isEmpty ||
                              codeController.text.trim().isEmpty) {
                            return;
                          }
                          Navigator.pop(context, true);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (added == true) {
      final friendName = nameController.text.trim();
      final friendCode = codeController.text.trim();
      nameController.dispose();
      codeController.dispose();

      if (friendCode.isEmpty || friendName.isEmpty) {
        return;
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (friendCode == deviceId) {
        messenger.showSnackBar(
          const SnackBar(content: Text('You cannot add yourself as a friend.')),
        );
        return;
      }

      try {
        await _service.addConnection(
          ownerDeviceId: deviceId,
          friendDeviceId: friendCode,
          friendName: friendName,
        );
        await _refreshFriendData();
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Added $friendName to your private leaderboard.'),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Could not add $friendName: $error')),
        );
      }
    } else {
      nameController.dispose();
      codeController.dispose();
    }
  }

  Future<void> _confirmRemoveConnection(DeviceConnection connection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove friend'),
        content: Text('Remove ${connection.friendName} from your connections?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && connection.id != null) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      try {
        await _service.removeConnection(connection.id!);
        await _refreshFriendData();
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('${connection.friendName} removed.')),
        );
      } catch (error) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not remove ${connection.friendName}: $error'),
          ),
        );
      }
    }
  }

  FriendLeaderboardEntry? _lookupFriendStat(String deviceId) {
    for (final entry in _friendLeaderboard) {
      if (entry.deviceId == deviceId) {
        return entry;
      }
    }
    return null;
  }

  String _formatRelativeTime(DateTime? timestamp) {
    if (timestamp == null) return 'never';
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.year}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.day.toString().padLeft(2, '0')}';
  }

  Widget _buildPostCard(CommunityPost post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    post.authorName.isNotEmpty
                        ? post.authorName[0].toUpperCase()
                        : '?',
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(post.createdAt.toIso8601String().split('T').first),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.favorite_border),
                  onPressed: () async {
                    await _service.appreciatePost(post.id!);
                    if (!mounted) return;
                    await _loadData();
                  },
                ),
                Text(post.likes.toString()),
              ],
            ),
            const SizedBox(height: 12),
            Text(post.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(post.message),
            if (post.location != null || post.fuelPrice != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (post.location != null)
                    Chip(
                      avatar: const Icon(Icons.place, size: 16),
                      label: Text(post.location!),
                    ),
                  if (post.fuelPrice != null)
                    Chip(
                      avatar: const Icon(Icons.local_gas_station, size: 16),
                      label: Text('₹${post.fuelPrice!.toStringAsFixed(2)}/L'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openComposer() async {
    final deviceProvider = context.read<DeviceProvider>();
    final deviceId = deviceProvider.currentDeviceId;
    if (deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please register a device first.')),
      );
      return;
    }

    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final locationController = TextEditingController();
    final priceController = TextEditingController();

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Headline'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyController,
                decoration:
                    const InputDecoration(labelText: 'What\'s the tip?'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Station / city (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                decoration:
                    const InputDecoration(labelText: 'Fuel price per liter'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  if (titleController.text.trim().isEmpty ||
                      bodyController.text.trim().isEmpty) {
                    return;
                  }
                  Navigator.pop(context, true);
                },
                icon: const Icon(Icons.send),
                label: const Text('Post'),
              ),
            ],
          ),
        );
      },
    );

    if (submitted == true) {
      double? price;
      if (priceController.text.trim().isNotEmpty) {
        price = double.tryParse(priceController.text.trim());
      }
      await _service.createPost(
        deviceId: deviceId,
        authorName: deviceProvider.currentPersonName,
        title: titleController.text.trim(),
        message: bodyController.text.trim(),
        location: locationController.text.trim().isEmpty
            ? null
            : locationController.text.trim(),
        fuelPrice: price,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shared with the community!')),
      );
      await _loadData();
    }
  }
}
