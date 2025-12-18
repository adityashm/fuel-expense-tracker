import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/automation_endpoint.dart';
import '../models/integration_token.dart';
import '../providers/device_provider.dart';
import '../services/automation_service.dart';
import '../services/export_service.dart';
import '../services/integration_token_service.dart';

class IntegrationHubScreen extends StatefulWidget {
  const IntegrationHubScreen({super.key});

  @override
  State<IntegrationHubScreen> createState() => _IntegrationHubScreenState();
}

class _IntegrationHubScreenState extends State<IntegrationHubScreen> {
  bool _isExporting = false;
  bool _isLoadingEndpoints = true;
  bool _isLoadingTokens = true;
  bool _isCreatingToken = false;
  bool _isBroadcasting = false;
  String? _status;
  List<AutomationEndpoint> _endpoints = const [];
  List<IntegrationToken> _tokens = const [];

  final ExportService _exportService = ExportService.instance;
  final AutomationService _automationService = AutomationService.instance;
  final IntegrationTokenService _tokenService =
      IntegrationTokenService.instance;

  @override
  void initState() {
    super.initState();
    _loadEndpoints();
    _loadTokens();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Integration Hub'),
      ),
      floatingActionButton: deviceProvider.hasDevice
          ? FloatingActionButton.extended(
              onPressed:
                  _isLoadingEndpoints ? null : () => _showEndpointSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Add endpoint'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connect your data',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Export a structured JSON snapshot to plug into Google Sheets, automation tools, or future APIs.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_status != null)
            Card(
              color: Colors.blueGrey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_status!),
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.copy),
            label: const Text('Copy JSON snapshot'),
            onPressed: _isExporting
                ? null
                : () => _handleExport(copyToClipboard: true),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.ios_share),
            label: const Text('Share JSON file'),
            onPressed: _isExporting
                ? null
                : () => _handleExport(copyToClipboard: false),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 24),
          _buildAutomationCard(),
          const SizedBox(height: 24),
          _buildTokenCard(deviceProvider.hasDevice),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.table_chart, color: Colors.green),
            title: const Text('Google Sheets'),
            subtitle:
                const Text('Use JSON as input for Apps Script to sync data'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showInfoDialog(
              'Google Sheets integration',
              '1. Copy the JSON snapshot.\n2. Paste it into a Google Apps Script project.\n3. Parse JSON and write rows into your sheet.\n4. Schedule the script to run periodically.',
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.directions_car_filled_outlined,
              color: Colors.orange,
            ),
            title: const Text('Android Auto / Car dashboards'),
            subtitle: const Text('Feed aggregated stats to custom dashboards'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showInfoDialog(
              'Dashboard integration',
              'Use the JSON snapshot with tools like Android Auto Custom Dashboards or Raspberry Pi dashboards to show live KPIs while driving.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.api, color: Colors.blue),
            title: const Text('Webhook automation'),
            subtitle: const Text('Post JSON to Zapier, Make, or custom APIs'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showInfoDialog(
              'Automation tips',
              'Combine the export with Tasker/Shortcuts to automatically POST your expenses to any REST API.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenCard(bool hasDevice) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.vpn_key_outlined, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Integration tokens',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Generate secret keys for CLI scripts or self-hosted dashboards.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  icon: _isCreatingToken
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: const Text('New token'),
                  onPressed: (!hasDevice || _isCreatingToken)
                      ? null
                      : _showCreateTokenSheet,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasDevice)
              const Text(
                'Set up a driver profile to issue tokens for automation jobs.',
              )
            else if (_isLoadingTokens)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_tokens.isEmpty)
              const Column(
                children: [
                  Icon(Icons.lock_open, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('No tokens yet.'),
                  Text(
                    'Generate a personal access token for secure API usage.',
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            else
              ..._tokens.map(_buildTokenTile),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenTile(IntegrationToken token) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(token.label),
            subtitle: Text(_buildTokenSubtitle(token)),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'copy':
                    _copyToken(token);
                    break;
                  case 'reveal':
                    _showTokenRevealSheet(token);
                    break;
                  case 'rename':
                    _showRenameTokenDialog(token);
                    break;
                  case 'delete':
                    _confirmDeleteToken(token);
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'copy', child: Text('Copy token')),
                PopupMenuItem(
                  value: 'reveal',
                  child: Text('Reveal full token'),
                ),
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Revoke')),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _maskToken(token.token),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy token',
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyToken(token),
                ),
                IconButton(
                  tooltip: 'Reveal full token',
                  icon: const Icon(Icons.visibility),
                  onPressed: () => _showTokenRevealSheet(token),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
        ],
      ),
    );
  }

  String _buildTokenSubtitle(IntegrationToken token) {
    final created = _formatTimestamp(token.createdAt);
    final lastUsed =
        token.lastUsed != null ? _formatTimestamp(token.lastUsed!) : 'never';
    return 'Created $created • Last used $lastUsed';
  }

  String _maskToken(String token) {
    if (token.length <= 12) return token;
    final prefix = token.substring(0, 6);
    final suffix = token.substring(token.length - 4);
    return '$prefix••••$suffix';
  }

  Future<void> _loadTokens() async {
    final deviceId = await _requireDeviceId();
    if (deviceId == null) {
      if (mounted) {
        setState(() {
          _tokens = const [];
          _isLoadingTokens = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isLoadingTokens = true);

    try {
      final tokens = await _tokenService.fetchTokens(deviceId);
      if (mounted) {
        setState(() {
          _tokens = tokens;
          _isLoadingTokens = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Failed to load tokens: $e';
          _isLoadingTokens = false;
        });
      }
    }
  }

  Future<void> _showCreateTokenSheet() async {
    final deviceId = await _requireDeviceId();
    if (deviceId == null) return;

    final labelController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    if (!mounted) return;
    final label = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generate integration token',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    hintText: 'Production server',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a label'
                      : null,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState?.validate() ?? false) {
                          Navigator.pop(context, labelController.text.trim());
                        }
                      },
                      child: const Text('Generate'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    labelController.dispose();
    if (label == null || label.trim().isEmpty) {
      return;
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isCreatingToken = true);
    try {
      final token = await _tokenService.createToken(
        deviceId: deviceId,
        label: label.trim(),
      );
      await _loadTokens();
      if (!mounted) return;
      await _showTokenRevealSheet(token);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Token "${token.label}" generated.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not create token: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingToken = false);
      }
    }
  }

  Future<void> _showTokenRevealSheet(IntegrationToken token) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
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
                'Token for ${token.label}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SelectableText(
                token.token,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _copyToken(token),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy token'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _copyToken(IntegrationToken token) async {
    await Clipboard.setData(ClipboardData(text: token.token));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Token "${token.label}" copied.')),
    );
  }

  Future<void> _showRenameTokenDialog(IntegrationToken token) async {
    if (token.id == null) return;
    final controller = TextEditingController(text: token.label);
    final newLabel = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename token'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Label'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newLabel == null || newLabel.isEmpty || newLabel == token.label) {
      return;
    }

    try {
      await _tokenService.renameToken(token.id!, newLabel);
      await _loadTokens();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Token renamed to "$newLabel".')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rename failed: $e')),
      );
    }
  }

  Future<void> _confirmDeleteToken(IntegrationToken token) async {
    if (token.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke token'),
        content: Text('Revoke access for "${token.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _tokenService.deleteToken(token.id!);
      await _loadTokens();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Token "${token.label}" revoked.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to revoke token: $e')),
      );
    }
  }

  Future<void> _handleExport({required bool copyToClipboard}) async {
    setState(() {
      _isExporting = true;
      _status = 'Preparing snapshot...';
    });

    try {
      final payload = await _exportService.buildJsonSnapshot();
      if (copyToClipboard) {
        await Clipboard.setData(ClipboardData(text: payload));
        if (mounted) {
          setState(
            () => _status = 'JSON copied to clipboard. Paste it where needed.',
          );
        }
      } else {
        await Share.share(payload, subject: 'Fuel tracker export');
        if (mounted) {
          setState(() => _status = 'Shared via system sheet.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Export failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAutomationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Automation endpoints',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  tooltip: 'Manual broadcast',
                  onPressed: _isBroadcasting ? null : _broadcastAll,
                  icon: _isBroadcasting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Automatically POST your snapshot to Zapier, Make, Slack, or any webhook.',
            ),
            const SizedBox(height: 16),
            if (_isLoadingEndpoints)
              const Center(child: CircularProgressIndicator())
            else if (_endpoints.isEmpty)
              const Column(
                children: [
                  Icon(Icons.hub_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('No automation endpoints yet.'),
                  Text(
                    'Tap "Add endpoint" to connect your favorite tools.',
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            else
              ..._endpoints.map((endpoint) => _buildEndpointTile(endpoint)),
          ],
        ),
      ),
    );
  }

  Widget _buildEndpointTile(AutomationEndpoint endpoint) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(endpoint.name),
          subtitle:
              Text(endpoint.url, maxLines: 1, overflow: TextOverflow.ellipsis),
          leading: Switch(
            value: endpoint.isEnabled,
            onChanged: (value) => _toggleEndpoint(endpoint, value),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'send':
                  _triggerEndpoint(endpoint);
                  break;
                case 'edit':
                  _showEndpointSheet(existing: endpoint);
                  break;
                case 'delete':
                  _deleteEndpoint(endpoint);
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'send', child: Text('Send sample payload')),
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ),
        if (endpoint.lastTriggered != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Last triggered ${_formatTimestamp(endpoint.lastTriggered!)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        const Divider(),
      ],
    );
  }

  Future<void> _loadEndpoints() async {
    final deviceId = await _requireDeviceId();
    if (deviceId == null) {
      if (mounted) {
        setState(() => _isLoadingEndpoints = false);
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingEndpoints = true;
    });

    try {
      final endpoints = await _automationService.fetchEndpoints(deviceId);
      if (mounted) {
        setState(() {
          _endpoints = endpoints;
          _isLoadingEndpoints = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Failed to load endpoints: $e';
          _isLoadingEndpoints = false;
        });
      }
    }
  }

  Future<void> _toggleEndpoint(
    AutomationEndpoint endpoint,
    bool enabled,
  ) async {
    await _automationService.toggleEndpoint(endpoint, enabled);
    if (!mounted) return;
    setState(() {
      _endpoints = _endpoints
          .map(
            (item) => item.id == endpoint.id
                ? endpoint.copyWith(isEnabled: enabled)
                : item,
          )
          .toList();
    });
  }

  Future<void> _triggerEndpoint(AutomationEndpoint endpoint) async {
    try {
      setState(() => _status = 'Sending sample payload to ${endpoint.name}');
      await _automationService.triggerEndpoint(endpoint);
      await _loadEndpoints();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sent payload to ${endpoint.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  Future<void> _deleteEndpoint(AutomationEndpoint endpoint) async {
    await _automationService.deleteEndpoint(endpoint.id!);
    if (!mounted) return;
    setState(() {
      _endpoints = _endpoints.where((item) => item.id != endpoint.id).toList();
    });
  }

  Future<void> _showEndpointSheet({AutomationEndpoint? existing}) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final nameController =
            TextEditingController(text: existing?.name ?? '');
        final urlController = TextEditingController(text: existing?.url ?? '');
        final headersController = TextEditingController(
          text: _headersToText(existing?.headers ?? {}),
        );
        final formKey = GlobalKey<FormState>();

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  existing == null
                      ? 'Add automation endpoint'
                      : 'Edit endpoint',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Zapier, Slack, etc.',
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Enter a name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: urlController,
                  decoration: const InputDecoration(labelText: 'Webhook URL'),
                  validator: (value) =>
                      value == null || !value.startsWith('http')
                          ? 'Enter a valid URL'
                          : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: headersController,
                  decoration: const InputDecoration(
                    labelText: 'Headers',
                    hintText: 'Authorization: Bearer token',
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState?.validate() ?? false) {
                          Navigator.pop<Map<String, String>>(context, {
                            'name': nameController.text.trim(),
                            'url': urlController.text.trim(),
                            'headers': headersController.text.trim(),
                          });
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null) return;
    final deviceId = await _requireDeviceId();
    if (deviceId == null) return;

    final headers = _headersFromText(result['headers'] ?? '');

    if (existing == null) {
      final created = await _automationService.createEndpoint(
        deviceId: deviceId,
        name: result['name']!,
        url: result['url']!,
        headers: headers,
      );
      if (!mounted) return;
      setState(() {
        _endpoints = [created, ..._endpoints];
      });
    } else {
      final updated = existing.copyWith(
        name: result['name'],
        url: result['url'],
        headers: headers,
      );
      await _automationService.updateEndpoint(updated);
      if (!mounted) return;
      setState(() {
        _endpoints = _endpoints
            .map((item) => item.id == existing.id ? updated : item)
            .toList();
      });
    }
  }

  Future<void> _broadcastAll() async {
    final deviceId = await _requireDeviceId();
    if (deviceId == null) return;

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isBroadcasting = true);
    final deviceProvider = context.read<DeviceProvider>();
    try {
      await _automationService.broadcastToAll(deviceProvider);
      await _loadEndpoints();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Broadcast sent to all enabled endpoints'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Broadcast failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isBroadcasting = false);
      }
    }
  }

  Future<String?> _requireDeviceId() async {
    final provider = context.read<DeviceProvider>();
    final activeId = provider.currentDeviceId;
    if (activeId == null) {
      if (mounted) {
        setState(
          () => _status =
              'No active device found. Set up a profile in onboarding.',
        );
      }
      return null;
    }
    return activeId;
  }

  Map<String, String> _headersFromText(String raw) {
    final lines = raw.split('\n');
    final headers = <String, String>{};
    for (final line in lines) {
      if (line.contains(':')) {
        final key = line.substring(0, line.indexOf(':')).trim();
        final value = line.substring(line.indexOf(':') + 1).trim();
        if (key.isNotEmpty) {
          headers[key] = value;
        }
      }
    }
    return headers;
  }

  String _headersToText(Map<String, String> headers) {
    if (headers.isEmpty) return '';
    return headers.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    return '${timestamp.year}-$month-$day';
  }
}
