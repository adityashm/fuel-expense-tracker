import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/fuel_expense.dart';
import '../models/general_expense.dart';
import '../providers/device_provider.dart';
import '../providers/expense_provider.dart';
import '../services/smart_suggestions_service.dart';
import '../utils/app_design_system.dart';
import '../utils/haptic_helper.dart';
import '../widgets/v2_components.dart';

/// V2.5 Progressive Add Expense Screen
/// Simplified 3-step flow: Amount → Category → Details
class AddExpenseV2Screen extends StatefulWidget {
  const AddExpenseV2Screen({
    super.key,
    this.initialCategory,
    this.initialAmount,
  });
  final String? initialCategory;
  final double? initialAmount;

  @override
  State<AddExpenseV2Screen> createState() => _AddExpenseV2ScreenState();
}

class _AddExpenseV2ScreenState extends State<AddExpenseV2Screen> {
  final PageController _pageController = PageController();
  final SmartSuggestionsService _suggestions = SmartSuggestionsService.instance;

  int _currentStep = 0;
  String _amountText = '';
  String? _selectedCategory;
  String? _selectedMerchant;
  String _note = '';
  DateTime _selectedDate = DateTime.now();
  bool _isSplit = false;
  bool _isLoading = false;

  // Suggestions
  List<RecentMerchant> _recentMerchants = [];
  AmountPrediction? _amountPrediction;

  // Category data
  final List<CategoryData> _categories = [
    CategoryData(
        'Fuel', Icons.local_gas_station_rounded, AppColors.fuelExpense,),
    CategoryData('Food', Icons.restaurant_rounded, const Color(0xFFF97316)),
    CategoryData(
        'Groceries', Icons.shopping_cart_rounded, AppColors.householdExpense,),
    CategoryData(
        'Transport', Icons.directions_car_rounded, const Color(0xFF06B6D4),),
    CategoryData(
        'Shopping', Icons.shopping_bag_rounded, const Color(0xFFEC4899),),
    CategoryData(
        'Healthcare', Icons.medical_services_rounded, const Color(0xFF8B5CF6),),
    CategoryData('Entertainment', Icons.movie_rounded, const Color(0xFFF59E0B)),
    CategoryData('Utilities', Icons.bolt_rounded, AppColors.generalExpense),
    CategoryData('Education', Icons.school_rounded, const Color(0xFF3B82F6)),
    CategoryData('Other', Icons.more_horiz_rounded, const Color(0xFF94A3B8)),
  ];

  @override
  void initState() {
    super.initState();
    _loadSuggestions();

    if (widget.initialAmount != null) {
      _amountText = widget.initialAmount!.toStringAsFixed(0);
    }
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    // Load suggestions from service
    // _frequentCategories = await _suggestions.getFrequentCategories();

    if (_selectedCategory != null) {
      _recentMerchants = await _suggestions.getRecentMerchants(
        category: _selectedCategory,
      );
      _amountPrediction = await _suggestions.predictAmount(
        category: _selectedCategory!,
      );
    }

    if (mounted) setState(() {});
  }

  void _goToNextStep() {
    if (_currentStep < 2) {
      HapticHelper.lightImpact();
      _pageController.nextPage(
        duration: AppDuration.normal,
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);

      if (_currentStep == 2 && _selectedCategory != null) {
        _loadMerchantSuggestions();
      }
    }
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      HapticHelper.lightImpact();
      _pageController.previousPage(
        duration: AppDuration.normal,
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _loadMerchantSuggestions() async {
    if (_selectedCategory == null) return;

    _recentMerchants = await _suggestions.getRecentMerchants(
      category: _selectedCategory,
    );
    _amountPrediction = await _suggestions.predictAmount(
      category: _selectedCategory!,
      merchant: _selectedMerchant,
    );

    if (mounted) setState(() {});
  }

  Future<void> _saveExpense() async {
    final amount = double.tryParse(_amountText);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    if (_selectedCategory == null) {
      _showError('Please select a category');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final expenseProvider =
          Provider.of<ExpenseProvider>(context, listen: false);
      final deviceProvider =
          Provider.of<DeviceProvider>(context, listen: false);
      final deviceId = deviceProvider.currentDeviceId;

      if (deviceId == null) {
        _showError('No device selected');
        return;
      }

      // Determine if this is a fuel expense or general expense
      if (_selectedCategory == 'Fuel') {
        final expense = FuelExpense(
          deviceId: deviceId,
          vehicleId: 0, // TODO: Get selected vehicle
          date: _selectedDate,
          fuelType: FuelType.petrol,
          amountPaid: amount,
          liters: 0,
          odometerReading: 0,
          pumpName: _selectedMerchant,
          notes: _note.isEmpty ? null : _note,
        );
        await expenseProvider.createFuelExpense(expense);
      } else {
        // Convert string category to ExpenseCategory enum
        final categoryEnum = _getCategoryEnum(_selectedCategory!);
        final expense = GeneralExpense(
          deviceId: deviceId,
          date: _selectedDate,
          amount: amount,
          category: categoryEnum,
          description: _note.isEmpty ? _selectedCategory! : _note,
        );
        await expenseProvider.createGeneralExpense(expense);
      }

      HapticHelper.success();

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '₹${amount.toStringAsFixed(0)} added for $_selectedCategory',),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to save expense: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    HapticHelper.error();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
      ),
    );
  }

  ExpenseCategory _getCategoryEnum(String category) {
    switch (category.toLowerCase()) {
      case 'groceries':
        return ExpenseCategory.groceries;
      case 'utilities':
        return ExpenseCategory.utilities;
      case 'healthcare':
        return ExpenseCategory.healthcare;
      case 'education':
        return ExpenseCategory.education;
      case 'entertainment':
        return ExpenseCategory.entertainment;
      case 'shopping':
        return ExpenseCategory.shopping;
      case 'food':
        return ExpenseCategory.food;
      case 'transport':
        return ExpenseCategory.transport;
      case 'maintenance':
        return ExpenseCategory.maintenance;
      case 'insurance':
        return ExpenseCategory.insurance;
      case 'parking':
        return ExpenseCategory.parking;
      case 'tolls':
        return ExpenseCategory.tolls;
      case 'servicing':
        return ExpenseCategory.servicing;
      default:
        return ExpenseCategory.other;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            _currentStep == 0 ? Icons.close_rounded : Icons.arrow_back_rounded,
          ),
          onPressed: _goToPreviousStep,
        ),
        title: _buildStepIndicator(theme),
        centerTitle: true,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildAmountStep(theme),
          _buildCategoryStep(theme),
          _buildDetailsStep(theme),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final isActive = index <= _currentStep;
        return Container(
          width: index == _currentStep ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildAmountStep(ThemeData theme) {
    final amount = double.tryParse(_amountText) ?? 0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Text(
            'Enter Amount',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          // Amount display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '₹',
                style: theme.textTheme.displayMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w300,
                ),
              ),
              Text(
                _amountText.isEmpty ? '0' : _amountText,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: _amountText.isEmpty
                      ? theme.colorScheme.outline
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          // Amount prediction hint
          if (_amountPrediction != null && _amountPrediction!.hasData)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _amountPrediction!.suggestionText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const Spacer(),
          // Number pad
          _buildNumberPad(theme),
          const SizedBox(height: 24),
          // Continue button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: amount > 0 ? _goToNextStep : null,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberPad(ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['1', '2', '3'].map((d) => _buildNumKey(d, theme)).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['4', '5', '6'].map((d) => _buildNumKey(d, theme)).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['7', '8', '9'].map((d) => _buildNumKey(d, theme)).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumKey('.', theme),
            _buildNumKey('0', theme),
            _buildNumKey('⌫', theme, isBackspace: true),
          ],
        ),
      ],
    );
  }

  Widget _buildNumKey(String value, ThemeData theme,
      {bool isBackspace = false,}) {
    return SizedBox(
      width: 80,
      height: 64,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            if (isBackspace) {
              if (_amountText.isNotEmpty) {
                setState(() {
                  _amountText =
                      _amountText.substring(0, _amountText.length - 1);
                });
              }
            } else if (value == '.') {
              if (!_amountText.contains('.')) {
                setState(() {
                  _amountText = _amountText.isEmpty ? '0.' : '$_amountText.';
                });
              }
            } else {
              // Prevent too many digits
              if (_amountText.replaceAll('.', '').length < 8) {
                setState(() {
                  _amountText = _amountText + value;
                });
              }
            }
          },
          onLongPress: isBackspace
              ? () {
                  HapticFeedback.mediumImpact();
                  setState(() => _amountText = '');
                }
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isBackspace
                ? Icon(
                    Icons.backspace_rounded,
                    size: 28,
                    color: theme.colorScheme.onSurface,
                  )
                : Text(
                    value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What's this for?",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_amountText.isEmpty ? '0' : _amountText}',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat.name;

                return CategoryIconButtonV2(
                  category: cat.name,
                  icon: cat.icon,
                  color: cat.color,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() => _selectedCategory = cat.name);
                    _loadMerchantSuggestions();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _selectedCategory != null ? _goToNextStep : null,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Text(
                  '₹${_amountText.isEmpty ? '0' : _amountText}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '•',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 12),
                Text(
                  _selectedCategory ?? 'Category',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Merchant (optional)
          Text(
            'Merchant (optional)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // Recent merchants chips
          if (_recentMerchants.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentMerchants.map((m) {
                final isSelected = _selectedMerchant == m.name;
                return FilterChip(
                  label: Text(m.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedMerchant = selected ? m.name : null;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          TextField(
            decoration: InputDecoration(
              hintText: 'Enter merchant name',
              prefixIcon: const Icon(Icons.store_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) =>
                _selectedMerchant = value.isEmpty ? null : value,
          ),
          const SizedBox(height: 24),

          // Note (optional)
          Text(
            'Note (optional)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              hintText: 'Add a note',
              prefixIcon: const Icon(Icons.note_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 2,
            onChanged: (value) => _note = value,
          ),
          const SizedBox(height: 24),

          // Date
          Text(
            'Date & Time',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatDate(_selectedDate),
                    style: theme.textTheme.bodyLarge,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Split toggle
          SwitchListTile(
            title: Text(
              'Split with family',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Divide this expense among family members',
              style: theme.textTheme.bodySmall,
            ),
            value: _isSplit,
            onChanged: (value) => setState(() => _isSplit = value),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 32),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _saveExpense,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_isLoading ? 'Saving...' : 'Save Expense'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (picked != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );

      if (mounted) {
        setState(() {
          _selectedDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time?.hour ?? _selectedDate.hour,
            time?.minute ?? _selectedDate.minute,
          );
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    String dayPart;
    if (dateOnly == today) {
      dayPart = 'Today';
    } else if (dateOnly == today.subtract(const Duration(days: 1))) {
      dayPart = 'Yesterday';
    } else {
      dayPart = '${date.day}/${date.month}/${date.year}';
    }

    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$dayPart, $hour12:$minute $period';
  }
}

/// Category data helper
class CategoryData {
  CategoryData(this.name, this.icon, this.color);
  final String name;
  final IconData icon;
  final Color color;
}
