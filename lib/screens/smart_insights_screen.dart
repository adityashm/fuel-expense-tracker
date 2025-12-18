import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/smart_insight.dart';
import '../providers/device_provider.dart';
import '../services/insights_service.dart';

class SmartInsightsScreen extends StatefulWidget {
  const SmartInsightsScreen({super.key});

  @override
  State<SmartInsightsScreen> createState() => _SmartInsightsScreenState();
}

class _SmartInsightsScreenState extends State<SmartInsightsScreen> {
  late Future<List<SmartInsight>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final deviceId = context.read<DeviceProvider>().currentDeviceId;
    _future = InsightsService.instance.generateInsights(deviceId: deviceId);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _shareInsights(List<SmartInsight> insights) async {
    if (insights.isEmpty) return;
    final summary = insights
        .take(5)
        .map((i) => '• ${i.title} – ${i.description}')
        .join('\n');
    await Share.share(summary, subject: 'Fuel tracker insights');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                final deviceId = context.read<DeviceProvider>().currentDeviceId;
                _future = InsightsService.instance
                    .generateInsights(deviceId: deviceId);
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<SmartInsight>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load insights: ${snapshot.error}'),
            );
          }
          final insights = snapshot.data ?? [];
          if (insights.isEmpty) {
            return Center(
              child: Text(
                'Add more expenses and maintenance logs to unlock personalized recommendations.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'These AI-assisted tips look at your last 60 days of activity to highlight anomalies, reminders, and planning cues.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.ios_share),
                      onPressed: () => _shareInsights(insights),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: insights.length,
                  itemBuilder: (context, index) {
                    final insight = insights[index];
                    final config = _categoryConfig(insight.category, context);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      config.color.withValues(alpha: 0.2),
                                  child: Icon(config.icon, color: config.color),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  insight.title,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(insight.description),
                            if (insight.actionLabel != null) ...[
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () =>
                                    _handleAction(context, insight.category),
                                child: Text(insight.actionLabel!),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  _InsightDisplayConfig _categoryConfig(
    InsightCategory category,
    BuildContext context,
  ) {
    switch (category) {
      case InsightCategory.savings:
        return _InsightDisplayConfig(
          icon: Icons.savings,
          color: Colors.green.shade600,
        );
      case InsightCategory.maintenance:
        return _InsightDisplayConfig(
          icon: Icons.build,
          color: Colors.orange.shade700,
        );
      case InsightCategory.planning:
        return _InsightDisplayConfig(
          icon: Icons.calendar_month,
          color: Colors.indigo,
        );
      case InsightCategory.collaboration:
        return _InsightDisplayConfig(
          icon: Icons.groups,
          color: Colors.pinkAccent,
        );
    }
  }

  void _handleAction(BuildContext context, InsightCategory category) {
    final message = () {
      switch (category) {
        case InsightCategory.savings:
          return 'Open Budget Settings from the Settings screen to tweak monthly limits.';
        case InsightCategory.maintenance:
          return 'Visit any vehicle and tap Maintenance to log the required service.';
        case InsightCategory.planning:
          return 'Use the Trip Tracker or Reminders screen to schedule the suggested activity.';
        case InsightCategory.collaboration:
          return 'Share the insight from Collaboration tools to keep everyone informed.';
      }
    }();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _InsightDisplayConfig {
  _InsightDisplayConfig({required this.icon, required this.color});
  final IconData icon;
  final Color color;
}
