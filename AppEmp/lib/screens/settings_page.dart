import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../services/realtime_service.dart';
import '../services/telegram_service.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.auth,
    required this.fcm,
    required this.realtime,
    required this.onLoggedOut,
  });

  final AuthService auth;
  final FcmService fcm;
  final RealtimeService realtime;
  final VoidCallback onLoggedOut;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TelegramService _telegram = TelegramService(widget.auth);

  String _fullName = '—';
  String _username = '—';
  String _company = '—';
  bool _loading = true;

  TelegramLinkStatus? _tgStatus;
  bool _tgLoading = true;
  bool _tgBusy = false;
  String? _tgError;

  String _fcmHint = 'جاري الفحص…';
  bool _fcmOk = false;
  bool _fcmLoading = true;
  bool _fcmBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadTelegram();
    _loadFcmStatus();
  }

  Future<void> _load() async {
    final profile = await widget.auth.getProfile();
    if (!mounted) return;
    setState(() {
      _fullName = (profile['fullName']?.isNotEmpty == true) ? profile['fullName']! : '—';
      _username = (profile['username']?.isNotEmpty == true) ? profile['username']! : '—';
      _company = (profile['companyName']?.isNotEmpty == true) ? profile['companyName']! : '—';
      _loading = false;
    });
  }

  Future<void> _loadTelegram() async {
    setState(() {
      _tgLoading = true;
      _tgError = null;
    });
    try {
      final status = await _telegram.getStatus();
      if (!mounted) return;
      setState(() {
        _tgStatus = status;
        _tgLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tgError = e.toString();
        _tgLoading = false;
      });
    }
  }

  Future<void> _linkTelegram() async {
    setState(() {
      _tgBusy = true;
      _tgError = null;
    });
    try {
      final start = await _telegram.createLink();
      final opened = await _telegram.openDeepLink(start.deepLink);
      if (!mounted) return;

      if (!opened) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('افتح تليجرام'),
              content: SelectableText(
                '${start.instructions}\n\n${start.deepLink}',
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: start.deepLink));
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('نسخ الرابط'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('حسناً'),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('افتح تليجرام واضغط Start لإكمال الربط.')),
        );
      }
      await Future<void>.delayed(const Duration(seconds: 2));
      await _loadTelegram();
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException && e.statusCode == 401
          ? 'انتهت الجلسة أو التوكن غير صالح. سجّل الخروج ثم الدخول مجدداً.'
          : e.toString();
      setState(() => _tgError = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _tgBusy = false);
    }
  }

  Future<void> _unlinkTelegram() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إلغاء ربط تليجرام'),
          content: const Text('لن تصلك إشعارات المهام على تليجرام بعد الإلغاء. هل تريد المتابعة؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إبقاء')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('إلغاء الربط'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    setState(() {
      _tgBusy = true;
      _tgError = null;
    });
    try {
      await _telegram.unlink();
      await _loadTelegram();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء ربط تليجرام.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _tgError = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _tgBusy = false);
    }
  }

  Future<void> _loadFcmStatus() async {
    setState(() => _fcmLoading = true);
    try {
      await widget.fcm.registerTokenWithBackend();
      final status = await widget.fcm.fetchBackendStatus();
      if (!mounted) return;
      final ready = status['firebaseReady'] == true || status['FirebaseReady'] == true;
      final match = status['projectIdMatchesExpected'] != false &&
          status['ProjectIdMatchesExpected'] != false;
      final devices = status['deviceCount'] ?? status['DeviceCount'] ?? 0;
      final hint = (status['hint'] ?? status['Hint'] ?? '').toString();
      setState(() {
        _fcmOk = ready && match && (devices is int ? devices > 0 : true);
        _fcmHint = hint.isNotEmpty
            ? hint
            : (ready ? 'FCM جاهز' : 'Firebase غير مهيأ على السيرفر');
        _fcmLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fcmOk = false;
        _fcmHint = e.toString();
        _fcmLoading = false;
      });
    }
  }

  Future<void> _sendFcmTest() async {
    setState(() => _fcmBusy = true);
    try {
      await widget.fcm.registerTokenWithBackend();
      final msg = await widget.fcm.sendTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await showDialog<void>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('اختبار FCM'),
            content: const Text(
              'الآن أزل التطبيق من Recent Apps وانتظر الإشعار.\n'
              'إن لم يصل: مفتاح Firebase على السيرفر غالباً من مشروع مختلف عن technicianemployeeapp.',
            ),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً')),
            ],
          ),
        ),
      );
      await _loadFcmStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _fcmBusy = false);
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل تريد تسجيل الخروج من التطبيق؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('خروج'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    await widget.fcm.unregisterToken();
    await widget.realtime.disconnect();
    await widget.auth.logout();
    if (!mounted) return;
    widget.onLoggedOut();
  }

  @override
  Widget build(BuildContext context) {
    final linked = _tgStatus?.linked == true;
    final tgValue = _tgLoading
        ? 'جاري التحقق…'
        : linked
            ? (_tgStatus?.telegramUsername?.isNotEmpty == true
                ? 'مرتبط (@${_tgStatus!.telegramUsername})'
                : 'مرتبط')
            : 'غير مرتبط — موصى به للآيفون/الويب';

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: const Text(
            'الإعدادات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Image.asset(
                        'assets/images/roz_logo_white_bg.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.person, color: AppColors.primary, size: 32),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _loading ? '…' : _fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _loading ? '' : _company,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _InfoTile(
                icon: Icons.badge_outlined,
                label: 'اسم الموظف',
                value: _fullName,
              ),
              _InfoTile(
                icon: Icons.apartment_rounded,
                label: 'اسم الشركة',
                value: _company,
              ),
              _InfoTile(
                icon: Icons.person_outline_rounded,
                label: 'اسم المستخدم',
                value: _username,
              ),
              const SizedBox(height: 8),
              const _InfoTile(
                icon: Icons.notifications_active_outlined,
                label: 'الإشعارات',
                value: 'FCM + تليجرام + اتصال مباشر',
              ),
              const SizedBox(height: 8),
              _FcmCard(
                statusText: _fcmLoading ? 'جاري الفحص…' : (_fcmOk ? 'FCM جاهز' : 'FCM غير سليم'),
                hint: _fcmHint,
                ok: _fcmOk,
                loading: _fcmLoading || _fcmBusy,
                onRefresh: _loadFcmStatus,
                onTest: _sendFcmTest,
              ),
              const SizedBox(height: 8),
              _TelegramCard(
                statusText: tgValue,
                linked: linked,
                loading: _tgLoading || _tgBusy,
                error: _tgError,
                onLink: _linkTelegram,
                onUnlink: _unlinkTelegram,
                onRefresh: _loadTelegram,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _logout,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FcmCard extends StatelessWidget {
  const _FcmCard({
    required this.statusText,
    required this.hint,
    required this.ok,
    required this.loading,
    required this.onRefresh,
    required this.onTest,
  });

  final String statusText;
  final String hint;
  final bool ok;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  ok ? Icons.notifications_active : Icons.notification_important_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إشعارات أندرويد (FCM)',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: loading ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'تحديث',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.35),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: loading ? null : onTest,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.science_outlined),
            label: Text(loading ? 'جاري…' : 'إرسال إشعار تجريبي ثم أغلق من Recent Apps'),
          ),
        ],
      ),
    );
  }
}

class _TelegramCard extends StatelessWidget {
  const _TelegramCard({
    required this.statusText,
    required this.linked,
    required this.loading,
    required this.onLink,
    required this.onUnlink,
    required this.onRefresh,
    this.error,
  });

  final String statusText;
  final bool linked;
  final bool loading;
  final String? error;
  final VoidCallback onLink;
  final VoidCallback onUnlink;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.send_rounded, color: Color(0xFF229ED9), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إشعارات تليجرام',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'بديل موثوق لإشعارات الآيفون عند استخدام ويب التطبيق',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: loading ? null : onRefresh,
                tooltip: 'تحديث الحالة',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: linked ? AppColors.success : AppColors.warning,
            ),
          ),
          if (error != null && error!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: const TextStyle(fontSize: 12, color: AppColors.danger),
            ),
          ],
          const SizedBox(height: 14),
          if (loading)
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            )
          else if (linked)
            OutlinedButton.icon(
              onPressed: onUnlink,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.link_off_rounded),
              label: const Text('إلغاء الربط'),
            )
          else
            FilledButton.icon(
              onPressed: onLink,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF229ED9),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.link_rounded),
              label: const Text('ربط تليجرام'),
            ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
