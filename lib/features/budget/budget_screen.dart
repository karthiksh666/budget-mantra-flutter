import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _budgetSummaryProvider =
    FutureProvider<Map<String, dynamic>>((ref) => ApiClient.instance.getBudgetSummary());

// ── Category Colours ──────────────────────────────────────────────────────────

const _categoryColors = <String, Color>{
  'Food': Color(0xFFF97316),
  'Transport': Color(0xFF3B82F6),
  'Shopping': Color(0xFF8B5CF6),
  'Bills': Color(0xFFEF4444),
  'Health': Color(0xFF10B981),
  'Entertainment': Color(0xFF14B8A6),
  'Other': Color(0xFF9CA3AF),
};

Color _colorForCategory(String category) =>
    _categoryColors[category] ?? const Color(0xFF9CA3AF);

// ── Screen ────────────────────────────────────────────────────────────────────

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(_budgetSummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Expenses'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textMain,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(_budgetSummaryProvider),
        child: summaryAsync.when(
          data: (data) => _BudgetBody(data: data),
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          ),
          error: (err, _) => _ErrorState(
            message: err.toString().replaceFirst('Exception: ', ''),
            onRetry: () => ref.invalidate(_budgetSummaryProvider),
          ),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _BudgetBody extends StatefulWidget {
  final Map<String, dynamic> data;
  const _BudgetBody({required this.data});

  @override
  State<_BudgetBody> createState() => _BudgetBodyState();
}

class _BudgetBodyState extends State<_BudgetBody> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##,##0', 'en_IN');
    final totalIncome = (widget.data['total_income'] as num?)?.toDouble() ?? 0;
    final totalExpenses = (widget.data['total_expenses'] as num?)?.toDouble() ?? 0;
    final balance = (widget.data['balance'] as num?)?.toDouble() ?? 0;
    final rawCategories = widget.data['by_category'] as List? ?? [];
    final categories = rawCategories
        .map((e) => e as Map<String, dynamic>)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Summary cards row
        Row(
          children: [
            _SummaryCard(
              label: 'Income',
              value: '₹${fmt.format(totalIncome)}',
              icon: Icons.trending_up_rounded,
              color: AppColors.success,
            ),
            const SizedBox(width: 10),
            _SummaryCard(
              label: 'Expenses',
              value: '₹${fmt.format(totalExpenses)}',
              icon: Icons.trending_down_rounded,
              color: AppColors.danger,
            ),
            const SizedBox(width: 10),
            _SummaryCard(
              label: 'Balance',
              value: '₹${fmt.format(balance)}',
              icon: Icons.account_balance_wallet_outlined,
              color: balance >= 0 ? AppColors.success : AppColors.danger,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Donut chart card
        if (categories.isNotEmpty)
          _DonutCard(
            categories: categories,
            totalExpenses: totalExpenses,
            fmt: fmt,
            touchedIndex: _touchedIndex,
            onTouch: (i) => setState(() => _touchedIndex = i),
          ),

        if (categories.isEmpty)
          _EmptyExpenses(fmt: fmt, totalIncome: totalIncome),

        const SizedBox(height: 20),

        // Category breakdown list
        if (categories.isNotEmpty) ...[
          Text('Breakdown by Category', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          ...categories.asMap().entries.map((entry) {
            final i = entry.key;
            final cat = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CategoryRow(
                category: cat['category'] as String? ?? 'Other',
                amount: (cat['amount'] as num?)?.toDouble() ?? 0,
                percentage: (cat['percentage'] as num?)?.toDouble() ?? 0,
                fmt: fmt,
                isHighlighted: _touchedIndex == i,
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ── Donut Chart Card ──────────────────────────────────────────────────────────

class _DonutCard extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final double totalExpenses;
  final NumberFormat fmt;
  final int touchedIndex;
  final ValueChanged<int> onTouch;

  const _DonutCard({
    required this.categories,
    required this.totalExpenses,
    required this.fmt,
    required this.touchedIndex,
    required this.onTouch,
  });

  @override
  Widget build(BuildContext context) {
    final sections = categories.asMap().entries.map((entry) {
      final i = entry.key;
      final cat = entry.value;
      final category = cat['category'] as String? ?? 'Other';
      final percentage = (cat['percentage'] as num?)?.toDouble() ?? 0;
      final isTouched = touchedIndex == i;
      final color = _colorForCategory(category);

      return PieChartSectionData(
        color: color,
        value: percentage,
        radius: isTouched ? 72 : 60,
        title: isTouched ? '${percentage.toStringAsFixed(1)}%' : '',
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        badgeWidget: isTouched
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  category,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              )
            : null,
        badgePositionPercentageOffset: 1.3,
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spending Breakdown', style: AppTextStyles.h3),
          Text(
            'Tap a slice to highlight',
            style: AppTextStyles.label,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (!event.isInterestedForInteractions ||
                            response == null ||
                            response.touchedSection == null) {
                          onTouch(-1);
                          return;
                        }
                        onTouch(response.touchedSection!.touchedSectionIndex);
                      },
                    ),
                    sections: sections,
                    centerSpaceRadius: 60,
                    sectionsSpace: 2,
                    startDegreeOffset: -90,
                  ),
                ),
                // Center label
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total',
                      style: AppTextStyles.label,
                    ),
                    Text(
                      '₹${fmt.format(totalExpenses)}',
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 16,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: categories.map((cat) {
              final category = cat['category'] as String? ?? 'Other';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _colorForCategory(category),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(category, style: AppTextStyles.label),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Category Row ──────────────────────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  final String category;
  final double amount;
  final double percentage;
  final NumberFormat fmt;
  final bool isHighlighted;

  const _CategoryRow({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.fmt,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorForCategory(category);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withOpacity(0.06) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted ? color.withOpacity(0.4) : AppColors.border,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_iconForCategory(category), color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      category,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '₹${fmt.format(amount)}',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (percentage / 100).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: color.withOpacity(0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 38,
                      child: Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: AppTextStyles.label,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconForCategory(String category) {
  const icons = <String, IconData>{
    'Food': Icons.restaurant_outlined,
    'Transport': Icons.directions_car_outlined,
    'Shopping': Icons.shopping_bag_outlined,
    'Bills': Icons.receipt_outlined,
    'Health': Icons.favorite_outline,
    'Entertainment': Icons.movie_outlined,
    'Other': Icons.category_outlined,
  };
  return icons[category] ?? Icons.category_outlined;
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 8),
            Text(label, style: AppTextStyles.label),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textMain,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty Expenses ────────────────────────────────────────────────────────────

class _EmptyExpenses extends StatelessWidget {
  final NumberFormat fmt;
  final double totalIncome;

  const _EmptyExpenses({required this.fmt, required this.totalIncome});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text('No expenses recorded', style: AppTextStyles.h3),
          const SizedBox(height: 6),
          Text(
            'Your spending breakdown will appear here once you add transactions.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSub),
            textAlign: TextAlign.center,
          ),
          if (totalIncome > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Total Income: ₹${fmt.format(totalIncome)}',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Error State ────────────────────────────────────────────────────────────────

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
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text('Could not load summary', style: AppTextStyles.h3),
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
