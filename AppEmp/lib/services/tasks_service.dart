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

  Future<void> completeMaintenance(String taskId, String note, {String? imagePath}) async {
    await _postComplete(
      '/EmployeeTasks/$taskId/complete-maintenance',
      jsonBody: {'note': note},
      formFields: {'note': note},
      imagePath: imagePath,
      errorFallback: 'فشل إكمال الصيانة',
    );
  }

  Future<void> completeInstallation({
    required String taskId,
    required double amountReceived,
    String? note,
    String? imagePath,
  }) async {
    final json = <String, dynamic>{
      'amountReceived': amountReceived,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };
    final fields = <String, String>{
      'amountReceived': amountReceived.toString(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };
    await _postComplete(
      '/EmployeeTasks/$taskId/complete-installation',
      jsonBody: json,
      formFields: fields,
      imagePath: imagePath,
      errorFallback: 'فشل إكمال التنصيب',
    );
  }

  Future<void> completeAmountReception({
    required String taskId,
    required double amountReceived,
    String? note,
    String? imagePath,
  }) async {
    final json = <String, dynamic>{
      'amountReceived': amountReceived,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };
    final fields = <String, String>{
      'amountReceived': amountReceived.toString(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };
    await _postComplete(
      '/EmployeeTasks/$taskId/complete-amount-reception',
      jsonBody: json,
      formFields: fields,
      imagePath: imagePath,
      errorFallback: 'فشل إكمال استلام المبلغ',
    );
  }

  Future<void> _postComplete(
    String path, {
    required Map<String, dynamic> jsonBody,
    required Map<String, String> formFields,
    String? imagePath,
    required String errorFallback,
  }) async {
    final tokenHeaders = await _auth.authHeaders();
    final authOnly = Map<String, String>.from(tokenHeaders)..remove('Content-Type');
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    late http.Response res;
    if (imagePath == null || imagePath.isEmpty) {
      res = await http.post(
        uri,
        headers: tokenHeaders,
        body: jsonEncode(jsonBody),
      );
    } else {
      final req = http.MultipartRequest('POST', uri);
      req.headers.addAll(authOnly);
      req.fields.addAll(formFields);
      req.files.add(await http.MultipartFile.fromPath('image', imagePath));
      final streamed = await req.send();
      res = await http.Response.fromStream(streamed);
    }

    if (res.statusCode != 200) {
      final body = _decode(res.body);
      throw ApiException(_msg(body) ?? errorFallback, statusCode: res.statusCode);
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
