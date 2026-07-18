import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/models.dart';
import 'auth_service.dart';

class TasksService {
  TasksService(this._auth);

  final AuthService _auth;

  Future<PaginatedTasks> fetchMyTasks({
    int page = 1,
    int pageSize = 20,
    int? status,
  }) async {
    final headers = await _auth.authHeaders();
    final params = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
    };
    if (status != null) params['status'] = '$status';

    final uri = Uri.parse('${ApiConfig.baseUrl}/EmployeeTasks/my')
        .replace(queryParameters: params);
    final res = await http.get(uri, headers: headers);
    final body = _decode(res.body);

    if (res.statusCode != 200) {
      throw ApiException(
        _msg(body) ?? 'فشل جلب المهام (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
    return PaginatedTasks.fromJson(body ?? {});
  }

  Future<void> acceptTask(String taskId) async {
    final headers = await _auth.authHeaders();
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/EmployeeTasks/$taskId/accept'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      final body = _decode(res.body);
      throw ApiException(_msg(body) ?? 'فشل قبول المهمة', statusCode: res.statusCode);
    }
  }

  Future<void> rejectTask(String taskId, String reason) async {
    final headers = await _auth.authHeaders();
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/EmployeeTasks/$taskId/reject'),
      headers: headers,
      body: jsonEncode({'reason': reason}),
    );
    if (res.statusCode != 200) {
      final body = _decode(res.body);
      throw ApiException(_msg(body) ?? 'فشل رفض المهمة', statusCode: res.statusCode);
    }
  }

  Future<void> completeMaintenance(String taskId, String note) async {
    final headers = await _auth.authHeaders();
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/EmployeeTasks/$taskId/complete-maintenance'),
      headers: headers,
      body: jsonEncode({'note': note}),
    );
    if (res.statusCode != 200) {
      final body = _decode(res.body);
      throw ApiException(_msg(body) ?? 'فشل إكمال الصيانة', statusCode: res.statusCode);
    }
  }

  Future<void> completeInstallation({
    required String taskId,
    required double amountReceived,
    String? note,
  }) async {
    final headers = await _auth.authHeaders();
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/EmployeeTasks/$taskId/complete-installation'),
      headers: headers,
      body: jsonEncode({
        'amountReceived': amountReceived,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }),
    );
    if (res.statusCode != 200) {
      final body = _decode(res.body);
      throw ApiException(_msg(body) ?? 'فشل إكمال التنصيب', statusCode: res.statusCode);
    }
  }

  Future<void> completeAmountReception({
    required String taskId,
    required double amountReceived,
    String? note,
  }) async {
    final headers = await _auth.authHeaders();
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/EmployeeTasks/$taskId/complete-amount-reception'),
      headers: headers,
      body: jsonEncode({
        'amountReceived': amountReceived,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }),
    );
    if (res.statusCode != 200) {
      final body = _decode(res.body);
      throw ApiException(_msg(body) ?? 'فشل إكمال استلام المبلغ', statusCode: res.statusCode);
    }
  }

  Map<String, dynamic>? _decode(String raw) {
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  String? _msg(Map<String, dynamic>? body) {
    if (body == null) return null;
    return (body['message'] ?? body['Message'] ?? body['detail'])?.toString();
  }
}
