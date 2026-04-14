import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_provider.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/transactions/transactions_screen.dart';
import '../../features/budget/budget_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/chatbot/chatbot_screen.dart';
import '../../features/income/income_screen.dart';
import '../../features/goals/goals_screen.dart';
import '../../features/emi/emi_screen.dart';
import '../../features/investments/investments_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/more/more_screen.dart';
import '../shell/main_shell.dart';

// RouterNotifier listens to auth changes and tells GoRouter to re-evaluate
// its redirect — without recreating the GoRouter itself.
class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = _ref.read(authProvider);
    if (auth.loading) return null;

    final loggedIn = auth.isLoggedIn;
    final onAuthPage = state.matchedLocation == '/login' ||
        state.matchedLocation == '/signup';

    if (!loggedIn && !onAuthPage) return '/login';
    if (loggedIn && onAuthPage) return '/';
    return null;
  }
}

final _routerNotifierProvider = ChangeNotifierProvider<_RouterNotifier>(
  (ref) => _RouterNotifier(ref),
);

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // Auth
      GoRoute(path: '/login',  builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),

      // Main shell with bottom nav
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/',        builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/alerts',  builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: '/chat',    builder: (_, __) => const ChatbotScreen()),
          GoRoute(path: '/expenses',builder: (_, __) => const BudgetScreen()),
          GoRoute(path: '/more',    builder: (_, __) => const MoreScreen()),
        ],
      ),

      // Stack screens (pushed from More / Dashboard)
      GoRoute(path: '/transactions', builder: (_, __) => const TransactionsScreen()),
      GoRoute(path: '/income',       builder: (_, __) => const IncomeScreen()),
      GoRoute(path: '/goals',        builder: (_, __) => const GoalsScreen()),
      GoRoute(path: '/emis',         builder: (_, __) => const EmiScreen()),
      GoRoute(path: '/investments',  builder: (_, __) => const InvestmentsScreen()),
    ],
  );
});
