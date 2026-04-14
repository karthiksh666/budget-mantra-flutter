import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_client.dart';

class AuthState {
  final Map<String, dynamic>? user;
  final String? token;
  final bool loading;

  const AuthState({this.user, this.token, this.loading = false});

  bool get isLoggedIn => token != null && user != null;

  AuthState copyWith({Map<String, dynamic>? user, String? token, bool? loading}) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      loading: loading ?? this.loading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(loading: true)) {
    _restore();
  }

  final _storage = const FlutterSecureStorage();

  Future<void> _restore() async {
    try {
      final token = await _storage.read(key: 'bm_token');
      if (token == null) { state = const AuthState(); return; }
      final user = await ApiClient.instance.getMe();
      state = AuthState(user: user, token: token);
    } catch (_) {
      await _storage.delete(key: 'bm_token');
      state = const AuthState();
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(loading: true);
    try {
      final res = await ApiClient.instance.login(email, password);
      final token = res['access_token'] as String;
      await _storage.write(key: 'bm_token', value: token);
      final user = await ApiClient.instance.getMe();
      state = AuthState(user: user, token: token);
    } catch (e) {
      state = state.copyWith(loading: false);
      rethrow;
    }
  }

  Future<void> signup(String name, String email, String password) async {
    state = state.copyWith(loading: true);
    try {
      final res = await ApiClient.instance.signup(name, email, password);
      final token = res['access_token'] as String?;
      if (token != null) {
        await _storage.write(key: 'bm_token', value: token);
        final user = await ApiClient.instance.getMe();
        state = AuthState(user: user, token: token);
      } else {
        // OTP pending — return without setting logged in
        state = const AuthState();
      }
    } catch (e) {
      state = state.copyWith(loading: false);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'bm_token');
    state = const AuthState();
  }

  Future<void> refreshUser() async {
    try {
      final user = await ApiClient.instance.getMe();
      state = state.copyWith(user: user);
    } catch (_) {}
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
