import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final _transactionsProvider =
    FutureProvider.family<List<dynamic>, DateTime>((ref, month) {
  return ApiClient.instance.getTransactions(
    month: month.month,
    year: month.year,
  );
});

// ── Screen ─────────────────────────────────────────────────────────────────────

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(_selectedMonthProvider);
    final txAsync = ref.watch(_transactionsProvider(selectedMonth));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textMain,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, ref, selectedMonth),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 26),
      ),
      body: Column(
        children: [
          _MonthSelector(
            selected: selectedMonth,
            onPrev: () {
              ref.read(_selectedMonthProvider.notifier).state =
                  DateTime(selectedMonth.year, selectedMonth.month - 1);
            },
            onNext: () {
              final next =
                  DateTime(selectedMonth.year, selectedMonth.month + 1);
              if (!next.isAfter(DateTime(DateTime.now().year, DateTime.now().month))) {
                ref.read(_selectedMonthProvider.notifier).state = next;
              }
            },
            isCurrentMonth: selectedMonth.year == DateTime.now().year &&
                selectedMonth.month == DateTime.now().month,
          ),
          Expanded(
            child: txAsync.when(
              data: (transactions) => _TransactionList(
                transactions: transactions,
                onDelete: (id) async {
                  await ApiClient.instance.deleteTransaction(id);
                  ref.invalidate(_transactionsProvider(selectedMonth));
                },
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
              error: (err, _) => _ErrorState(
                message: err.toString().replaceFirst('Exception: ', ''),
                onRetry: () =>
                    ref.invalidate(_transactionsProvider(selectedMonth)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSheet(
      BuildContext context, WidgetRef ref, DateTime month) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTransactionSheet(
        onSaved: () => ref.invalidate(_transactionsProvider(month)),
      ),
    );
  }
}

// ── Month Selector ─────────────────────────────────────────────────────────────

class _MonthSelector extends StatelessWidget {
  final DateTime selected;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool isCurrentMonth;

  const _MonthSelector({
    required this.selected,
    required this.onPrev,
    required this.onNext,
    required this.isCurrentMonth,
  });

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM yyyy').format(selected);
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavButton(icon: Icons.chevron_left, onTap: onPrev),
          Text(label, style: AppTextStyles.h3.copyWith(fontSize: 16)),
          _NavButton(
            icon: Icons.chevron_right,
            onTap: isCurrentMonth ? null : onNext,
            disabled: isCurrentMonth,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;

  const _NavButton({
    required this.icon,
    this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: disabled ? AppColors.border.withOpacity(0.4) : AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          size: 20,
          color: disabled ? AppColors.textMuted : AppColors.textMain,
        ),
      ),
    );
  }
}

// ── Transaction List ──────────────────────────────────────────────────────────

class _TransactionList extends StatelessWidget {
  final List<dynamic> transactions;
  final Future<void> Function(String id) onDelete;

  const _TransactionList({
    required this.transactions,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const _EmptyState();
    }

    final fmt = NumberFormat('#,##,##0', 'en_IN');

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tx = transactions[index] as Map<String, dynamic>;
        return _TransactionTile(
          transaction: tx,
          fmt: fmt,
          onDelete: () => onDelete(tx['id'].toString()),
        );
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final NumberFormat fmt;
  final VoidCallback onDelete;

  const _TransactionTile({
    required this.transaction,
    required this.fmt,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = (transaction['type'] as String?) == 'income';
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
    final category = transaction['category'] as String? ?? 'Other';
    final description = transaction['description'] as String? ?? '';
    final dateStr = transaction['date'] as String? ?? '';
    String formattedDate = '';
    try {
      formattedDate = DateFormat('dd MMM').format(DateTime.parse(dateStr));
    } catch (_) {
      formattedDate = dateStr;
    }

    return Dismissible(
      key: ValueKey(transaction['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.danger, size: 24),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Transaction'),
          content: const Text('Are you sure you want to delete this transaction?'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSub)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete', style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _CategoryIcon(category: category, isIncome: isIncome),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category,
                    style: AppTextStyles.label,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : '-'}₹${fmt.format(amount)}',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isIncome ? AppColors.success : AppColors.danger,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formattedDate,
                  style: AppTextStyles.label,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final String category;
  final bool isIncome;
  const _CategoryIcon({required this.category, required this.isIncome});

  static const _icons = <String, IconData>{
    'Food': Icons.restaurant_outlined,
    'Transport': Icons.directions_car_outlined,
    'Shopping': Icons.shopping_bag_outlined,
    'Bills': Icons.receipt_outlined,
    'Health': Icons.favorite_outline,
    'Entertainment': Icons.movie_outlined,
    'Other': Icons.category_outlined,
    'Income': Icons.trending_up_rounded,
  };

  static const _colors = <String, Color>{
    'Food': Color(0xFFF97316),
    'Transport': Color(0xFF3B82F6),
    'Shopping': Color(0xFF8B5CF6),
    'Bills': Color(0xFFEF4444),
    'Health': Color(0xFF10B981),
    'Entertainment': Color(0xFF14B8A6),
    'Other': Color(0xFF9CA3AF),
  };

  @override
  Widget build(BuildContext context) {
    final color = isIncome
        ? AppColors.success
        : (_colors[category] ?? AppColors.textMuted);
    final icon = isIncome
        ? Icons.trending_up_rounded
        : (_icons[category] ?? Icons.category_outlined);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

// ── Empty / Error States ───────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text('No transactions yet', style: AppTextStyles.h3),
          const SizedBox(height: 6),
          Text(
            'Tap + to add your first transaction',
            style: AppTextStyles.body.copyWith(color: AppColors.textSub),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('Could not load transactions', style: AppTextStyles.h3),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppTextStyles.body.copyWith(color: AppColors.textSub),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add Transaction Bottom Sheet ───────────────────────────────────────────────

class _AddTransactionSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _AddTransactionSheet({required this.onSaved});

  @override
  ConsumerState<_AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<_AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();

  final _amountFocus = FocusNode();
  final _dateFocus = FocusNode();

  String _category = 'Food';
  String _type = 'expense';
  bool _loading = false;
  String? _error;

  static const _categories = [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Health',
    'Entertainment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    _amountFocus.dispose();
    _dateFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiClient.instance.createTransaction({
        'description': _descCtrl.text.trim(),
        'amount': double.parse(_amountCtrl.text.trim()),
        'category': _category,
        'type': _type,
        'date': _dateCtrl.text.trim(),
      });
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Add Transaction', style: AppTextStyles.h2),
              const SizedBox(height: 20),

              // Type toggle
              _TypeToggle(
                selected: _type,
                onChanged: (v) => setState(() => _type = v),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descCtrl,
                textInputAction: TextInputAction.next,
                onEditingComplete: () => _amountFocus.requestFocus(),
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Description is required'
                    : null,
              ),
              const SizedBox(height: 12),

              // Amount
              TextFormField(
                controller: _amountCtrl,
                focusNode: _amountFocus,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                textInputAction: TextInputAction.next,
                onEditingComplete: () => _dateFocus.requestFocus(),
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Amount is required';
                  if (double.tryParse(v.trim()) == null) {
                    return 'Enter a valid amount';
                  }
                  if (double.parse(v.trim()) <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Category dropdown
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),

              // Date
              TextFormField(
                controller: _dateCtrl,
                focusNode: _dateFocus,
                textInputAction: TextInputAction.done,
                onEditingComplete: _submit,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'Date (YYYY-MM-DD)',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Date is required';
                  try {
                    DateTime.parse(v.trim());
                  } catch (_) {
                    return 'Use format YYYY-MM-DD';
                  }
                  return null;
                },
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save Transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Type Toggle ────────────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _TypeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _ToggleOption(
            label: 'Expense',
            icon: Icons.trending_down_rounded,
            isSelected: selected == 'expense',
            activeColor: AppColors.danger,
            onTap: () => onChanged('expense'),
          ),
          const SizedBox(width: 4),
          _ToggleOption(
            label: 'Income',
            icon: Icons.trending_up_rounded,
            isSelected: selected == 'income',
            activeColor: AppColors.success,
            onTap: () => onChanged('income'),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: activeColor.withOpacity(0.4))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: isSelected ? activeColor : AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  color: isSelected ? activeColor : AppColors.textMuted,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
