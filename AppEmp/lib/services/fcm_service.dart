import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

/// يُستدعى لرسائل data (أو عند الحاجة) والتطبيق في الخلفية/مغلق.
/// رسائل notification+data على Android تُعرض عادةً من النظام دون الاعتماد على هذا الـ handler.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

typedef TaskPushCallback = void Function(RemoteMessage message);

/// تسجيل توكن FCM لدى الباكند واستقبال الإشعارات والتطبيق مغلق.
class FcmService {
  FcmService(this._auth);

  final AuthService _auth;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  bool ready = false;
  String? _lastToken;
  TaskPushCallback? onTaskPush;

  Future<void> init({TaskPushCallback? onPush}) async {
    onTaskPush = onPush;
    try {
      await Firebase.initializeApp();
      ready = true;
    } catch (e) {
      debugPrint('FCM: ضع google-services.json أولاً: $e');
      ready = false;
      return;
    }

    // onBackgroundMessage يُسجَّل مرة واحدة من main.dart قبل runApp.

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    const channel = AndroidNotificationChannel(
      'employee_tasks',
      'مهام الموظفين',
      description: 'إشعارات المهام الجديدة',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Android 13+: إذن الإشعارات عبر قناة النظام (إضافة لطلب Firebase)
    if (!kIsWeb && Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) {
      _showLocal(message);
      onTaskPush?.call(message);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onTaskPush?.call(message);
    });

    final initial = await messaging.getInitialMessage();
    if (initial != null) onTaskPush?.call(initial);
  }

  Future<void> registerTokenWithBackend() async {
    if (!ready) return;
    try {
      final messaging = FirebaseMessaging.instance;

      // على iOS يجب وجود APNS قبل getToken — المحاكي غالباً بلا توكن.
      if (!kIsWeb && Platform.isIOS) {
        String? apns;
        for (var i = 0; i < 15; i++) {
          apns = await messaging.getAPNSToken();
          if (apns != null && apns.isNotEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        if (apns == null || apns.isEmpty) {
          debugPrint(
            'FCM: لا يوجد APNS token بعد — طبيعي على المحاكي. استخدم جهازاً حقيقياً للإشعارات.',
          );
          return;
        }
      }

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('FCM: لم يُحصل على توكن');
        return;
      }
      _lastToken = token;

      final jwt = await _auth.getToken();
      if (jwt == null || jwt.isEmpty) return;

      final platform = Platform.isIOS ? 1 : 0;
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/FcmDevices/token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({'token': token, 'platform': platform}),
      );
      debugPrint(res.statusCode == 200
          ? 'FCM: تم تسجيل الجهاز'
          : 'FCM: فشل التسجيل ${res.statusCode} ${res.body}');

      messaging.onTokenRefresh.listen((newToken) async {
        _lastToken = newToken;
        final t = await _auth.getToken();
        if (t == null) return;
        try {
          await http.post(
            Uri.parse('${ApiConfig.baseUrl}/FcmDevices/token'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $t',
            },
            body: jsonEncode({'token': newToken, 'platform': platform}),
          );
        } catch (e) {
          debugPrint('FCM: فشل تحديث التوكن: $e');
        }
      });
    } catch (e) {
      debugPrint('FCM: فشل تسجيل التوكن: $e');
    }
  }

  Future<void> unregisterToken() async {
    final token = _lastToken;
    if (token == null) return;
    try {
      final jwt = await _auth.getToken();
      if (jwt == null) return;
      await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/FcmDevices/token')
            .replace(queryParameters: {'token': token}),
        headers: {'Authorization': 'Bearer $jwt'},
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>> fetchBackendStatus() async {
    final headers = await _auth.authHeaders();
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/FcmDevices/status'),
      headers: headers,
    );
    final body = _tryDecode(res.body) ?? <String, dynamic>{};
    if (res.statusCode != 200) {
      throw ApiException(
        (body['message'] ?? body['Message'] ?? 'تعذر فحص حالة FCM (${res.statusCode})').toString(),
        statusCode: res.statusCode,
      );
    }
    return body;
  }

  Future<String> sendTestNotification() async {
    final headers = await _auth.authHeaders();
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/FcmDevices/test'),
      headers: headers,
    );
    final body = _tryDecode(res.body);
    final message = (body?['message'] ?? body?['Message'] ?? res.body).toString();
    if (res.statusCode != 200) {
      throw ApiException(message, statusCode: res.statusCode);
    }
    return message;
  }

  Map<String, dynamic>? _tryDecode(String raw) {
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showLocal(RemoteMessage message) async {
    final n = message.notification;
    await _local.show(
      message.hashCode,
      n?.title ?? 'مهمة جديدة',
      n?.body ?? 'لديك مهمة جديدة',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'employee_tasks',
          'مهام الموظفين',
          channelDescription: 'إشعارات المهام الجديدة',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
