import 'package:flutter/material.dart';
import '../models/expense_template.dart';
import '../services/template_service.dart';

class RecentExpensesQuickFill extends StatefulWidget {
  const RecentExpensesQuickFill({
    super.key,
    required this.vehicleId,
    required this.onQuickFill,
  });
  final int vehicleId;
  final Function(double amount, double? quantity, String? station) onQuickFill;

  @override
  State<RecentExpensesQuickFill> createState() =>
      _RecentExpensesQuickFillState();
}

class _RecentExpensesQuickFillState extends State<RecentExpensesQuickFill> {
  final _templateService = TemplateService.instance;
  List<RecentExpenseQuickFill> _recentExpenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentExpenses();
  }

  Future<void> _loadRecentExpenses() async {
    final expenses =
        await _templateService.getQuickFillSuggestions(widget.vehicleId);
    setState(() {
      _recentExpenses = expenses;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _recentExpenses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              'Recent amounts',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _recentExpenses
              .map((expense) => _buildQuickFillChip(expense))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildQuickFillChip(RecentExpenseQuickFill expense) {
    return ActionChip(
      label: Text(expense.getDisplayText()),
      avatar: const Icon(Icons.arrow_downward, size: 16),
      onPressed: () {
        widget.onQuickFill(
          expense.amount,
          expense.quantity,
          expense.stationName,
        );
      },
    );
  }
}

class CreateTemplateButton extends StatelessWidget {
  const CreateTemplateButton({
    super.key,
    required this.onPressed,
    this.hasExpense = false,
  });
  final VoidCallback onPressed;
  final bool hasExpense;

  @override
  Widget build(BuildContext context) {
    if (!hasExpense) return const SizedBox.shrink();

    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.bookmark_add, size: 18),
      label: const Text('Save as Template'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.blue,
      ),
    );
  }
}
