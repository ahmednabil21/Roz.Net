import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../config/api_config.dart';
import 'auth_service.dart';

typedef TaskRealtimeCallback = void Function();

/// اتصال SignalR مع باكند المشروع (بدون Firebase).
/// يستقبل مهام جديدة طالما التطبيق مفتوح ومتصل.
class RealtimeService {
  RealtimeService(this._auth);

  final AuthService _auth;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  HubConnection? _connection;
  bool _localReady = false;
  TaskRealtimeCallback? onTasksChanged;

  bool get isConnected =>
      _connection?.state == HubConnectionState.Connected;

  Future<void> init({TaskRealtimeCallback? onChanged}) async {
    onTasksChanged = onChanged;
    await _initLocalNotifications();
  }

  Future<void> _initLocalNotifications() async {
    if (_localReady) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    const channel = AndroidNotificationChannel(
      'employee_tasks',
      'مهام الموظفين',
      description: 'تنبيهات المهام من النظام',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    _localReady = true;
  }

  Future<void> connect() async {
    await disconnect();

    final token = await _auth.getToken();
    if (token == null || token.isEmpty) return;

    final conn = HubConnectionBuilder()
        .withUrl(
          ApiConfig.hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
          ),
        )
        .withAutomaticReconnect()
        .build();

    conn.onclose(({Exception? error}) {
      debugPrint('SignalR closed: $error');
    });

    conn.onreconnected(({String? connectionId}) async {
      debugPrint('SignalR reconnected');
      try {
        await conn.invoke('JoinEmployeeTasksGroup');
      } catch (e) {
        debugPrint('SignalR re-join failed: $e');
      }
    });

    void handleAssigned(List<Object?>? args) {
      _showLocal('مهمة جديدة', 'لديك مهمة جديدة');
      onTasksChanged?.call();
    }

    void handleBatch(List<Object?>? args) {
      _showLocal('مهام جديدة', 'لديك مهام جديدة');
      onTasksChanged?.call();
    }

    void handleReassigned(List<Object?>? args) {
      _showLocal('تحديث مهمة', 'أُعيد تعيين مهمة من قائمتك');
      onTasksChanged?.call();
    }

    conn.on('employeeTaskAssigned', handleAssigned);
    conn.on('employeeTaskAssignedBatch', handleBatch);
    conn.on('employeeTaskReassignedAway', handleReassigned);
    conn.on('employeeTaskUpdated', (_) => onTasksChanged?.call());

    try {
      await conn.start();
      await conn.invoke('JoinEmployeeTasksGroup');
      _connection = conn;
      debugPrint('SignalR connected to ${ApiConfig.hubUrl}');
    } catch (e) {
      debugPrint('SignalR connect failed: $e');
      try {
        await conn.stop();
      } catch (_) {}
    }
  }

  Future<void> disconnect() async {
    final conn = _connection;
    _connection = null;
    if (conn == null) return;
    try {
      await conn.invoke('LeaveEmployeeTasksGroup');
    } catch (_) {}
    try {
      await conn.stop();
    } catch (_) {}
  }

  Future<void> _showLocal(String title, String body) async {
    if (!_localReady) await _initLocalNotifications();
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'employee_tasks',
          'مهام الموظفين',
          channelDescription: 'تنبيهات المهام من النظام',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
