import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'services/realtime_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // يجب تسجيل الـ background handler قبل runApp (متطلب Firebase).
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final auth = AuthService();
  final fcm = FcmService(auth);
  final realtime = RealtimeService(auth);

  await fcm.init(onPush: (_) {});
  await realtime.init();
  final loggedIn = await auth.isLoggedIn();
  if (loggedIn) {
    await fcm.registerTokenWithBackend();
    await realtime.connect();
  }

  runApp(TechnicianApp(
    auth: auth,
    fcm: fcm,
    realtime: realtime,
    loggedIn: loggedIn,
  ));
}

class TechnicianApp extends StatelessWidget {
  const TechnicianApp({
    super.key,
    required this.auth,
    required this.fcm,
    required this.realtime,
    required this.loggedIn,
  });

  final AuthService auth;
  final FcmService fcm;
  final RealtimeService realtime;
  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'روز — الموظف الفني',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: loggedIn
          ? HomeShell(auth: auth, fcm: fcm, realtime: realtime)
          : LoginScreen(auth: auth, fcm: fcm, realtime: realtime),
    );
  }
}
