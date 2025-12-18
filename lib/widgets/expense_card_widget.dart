import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fuel_expense.dart';
import '../models/general_expense.dart';
import '../utils/app_design_system.dart';

class ExpenseCardWidget extends StatelessWidget {
  const ExpenseCardWidget({
    super.key,
    required this.expense,
  });

  final dynamic expense; // Can be FuelExpense or GeneralExpense

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isFuel = expense is FuelExpense;
    final String description = isFuel
        ? (expense as FuelExpense).location ?? 'Fuel Expense'
        : (expense as GeneralExpense).description;
    final double amount = isFuel
        ? (expense as FuelExpense).amountPaid
        : (expense as GeneralExpense).amount;
    final DateTime date = isFuel
        ? (expense as FuelExpense).date
        : (expense as GeneralExpense).date;
    final String category =
        isFuel ? 'Fuel' : (expense as GeneralExpense).category.name;
    final bool isHousehold =
        !isFuel && (expense as GeneralExpense).isHouseholdExpense;

    final IconData categoryIcon = _getCategoryIcon(category);
    final Color categoryColor = isFuel
        ? AppColors.fuelExpense
        : isHousehold
            ? AppColors.householdExpense
            : AppColors.generalExpense;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
          onTap: () {
            _showExpenseDetails(context);
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.spacing16),
            child: Row(
              children: [
                // Category Icon with gradient background
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        categoryColor,
                        categoryColor.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: categoryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(categoryIcon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: AppSpacing.spacing14),
                // Title, Category & Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: categoryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM dd').format(date),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Amount Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${amount.toStringAsFixed(0)}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (!isFuel &&
                        (expense as GeneralExpense).familyMemberName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              (expense as GeneralExpense).familyMemberName!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if ((!isFuel &&
                            (expense as GeneralExpense).receiptImagePath !=
                                null) ||
                        (isFuel &&
                            (expense as FuelExpense).receiptImagePath != null))
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          size: 16,
                          color: AppColors.tertiary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'fuel':
        return Icons.local_gas_station_rounded;
      case 'groceries':
        return Icons.shopping_cart_rounded;
      case 'utilities':
        return Icons.lightbulb_rounded;
      case 'healthcare':
        return Icons.local_hospital_rounded;
      case 'education':
        return Icons.school_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'transport':
        return Icons.directions_bus_rounded;
      case 'maintenance':
        return Icons.build_rounded;
      case 'insurance':
        return Icons.shield_rounded;
      case 'parking':
        return Icons.local_parking_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  void _showExpenseDetails(BuildContext context) {
    final theme = Theme.of(context);
    final bool isFuel = expense is FuelExpense;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isFuel
                            ? AppColors.fuelExpense
                            : AppColors.generalExpense)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isFuel ? Icons.local_gas_station : Icons.category,
                    color: isFuel
                        ? AppColors.fuelExpense
                        : AppColors.generalExpense,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expense Details',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isFuel
                            ? 'Fuel Expense'
                            : (expense as GeneralExpense).category.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 32),
            if (isFuel)
              ..._buildFuelDetails(expense as FuelExpense, theme)
            else
              ..._buildGeneralDetails(expense as GeneralExpense, theme),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFuelDetails(FuelExpense fuel, ThemeData theme) {
    return [
      _buildDetailRow(
          'Amount', '\$${fuel.amountPaid.toStringAsFixed(2)}', theme,),
      _buildDetailRow('Liters', '${fuel.liters.toStringAsFixed(2)} L', theme),
      _buildDetailRow(
          'Odometer', '${fuel.odometerReading.toStringAsFixed(0)} km', theme,),
      if (fuel.pumpName != null) _buildDetailRow('Pump', fuel.pumpName!, theme),
      if (fuel.location != null)
        _buildDetailRow('Location', fuel.location!, theme),
      _buildDetailRow(
          'Date', DateFormat('MMM dd, yyyy').format(fuel.date), theme,),
      if (fuel.isFullTank)
        _buildDetailRow('Fill Type', 'Full Tank ⛽', theme, highlighted: true),
      if (fuel.notes != null && fuel.notes!.isNotEmpty)
        _buildDetailRow('Notes', fuel.notes!, theme),
    ];
  }

  List<Widget> _buildGeneralDetails(GeneralExpense general, ThemeData theme) {
    return [
      _buildDetailRow(
          'Amount', '\$${general.amount.toStringAsFixed(2)}', theme,),
      _buildDetailRow('Description', general.description, theme),
      _buildDetailRow('Category', general.category.name, theme),
      _buildDetailRow(
          'Date', DateFormat('MMM dd, yyyy').format(general.date), theme,),
      if (general.isHouseholdExpense)
        _buildDetailRow('Type', 'Household Expense', theme, highlighted: true),
    ];
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme,
      {bool highlighted = false,}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: highlighted ? FontWeight.bold : FontWeight.normal,
                color: highlighted ? AppColors.success : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
