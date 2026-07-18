import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/tasks_service.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({
    super.key,
    required this.auth,
    required this.task,
  });

  final AuthService auth;
  final EmployeeTask task;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late final EmployeeTask _task = widget.task;
  late final TasksService _tasks = TasksService(widget.auth);
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, {String ok = 'تم'}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok)));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ غير متوقع')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() => _run(() => _tasks.acceptTask(_task.id), ok: 'تم قبول المهمة');

  Future<void> _reject() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رفض المهمة'),
          content: TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'سبب الرفض (إلزامي)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('رفض'),
            ),
          ],
        ),
      ),
    );
    if (reason == null) return;
    if (!mounted) return;
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سبب الرفض مطلوب')),
      );
      return;
    }
    await _run(() => _tasks.rejectTask(_task.id, reason), ok: 'تم رفض المهمة');
  }

  Future<void> _completeMaintenance() async {
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إكمال الصيانة'),
          content: TextField(
            controller: ctrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'ملاحظات التنفيذ (إلزامي)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('إكمال'),
            ),
          ],
        ),
      ),
    );
    if (note == null) return;
    if (!mounted) return;
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الملاحظة مطلوبة')),
      );
      return;
    }
    await _run(() => _tasks.completeMaintenance(_task.id, note), ok: 'تم إكمال الصيانة');
  }

  Future<void> _completeWithAmount({required bool installation}) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(installation ? 'إكمال التنصيب' : 'إكمال استلام المبلغ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'المبلغ المستلم',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إكمال')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مبلغاً صالحاً')),
      );
      return;
    }
    await _run(
      () => installation
          ? _tasks.completeInstallation(
              taskId: _task.id,
              amountReceived: amount,
              note: noteCtrl.text,
            )
          : _tasks.completeAmountReception(
              taskId: _task.id,
              amountReceived: amount,
              note: noteCtrl.text,
            ),
      ok: 'تم الإكمال',
    );
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final created = _task.createdAt == null
        ? '—'
        : DateFormat('yyyy-MM-dd HH:mm').format(_task.createdAt!.toLocal());

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          title: const Text('تفاصيل المهمة'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _task.displayTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(_task.statusLabel),
                    backgroundColor: const Color(0xFFE8EEFF),
                    labelStyle: const TextStyle(
                      color: Color(0xFF2962FF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Divider(height: 24),
                  _row('النوع', _task.taskTypeLabel),
                  if (_task.isMaintenance) _row('نوع الصيانة', _task.maintenanceTypeLabel),
                  _row('المشترك', _task.subscriberDisplayName),
                  _row('اسم للتنصيب', _task.newSubscriberName),
                  _row('هاتف', _task.newSubscriberPhone),
                  _row('العنوان', _task.newSubscriberAddress),
                  _row('ملاحظة', _task.note),
                  _row('التفاصيل', _task.taskDetails),
                  _row('أنشأها', _task.createdByUserName),
                  _row('التاريخ', created),
                  if (_task.rejectionReason != null) _row('سبب الرفض', _task.rejectionReason),
                  if (_task.completedNote != null) _row('ملاحظة الإكمال', _task.completedNote),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_busy)
              const Center(child: CircularProgressIndicator(color: Color(0xFF2962FF)))
            else ...[
              if (_task.isPending) ...[
                FilledButton.icon(
                  onPressed: _accept,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('قبول المهمة'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2962FF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _reject,
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text('رفض', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
              if (_task.isAccepted) ...[
                if (_task.isMaintenance)
                  FilledButton.icon(
                    onPressed: _completeMaintenance,
                    icon: const Icon(Icons.done_all),
                    label: const Text('إكمال الصيانة'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                if (_task.isInstallation)
                  FilledButton.icon(
                    onPressed: () => _completeWithAmount(installation: true),
                    icon: const Icon(Icons.done_all),
                    label: const Text('إكمال التنصيب'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                if (_task.isAmountReception)
                  FilledButton.icon(
                    onPressed: () => _completeWithAmount(installation: false),
                    icon: const Icon(Icons.done_all),
                    label: const Text('إكمال استلام المبلغ'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _reject,
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text('رفض', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
