import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AuthService {
  AuthService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              // تثبيت تخزين الويب حتى لا يضيع JWT بين الجلسات/التبويبات
              webOptions: WebOptions(
                dbName: 'roz_emp_secure',
                publicKey: 'roz_emp_key',
              ),
            );

  static const _tokenKey = 'jwt';
  static const _nameKey = 'fullName';
  static const _usernameKey = 'username';
  static const _companyKey = 'companyName';
  static const _roleKey = 'role';

  final FlutterSecureStorage _storage;

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<String?> getFullName() => _storage.read(key: _nameKey);

  Future<String?> getUsername() => _storage.read(key: _usernameKey);

  Future<String?> getCompanyName() => _storage.read(key: _companyKey);

  Future<Map<String, String>> getProfile() async {
    return {
      'fullName': await getFullName() ?? '',
      'username': await getUsername() ?? '',
      'companyName': await getCompanyName() ?? '',
    };
  }

  Future<bool> isLoggedIn() async {
    final t = await getToken();
    return t != null && t.isNotEmpty;
  }

  Future<LoginResult> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/Auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username.trim(),
        'password': password,
      }),
    );

    final body = _tryDecode(res.body);
    if (res.statusCode != 200) {
      throw ApiException(
        _messageFromBody(body) ?? 'فشل تسجيل الدخول (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }

    final result = LoginResult.fromJson(body ?? {});
    if (result.token.isEmpty) {
      throw ApiException('لم يُرجع الخادم رمز الدخول.');
    }
    if (!result.isEmployee) {
      throw ApiException('هذا التطبيق مخصص لدور الموظف فقط.');
    }

    await _storage.write(key: _tokenKey, value: result.token);
    await _storage.write(key: _nameKey, value: result.fullName ?? '');
    await _storage.write(key: _usernameKey, value: result.username ?? username.trim());
    await _storage.write(key: _companyKey, value: result.companyName ?? '');
    await _storage.write(key: _roleKey, value: result.role ?? 'Employee');

    // حدّث من /Auth/me عند الحاجة (الاسم / الشركة)
    await _refreshProfileFromMe();
    return result;
  }

  Future<void> _refreshProfileFromMe() async {
    try {
      final headers = await authHeaders();
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/Auth/me'), headers: headers);
      if (res.statusCode != 200) return;
      final body = _tryDecode(res.body);
      if (body == null) return;
      final fullName = (body['fullName'] ?? body['FullName'])?.toString();
      final username = (body['username'] ?? body['Username'])?.toString();
      final company = (body['companyName'] ?? body['CompanyName'])?.toString();
      if (fullName != null && fullName.isNotEmpty) {
        await _storage.write(key: _nameKey, value: fullName);
      }
      if (username != null && username.isNotEmpty) {
        await _storage.write(key: _usernameKey, value: username);
      }
      if (company != null && company.isNotEmpty) {
        await _storage.write(key: _companyKey, value: company);
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _nameKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _companyKey);
    await _storage.delete(key: _roleKey);
  }

  Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('يجب تسجيل الدخول أولاً.', statusCode: 401);
    }
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      // بعض البيئات/البروكسي تمرّر هذا الهيدر إن حُجب Authorization
      'x-authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic>? _tryDecode(String raw) {
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  String? _messageFromBody(Map<String, dynamic>? body) {
    if (body == null) return null;
    return (body['message'] ?? body['Message'] ?? body['title'] ?? body['detail'])
        ?.toString();
  }
}
