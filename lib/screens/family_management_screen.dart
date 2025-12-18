import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/allowance.dart';
import '../models/family_member.dart';
import '../providers/family_member_provider.dart';
import '../services/database_service.dart';
import '../utils/app_design_system.dart';

/// Screen for managing family members and their allowances
class FamilyManagementScreen extends StatefulWidget {
  const FamilyManagementScreen({super.key});

  @override
  State<FamilyManagementScreen> createState() => _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends State<FamilyManagementScreen> {
  final Map<int, double> _totalAllowances = {};
  final Map<int, double> _totalSpending = {};
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    _loadAllStats();
  }

  Future<void> _loadAllStats() async {
    setState(() => _isLoadingStats = true);
    final provider = context.read<FamilyMemberProvider>();
    for (final member in provider.members) {
      if (member.id != null) {
        await _loadMemberStats(member.id!);
      }
    }
    setState(() => _isLoadingStats = false);
  }

  Future<void> _loadMemberStats(int memberId) async {
    final allowanceTotal =
        await DatabaseService.instance.getTotalAllowanceForMember(memberId);
    final spendingTotal =
        await DatabaseService.instance.getTotalSpendingByMember(memberId);
    setState(() {
      _totalAllowances[memberId] = allowanceTotal;
      _totalSpending[memberId] = spendingTotal;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Management'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Consumer<FamilyMemberProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.members.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.members.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.loadMembers();
              await _loadAllStats();
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.spacing16,
                vertical: AppSpacing.spacing12,
              ),
              itemCount: provider.members.length + 1,
              itemBuilder: (context, index) {
                if (index == provider.members.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.spacing8),
                    child: _buildAddMemberButton(),
                  );
                }
                final member = provider.members[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.spacing12),
                  child: _buildMemberCard(member),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.family_restroom, size: 80, color: Colors.grey[400]),
          const SizedBox(height: AppSpacing.spacing16),
          Text(
            'No Family Members',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.spacing8),
          Text(
            'Add family members to track expenses',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: AppSpacing.spacing24),
          _buildAddMemberButton(),
        ],
      ),
    );
  }

  Widget _buildAddMemberButton() {
    final provider = context.read<FamilyMemberProvider>();
    final canAdd =
        provider.members.length < FamilyMemberProvider.maxFamilyMembers;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.spacing16),
      child: OutlinedButton.icon(
        onPressed: canAdd ? () => _showAddMemberDialog() : null,
        icon: const Icon(Icons.person_add),
        label: Text(
          canAdd
              ? 'Add Family Member'
              : 'Maximum ${FamilyMemberProvider.maxFamilyMembers} members',
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(AppSpacing.spacing16),
        ),
      ),
    );
  }

  Widget _buildMemberCard(FamilyMember member) {
    final allowance = _totalAllowances[member.id] ?? 0.0;
    final spending = _totalSpending[member.id] ?? 0.0;
    final remaining = allowance - spending;
    final percentSpent = allowance > 0 ? (spending / allowance) * 100 : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.spacing16),
      child: InkWell(
        onTap: () => _showMemberDetails(member),
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        Color(member.colorHex).withValues(alpha: 0.2),
                    child: Text(
                      member.avatarIcon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.spacing16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        if (_isLoadingStats)
                          const SizedBox(
                            height: 12,
                            width: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Text(
                            remaining >= 0
                                ? 'Remaining: ₹${remaining.toStringAsFixed(0)}'
                                : 'Over budget by ₹${(-remaining).toStringAsFixed(0)}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: remaining >= 0
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'add_allowance':
                          _showAddAllowanceDialog(member);
                          break;
                        case 'edit':
                          _showEditMemberDialog(member);
                          break;
                        case 'delete':
                          _confirmDeleteMember(member);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'add_allowance',
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet),
                            SizedBox(width: 8),
                            Text('Add Allowance'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (!_isLoadingStats && allowance > 0) ...[
                const SizedBox(height: AppSpacing.spacing16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Given',
                              style: Theme.of(context).textTheme.bodySmall,),
                          Text(
                            '₹${allowance.toStringAsFixed(0)}',
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Spent',
                              style: Theme.of(context).textTheme.bodySmall,),
                          Text(
                            '₹${spending.toStringAsFixed(0)}',
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spacing8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppBorderRadius.small),
                  child: LinearProgressIndicator(
                    value: percentSpent / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percentSpent > 100
                          ? Colors.red
                          : percentSpent > 80
                              ? Colors.orange
                              : Colors.green,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${percentSpent.toStringAsFixed(1)}% used',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showMemberDetails(FamilyMember member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemberDetailScreen(member: member),
      ),
    ).then((_) => _loadMemberStats(member.id!));
  }

  void _showAddMemberDialog() {
    final nameController = TextEditingController();
    String selectedIcon = '👤';
    int selectedColor = 0xFF2196F3;

    final icons = [
      '👤',
      '👨',
      '👩',
      '👦',
      '👧',
      '👶',
      '👴',
      '👵',
      '🧑',
      '👨‍👩‍👦',
    ];
    final colors = [
      0xFF2196F3, // Blue
      0xFFF44336, // Red
      0xFF4CAF50, // Green
      0xFFFF9800, // Orange
      0xFF9C27B0, // Purple
      0xFFE91E63, // Pink
      0xFF00BCD4, // Cyan
      0xFFFFEB3B, // Yellow
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Family Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.spacing16),
                Text('Avatar', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.spacing8),
                Wrap(
                  spacing: 8,
                  children: icons.map((icon) {
                    return ChoiceChip(
                      label: Text(icon, style: const TextStyle(fontSize: 24)),
                      selected: selectedIcon == icon,
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() => selectedIcon = icon);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.spacing16),
                Text('Color', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.spacing8),
                Wrap(
                  spacing: 8,
                  children: colors.map((color) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == color
                                ? Colors.black
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a name')),
                  );
                  return;
                }

                final member = FamilyMember(
                  name: nameController.text.trim(),
                  avatarIcon: selectedIcon,
                  colorHex: selectedColor,
                );

                try {
                  await context
                      .read<FamilyMemberProvider>()
                      .createMember(member);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('${member.name} added successfully'),),
                    );
                    await _loadAllStats();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditMemberDialog(FamilyMember member) {
    final nameController = TextEditingController(text: member.name);
    String selectedIcon = member.avatarIcon;
    int selectedColor = member.colorHex;

    final icons = [
      '👤',
      '👨',
      '👩',
      '👦',
      '👧',
      '👶',
      '👴',
      '👵',
      '🧑',
      '👨‍👩‍👦',
    ];
    final colors = [
      0xFF2196F3,
      0xFFF44336,
      0xFF4CAF50,
      0xFFFF9800,
      0xFF9C27B0,
      0xFFE91E63,
      0xFF00BCD4,
      0xFFFFEB3B,
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Family Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.spacing16),
                Text('Avatar', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.spacing8),
                Wrap(
                  spacing: 8,
                  children: icons.map((icon) {
                    return ChoiceChip(
                      label: Text(icon, style: const TextStyle(fontSize: 24)),
                      selected: selectedIcon == icon,
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() => selectedIcon = icon);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.spacing16),
                Text('Color', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.spacing8),
                Wrap(
                  spacing: 8,
                  children: colors.map((color) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == color
                                ? Colors.black
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a name')),
                  );
                  return;
                }

                final updated = member.copyWith(
                  name: nameController.text.trim(),
                  avatarIcon: selectedIcon,
                  colorHex: selectedColor,
                );

                try {
                  await context
                      .read<FamilyMemberProvider>()
                      .updateMember(updated);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${updated.name} updated')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAllowanceDialog(FamilyMember member) {
    final amountController = TextEditingController();
    final givenByController = TextEditingController(text: 'Father');
    final purposeController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add Allowance for ${member.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: AppSpacing.spacing16),
                TextField(
                  controller: givenByController,
                  decoration: const InputDecoration(
                    labelText: 'Given By',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.spacing16),
                TextField(
                  controller: purposeController,
                  decoration: const InputDecoration(
                    labelText: 'Purpose (Optional)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Monthly allowance',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.spacing16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.spacing16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Date'),
                  subtitle: Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: dialogContext,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Capture messenger early to avoid ancestor lookup after widget disposal
                final messenger = ScaffoldMessenger.maybeOf(context);
                if (messenger == null) return;

                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  messenger.showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a valid amount'),),
                  );
                  return;
                }

                if (givenByController.text.trim().isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(
                        content: Text('Please enter who gave the allowance'),),
                  );
                  return;
                }

                final allowance = Allowance(
                  memberId: member.id!,
                  givenBy: givenByController.text.trim(),
                  amount: amount,
                  givenDate: selectedDate,
                  purpose: purposeController.text.trim().isEmpty
                      ? null
                      : purposeController.text.trim(),
                  notes: notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim(),
                );

                try {
                  await DatabaseService.instance.createAllowance(allowance);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text('Allowance added for ${member.name}'),),
                  );
                  await _loadMemberStats(member.id!);
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteMember(FamilyMember member) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Member'),
        content: Text(
          'Are you sure you want to delete ${member.name}? This will also delete all their allowance records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await context
                    .read<FamilyMemberProvider>()
                    .deleteMember(member.id!);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${member.name} deleted')),
                  );
                  await _loadAllStats();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Detail screen showing all allowances and expenses for a member
class MemberDetailScreen extends StatefulWidget {
  const MemberDetailScreen({super.key, required this.member});
  final FamilyMember member;

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  List<Allowance> _allowances = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllowances();
  }

  Future<void> _loadAllowances() async {
    setState(() => _isLoading = true);
    final allowances = await DatabaseService.instance
        .getAllowances(memberId: widget.member.id);
    setState(() {
      _allowances = allowances;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.member.name),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allowances.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          size: 80, color: Colors.grey[400],),
                      const SizedBox(height: AppSpacing.spacing16),
                      Text(
                        'No Allowances Yet',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.spacing8),
                      Text(
                        'Add an allowance to start tracking',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.spacing16),
                  itemCount: _allowances.length,
                  itemBuilder: (context, index) {
                    final allowance = _allowances[index];
                    return Card(
                      margin:
                          const EdgeInsets.only(bottom: AppSpacing.spacing8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: const Icon(Icons.account_balance_wallet),
                        ),
                        title: Text('₹${allowance.amount.toStringAsFixed(0)}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('From: ${allowance.givenBy}'),
                            Text(
                              '${allowance.givenDate.day}/${allowance.givenDate.month}/${allowance.givenDate.year}',
                            ),
                            if (allowance.purpose != null)
                              Text('Purpose: ${allowance.purpose}'),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDeleteAllowance(allowance),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _confirmDeleteAllowance(Allowance allowance) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Allowance'),
        content: const Text(
            'Are you sure you want to delete this allowance record?',),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await DatabaseService.instance.deleteAllowance(allowance.id!);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Allowance deleted')),
                  );
                  await _loadAllowances();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
