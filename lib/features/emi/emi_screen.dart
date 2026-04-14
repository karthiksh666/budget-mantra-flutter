import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _emisProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final raw = await ApiClient.instance.getEmis();
  return raw.cast<Map<String, dynamic>>();
});

// ── Screen ───────────────────────────────────────────────────────────────────

class EmiScreen extends ConsumerWidget {
  const EmiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emisAsync = ref.watch(_emisProvider);
    final fmt = NumberFormat('#,##,##0.00', 'en_IN');

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('EMIs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEmiSheet(context, ref),
        backgroundColor: AppColors.warning,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add EMI', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
      ),
      body: emisAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
        error: (err, _) => _ErrorView(
          message: err.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(_emisProvider),
        ),
        data: (emis) {
          if (emis.isEmpty) {
            return _EmptyView(onAdd: () => _showAddEmiSheet(context, ref));
          }

          // Sum only active EMI amounts for monthly burden
          final monthlyBurden = emis
              .where((e) => (e['status'] as String?)?.toLowerCase() == 'active')
              .fold<double>(0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0));

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(_emisProvider),
            child: CustomScrollView(
              slivers: [
                // Summary card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _BurdenCard(monthlyBurden: monthlyBurden, fmt: fmt),
                  ),
                ),

                // Status strip
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: _StatusStrip(emis: emis),
                  ),
                ),

                // List header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      '${emis.length} ${emis.length == 1 ? 'EMI' : 'EMIs'}',
                      style: AppTextStyles.label,
                    ),
                  ),
                ),

                // EMI cards
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  sliver: SliverList.separated(
                    itemCount: emis.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _EmiCard(emi: emis[i], fmt: fmt),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddEmiSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEmiSheet(onAdded: () => ref.invalidate(_emisProvider)),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _BurdenCard extends StatelessWidget {
  final double monthlyBurden;
  final NumberFormat fmt;
  const _BurdenCard({required this.monthlyBurden, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD97706), AppColors.warning],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.credit_card_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monthly EMI Burden',
                style: AppTextStyles.heroSub.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                '₹${fmt.format(monthlyBurden)}',
                style: AppTextStyles.hero.copyWith(fontSize: 28),
              ),
              Text(
                'from active EMIs only',
                style: AppTextStyles.heroSub.copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  final List<Map<String, dynamic>> emis;
  const _StatusStrip({required this.emis});

  @override
  Widget build(BuildContext context) {
    final active  = emis.where((e) => (e['status'] as String?)?.toLowerCase() == 'active').length;
    final paid    = emis.where((e) => (e['status'] as String?)?.toLowerCase() == 'paid').length;
    final overdue = emis.where((e) => (e['status'] as String?)?.toLowerCase() == 'overdue').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _StripItem(value: '$active',  label: 'Active',  color: const Color(0xFF3B82F6)),
          _Divider(),
          _StripItem(value: '$paid',    label: 'Paid',    color: AppColors.success),
          _Divider(),
          _StripItem(value: '$overdue', label: 'Overdue', color: AppColors.danger),
        ],
      ),
    );
  }
}

class _StripItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StripItem({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTextStyles.h2.copyWith(color: color, fontSize: 20)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.label.copyWith(fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: AppColors.border);
  }
}

class _EmiCard extends StatelessWidget {
  final Map<String, dynamic> emi;
  final NumberFormat fmt;
  const _EmiCard({required this.emi, required this.fmt});

  static const _blue = Color(0xFF3B82F6);

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':    return AppColors.success;
      case 'overdue': return AppColors.danger;
      default:        return _blue; // active
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'paid':    return 'Paid';
      case 'overdue': return 'Overdue';
      default:        return 'Active';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name        = (emi['name'] as String?) ?? 'EMI';
    final amount      = (emi['amount'] as num?)?.toDouble() ?? 0;
    final totalAmount = (emi['total_amount'] as num?)?.toDouble() ?? 0;
    final paidAmount  = (emi['paid_amount'] as num?)?.toDouble() ?? 0;
    final dueDate     = emi['due_date'];
    final status      = (emi['status'] as String?) ?? 'active';

    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);

    // due_date may be a day-of-month integer or a date string
    String dueDateDisplay = '';
    if (dueDate != null) {
      if (dueDate is int) {
        dueDateDisplay = 'Due on day $dueDate of month';
      } else if (dueDate is String && dueDate.isNotEmpty) {
        try {
          final d = DateTime.parse(dueDate);
          dueDateDisplay = 'Due ${DateFormat('dd MMM yyyy').format(d)}';
        } catch (_) {
          dueDateDisplay = 'Due $dueDate';
        }
      }
    }

    // Progress towards payoff
    final progress = totalAmount > 0 ? (paidAmount / totalAmount).clamp(0.0, 1.0) : 0.0;
    final hasProgress = totalAmount > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: status.toLowerCase() == 'overdue'
              ? AppColors.danger.withOpacity(0.35)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + status
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.receipt_long_rounded, color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                    if (dueDateDisplay.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 10, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            dueDateDisplay,
                            style: AppTextStyles.label.copyWith(color: AppColors.textMuted, fontSize: 10),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              _StatusBadge(label: statusLabel, color: statusColor),
            ],
          ),

          const SizedBox(height: 14),

          // Amounts row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Monthly
              _AmountChip(
                label: 'Monthly',
                value: '₹${fmt.format(amount)}',
                color: statusColor,
              ),
              if (hasProgress) ...[
                // Paid
                _AmountChip(
                  label: 'Paid',
                  value: '₹${fmt.format(paidAmount)}',
                  color: AppColors.success,
                ),
                // Total
                _AmountChip(
                  label: 'Total',
                  value: '₹${fmt.format(totalAmount)}',
                  color: AppColors.textSub,
                ),
              ],
            ],
          ),

          if (hasProgress) ...[
            const SizedBox(height: 12),
            // Payoff progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  status.toLowerCase() == 'paid' ? AppColors.success : statusColor,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(progress * 100).toStringAsFixed(0)}% paid off',
                style: AppTextStyles.label.copyWith(fontSize: 10, color: AppColors.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _AmountChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label.copyWith(fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, color: color, fontSize: 13)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(color: color, fontSize: 11),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.credit_card_rounded, color: AppColors.warning, size: 40),
            ),
            const SizedBox(height: 20),
            Text('No EMIs tracked yet', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Text(
              'Add your loan and credit EMIs to track monthly obligations.',
              style: AppTextStyles.body.copyWith(color: AppColors.textSub),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 180,
              child: ElevatedButton.icon(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  minimumSize: const Size(180, 48),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add EMI'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
            const SizedBox(height: 16),
            Text('Something went wrong', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Text(message, style: AppTextStyles.body.copyWith(color: AppColors.textSub), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: 140,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(minimumSize: const Size(140, 48)),
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add EMI Bottom Sheet ──────────────────────────────────────────────────────

class _AddEmiSheet extends StatefulWidget {
  final VoidCallback onAdded;
  const _AddEmiSheet({required this.onAdded});

  @override
  State<_AddEmiSheet> createState() => _AddEmiSheetState();
}

class _AddEmiSheetState extends State<_AddEmiSheet> {
  final _formKey       = GlobalKey<FormState>();
  final _nameCtrl      = TextEditingController();
  final _amountCtrl    = TextEditingController();
  final _totalCtrl     = TextEditingController();
  final _dueDayCtrl    = TextEditingController();

  final _amountFocus   = FocusNode();
  final _totalFocus    = FocusNode();
  final _dueDayFocus   = FocusNode();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _totalCtrl.dispose();
    _dueDayCtrl.dispose();
    _amountFocus.dispose();
    _totalFocus.dispose();
    _dueDayFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.instance.dio.post('/emis', data: {
        'name':         _nameCtrl.text.trim(),
        'amount':       double.parse(_amountCtrl.text.trim()),
        'total_amount': double.parse(_totalCtrl.text.trim()),
        'due_date':     int.parse(_dueDayCtrl.text.trim()),
      });
      widget.onAdded();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text('Add EMI', style: AppTextStyles.h2),
              const SizedBox(height: 4),
              Text(
                'Track a monthly loan or credit repayment.',
                style: AppTextStyles.body.copyWith(color: AppColors.textSub, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Name
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                onEditingComplete: () => _amountFocus.requestFocus(),
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'EMI Name *',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                  hintText: 'e.g. Home Loan, Car EMI',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name is required';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Monthly amount
              TextFormField(
                controller: _amountCtrl,
                focusNode: _amountFocus,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                textInputAction: TextInputAction.next,
                onEditingComplete: () => _totalFocus.requestFocus(),
                decoration: const InputDecoration(
                  labelText: 'Monthly Amount (₹) *',
                  prefixIcon: Icon(Icons.currency_rupee_rounded),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Monthly amount is required';
                  if (double.tryParse(v.trim()) == null) return 'Enter a valid amount';
                  if (double.parse(v.trim()) <= 0) return 'Amount must be greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Total loan amount
              TextFormField(
                controller: _totalCtrl,
                focusNode: _totalFocus,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                textInputAction: TextInputAction.next,
                onEditingComplete: () => _dueDayFocus.requestFocus(),
                decoration: const InputDecoration(
                  labelText: 'Total Loan Amount (₹) *',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                  hintText: 'Full principal amount',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Total amount is required';
                  if (double.tryParse(v.trim()) == null) return 'Enter a valid amount';
                  if (double.parse(v.trim()) <= 0) return 'Amount must be greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Due day of month
              TextFormField(
                controller: _dueDayCtrl,
                focusNode: _dueDayFocus,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
                onEditingComplete: _submit,
                decoration: const InputDecoration(
                  labelText: 'Due Day of Month (1–31) *',
                  prefixIcon: Icon(Icons.event_available_rounded),
                  hintText: 'e.g. 5 means 5th of every month',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Due day is required';
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 1 || n > 31) return 'Enter a day between 1 and 31';
                  return null;
                },
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: AppTextStyles.body.copyWith(color: AppColors.danger, fontSize: 13))),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save EMI'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
