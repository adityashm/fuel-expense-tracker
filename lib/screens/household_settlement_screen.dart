import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/family_member.dart';
import '../providers/expense_provider.dart';
import '../utils/app_localizations.dart';

class HouseholdSettlementScreen extends StatefulWidget {
  const HouseholdSettlementScreen({super.key});

  @override
  State<HouseholdSettlementScreen> createState() =>
      _HouseholdSettlementScreenState();
}

class _HouseholdSettlementScreenState extends State<HouseholdSettlementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final expenseProvider =
        Provider.of<ExpenseProvider>(context, listen: false);
    await expenseProvider.loadHouseholdExpenses();
    await expenseProvider.loadFamilyMembers();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settlement & Balance'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Consumer<ExpenseProvider>(
          builder: (context, expenseProvider, child) {
            final members = expenseProvider.familyMembers;
            final expenses = expenseProvider.householdExpenses;

            if (members.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No family members yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to add family member
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Family Member'),
                    ),
                  ],
                ),
              );
            }

            // Calculate contributions per member
            final Map<int, double> memberContributions = {};
            for (final member in members) {
              memberContributions[member.id!] = expenses
                  .where((e) => e.familyMemberId == member.id)
                  .fold<double>(0, (sum, expense) => sum + expense.amount);
            }

            final totalContributions = memberContributions.values.fold<double>(
              0,
              (sum, amount) => sum + amount,
            );
            final fairShare =
                members.isEmpty ? 0.0 : totalContributions / members.length;

            // Calculate who owes whom
            final Map<int, double> balances = {};
            for (final member in members) {
              final contribution = memberContributions[member.id] ?? 0.0;
              balances[member.id!] = contribution - fairShare;
            }

            // Split into creditors and debtors
            final creditors = balances.entries
                .where((e) => e.value > 0.01)
                .toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final debtors = balances.entries
                .where((e) => e.value < -0.01)
                .toList()
              ..sort((a, b) => a.value.compareTo(b.value));

            // Calculate settlements
            final settlements = _calculateSettlements(
              creditors.map((e) => MapEntry(e.key, e.value)).toList(),
              debtors.map((e) => MapEntry(e.key, -e.value)).toList(),
              members,
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(
                    theme,
                    localizations,
                    totalContributions,
                    fairShare,
                    members.length,
                  ),
                  const SizedBox(height: 20),
                  _buildBalancesSection(
                    theme,
                    localizations,
                    members,
                    balances,
                  ),
                  const SizedBox(height: 20),
                  _buildSettlementsSection(
                    theme,
                    localizations,
                    settlements,
                    members,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    ThemeData theme,
    AppLocalizations localizations,
    double totalAmount,
    double fairShare,
    int memberCount,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.secondary,
              theme.colorScheme.secondary.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total Household Expenses',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localizations.formatCurrency(totalAmount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white38),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fair Share',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localizations.formatCurrency(fairShare),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Members',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      memberCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalancesSection(
    ThemeData theme,
    AppLocalizations localizations,
    List<FamilyMember> members,
    Map<int, double> balances,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Member Balances',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...members.map((member) {
              final balance = balances[member.id] ?? 0.0;
              final isPositive = balance > 0.01;
              final isNegative = balance < -0.01;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(member.colorHex),
                      child: Text(
                        member.avatarIcon,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPositive
                                ? 'Should receive ${localizations.formatCurrency(balance)}'
                                : isNegative
                                    ? 'Should pay ${localizations.formatCurrency(-balance)}'
                                    : 'Settled up',
                            style: TextStyle(
                              fontSize: 13,
                              color: isPositive
                                  ? Colors.green
                                  : isNegative
                                      ? Colors.red
                                      : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isPositive
                            ? Colors.green.withValues(alpha: 0.1)
                            : isNegative
                                ? Colors.red.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositive
                                ? Icons.arrow_upward
                                : isNegative
                                    ? Icons.arrow_downward
                                    : Icons.check,
                            size: 16,
                            color: isPositive
                                ? Colors.green
                                : isNegative
                                    ? Colors.red
                                    : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            localizations.formatCurrency(balance.abs()),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPositive
                                  ? Colors.green
                                  : isNegative
                                      ? Colors.red
                                      : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementsSection(
    ThemeData theme,
    AppLocalizations localizations,
    List<Settlement> settlements,
    List<FamilyMember> members,
  ) {
    if (settlements.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Colors.green[400],
              ),
              const SizedBox(height: 16),
              const Text(
                'All Settled!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Everyone has paid their fair share',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suggested Settlements (Optimized)',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Reduce number of transactions with these recommended payments:',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ...settlements.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final settlement = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _markAsSettled(settlement),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$index',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        Color(settlement.from.colorHex),
                                    child: Text(settlement.from.avatarIcon),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      settlement.from.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward, size: 18),
                                  const SizedBox(width: 8),
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        Color(settlement.to.colorHex),
                                    child: Text(settlement.to.avatarIcon),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      settlement.to.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  localizations
                                      .formatCurrency(settlement.amount),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap to record',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[600],),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _markAsSettled(settlement),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Mark Settled'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _recordPaymentFromSettlement(settlement),
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text('Record Payment'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<Settlement> _calculateSettlements(
    List<MapEntry<int, double>> creditors,
    List<MapEntry<int, double>> debtors,
    List<FamilyMember> members,
  ) {
    final settlements = <Settlement>[];
    final creditorsQueue = List<MapEntry<int, double>>.from(creditors);
    final debtorsQueue = List<MapEntry<int, double>>.from(debtors);

    while (creditorsQueue.isNotEmpty && debtorsQueue.isNotEmpty) {
      final creditor = creditorsQueue.first;
      final debtor = debtorsQueue.first;

      // Safe lookup with null handling
      final creditorMember = members.cast<FamilyMember?>().firstWhere(
            (m) => m?.id == creditor.key,
            orElse: () => null,
          );
      final debtorMember = members.cast<FamilyMember?>().firstWhere(
            (m) => m?.id == debtor.key,
            orElse: () => null,
          );

      // Skip if members not found
      if (creditorMember == null || debtorMember == null) {
        creditorsQueue.removeAt(0);
        debtorsQueue.removeAt(0);
        continue;
      }

      final amount =
          creditor.value < debtor.value ? creditor.value : debtor.value;

      settlements.add(
        Settlement(
          from: debtorMember,
          to: creditorMember,
          amount: amount,
        ),
      );

      if (creditor.value - amount < 0.01) {
        creditorsQueue.removeAt(0);
      } else {
        creditorsQueue[0] = MapEntry(creditor.key, creditor.value - amount);
      }

      if (debtor.value - amount < 0.01) {
        debtorsQueue.removeAt(0);
      } else {
        debtorsQueue[0] = MapEntry(debtor.key, debtor.value - amount);
      }
    }

    return settlements;
  }

  void _markAsSettled(Settlement settlement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Settled'),
        content: Text(
          'Mark payment from ${settlement.from.name} to ${settlement.to.name} as completed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Save settlement record to database
              try {
                // Create settlement record with timestamp (for future database implementation)
                // final settlementRecord = {
                //   'from_member_id': settlement.from.id,
                //   'to_member_id': settlement.to.id,
                //   'amount': settlement.amount,
                //   'settled_at': DateTime.now().toIso8601String(),
                //   'settled_by': 'current_user',
                // };
                // Save to database (implementation depends on your database service)
                // await DatabaseService.instance.saveSettlement(settlementRecord);

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Settlement of ${settlement.amount.toStringAsFixed(2)} saved',),
                    backgroundColor: Colors.green,
                  ),
                );
                setState(() {});
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error saving settlement: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _recordPaymentFromSettlement(Settlement settlement) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record Settlement Payment'),
        content: Text(
          'Record payment of ${settlement.amount.toStringAsFixed(2)} from ${settlement.from.name} to ${settlement.to.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment recorded (placeholder)')),
              );
            },
            icon: const Icon(Icons.check),
            label: const Text('Record Payment'),
          ),
        ],
      ),
    );
  }
}

class Settlement {
  const Settlement({
    required this.from,
    required this.to,
    required this.amount,
  });
  final FamilyMember from;
  final FamilyMember to;
  final double amount;
}
