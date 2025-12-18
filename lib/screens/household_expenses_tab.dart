import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/general_expense.dart';
import '../providers/expense_provider.dart';
import '../utils/app_localizations.dart';
import '../widgets/animated_fade_in.dart';
import '../widgets/staggered_list_item.dart';
import 'add_household_expense_screen.dart';
import 'split_bill_screen.dart';

/// Redesigned Household Expenses tab: search, category chips, date grouping, shimmer loading.
class HouseholdExpensesTab extends StatefulWidget {
  const HouseholdExpensesTab({super.key});

  @override
  State<HouseholdExpensesTab> createState() => _HouseholdExpensesTabState();
}

class _HouseholdExpensesTabState extends State<HouseholdExpensesTab> {
  final TextEditingController _searchController = TextEditingController();
  ExpenseCategory? _selectedCategory; // null = All
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ExpenseProvider>(context, listen: false)
          .loadHouseholdExpenses();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Provider.of<ExpenseProvider>(context, listen: false)
        .loadHouseholdExpenses(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, child) {
        final loading = expenseProvider.isHouseholdLoading;
        var expenses = expenseProvider.householdExpenses;

        // Filter by category
        if (_selectedCategory != null) {
          expenses =
              expenses.where((e) => e.category == _selectedCategory).toList();
        }
        // Filter by search
        final query = _searchController.text.trim().toLowerCase();
        if (query.isNotEmpty) {
          expenses = expenses.where((e) {
            final haystack =
                '${e.description.toLowerCase()} ${e.familyMemberName?.toLowerCase() ?? ''} ${e.category.name.toLowerCase()}';
            return haystack.contains(query);
          }).toList();
        }
        // Sort by date desc
        expenses.sort((a, b) => b.date.compareTo(a.date));

        // Group by date (Y-M-D)
        final Map<String, List<GeneralExpense>> grouped = {};
        for (final e in expenses) {
          final key = '${e.date.year}-${e.date.month}-${e.date.day}';
          grouped.putIfAbsent(key, () => []).add(e);
        }
        final keys = grouped.keys.toList()
          ..sort((a, b) {
            final as = a.split('-');
            final bs = b.split('-');
            final ad =
                DateTime(int.parse(as[0]), int.parse(as[1]), int.parse(as[2]));
            final bd =
                DateTime(int.parse(bs[0]), int.parse(bs[1]), int.parse(bs[2]));
            return bd.compareTo(ad);
          });

        return Scaffold(
          floatingActionButton: _buildFab(context),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(child: _buildHeader(localizations)),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(child: _buildCategoryChips(localizations)),
                if (_showSearch)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _showSearch = false;
                                _searchController.clear();
                              });
                            },
                          ),
                          hintText: 'Search household expenses',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                if (loading)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ShimmerPlaceholder(
                            height: 72, width: double.infinity,),
                      ),
                      childCount: 6,
                    ),
                  )
                else if (expenses.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          Icon(Icons.home_outlined,
                              size: 72, color: Colors.grey[500],),
                          const SizedBox(height: 12),
                          const Text('No household expenses yet'),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AddHouseholdExpenseScreen(),
                                ),
                              );
                              if (result == true && mounted) {
                                await _refresh();
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Expense'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...keys.map((key) {
                    final dateParts = key.split('-');
                    final date = DateTime(int.parse(dateParts[0]),
                        int.parse(dateParts[1]), int.parse(dateParts[2]),);
                    final dayExpenses = grouped[key]!;
                    final dayTotal =
                        dayExpenses.fold<double>(0, (sum, e) => sum + e.amount);
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  localizations.formatDate(date),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  localizations.formatCurrency(dayTotal),
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(dayExpenses.length, (i) {
                              final expense = dayExpenses[i];
                              return StaggeredListItem(
                                index: i,
                                child: Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {},
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildCategoryIcon(expense.category),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  expense.description,
                                                  style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  expense.familyMemberName !=
                                                          null
                                                      ? 'By ${expense.familyMemberName}'
                                                      : localizations.translate(
                                                          expense
                                                              .category.name,),
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],),
                                                ),
                                                if (expense.receiptImagePath !=
                                                    null) ...[
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.receipt_long,
                                                          size: 16,
                                                          color: Colors
                                                              .orange[700],),
                                                      const SizedBox(width: 4),
                                                      Text('Receipt attached',
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              color:
                                                                  Colors.orange[
                                                                      700],),),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                localizations.formatCurrency(
                                                    expense.amount,),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                _relativeTime(expense.date),
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[500],),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  }),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(AppLocalizations localizations) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Household Expenses',
              style: Theme.of(context).textTheme.titleLarge,),
          Row(
            children: [
              IconButton(
                tooltip: 'Search',
                icon: const Icon(Icons.search),
                onPressed: () => setState(() => _showSearch = !_showSearch),
              ),
              IconButton(
                tooltip: 'Split Bill',
                icon: const Icon(Icons.call_split),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SplitBillScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(AppLocalizations localizations) {
    const categories = ExpenseCategory.values;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: _selectedCategory == null,
            onSelected: (_) => setState(() => _selectedCategory = null),
          ),
          ...categories.map((c) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(localizations.translate(c.name)),
                selected: _selectedCategory == c,
                onSelected: (_) => setState(() => _selectedCategory = c),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryIcon(ExpenseCategory category) {
    IconData icon;
    switch (category) {
      case ExpenseCategory.groceries:
        icon = Icons.shopping_cart;
        break;
      case ExpenseCategory.utilities:
        icon = Icons.water_drop;
        break;
      case ExpenseCategory.healthcare:
        icon = Icons.medical_services;
        break;
      case ExpenseCategory.education:
        icon = Icons.school;
        break;
      case ExpenseCategory.entertainment:
        icon = Icons.movie;
        break;
      case ExpenseCategory.shopping:
        icon = Icons.shopping_bag;
        break;
      case ExpenseCategory.food:
        icon = Icons.restaurant;
        break;
      case ExpenseCategory.transport:
        icon = Icons.train;
        break;
      case ExpenseCategory.maintenance:
        icon = Icons.build;
        break;
      case ExpenseCategory.insurance:
        icon = Icons.shield;
        break;
      case ExpenseCategory.parking:
        icon = Icons.local_parking;
        break;
      case ExpenseCategory.tolls:
        icon = Icons.toll;
        break;
      case ExpenseCategory.servicing:
        icon = Icons.car_repair;
        break;
      default:
        icon = Icons.category;
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Theme.of(context).colorScheme.primary),
    );
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Widget _buildFab(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddHouseholdExpenseScreen()),
        );
        if (result == true && mounted) {
          await _refresh();
        }
      },
      icon: const Icon(Icons.add),
      label: const Text('Add Household Expense'),
    );
  }
}
