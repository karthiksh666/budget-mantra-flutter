import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _incomeProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final raw = await ApiClient.instance.getIncomeEntries();
  return raw.cast<Map<String, dynamic>>();
});

// ── Screen ───────────────────────────────────────────────────────────────────

class IncomeScreen extends ConsumerWidget {
  const IncomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomeAsync = ref.watch(_incomeProvider);
    final fmt = NumberFormat('#,##,##0.00', 'en_IN');

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Income'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddIncomeSheet(context, ref),
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Income', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
      ),
      body: incomeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
        error: (err, _) => _ErrorView(
          message: err.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(_incomeProvider),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return _EmptyView(onAdd: () => _showAddIncomeSheet(context, ref));
          }

          final total = entries.fold<double>(
            0,
            (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0),
          );

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(_incomeProvider),
            child: CustomScrollView(
              slivers: [
                // Summary card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _TotalCard(total: total, fmt: fmt),
                  ),
                ),

                // List header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}',
                      style: AppTextStyles.label,
                    ),
                  ),
                ),

                // Income entries
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  sliver: SliverList.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _IncomeCard(entry: entries[i], fmt: fmt),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddIncomeSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddIncomeSheet(onAdded: () => ref.invalidate(_incomeProvider)),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TotalCard extends StatelessWidget {
  final double total;
  final NumberFormat fmt;
  const _TotalCard({required this.total, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), AppColors.success],
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
            child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Income',
                style: AppTextStyles.heroSub.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                '₹${fmt.format(total)}',
                style: AppTextStyles.hero.copyWith(fontSize: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IncomeCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final NumberFormat fmt;
  const _IncomeCard({required this.entry, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final source = (entry['source_name'] as String?) ?? 'Unknown Source';
    final amount = (entry['amount'] as num?)?.toDouble() ?? 0;
    final note   = (entry['note'] as String?) ?? '';
    final dateRaw = (entry['date'] as String?) ?? '';

    String formattedDate = dateRaw;
    try {
      if (dateRaw.isNotEmpty) {
        final d = DateTime.parse(dateRaw);
        formattedDate = DateFormat('dd MMM yyyy').format(d);
      }
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.payments_outlined, color: AppColors.success, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(note, style: AppTextStyles.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(formattedDate, style: AppTextStyles.label.copyWith(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '+ ₹${fmt.format(amount)}',
            style: AppTextStyles.h3.copyWith(color: AppColors.success, fontSize: 15),
          ),
        ],
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
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.savings_outlined, color: AppColors.success, size: 40),
            ),
            const SizedBox(height: 20),
            Text('No income entries yet', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to record your first income source.',
              style: AppTextStyles.body.copyWith(color: AppColors.textSub),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 180,
              child: ElevatedButton.icon(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size(180, 48),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Income'),
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

// ── Add Income Bottom Sheet ───────────────────────────────────────────────────

class _AddIncomeSheet extends StatefulWidget {
  final VoidCallback onAdded;
  const _AddIncomeSheet({required this.onAdded});

  @override
  State<_AddIncomeSheet> createState() => _AddIncomeSheetState();
}

class _AddIncomeSheetState extends State<_AddIncomeSheet> {
  final _formKey     = GlobalKey<FormState>();
  final _amountCtrl  = TextEditingController();
  final _sourceCtrl  = TextEditingController();
  final _noteCtrl    = TextEditingController();
  final _dateCtrl    = TextEditingController();

  final _sourceFocus = FocusNode();
  final _noteFocus   = FocusNode();
  final _dateFocus   = FocusNode();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _sourceCtrl.dispose();
    _noteCtrl.dispose();
    _dateCtrl.dispose();
    _sourceFocus.dispose();
    _noteFocus.dispose();
    _dateFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.instance.dio.post('/income-entries', data: {
        'amount':      double.parse(_amountCtrl.text.trim()),
        'source_name': _sourceCtrl.text.trim(),
        'note':        _noteCtrl.text.trim(),
        'date':        _dateCtrl.text.trim(),
      });
      widget.onAdded();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_dateCtrl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.success),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
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
            Text('Add Income', style: AppTextStyles.h2),
            const SizedBox(height: 20),

            // Amount
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              textInputAction: TextInputAction.next,
              onEditingComplete: () => _sourceFocus.requestFocus(),
              decoration: const InputDecoration(
                labelText: 'Amount (₹) *',
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Amount is required';
                if (double.tryParse(v.trim()) == null) return 'Enter a valid amount';
                if (double.parse(v.trim()) <= 0) return 'Amount must be greater than 0';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Source name
            TextFormField(
              controller: _sourceCtrl,
              focusNode: _sourceFocus,
              textInputAction: TextInputAction.next,
              onEditingComplete: () => _noteFocus.requestFocus(),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Source Name *',
                prefixIcon: Icon(Icons.business_center_outlined),
                hintText: 'e.g. Salary, Freelance, Rental',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Source name is required';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Note (optional)
            TextFormField(
              controller: _noteCtrl,
              focusNode: _noteFocus,
              textInputAction: TextInputAction.next,
              onEditingComplete: () => _dateFocus.requestFocus(),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 14),

            // Date
            TextFormField(
              controller: _dateCtrl,
              focusNode: _dateFocus,
              textInputAction: TextInputAction.done,
              onEditingComplete: _submit,
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(
                labelText: 'Date (YYYY-MM-DD) *',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Date is required';
                if (DateTime.tryParse(v.trim()) == null) return 'Enter a valid date';
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Income'),
            ),
          ],
        ),
      ),
    );
  }
}
