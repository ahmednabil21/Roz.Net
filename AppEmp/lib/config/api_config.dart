/// إعدادات الاتصال بباكند مشروع روز.
class ApiConfig {
  ApiConfig._();

  /// عنوان الإنتاج — روز.
  static const String productionBaseUrl = 'https://roz-api.execute-iq.com/wakeel/api';

  /// للتطوير المحلي — عدّل المنفذ حسب تشغيل الباكند.
  static const String localBaseUrl = 'http://10.0.2.2:8080/wakeel/api';

  /// غيّر إلى [localBaseUrl] أثناء التطوير على المحاكي.
  static const String baseUrl = productionBaseUrl;

  /// عنوان Hub الخاص بـ SignalR (بدون /api).
  static String get hubUrl => baseUrl.replaceFirst(RegExp(r'/api/?$'), '/hubs/dashboard');
}
