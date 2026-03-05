import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/payment.dart';

class ApiService {
  static const _secureStorage = FlutterSecureStorage();
  static const _apiKeyKey = 'api_key';
  static const _domainKey = 'api_domain';

  static Dio _buildDio(String baseUrl) {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  // ── Domain ────────────────────────────────────────────────────────────────

  static Future<String> getDomain() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_domainKey) ?? '';
  }

  static Future<void> saveDomain(String domain) async {
    final prefs = await SharedPreferences.getInstance();
    // Normalize: strip trailing slash
    await prefs.setString(
      _domainKey,
      domain.trimRight().replaceAll(RegExp(r'/+$'), ''),
    );
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  static Future<String?> getApiKey() async {
    return _secureStorage.read(key: _apiKeyKey);
  }

  static Future<void> saveApiKey(String key) async {
    await _secureStorage.write(key: _apiKeyKey, value: key);
  }

  static Future<void> clearApiKey() async {
    await _secureStorage.delete(key: _apiKeyKey);
  }

  static Future<bool> isLoggedIn() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  /// POST {domain}/api/auth/login → returns api_key
  static Future<String> login(
    String domain,
    String username,
    String password,
  ) async {
    final dio = _buildDio(domain);
    try {
      final response = await dio.post(
        '/api/auth/login',
        data: {'username': username, 'password': password},
      );
      final key = response.data['api_key'] as String?;
      if (key == null || key.isEmpty) throw Exception('No api_key in response');
      await saveApiKey(key);
      await saveDomain(domain);
      return key;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Login failed';
      throw Exception(msg);
    }
  }

  // ── Payment Reporting ─────────────────────────────────────────────────────

  /// POST {domain}/api/register_payment
  /// Throws on any failure so caller can enqueue.
  static Future<void> reportPayment(Payment payment) async {
    final domain = await getDomain();
    if (domain.isEmpty) throw Exception('API domain not configured');

    final apiKey = await getApiKey();
    if (apiKey == null) throw Exception('Not logged in');

    final dio = _buildDio(domain);
    dio.options.headers['Authorization'] = 'Bearer $apiKey';

    final response = await dio.post(
      '/api/register_payment',
      data: payment.toApiJson(),
    );

    if (response.statusCode == null || response.statusCode! >= 300) {
      throw Exception('Server responded with ${response.statusCode}');
    }
  }
}
