import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _goalsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final raw = await ApiClient.instance.getGoals();
  return raw.cast<Map<String, dynamic>>();
});

// ── Screen ───────────────────────────────────────────────────────────────────

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(_goalsProvider);
    final fmt = NumberFormat('#,##,##0.00', 'en_IN');

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Goals'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGoalSheet(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Goal', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
        error: (err, _) => _ErrorView(
          message: err.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(_goalsProvider),
        ),
        data: (goals) {
          if (goals.isEmpty) {
            return _EmptyView(onAdd: () => _showAddGoalSheet(context, ref));
          }

          final activeCount = goals.where((g) => (g['status'] as String?) != 'completed').length;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(_goalsProvider),
            child: CustomScrollView(
              slivers: [
                // Summary strip
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _SummaryStrip(total: goals.length, active: activeCount),
                  ),
                ),

                // List header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      '${goals.length} ${goals.length == 1 ? 'goal' : 'goals'}',
                      style: AppTextStyles.label,
                    ),
                  ),
                ),

                // Goal cards
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  sliver: SliverList.separated(
                    itemCount: goals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _GoalCard(goal: goals[i], fmt: fmt),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddGoalSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddGoalSheet(onAdded: () => ref.invalidate(_goalsProvider)),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  final int total;
  final int active;
  const _SummaryStrip({required this.total, required this.active});

  @override
  Widget build(BuildContext context) {
    final completed = total - active;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _StripItem(value: '$total', label: 'Total Goals', color: AppColors.primary),
          _Divider(),
          _StripItem(value: '$active', label: 'In Progress', color: AppColors.warning),
          _Divider(),
          _StripItem(value: '$completed', label: 'Completed', color: AppColors.success),
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

class _GoalCard extends StatelessWidget {
  final Map<String, dynamic> goal;
  final NumberFormat fmt;
  const _GoalCard({required this.goal, required this.fmt});

  /// Determines the progress bar color based on deadline proximity and completion status.
  Color _progressColor(double progress, String status, String? deadline) {
    if (status == 'completed') return AppColors.textMuted;

    // Check if overdue / behind
    if (deadline != null && deadline.isNotEmpty) {
      try {
        final due = DateTime.parse(deadline);
        final now = DateTime.now();
        if (now.isAfter(due) && progress < 1.0) return AppColors.warning; // behind
      } catch (_) {}
    }
    return AppColors.success; // on track
  }

  @override
  Widget build(BuildContext context) {
    final name    = (goal['name'] as String?) ?? 'Goal';
    final target  = (goal['target_amount'] as num?)?.toDouble() ?? 0;
    final current = (goal['current_amount'] as num?)?.toDouble() ?? 0;
    final status  = (goal['status'] as String?) ?? 'active';
    final deadlineRaw = (goal['deadline'] as String?) ?? '';

    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final pct      = (progress * 100).toStringAsFixed(0);
    final barColor = _progressColor(progress, status, deadlineRaw);
    final isCompleted = status == 'completed';

    String formattedDeadline = deadlineRaw;
    try {
      if (deadlineRaw.isNotEmpty) {
        final d = DateTime.parse(deadlineRaw);
        formattedDeadline = DateFormat('dd MMM yyyy').format(d);
      }
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: barColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle_rounded : Icons.flag_rounded,
                  color: barColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                    if (deadlineRaw.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 10, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            formattedDeadline,
                            style: AppTextStyles.label.copyWith(color: AppColors.textMuted, fontSize: 10),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),

          const SizedBox(height: 16),

          // Amount row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Saved', style: AppTextStyles.label),
                  Text('₹${fmt.format(current)}', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, color: barColor)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Target', style: AppTextStyles.label),
                  Text('₹${fmt.format(target)}', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),

          const SizedBox(height: 8),

          // Percentage label
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$pct% complete',
              style: AppTextStyles.label.copyWith(color: barColor, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _color {
    switch (status.toLowerCase()) {
      case 'completed': return AppColors.success;
      case 'paused':    return AppColors.textMuted;
      default:          return AppColors.primary;
    }
  }

  String get _label {
    switch (status.toLowerCase()) {
      case 'completed': return 'Done';
      case 'paused':    return 'Paused';
      default:          return 'Active';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label,
        style: AppTextStyles.label.copyWith(color: _color, fontSize: 11),
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
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.flag_rounded, color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 20),
            Text('No savings goals yet', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Text(
              'Set a target and track your progress towards financial milestones.',
              style: AppTextStyles.body.copyWith(color: AppColors.textSub),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 180,
              child: ElevatedButton.icon(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(minimumSize: const Size(180, 48)),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Goal'),
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

// ── Add Goal Bottom Sheet ─────────────────────────────────────────────────────

class _AddGoalSheet extends StatefulWidget {
  final VoidCallback onAdded;
  const _AddGoalSheet({required this.onAdded});

  @override
  State<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<_AddGoalSheet> {
  final _formKey        = GlobalKey<FormState>();
  final _nameCtrl       = TextEditingController();
  final _targetCtrl     = TextEditingController();
  final _deadlineCtrl   = TextEditingController();

  final _targetFocus   = FocusNode();
  final _deadlineFocus = FocusNode();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _deadlineCtrl.dispose();
    _targetFocus.dispose();
    _deadlineFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.instance.dio.post('/savings-goals', data: {
        'name':          _nameCtrl.text.trim(),
        'target_amount': double.parse(_targetCtrl.text.trim()),
        'deadline':      _deadlineCtrl.text.trim(),
      });
      widget.onAdded();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _pickDeadline() async {
    final initial = DateTime.tryParse(_deadlineCtrl.text) ?? DateTime.now().add(const Duration(days: 90));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _deadlineCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
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
            Text('New Savings Goal', style: AppTextStyles.h2),
            const SizedBox(height: 20),

            // Goal name
            TextFormField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              onEditingComplete: () => _targetFocus.requestFocus(),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Goal Name *',
                prefixIcon: Icon(Icons.flag_outlined),
                hintText: 'e.g. Emergency Fund, Vacation',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Goal name is required';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Target amount
            TextFormField(
              controller: _targetCtrl,
              focusNode: _targetFocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              textInputAction: TextInputAction.next,
              onEditingComplete: () => _deadlineFocus.requestFocus(),
              decoration: const InputDecoration(
                labelText: 'Target Amount (₹) *',
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Target amount is required';
                if (double.tryParse(v.trim()) == null) return 'Enter a valid amount';
                if (double.parse(v.trim()) <= 0) return 'Amount must be greater than 0';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Deadline
            TextFormField(
              controller: _deadlineCtrl,
              focusNode: _deadlineFocus,
              textInputAction: TextInputAction.done,
              onEditingComplete: _submit,
              readOnly: true,
              onTap: _pickDeadline,
              decoration: const InputDecoration(
                labelText: 'Deadline (YYYY-MM-DD) *',
                prefixIcon: Icon(Icons.event_rounded),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Deadline is required';
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
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Create Goal'),
            ),
          ],
        ),
      ),
    );
  }
}
