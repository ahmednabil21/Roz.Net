import 'package:flutter_test/flutter_test.dart';
import 'package:technician_employee_app/main.dart';
import 'package:technician_employee_app/services/auth_service.dart';
import 'package:technician_employee_app/services/fcm_service.dart';
import 'package:technician_employee_app/services/realtime_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boots to login when logged out', (WidgetTester tester) async {
    final auth = AuthService();
    await auth.logout();
    final fcm = FcmService(auth);
    final realtime = RealtimeService(auth);

    await tester.pumpWidget(TechnicianApp(auth: auth, fcm: fcm, realtime: realtime));
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الدخول'), findsNothing);
    expect(find.text('دخول'), findsOneWidget);
  });
}
