import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense_comment.dart';
import '../providers/expense_provider.dart';
import '../utils/app_localizations.dart';
import '../widgets/expense_comments_sheet.dart';
import 'add_general_expense_screen.dart';
import 'add_household_expense_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _fuelScrollController = ScrollController();
  final ScrollController _generalScrollController = ScrollController();
  final ScrollController _householdScrollController = ScrollController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    // Add scroll listeners for lazy loading
    _fuelScrollController.addListener(_onFuelScroll);
    _generalScrollController.addListener(_onGeneralScroll);
    _householdScrollController.addListener(_onHouseholdScroll);

    // Load expenses data if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExpensesIfNeeded();
    });
  }

  void _onFuelScroll() {
    if (!_fuelScrollController.hasClients) return;
    if (_fuelScrollController.position.pixels >=
        _fuelScrollController.position.maxScrollExtent * 0.8) {
      final expenseProvider =
          Provider.of<ExpenseProvider>(context, listen: false);
      if (!expenseProvider.isLoadingMore && expenseProvider.hasMoreData) {
        expenseProvider.loadMoreFuelExpenses();
      }
    }
  }

  void _onGeneralScroll() {
    if (!_generalScrollController.hasClients) return;
    if (_generalScrollController.position.pixels >=
        _generalScrollController.position.maxScrollExtent * 0.8) {
      final expenseProvider =
          Provider.of<ExpenseProvider>(context, listen: false);
      if (!expenseProvider.isLoadingMore && expenseProvider.hasMoreData) {
        expenseProvider.loadMoreGeneralExpenses();
      }
    }
  }

  void _onHouseholdScroll() {
    if (!_householdScrollController.hasClients) return;
    if (_householdScrollController.position.pixels >=
        _householdScrollController.position.maxScrollExtent * 0.8) {
      final expenseProvider =
          Provider.of<ExpenseProvider>(context, listen: false);
      if (!expenseProvider.isLoadingMore && expenseProvider.hasMoreData) {
        expenseProvider.loadMoreHouseholdExpenses();
      }
    }
  }

  Future<void> _loadExpensesIfNeeded() async {
    final expenseProvider =
        Provider.of<ExpenseProvider>(context, listen: false);

    // Only load if data appears empty
    if (expenseProvider.fuelExpenses.isEmpty &&
        expenseProvider.generalExpenses.isEmpty &&
        expenseProvider.householdExpenses.isEmpty) {
      await expenseProvider.loadFuelExpenses();
      await expenseProvider.loadGeneralExpenses();
      await expenseProvider.loadHouseholdExpenses();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _fuelScrollController.dispose();
    _generalScrollController.dispose();
    _householdScrollController.dispose();
    super.dispose();
  }

  Future<void> _openComments(ExpenseType type, int expenseId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ExpenseCommentsSheet(type: type, expenseId: expenseId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Stack(
      children: [
        Column(
          children: [
            // Search bar
            if (_isSearching)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search expenses...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _isSearching = false;
                          _searchController.clear();
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        setState(() {
                          _isSearching = true;
                        });
                      },
                    ),
                  ],
                ),
              ),
            // Tab bar
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: localizations.translate('fuel_expenses')),
                Tab(text: localizations.translate('general_expenses')),
                Tab(text: localizations.translate('household_expenses')),
              ],
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFuelExpensesList(),
                  _buildGeneralExpensesList(),
                  _buildHouseholdExpensesList(),
                ],
              ),
            ),
          ],
        ),
        // FAB
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => _showAddExpenseDialog(),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildFuelExpensesList() {
    final localizations = AppLocalizations.of(context);

    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, child) {
        if (expenseProvider.isFuelLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter expenses based on search query
        var filteredExpenses = expenseProvider.fuelExpenses;
        if (_searchQuery.isNotEmpty) {
          filteredExpenses = filteredExpenses.where((expense) {
            final searchIn = [
              expense.pumpName?.toLowerCase() ?? '',
              expense.location?.toLowerCase() ?? '',
              expense.fuelType.name.toLowerCase(),
              expense.amountPaid.toString(),
              expense.liters.toString(),
            ].join(' ');
            return searchIn.contains(_searchQuery);
          }).toList();
        }

        if (filteredExpenses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _searchQuery.isEmpty
                      ? Icons.local_gas_station
                      : Icons.search_off,
                  size: 80,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'No fuel expenses yet'
                      : 'No results found',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _fuelScrollController,
          padding: const EdgeInsets.all(16),
          itemCount:
              filteredExpenses.length + (expenseProvider.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            // Show loading indicator at bottom
            if (index == filteredExpenses.length) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final expense = filteredExpenses[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: expense.id == null ? Colors.grey[200] : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: expense.id == null ? Colors.grey[400] : null,
                  child: Icon(
                    Icons.local_gas_station,
                    color: expense.id == null ? Colors.grey[600] : null,
                  ),
                ),
                title: Text(
                  localizations.formatCurrency(expense.amountPaid),
                  style: expense.id == null
                      ? TextStyle(color: Colors.grey[600])
                      : null,
                ),
                subtitle: Text(
                  '${expense.liters.toStringAsFixed(2)} L - ${expense.fuelType.name}\n${localizations.formatDate(expense.date)}',
                  style: expense.id == null
                      ? TextStyle(color: Colors.grey[500])
                      : null,
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${expense.odometerReading.toStringAsFixed(0)} km',
                      style: expense.id == null
                          ? TextStyle(color: Colors.grey[600])
                          : null,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.chat_bubble_outline,
                        size: 20,
                        color: expense.id == null ? Colors.grey[400] : null,
                      ),
                      tooltip: 'Comments',
                      onPressed: expense.id == null
                          ? null
                          : () => _openComments(ExpenseType.fuel, expense.id!),
                    ),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGeneralExpensesList() {
    final localizations = AppLocalizations.of(context);

    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, child) {
        if (expenseProvider.isGeneralLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        var vehicleExpenses = expenseProvider.generalExpenses
            .where((e) => !e.isHouseholdExpense)
            .toList();

        // Filter based on search query
        if (_searchQuery.isNotEmpty) {
          vehicleExpenses = vehicleExpenses.where((expense) {
            final searchIn = [
              expense.description.toLowerCase(),
              expense.category.name.toLowerCase(),
              expense.amount.toString(),
            ].join(' ');
            return searchIn.contains(_searchQuery);
          }).toList();
        }

        if (vehicleExpenses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _searchQuery.isEmpty ? Icons.receipt : Icons.search_off,
                  size: 80,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'No general expenses yet'
                      : 'No results found',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _generalScrollController,
          padding: const EdgeInsets.all(16),
          itemCount:
              vehicleExpenses.length + (expenseProvider.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            // Show loading indicator at bottom
            if (index == vehicleExpenses.length) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final expense = vehicleExpenses[index];
            final isGrey = expense.id == null;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: isGrey ? Colors.grey[200] : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isGrey ? Colors.grey[400] : null,
                  child: Icon(
                    _getCategoryIcon(expense.category),
                    color: isGrey ? Colors.grey[600] : null,
                  ),
                ),
                title: Text(
                  localizations.formatCurrency(expense.amount),
                  style: isGrey ? TextStyle(color: Colors.grey[600]) : null,
                ),
                subtitle: Text(
                  '${localizations.translate(expense.category.name)}\n${expense.description}',
                  style: isGrey ? TextStyle(color: Colors.grey[500]) : null,
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      localizations.formatDate(expense.date),
                      style: isGrey ? TextStyle(color: Colors.grey[600]) : null,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.chat_bubble_outline,
                        size: 20,
                        color: isGrey ? Colors.grey[400] : null,
                      ),
                      tooltip: 'Comments',
                      onPressed: expense.id == null
                          ? null
                          : () =>
                              _openComments(ExpenseType.general, expense.id!),
                    ),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHouseholdExpensesList() {
    final localizations = AppLocalizations.of(context);

    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, child) {
        if (expenseProvider.isHouseholdLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        var householdExpenses = expenseProvider.householdExpenses;

        // Filter based on search query
        if (_searchQuery.isNotEmpty) {
          householdExpenses = householdExpenses.where((expense) {
            final searchIn = [
              expense.description.toLowerCase(),
              expense.category.name.toLowerCase(),
              expense.amount.toString(),
            ].join(' ');
            return searchIn.contains(_searchQuery);
          }).toList();
        }

        if (householdExpenses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _searchQuery.isEmpty ? Icons.home : Icons.search_off,
                  size: 80,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'No household expenses yet'
                      : 'No results found',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _householdScrollController,
          padding: const EdgeInsets.all(16),
          itemCount: householdExpenses.length +
              (expenseProvider.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            // Show loading indicator at bottom
            if (index == householdExpenses.length) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final expense = householdExpenses[index];
            final isGrey = expense.id == null;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: isGrey ? Colors.grey[200] : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isGrey ? Colors.grey[400] : null,
                  child: Icon(
                    _getCategoryIcon(expense.category),
                    color: isGrey ? Colors.grey[600] : null,
                  ),
                ),
                title: Text(
                  localizations.formatCurrency(expense.amount),
                  style: isGrey ? TextStyle(color: Colors.grey[600]) : null,
                ),
                subtitle: Text(
                  '${localizations.translate(expense.category.name)}\n${expense.description}',
                  style: isGrey ? TextStyle(color: Colors.grey[500]) : null,
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      localizations.formatDate(expense.date),
                      style: isGrey ? TextStyle(color: Colors.grey[600]) : null,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.chat_bubble_outline,
                        size: 20,
                        color: isGrey ? Colors.grey[400] : null,
                      ),
                      tooltip: 'Comments',
                      onPressed: expense.id == null
                          ? null
                          : () =>
                              _openComments(ExpenseType.general, expense.id!),
                    ),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  IconData _getCategoryIcon(Object category) {
    switch ((category as Map<String, dynamic>)['name'] as String) {
      case 'maintenance':
        return Icons.build;
      case 'insurance':
        return Icons.shield;
      case 'parking':
        return Icons.local_parking;
      case 'tolls':
        return Icons.toll;
      case 'servicing':
        return Icons.car_repair;
      case 'groceries':
        return Icons.shopping_cart;
      case 'utilities':
        return Icons.water_drop;
      case 'healthcare':
        return Icons.medical_services;
      case 'education':
        return Icons.school;
      case 'entertainment':
        return Icons.movie;
      case 'shopping':
        return Icons.shopping_bag;
      case 'food':
        return Icons.restaurant;
      case 'transport':
        return Icons.train;
      default:
        return Icons.category;
    }
  }

  void _showAddExpenseDialog() {
    final localizations = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: Text(localizations.translate('add_general_expense')),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddGeneralExpenseScreen(),
                  ),
                );
                if (result == true && context.mounted) {
                  final expenseProvider =
                      Provider.of<ExpenseProvider>(context, listen: false);
                  // Refresh both lists to ensure UI updates
                  await expenseProvider.loadGeneralExpenses(refresh: true);
                  await expenseProvider.loadHouseholdExpenses(refresh: true);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: Text(localizations.translate('add_household_expense')),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddHouseholdExpenseScreen(),
                  ),
                );
                if (result == true && context.mounted) {
                  final expenseProvider =
                      Provider.of<ExpenseProvider>(context, listen: false);
                  // Refresh both lists to ensure UI updates
                  await expenseProvider.loadGeneralExpenses(refresh: true);
                  await expenseProvider.loadHouseholdExpenses(refresh: true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
