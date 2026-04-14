import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final name = (auth.user?['name'] as String? ?? '').trim();
    final email = (auth.user?['email'] as String? ?? '').trim();
    final avatarLetter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────────
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
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 20,
                20,
                28,
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white38, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      avatarLetter,
                      style: AppTextStyles.h2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty ? name : 'User',
                          style: AppTextStyles.h3.copyWith(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: AppTextStyles.heroSub,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // ── Manage section ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'Manage'),
                  const SizedBox(height: 8),
                  _MenuGroup(
                    items: [
                      _MenuItem(
                        icon: Icons.trending_up_outlined,
                        label: 'Income',
                        color: AppColors.success,
                        onTap: () => context.push('/income'),
                      ),
                      _MenuItem(
                        icon: Icons.receipt_long_outlined,
                        label: 'Transactions',
                        color: const Color(0xFF3B82F6), // blue
                        onTap: () => context.push('/transactions'),
                      ),
                      _MenuItem(
                        icon: Icons.savings_outlined,
                        label: 'Goals',
                        color: AppColors.primary,
                        onTap: () => context.push('/goals'),
                      ),
                      _MenuItem(
                        icon: Icons.payment_outlined,
                        label: 'EMIs',
                        color: const Color(0xFF8B5CF6), // purple
                        onTap: () => context.push('/emis'),
                      ),
                      _MenuItem(
                        icon: Icons.show_chart_outlined,
                        label: 'Investments',
                        color: const Color(0xFF14B8A6), // teal
                        onTap: () => context.push('/investments'),
                        isLast: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Preferences section ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'Preferences'),
                  const SizedBox(height: 8),
                  _MenuGroup(
                    items: [
                      _MenuItem(
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        color: AppColors.primary,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Coming soon'),
                              backgroundColor: AppColors.textMain,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        isLast: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Account section ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'Account'),
                  const SizedBox(height: 8),
                  _MenuGroup(
                    items: [
                      _MenuItem(
                        icon: Icons.logout_outlined,
                        label: 'Sign Out',
                        color: AppColors.danger,
                        onTap: () => _confirmSignOut(context, ref),
                        isLast: true,
                        isDestructive: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom padding for nav bar clearance
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.surface,
        title: Text('Sign out?', style: AppTextStyles.h3),
        content: Text(
          'You will be returned to the login screen.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: AppTextStyles.body.copyWith(color: AppColors.textSub),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(authProvider.notifier).logout();
            },
            child: Text(
              'Sign Out',
              style: AppTextStyles.body.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.label.copyWith(
          fontSize: 11,
          letterSpacing: 0.8,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

// ── Menu group (card container) ────────────────────────────────────────────────

class _MenuGroup extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: items,
      ),
    );
  }
}

// ── Individual menu item ───────────────────────────────────────────────────────

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isLast;
  final bool isDestructive;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLast = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(16),
            bottom: isLast ? const Radius.circular(16) : Radius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                // Icon badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                // Label
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? AppColors.danger : AppColors.textMain,
                    ),
                  ),
                ),
                // Chevron
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDestructive ? AppColors.danger.withOpacity(0.6) : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            thickness: 1,
            indent: 68,
            endIndent: 0,
            color: AppColors.border,
          ),
      ],
    );
  }
}
