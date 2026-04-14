import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';

final _summaryProvider = FutureProvider<Map<String, dynamic>>((ref) => ApiClient.instance.getBudgetSummary());
final _scoreProvider   = FutureProvider<Map<String, dynamic>>((ref) => ApiClient.instance.getFinancialScore());

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth    = ref.watch(authProvider);
    final summary = ref.watch(_summaryProvider);
    final score   = ref.watch(_scoreProvider);
    final name    = (auth.user?['name'] as String? ?? '').split(' ').first;
    final fmt     = NumberFormat('#,##,##0', 'en_IN');

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(_summaryProvider);
          ref.invalidate(_scoreProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFEA580C), AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
                padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Good ${_greeting()}, $name 👋', style: AppTextStyles.heroSub),
                            Text('Budget Mantra', style: AppTextStyles.hero.copyWith(fontSize: 22)),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => context.go('/alerts'),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    summary.when(
                      data: (d) {
                        final balance = (d['balance'] as num?)?.toDouble() ?? 0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Net Balance', style: AppTextStyles.heroSub),
                            Text('₹${fmt.format(balance)}', style: AppTextStyles.hero.copyWith(fontSize: 36)),
                          ],
                        );
                      },
                      loading: () => const SizedBox(height: 52, child: Center(child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2))),
                      error: (_, __) => Text('—', style: AppTextStyles.hero),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Summary cards
            SliverToBoxAdapter(
              child: summary.when(
                data: (d) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _SummaryCard(
                        label: 'Income',
                        value: '₹${fmt.format((d['total_income'] as num?)?.toDouble() ?? 0)}',
                        icon: Icons.trending_up_rounded,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 12),
                      _SummaryCard(
                        label: 'Expenses',
                        value: '₹${fmt.format((d['total_expenses'] as num?)?.toDouble() ?? 0)}',
                        icon: Icons.trending_down_rounded,
                        color: AppColors.danger,
                      ),
                    ],
                  ),
                ),
                loading: () => const SizedBox(height: 90, child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Financial health score
            SliverToBoxAdapter(
              child: score.when(
                data: (d) {
                  final s = (d['score'] as num?)?.toInt() ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ScoreCard(score: s),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Quick actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick Actions', style: AppTextStyles.h3),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _QuickAction(icon: Icons.add_circle_outline, label: 'Add Expense', color: AppColors.danger,  onTap: () => context.push('/transactions')),
                        const SizedBox(width: 10),
                        _QuickAction(icon: Icons.savings_outlined,   label: 'Goals',      color: AppColors.success, onTap: () => context.push('/goals')),
                        const SizedBox(width: 10),
                        _QuickAction(icon: Icons.payment_outlined,   label: 'EMIs',       color: AppColors.warning, onTap: () => context.push('/emis')),
                        const SizedBox(width: 10),
                        _QuickAction(icon: Icons.trending_up,        label: 'Invest',     color: AppColors.primary, onTap: () => context.push('/investments')),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.label),
                const SizedBox(height: 2),
                Text(value, style: AppTextStyles.h3.copyWith(fontSize: 15), overflow: TextOverflow.ellipsis),
              ],
            )),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final int score;
  const _ScoreCard({required this.score});

  Color get _color {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.danger;
  }

  String get _label {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Needs work';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 56, height: 56,
                child: CircularProgressIndicator(
                  value: score / 100,
                  backgroundColor: AppColors.border,
                  color: _color,
                  strokeWidth: 5,
                ),
              ),
              Text('$score', style: AppTextStyles.h3.copyWith(fontSize: 16, color: _color)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Financial Health', style: AppTextStyles.label),
              const SizedBox(height: 2),
              Text(_label, style: AppTextStyles.h3.copyWith(color: _color)),
              Text('Score out of 100', style: AppTextStyles.label),
            ],
          )),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label, style: AppTextStyles.label.copyWith(fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
