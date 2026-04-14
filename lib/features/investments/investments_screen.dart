import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _investmentsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final raw = await ApiClient.instance.getInvestments();
  return raw.cast<Map<String, dynamic>>();
});

// ── Screen ───────────────────────────────────────────────────────────────────

class InvestmentsScreen extends ConsumerWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investmentsAsync = ref.watch(_investmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Investments'),
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: investmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => _ErrorView(message: e.toString(), onRetry: () => ref.invalidate(_investmentsProvider)),
        data: (investments) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(_investmentsProvider),
          child: investments.isEmpty
              ? _EmptyView()
              : _InvestmentsList(investments: investments),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddInvestmentSheet(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Investment', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _showAddInvestmentSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddInvestmentSheet(onAdded: () => ref.invalidate(_investmentsProvider)),
    );
  }
}

// ── Summary + List ────────────────────────────────────────────────────────────

class _InvestmentsList extends StatelessWidget {
  final List<Map<String, dynamic>> investments;

  const _InvestmentsList({required this.investments});

  @override
  Widget build(BuildContext context) {
    double totalInvested = 0;
    double totalCurrent = 0;
    for (final inv in investments) {
      totalInvested += (inv['invested_amount'] as num?)?.toDouble() ?? 0;
      totalCurrent += (inv['current_value'] as num?)?.toDouble() ?? 0;
    }
    final totalGain = totalCurrent - totalInvested;
    final totalGainPct = totalInvested > 0 ? (totalGain / totalInvested) * 100 : 0.0;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _SummaryBanner(
            totalInvested: totalInvested,
            totalCurrent: totalCurrent,
            totalGain: totalGain,
            totalGainPct: totalGainPct,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _InvestmentCard(investment: investments[index]),
              childCount: investments.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Summary Banner ────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final double totalInvested;
  final double totalCurrent;
  final double totalGain;
  final double totalGainPct;

  const _SummaryBanner({
    required this.totalInvested,
    required this.totalCurrent,
    required this.totalGain,
    required this.totalGainPct,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##,##0', 'en_IN');
    final isGain = totalGain >= 0;
    final gainColor = isGain ? AppColors.success : AppColors.danger;
    final gainIcon = isGain ? Icons.trending_up_rounded : Icons.trending_down_rounded;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Portfolio Overview',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${fmt.format(totalCurrent)}',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(gainIcon, color: gainColor, size: 16),
              const SizedBox(width: 4),
              Text(
                '${isGain ? '+' : ''}₹${fmt.format(totalGain.abs())} (${totalGainPct.toStringAsFixed(1)}%)',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: gainColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Total Invested',
                  value: '₹${fmt.format(totalInvested)}',
                  color: Colors.white70,
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'Current Value',
                  value: '₹${fmt.format(totalCurrent)}',
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryMetric({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.white54)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

// ── Investment Card ───────────────────────────────────────────────────────────

class _InvestmentCard extends StatelessWidget {
  final Map<String, dynamic> investment;

  const _InvestmentCard({required this.investment});

  static const _typeColors = <String, Color>{
    'Stocks': Color(0xFF6366F1),
    'Mutual Fund': Color(0xFF0EA5E9),
    'Fixed Deposit': Color(0xFF10B981),
    'Gold': Color(0xFFF59E0B),
    'Real Estate': Color(0xFF8B5CF6),
    'Crypto': Color(0xFFEC4899),
    'Other': Color(0xFF78716C),
  };

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##,##0', 'en_IN');
    final name = investment['name'] as String? ?? 'Unknown';
    final type = investment['type'] as String? ?? 'Other';
    final invested = (investment['invested_amount'] as num?)?.toDouble() ?? 0;
    final current = (investment['current_value'] as num?)?.toDouble() ?? 0;
    final gain = current - invested;
    final gainPct = invested > 0 ? (gain / invested) * 100 : 0.0;
    final isGain = gain >= 0;
    final gainColor = isGain ? AppColors.success : AppColors.danger;
    final typeColor = _typeColors[type] ?? _typeColors['Other']!;

    String dateStr = '';
    final rawDate = investment['date'];
    if (rawDate != null) {
      try {
        final dt = DateTime.parse(rawDate.toString());
        dateStr = DateFormat('dd MMM yyyy').format(dt);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.h3.copyWith(fontSize: 15)),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(dateStr, style: AppTextStyles.label),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: typeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ValueRow(label: 'Invested', value: '₹${fmt.format(invested)}', color: AppColors.textSub),
              ),
              Expanded(
                child: _ValueRow(label: 'Current', value: '₹${fmt.format(current)}', color: AppColors.textMain),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: gainColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isGain ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      color: gainColor,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isGain ? '+' : ''}₹${fmt.format(gain.abs())}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: gainColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${isGain ? '+' : ''}${gainPct.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: gainColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ValueRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

// ── Add Investment Sheet ───────────────────────────────────────────────────────

class _AddInvestmentSheet extends StatefulWidget {
  final VoidCallback onAdded;
  const _AddInvestmentSheet({required this.onAdded});

  @override
  State<_AddInvestmentSheet> createState() => _AddInvestmentSheetState();
}

class _AddInvestmentSheetState extends State<_AddInvestmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _investedCtrl = TextEditingController();
  final _currentCtrl = TextEditingController();

  String _selectedType = 'Stocks';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _error;

  static const _types = ['Stocks', 'Mutual Fund', 'Fixed Deposit', 'Gold', 'Real Estate', 'Crypto', 'Other'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _investedCtrl.dispose();
    _currentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      await ApiClient.instance.dio.post('/investments', data: {
        'name': _nameCtrl.text.trim(),
        'type': _selectedType,
        'invested_amount': double.parse(_investedCtrl.text.trim()),
        'current_value': double.parse(_currentCtrl.text.trim()),
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      });
      if (mounted) {
        widget.onAdded();
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() { _error = 'Failed to add investment. Please try again.'; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Add Investment', style: AppTextStyles.h2),
                const SizedBox(height: 20),

                // Name
                _FieldLabel('Investment Name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'e.g. Reliance Industries'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),

                // Type
                _FieldLabel('Investment Type'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) { if (v != null) setState(() => _selectedType = v); },
                ),
                const SizedBox(height: 16),

                // Amounts row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel('Invested Amount (₹)'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _investedCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            decoration: const InputDecoration(hintText: '0.00'),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              if (double.tryParse(v.trim()) == null) return 'Invalid amount';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel('Current Value (₹)'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _currentCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            decoration: const InputDecoration(hintText: '0.00'),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              if (double.tryParse(v.trim()) == null) return 'Invalid amount';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date
                _FieldLabel('Date'),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textSub),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('dd MMM yyyy').format(_selectedDate),
                          style: AppTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: AppTextStyles.body.copyWith(color: AppColors.danger))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Investment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600));
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.trending_up_rounded, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text('No investments yet', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Text(
              'Track your stocks, mutual funds,\nand more in one place.',
              style: AppTextStyles.body.copyWith(color: AppColors.textSub),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error View ────────────────────────────────────────────────────────────────

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
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('Failed to load investments', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Text(message, style: AppTextStyles.body.copyWith(color: AppColors.textSub), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
