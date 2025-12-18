import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/family_member.dart';
import '../models/payment.dart';
import '../providers/device_provider.dart';
import '../providers/expense_provider.dart';

/// Screen for recording payments/settlements between members
class PaymentTrackingScreen extends StatefulWidget {
  const PaymentTrackingScreen({super.key});

  @override
  State<PaymentTrackingScreen> createState() => _PaymentTrackingScreenState();
}

class _PaymentTrackingScreenState extends State<PaymentTrackingScreen> {
  bool _isLoading = true;
  PaymentStatus? _statusFilter; // null = all
  bool _showPendingFirst = true;

  // Pagination
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  final int _itemsPerPage = 20;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ExpenseProvider>(context, listen: false)
          .loadPayments()
          .then((_) {
        if (mounted) setState(() => _isLoading = false);
      });
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMorePayments();
    }
  }

  Future<void> _loadMorePayments() async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(),
            tooltip: 'Filter',
          ),
        ],
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, child) {
          var payments = provider.payments;

          if (_statusFilter != null) {
            payments =
                payments.where((p) => p.status == _statusFilter).toList();
          }

          payments.sort((a, b) {
            if (_showPendingFirst) {
              if (a.status == PaymentStatus.pending &&
                  b.status != PaymentStatus.pending) {
                return -1;
              }
              if (b.status == PaymentStatus.pending &&
                  a.status != PaymentStatus.pending) {
                return 1;
              }
            }
            return b.paymentDate.compareTo(a.paymentDate);
          });

          if (_isLoading) {
            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: 6,
              itemBuilder: (context, index) => _buildLoadingSkeleton(theme),
            );
          }

          // Pagination: show only visible items
          final maxIndex =
              (_currentPage * _itemsPerPage).clamp(0, payments.length);
          final visiblePayments = payments.sublist(0, maxIndex);

          if (visiblePayments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payments_outlined,
                      size: 80, color: Colors.grey[400],),
                  const SizedBox(height: 16),
                  Text(
                    _statusFilter == null
                        ? 'No payments yet'
                        : 'No ${_statusFilter!.displayName.toLowerCase()} payments',
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text('Record settlements between members',
                      style: TextStyle(fontSize: 14, color: Colors.grey),),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddPaymentDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Record Payment'),
                  ),
                ],
              ),
            );
          }

          final grouped = <String, List<Payment>>{};
          for (final payment in payments) {
            final dateKey =
                '${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}';
            grouped.putIfAbsent(dateKey, () => []).add(payment);
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _isLoading = true);
              await provider.loadPayments();
              if (mounted) setState(() => _isLoading = false);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _buildHeader(
                    theme,
                    provider.payments.length,
                    provider.payments
                        .where((p) => p.status == PaymentStatus.pending)
                        .length,),
                const SizedBox(height: 12),
                ...grouped.entries.map((entry) =>
                    _buildDateGroup(theme, entry.key, entry.value, provider),),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPaymentDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Record Payment'),
      ),
    );
  }

  Widget _buildPaymentCard(
      Payment payment, ExpenseProvider provider, ThemeData theme,) {
    // Safe lookup of family members with fallback
    final fromMember = provider.familyMembers.cast<FamilyMember?>().firstWhere(
          (m) => m?.id == payment.fromMemberId,
          orElse: () => null,
        );
    final toMember = provider.familyMembers.cast<FamilyMember?>().firstWhere(
          (m) => m?.id == payment.toMemberId,
          orElse: () => null,
        );

    // Skip rendering if members not found
    if (fromMember == null || toMember == null) {
      return const SizedBox.shrink();
    }

    Color statusColor;
    switch (payment.status) {
      case PaymentStatus.completed:
        statusColor = Colors.green;
        break;
      case PaymentStatus.pending:
        statusColor = Colors.orange;
        break;
      case PaymentStatus.partial:
        statusColor = Colors.blue;
        break;
      case PaymentStatus.failed:
        statusColor = Colors.red;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showPaymentDetails(payment, fromMember, toMember),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        payment.paymentMethod.icon,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                fromMember.name,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward, size: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                toMember.name,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          payment.paymentMethod.displayName,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[700]),
                        ),
                        if (payment.notes?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            payment.notes!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${payment.amount.toStringAsFixed(0)}',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4,),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          payment.status.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: Colors.grey[700]),
                  ),
                  const Spacer(),
                  if (payment.status == PaymentStatus.pending)
                    TextButton.icon(
                      onPressed: () async {
                        final updated = payment.copyWith(
                            status: PaymentStatus.completed,
                            updatedAt: DateTime.now(),);
                        await provider.updatePayment(updated);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Marked as paid')),);
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Mark Paid'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filters', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _statusFilter == null,
                  onSelected: (_) => setState(() {
                    _statusFilter = null;
                    Navigator.pop(context);
                  }),
                ),
                ...PaymentStatus.values.map(
                  (status) => FilterChip(
                    label: Text(status.displayName),
                    selected: _statusFilter == status,
                    onSelected: (_) => setState(() {
                      _statusFilter = status;
                      Navigator.pop(context);
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Pending first'),
                const Spacer(),
                Switch(
                  value: _showPendingFirst,
                  onChanged: (v) => setState(() => _showPendingFirst = v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPaymentDialog() {
    final formKey = GlobalKey<FormState>();
    FamilyMember? fromMember;
    FamilyMember? toMember;
    final amountController = TextEditingController();
    PaymentMethod selectedMethod = PaymentMethod.cash;
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String? receiptPath;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Record Payment'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Consumer<ExpenseProvider>(
                builder: (context, provider, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // From member
                    DropdownButtonFormField<FamilyMember>(
                      initialValue: fromMember,
                      decoration: const InputDecoration(
                        labelText: 'From (Payer)',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: provider.familyMembers
                          .map(
                            (member) => DropdownMenuItem(
                              value: member,
                              child: Text(member.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => fromMember = value),
                      validator: (value) =>
                          value == null ? 'Select payer' : null,
                    ),
                    const SizedBox(height: 16),

                    // To member
                    DropdownButtonFormField<FamilyMember>(
                      initialValue: toMember,
                      decoration: const InputDecoration(
                        labelText: 'To (Receiver)',
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: provider.familyMembers
                          .where((m) => m != fromMember)
                          .map(
                            (member) => DropdownMenuItem(
                              value: member,
                              child: Text(member.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => toMember = value),
                      validator: (value) =>
                          value == null ? 'Select receiver' : null,
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    TextFormField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Payment method
                    DropdownButtonFormField<PaymentMethod>(
                      initialValue: selectedMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        prefixIcon: Icon(Icons.payment),
                      ),
                      items: PaymentMethod.values
                          .map(
                            (method) => DropdownMenuItem(
                              value: method,
                              child:
                                  Text('${method.icon} ${method.displayName}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => selectedMethod = value!),
                    ),
                    const SizedBox(height: 16),

                    // Date
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Date'),
                      subtitle: Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',),
                      trailing: const Icon(Icons.edit),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => selectedDate = date);
                        }
                      },
                    ),

                    // Notes
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Receipt upload
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final image =
                            await picker.pickImage(source: ImageSource.camera);
                        if (image != null) {
                          setState(() => receiptPath = image.path);
                        }
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: Text(receiptPath != null
                          ? 'Receipt captured'
                          : 'Capture Receipt',),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final payment = Payment(
                    id: const Uuid().v4(),
                    fromMemberId: fromMember!.id!,
                    toMemberId: toMember!.id!,
                    amount: double.parse(amountController.text),
                    paymentMethod: selectedMethod,
                    status: PaymentStatus.pending,
                    paymentDate: selectedDate,
                    notes: notesController.text.isEmpty
                        ? null
                        : notesController.text,
                    receiptPath: receiptPath,
                    deviceId:
                        Provider.of<DeviceProvider>(context, listen: false)
                            .currentDeviceId,
                    createdAt: DateTime.now(),
                  );

                  await Provider.of<ExpenseProvider>(context, listen: false)
                      .createPayment(payment);

                  if (!context.mounted) {
                    return;
                  }
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment recorded successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDetails(
      Payment payment, FamilyMember fromMember, FamilyMember toMember,) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            _detailRow('From', fromMember.name),
            _detailRow('To', toMember.name),
            _detailRow('Amount', '₹${payment.amount.toStringAsFixed(2)}'),
            _detailRow('Method', payment.paymentMethod.displayName),
            _detailRow('Status', payment.status.displayName),
            _detailRow('Date',
                '${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}',),
            if (payment.notes != null) _detailRow('Notes', payment.notes!),
            if (payment.referenceNumber != null)
              _detailRow('Reference', payment.referenceNumber!),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                if (payment.status == PaymentStatus.pending)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final updated = payment.copyWith(
                            status: PaymentStatus.completed,
                            updatedAt: DateTime.now(),);
                        await Provider.of<ExpenseProvider>(context,
                                listen: false,)
                            .updatePayment(updated);
                        if (!context.mounted) {
                          return;
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Payment marked completed'),),
                        );
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Mark Paid'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, int totalCount, int pendingCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.secondary,
            theme.colorScheme.secondary.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payments ($totalCount)',
              style: const TextStyle(color: Colors.white70),),
          const SizedBox(height: 4),
          Text('$pendingCount pending',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,),),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.payments_outlined, color: Colors.white70, size: 18),
              SizedBox(width: 8),
              Text('Track settlements between members',
                  style: TextStyle(color: Colors.white70),),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateGroup(ThemeData theme, String dateKey,
      List<Payment> payments, ExpenseProvider provider,) {
    final totalForDate = payments.fold<double>(0, (sum, p) => sum + p.amount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(dateKey,
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.grey[700],),),
            const Spacer(),
            Text('₹${totalForDate.toStringAsFixed(0)}',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: Colors.grey[600]),),
          ],
        ),
        const SizedBox(height: 8),
        ...payments.map((p) => _buildPaymentCard(p, provider, theme)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildLoadingSkeleton(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: const SizedBox(height: 100),
    );
  }
}
