import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    _TabItem(path: '/',        icon: Icons.home_outlined,        activeIcon: Icons.home,               label: 'Overview'),
    _TabItem(path: '/alerts',  icon: Icons.notifications_outlined, activeIcon: Icons.notifications,    label: 'Alerts'),
    _TabItem(path: '/chat',    icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome,      label: 'Chanakya'),
    _TabItem(path: '/expenses', icon: Icons.pie_chart_outline,   activeIcon: Icons.pie_chart,          label: 'Expenses'),
    _TabItem(path: '/more',    icon: Icons.grid_view_outlined,   activeIcon: Icons.grid_view,          label: 'More'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _tabs.indexWhere((t) => t.path == location);
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: current,
        onTap: (i) => context.go(_tabs[i].path),
        items: _tabs.map((t) => BottomNavigationBarItem(
          icon: Icon(t.icon),
          activeIcon: Icon(t.activeIcon, color: AppColors.primary),
          label: t.label,
        )).toList(),
      ),
    );
  }
}

class _TabItem {
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabItem({required this.path, required this.icon, required this.activeIcon, required this.label});
}
