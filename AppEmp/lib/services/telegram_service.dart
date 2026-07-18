import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../utils/open_external_url.dart';
import 'auth_service.dart';

class TelegramLinkStatus {
  final bool linked;
  final String? telegramUsername;
  final DateTime? linkedAt;
  final String? botUsername;

  const TelegramLinkStatus({
    required this.linked,
    this.telegramUsername,
    this.linkedAt,
    this.botUsername,
  });

  factory TelegramLinkStatus.fromJson(Map<String, dynamic> json) {
    return TelegramLinkStatus(
      linked: json['linked'] == true || json['Linked'] == true,
      telegramUsername: _asString(json['telegramUsername'] ?? json['TelegramUsername']),
      linkedAt: DateTime.tryParse(
        (json['linkedAt'] ?? json['LinkedAt'] ?? '').toString(),
      ),
      botUsername: _asString(json['botUsername'] ?? json['BotUsername']),
    );
  }
}

class TelegramLinkStart {
  final String deepLink;
  final String botUsername;
  final DateTime? expiresAt;
  final String instructions;

  const TelegramLinkStart({
    required this.deepLink,
    required this.botUsername,
    this.expiresAt,
    required this.instructions,
  });

  factory TelegramLinkStart.fromJson(Map<String, dynamic> json) {
    return TelegramLinkStart(
      deepLink: (json['deepLink'] ?? json['DeepLink'] ?? '').toString(),
      botUsername: (json['botUsername'] ?? json['BotUsername'] ?? '').toString(),
      expiresAt: DateTime.tryParse(
        (json['expiresAt'] ?? json['ExpiresAt'] ?? '').toString(),
      ),
      instructions: (json['instructions'] ??
              json['Instructions'] ??
              'افتح الرابط في تليجرام واضغط Start.')
          .toString(),
    );
  }
}

/// ربط حساب الموظف ببوت تليجرام لاستلام إشعارات المهام على الآيفون/الويب.
class TelegramService {
  TelegramService(this._auth);

  final AuthService _auth;

  Future<TelegramLinkStatus> getStatus() async {
    final headers = await _auth.authHeaders();
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/Telegram/status'),
      headers: headers,
    );
    final body = _tryDecode(res.body);
    if (res.statusCode != 200) {
      throw ApiException(
        _messageFromBody(body) ?? 'تعذر جلب حالة تليجرام (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
    return TelegramLinkStatus.fromJson(body ?? {});
  }

  Future<TelegramLinkStart> createLink() async {
    final headers = await _auth.authHeaders();
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/Telegram/link'),
      headers: headers,
    );
    final body = _tryDecode(res.body);
    if (res.statusCode != 200) {
      throw ApiException(
        _messageFromBody(body) ?? 'تعذر إنشاء رابط الربط (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
    final start = TelegramLinkStart.fromJson(body ?? {});
    if (start.deepLink.isEmpty) {
      throw ApiException('الخادم لم يُرجع رابط تليجرام.');
    }
    return start;
  }

  Future<void> unlink() async {
    final headers = await _auth.authHeaders();
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/Telegram/link'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      final body = _tryDecode(res.body);
      throw ApiException(
        _messageFromBody(body) ?? 'تعذر إلغاء الربط (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
  }

  Future<bool> openDeepLink(String deepLink) async {
    final uri = Uri.tryParse(deepLink);
    if (uri == null) return false;

    // على الويب: فتح مباشر عبر window.open لتجنب MissingPluginException
    // عندما لا يُبنى url_launcher_web بشكل صحيح أو بعد hot-reload فقط.
    if (kIsWeb) {
      try {
        return openExternalUrl(deepLink);
      } catch (_) {
        return false;
      }
    }

    try {
      if (await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return launchUrl(uri, mode: LaunchMode.platformDefault);
    } on MissingPluginException {
      return openExternalUrl(deepLink);
    } catch (_) {
      return false;
    }
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

String? _asString(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}
