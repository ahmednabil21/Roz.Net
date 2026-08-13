import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

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
    final result = await _showCompleteDialog(
      title: 'إكمال الصيانة',
      requireNote: true,
      noteHint: 'ملاحظات التنفيذ (إلزامي)',
    );
    if (result == null) return;
    if (!mounted) return;
    if (result.note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الملاحظة مطلوبة')),
      );
      return;
    }
    await _run(
      () => _tasks.completeMaintenance(_task.id, result.note, imagePath: result.imagePath),
      ok: 'تم إكمال الصيانة',
    );
  }

  Future<void> _completeWithAmount({required bool installation}) async {
    final result = await _showCompleteDialog(
      title: installation ? 'إكمال التنصيب' : 'إكمال استلام المبلغ',
      requireAmount: true,
    );
    if (result == null) return;
    if (!mounted) return;
    if (result.amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مبلغاً صالحاً')),
      );
      return;
    }
    await _run(
      () => installation
          ? _tasks.completeInstallation(
              taskId: _task.id,
              amountReceived: result.amount!,
              note: result.note,
              imagePath: result.imagePath,
            )
          : _tasks.completeAmountReception(
              taskId: _task.id,
              amountReceived: result.amount!,
              note: result.note,
              imagePath: result.imagePath,
            ),
      ok: 'تم الإكمال',
    );
  }

  Future<({String note, double? amount, String? imagePath})?> _showCompleteDialog({
    required String title,
    bool requireNote = false,
    bool requireAmount = false,
    String noteHint = 'ملاحظة (اختياري)',
  }) {
    final noteCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String? imagePath;

    return showDialog<({String note, double? amount, String? imagePath})>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (requireAmount) ...[
                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'المبلغ المستلم',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: noteCtrl,
                      maxLines: requireNote ? 4 : 2,
                      decoration: InputDecoration(
                        hintText: noteHint,
                        labelText: requireNote ? null : noteHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (imagePath != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(imagePath!), height: 140, fit: BoxFit.cover),
                      ),
                      TextButton(
                        onPressed: () => setLocal(() => imagePath = null),
                        child: const Text('إزالة الصورة'),
                      ),
                    ],
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final file = await picker.pickImage(
                          source: ImageSource.camera,
                          imageQuality: 80,
                          maxWidth: 1600,
                        );
                        if (file != null) setLocal(() => imagePath = file.path);
                      },
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('التقاط صورة (اختياري)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx, (
                      note: noteCtrl.text.trim(),
                      amount: requireAmount ? double.tryParse(amountCtrl.text.trim()) : null,
                      imagePath: imagePath,
                    ));
                  },
                  child: const Text('إكمال'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openMaps() async {
    final coords = _task.displayCoordinates;
    if (coords == null || coords.isEmpty) return;
    final cleaned = coords.replaceAll(' ', '');
    final uri = Uri.parse('https://www.google.com/maps?q=$cleaned');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح خرائط Google')),
      );
    }
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
                  _row('اسم المشترك', _task.displaySubscriberName),
                  _row('العنوان', _task.displayAddress),
                  _row('الإحداثيات', _task.displayCoordinates),
                  _row('هاتف', _task.newSubscriberPhone),
                  _row('ملاحظة', _task.note),
                  _row('التفاصيل', _task.taskDetails),
                  _row('أنشأها', _task.createdByUserName),
                  _row('التاريخ', created),
                  if (_task.rejectionReason != null) _row('سبب الرفض', _task.rejectionReason),
                  if (_task.completedNote != null) _row('ملاحظة الإكمال', _task.completedNote),
                ],
              ),
            ),
            if (_task.displayCoordinates != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _openMaps,
                icon: const Icon(Icons.location_on),
                label: const Text('اذهب الى الموقع'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
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
                    label: const Text('إكمال المهمة'),
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
                    label: const Text('إكمال المهمة'),
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
                    label: const Text('إكمال المهمة'),
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
