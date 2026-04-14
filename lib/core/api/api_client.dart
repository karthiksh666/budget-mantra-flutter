import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kBaseUrl = 'https://budgetmantra-supabase-production.up.railway.app/api';
// For local dev, swap to: 'http://192.168.x.x:8001/api'

class ApiClient {
  ApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: _kBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'bm_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        // 401 → token expired, could trigger logout here
        return handler.next(error);
      },
    ));
  }

  static final ApiClient instance = ApiClient._();
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  Dio get dio => _dio;

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> signup(String name, String email, String password) async {
    final res = await _dio.post('/auth/register', data: {'name': name, 'email': email, 'password': password});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/auth/me');
    return res.data as Map<String, dynamic>;
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  Future<List> getTransactions({int? month, int? year}) async {
    final res = await _dio.get('/transactions', queryParameters: {
      if (month != null) 'month': month,
      if (year != null) 'year': year,
    });
    return res.data as List;
  }

  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> data) async {
    final res = await _dio.post('/transactions', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteTransaction(String id) async {
    await _dio.delete('/transactions/$id');
  }

  // ── Dashboard summary ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getBudgetSummary() async {
    final res = await _dio.get('/budget-summary');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getFinancialScore() async {
    final res = await _dio.get('/financial-score');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getNetWorth() async {
    final res = await _dio.get('/net-worth');
    return res.data as Map<String, dynamic>;
  }

  // ── Goals ─────────────────────────────────────────────────────────────────

  Future<List> getGoals() async {
    final res = await _dio.get('/savings-goals');
    return res.data as List;
  }

  // ── EMIs ──────────────────────────────────────────────────────────────────

  Future<List> getEmis() async {
    final res = await _dio.get('/emis');
    return res.data as List;
  }

  // ── Income ────────────────────────────────────────────────────────────────

  Future<List> getIncomeEntries() async {
    final res = await _dio.get('/income-entries');
    return res.data as List;
  }

  // ── Investments ───────────────────────────────────────────────────────────

  Future<List> getInvestments() async {
    final res = await _dio.get('/investments');
    return res.data as List;
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<List> getUnreadNotifications() async {
    final res = await _dio.get('/notifications/unread');
    return res.data as List;
  }

  Future<Map<String, dynamic>> getNotificationPrefs() async {
    final res = await _dio.get('/notifications/prefs');
    return res.data as Map<String, dynamic>;
  }

  Future<void> updateNotificationPrefs(Map<String, dynamic> prefs) async {
    await _dio.put('/notifications/prefs', data: prefs);
  }

  // ── Chanakya chat ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> chat(String message, {String? sessionId}) async {
    final res = await _dio.post('/chatbot', data: {
      'message': message,
      if (sessionId != null) 'session_id': sessionId,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List> getChatHistory() async {
    final res = await _dio.get('/chatbot/history');
    return res.data as List;
  }
}
