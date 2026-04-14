import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _notificationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final raw = await ApiClient.instance.getUnreadNotifications();
  return raw.cast<Map<String, dynamic>>();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // Locally track which notification IDs have been read this session so the
  // UI can update immediately without waiting for a refetch.
  final Set<String> _locallyRead = {};
  bool _markingAll = false;

  Future<void> _markRead(String id) async {
    setState(() => _locallyRead.add(id));
    try {
      await ApiClient.instance.dio.patch('/notifications/$id/read');
    } catch (_) {
      // Silently revert optimistic update on failure
      if (mounted) setState(() => _locallyRead.remove(id));
    }
  }

  Future<void> _markAllRead(List<Map<String, dynamic>> notifications) async {
    setState(() => _markingAll = true);
    final unread = notifications.where((n) {
      final id = n['id']?.toString() ?? '';
      return !(n['read'] as bool? ?? false) && !_locallyRead.contains(id);
    }).toList();

    for (final n in unread) {
      final id = n['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      setState(() => _locallyRead.add(id));
      try {
        await ApiClient.instance.dio.patch('/notifications/$id/read');
      } catch (_) {}
    }
    if (mounted) setState(() => _markingAll = false);
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(_notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Alerts'),
        automaticallyImplyLeading: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
        actions: [
          notificationsAsync.whenOrNull(
            data: (notifications) {
              final hasUnread = notifications.any((n) {
                final id = n['id']?.toString() ?? '';
                return !(n['read'] as bool? ?? false) && !_locallyRead.contains(id);
              });
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: _markingAll ? null : () => _markAllRead(notifications),
                child: _markingAll
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Text(
                        'Mark all read',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          fontSize: 13,
                        ),
                      ),
              );
            },
          ) ?? const SizedBox.shrink(),
          const SizedBox(width: 4),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => _ErrorView(onRetry: () => ref.invalidate(_notificationsProvider)),
        data: (notifications) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            _locallyRead.clear();
            ref.invalidate(_notificationsProvider);
          },
          child: notifications.isEmpty
              ? _EmptyView()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    final id = n['id']?.toString() ?? '';
                    final isRead = (n['read'] as bool? ?? false) || _locallyRead.contains(id);
                    return _NotificationCard(
                      notification: n,
                      isRead: isRead,
                      onTap: isRead ? null : () => _markRead(id),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

// ── Notification Card ─────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final bool isRead;
  final VoidCallback? onTap;

  const _NotificationCard({
    required this.notification,
    required this.isRead,
    required this.onTap,
  });

  static const _typeConfig = <String, _TypeConfig>{
    'budget_alert':    _TypeConfig(Icons.warning_amber_rounded, Color(0xFFF97316)),
    'emi_reminder':    _TypeConfig(Icons.payment_rounded,        Color(0xFF0EA5E9)),
    'goal_alert':      _TypeConfig(Icons.savings_rounded,        Color(0xFF10B981)),
    'monthly_summary': _TypeConfig(Icons.calendar_month_rounded, Color(0xFF8B5CF6)),
    'weekly_digest':   _TypeConfig(Icons.bar_chart_rounded,      Color(0xFF14B8A6)),
    'general':         _TypeConfig(Icons.info_outline_rounded,   Color(0xFF78716C)),
  };

  @override
  Widget build(BuildContext context) {
    final type = notification['type'] as String? ?? 'general';
    final title = notification['title'] as String? ?? '';
    final message = notification['message'] as String? ?? '';
    final createdAt = notification['created_at'];
    final config = _typeConfig[type] ?? _typeConfig['general']!;
    final timeStr = createdAt != null ? _relativeTime(createdAt.toString()) : '';

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? AppColors.surface : config.color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead ? AppColors.border : config.color.withOpacity(0.25),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: config.color.withOpacity(isRead ? 0.08 : 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(config.icon, color: config.color.withOpacity(isRead ? 0.5 : 1.0), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                            color: isRead ? AppColors.textSub : AppColors.textMain,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isRead) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: config.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: AppTextStyles.body.copyWith(
                      color: isRead ? AppColors.textMuted : AppColors.textSub,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(timeStr, style: AppTextStyles.label.copyWith(fontSize: 11)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('dd MMM').format(dt);
    } catch (_) {
      return '';
    }
  }
}

class _TypeConfig {
  final IconData icon;
  final Color color;
  const _TypeConfig(this.icon, this.color);
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      size: 44,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text("You're all caught up!", style: AppTextStyles.h3),
                  const SizedBox(height: 8),
                  Text(
                    'No new alerts at the moment.\nPull down to refresh.',
                    style: AppTextStyles.body.copyWith(color: AppColors.textSub),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Error View ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

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
            Text('Failed to load alerts', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: AppTextStyles.body.copyWith(color: AppColors.textSub),
              textAlign: TextAlign.center,
            ),
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
