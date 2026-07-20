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

  runApp(TechnicianApp(
    auth: auth,
    fcm: fcm,
    realtime: realtime,
  ));
}

class TechnicianApp extends StatelessWidget {
  const TechnicianApp({
    super.key,
    required this.auth,
    required this.fcm,
    required this.realtime,
  });

  final AuthService auth;
  final FcmService fcm;
  final RealtimeService realtime;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'روز — الموظف الفني',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: AuthGate(
        auth: auth,
        fcm: fcm,
        realtime: realtime,
      ),
    );
  }
}

/// يستعيد الجلسة المحفوظة قبل عرض الشاشة الرئيسية أو تسجيل الدخول.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.auth,
    required this.fcm,
    required this.realtime,
  });

  final AuthService auth;
  final FcmService fcm;
  final RealtimeService realtime;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _loggedIn;

  @override
  void initState() {
    super.initState();
    widget.auth.onSessionExpired = _onLoggedOut;
    _bootstrap();
  }

  @override
  void dispose() {
    if (widget.auth.onSessionExpired == _onLoggedOut) {
      widget.auth.onSessionExpired = null;
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final ok = await widget.auth.restoreSession();
    if (!mounted) return;

    if (ok) {
      await widget.fcm.registerTokenWithBackend();
      await widget.realtime.connect();
    }

    if (!mounted) return;
    setState(() => _loggedIn = ok);
  }

  void _onLoggedIn() {
    setState(() => _loggedIn = true);
  }

  void _onLoggedOut() {
    if (!mounted) return;
    setState(() => _loggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loggedIn == null) {
      return const _SessionSplash();
    }

    if (_loggedIn!) {
      return HomeShell(
        auth: widget.auth,
        fcm: widget.fcm,
        realtime: widget.realtime,
        onLoggedOut: _onLoggedOut,
      );
    }

    return LoginScreen(
      auth: widget.auth,
      fcm: widget.fcm,
      realtime: widget.realtime,
      onLoggedIn: _onLoggedIn,
    );
  }
}

class _SessionSplash extends StatelessWidget {
  const _SessionSplash();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEEF3FF), AppColors.background, Colors.white],
            ),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: Image(
                  image: AssetImage('assets/images/roz_logo_white_bg.png'),
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'جاري استعادة الجلسة…',
                style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
