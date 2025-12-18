import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accessibility_provider.dart';

class AccessibilitySettingsScreen extends StatelessWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accessibility'),
      ),
      body: Consumer<AccessibilityProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personalize readability',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Adjust contrast, text size, and animations to match your comfort level.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                title: const Text('High contrast mode'),
                subtitle: const Text('Boost contrast for improved legibility'),
                value: provider.highContrast,
                onChanged: provider.setHighContrast,
                secondary: const Icon(Icons.contrast),
              ),
              SwitchListTile.adaptive(
                title: const Text('Reduce motion'),
                subtitle: const Text(
                  'Disable fancy transitions to avoid motion sickness',
                ),
                value: provider.reduceMotion,
                onChanged: provider.setReduceMotion,
                secondary: const Icon(Icons.motion_photos_off),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.format_size),
                          const SizedBox(width: 8),
                          const Text('Text size'),
                          const Spacer(),
                          Text('${provider.textScale.toStringAsFixed(1)}x'),
                        ],
                      ),
                      Slider(
                        value: provider.textScale,
                        min: 0.8,
                        max: 1.6,
                        divisions: 4,
                        label: '${(provider.textScale * 100).round()}%',
                        onChanged: provider.setTextScale,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _PreviewCard(provider: provider),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  provider
                    ..setHighContrast(false)
                    ..setTextScale(1.0)
                    ..setReduceMotion(false);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reset to defaults'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.provider});
  final AccessibilityProvider provider;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Your next service is due soon. Tap to review reminders and log maintenance.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 8,
              children: [
                Chip(label: Text('High contrast')),
                Chip(label: Text('Large text')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
