import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/models.dart';
import '../theme/app_theme.dart';

Color statusColor(int status) {
  switch (status) {
    case 1:
      return AppColors.warning;
    case 2:
      return AppColors.info;
    case 3:
      return AppColors.success;
    case 4:
      return AppColors.danger;
    default:
      return AppColors.textMuted;
  }
}

IconData taskTypeIcon(int taskType) {
  switch (taskType) {
    case 1:
      return Icons.person_add_alt_1_rounded;
    case 2:
      return Icons.build_circle_outlined;
    case 4:
      return Icons.payments_outlined;
    default:
      return Icons.assignment_outlined;
  }
}

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
  });

  final EmployeeTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = task.createdAt;
    final dateStr = date == null
        ? '—'
        : DateFormat('yyyy/MM/dd  HH:mm').format(date.toLocal());
    final color = statusColor(task.status);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(taskTypeIcon(task.taskType), color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.displayTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: AppColors.text,
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            task.statusLabel,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      task.taskTypeLabel,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (task.note != null && task.note!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        task.note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_left_rounded, color: Colors.grey.shade400),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
