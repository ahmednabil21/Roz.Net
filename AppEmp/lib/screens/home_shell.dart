import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../services/realtime_service.dart';
import 'settings_page.dart';
import 'tasks_list_page.dart';

/// الحاوية الرئيسية مع شريط تنقل سفلي.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.auth,
    required this.fcm,
    required this.realtime,
  });

  final AuthService auth;
  final FcmService fcm;
  final RealtimeService realtime;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final ValueNotifier<int> _refreshTick = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    widget.realtime.onTasksChanged = _bump;
    widget.fcm.onTaskPush = (_) => _bump();
    _prepare();
  }

  Future<void> _prepare() async {
    if (widget.fcm.ready) {
      await widget.fcm.registerTokenWithBackend();
    }
    if (!widget.realtime.isConnected) {
      await widget.realtime.connect();
    }
  }

  void _bump() {
    _refreshTick.value++;
  }

  @override
  void dispose() {
    widget.realtime.onTasksChanged = null;
    widget.fcm.onTaskPush = null;
    _refreshTick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TasksListPage(
        auth: widget.auth,
        realtime: widget.realtime,
        refreshTick: _refreshTick,
        title: 'المهام',
      ),
      TasksListPage(
        auth: widget.auth,
        realtime: widget.realtime,
        refreshTick: _refreshTick,
        title: 'المهام بالانتظار',
        statusFilter: 1,
      ),
      TasksListPage(
        auth: widget.auth,
        realtime: widget.realtime,
        refreshTick: _refreshTick,
        title: 'المهام المكتملة',
        statusFilter: 3,
      ),
      SettingsPage(
        auth: widget.auth,
        fcm: widget.fcm,
        realtime: widget.realtime,
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _index, children: pages),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          height: 68,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment_rounded),
              label: 'المهام',
            ),
            NavigationDestination(
              icon: Icon(Icons.hourglass_empty_rounded),
              selectedIcon: Icon(Icons.hourglass_top_rounded),
              label: 'بالانتظار',
            ),
            NavigationDestination(
              icon: Icon(Icons.task_alt_outlined),
              selectedIcon: Icon(Icons.task_alt_rounded),
              label: 'مكتملة',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }
}
