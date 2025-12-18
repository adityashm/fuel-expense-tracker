import 'package:flutter/material.dart';
import '../models/expense_model.dart';
import 'expense_card.dart';

/// Expense list widget
class ExpenseList extends StatelessWidget {
  const ExpenseList({
    super.key,
    required this.expenses,
    this.onRefresh,
  });
  final List<Expense> expenses;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return const Center(
        child: Text('No expenses'),
      );
    }

    return ListView.builder(
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        return ExpenseCard(
          expense: expenses[index],
        );
      },
    );
  }
}
