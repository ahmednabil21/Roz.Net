import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/realtime_service.dart';
import '../services/tasks_service.dart';
import '../theme/app_theme.dart';
import '../widgets/task_card.dart';
import 'task_detail_screen.dart';

/// قائمة مهام لصفحة واحدة ضمن الشريط السفلي.
class TasksListPage extends StatefulWidget {
  const TasksListPage({
    super.key,
    required this.auth,
    required this.realtime,
    required this.refreshTick,
    required this.title,
    this.statusFilter,
  });

  final AuthService auth;
  final RealtimeService realtime;
  final ValueNotifier<int> refreshTick;
  final String title;
  final int? statusFilter;

  @override
  State<TasksListPage> createState() => _TasksListPageState();
}

class _TasksListPageState extends State<TasksListPage> {
  late final TasksService _tasks = TasksService(widget.auth);
  List<EmployeeTask> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.refreshTick.addListener(_onTick);
    _load();
  }

  @override
  void didUpdateWidget(covariant TasksListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statusFilter != widget.statusFilter) {
      _load();
    }
  }

  @override
  void dispose() {
    widget.refreshTick.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await _tasks.fetchMyTasks(status: widget.statusFilter);
      if (!mounted) return;
      setState(() {
        _items = page.data;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        await widget.auth.handleUnauthorized();
        return;
      }
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل المهام';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(title: widget.title, count: _items.length, loading: _loading),
        if (!widget.realtime.isConnected)
          _Banner(
            color: Colors.amber,
            text: 'الاتصال المباشر غير نشط — اسحب للتحديث أو تأكد من الشبكة.',
          ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _load(),
            child: _buildBody(),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),
          Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(onPressed: () => _load(), child: const Text('إعادة المحاولة')),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'لا توجد مهام هنا',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final task = _items[index];
        return TaskCard(
          task: task,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TaskDetailScreen(auth: widget.auth, task: task),
              ),
            );
            _load(silent: true);
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.count,
    required this.loading,
  });

  final String title;
  final int count;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/roz_logo_white_bg.png',
              height: 40,
              width: 40,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.wifi_tethering, color: AppColors.primary, size: 32),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  loading ? 'جاري التحديث…' : '$count مهمة',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.text});

  final MaterialColor color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: color.shade900)),
    );
  }
}
