class LoginResult {
  final String token;
  final String? role;
  final String? fullName;
  final String? username;
  final String? companyName;
  final int? expiresInSeconds;

  const LoginResult({
    required this.token,
    this.role,
    this.fullName,
    this.username,
    this.companyName,
    this.expiresInSeconds,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      token: (json['token'] ?? json['Token'] ?? '').toString(),
      role: (json['role'] ?? json['Role'])?.toString(),
      fullName: (json['fullName'] ?? json['FullName'])?.toString(),
      username: (json['username'] ?? json['Username'])?.toString(),
      companyName: (json['companyName'] ?? json['CompanyName'])?.toString(),
      expiresInSeconds: _asInt(json['expiresInSeconds'] ?? json['ExpiresInSeconds']),
    );
  }

  bool get isEmployee {
    final r = role?.toLowerCase() ?? '';
    return r == 'employee' || r == '4';
  }
}

class EmployeeTask {
  final String id;
  final int taskType;
  final int status;
  final String? taskTitle;
  final String? taskDetails;
  final String? note;
  final String? subscriberId;
  final String? subscriberDisplayName;
  final int? maintenanceType;
  final double? amountReceived;
  final String? newSubscriberName;
  final String? newSubscriberPhone;
  final String? newSubscriberAddress;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final String? rejectionReason;
  final String? completedNote;
  final String? createdByUserName;
  final String? employeeName;

  const EmployeeTask({
    required this.id,
    required this.taskType,
    required this.status,
    this.taskTitle,
    this.taskDetails,
    this.note,
    this.subscriberId,
    this.subscriberDisplayName,
    this.maintenanceType,
    this.amountReceived,
    this.newSubscriberName,
    this.newSubscriberPhone,
    this.newSubscriberAddress,
    this.createdAt,
    this.acceptedAt,
    this.completedAt,
    this.rejectionReason,
    this.completedNote,
    this.createdByUserName,
    this.employeeName,
  });

  factory EmployeeTask.fromJson(Map<String, dynamic> json) {
    return EmployeeTask(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      taskType: _asInt(json['taskType'] ?? json['TaskType']) ?? 0,
      status: _asInt(json['status'] ?? json['Status']) ?? 1,
      taskTitle: _asString(json['taskTitle'] ?? json['TaskTitle']),
      taskDetails: _asString(json['taskDetails'] ?? json['TaskDetails']),
      note: _asString(json['note'] ?? json['Note']),
      subscriberId: _asString(json['subscriberId'] ?? json['SubscriberId']),
      subscriberDisplayName: _asString(json['subscriberDisplayName'] ?? json['SubscriberDisplayName']),
      maintenanceType: _asInt(json['maintenanceType'] ?? json['MaintenanceType']),
      amountReceived: _asDouble(json['amountReceived'] ?? json['AmountReceived']),
      newSubscriberName: _asString(json['newSubscriberName'] ?? json['NewSubscriberName']),
      newSubscriberPhone: _asString(json['newSubscriberPhone'] ?? json['NewSubscriberPhone']),
      newSubscriberAddress: _asString(json['newSubscriberAddress'] ?? json['NewSubscriberAddress']),
      createdAt: _asDate(json['createdAt'] ?? json['CreatedAt']),
      acceptedAt: _asDate(json['acceptedAt'] ?? json['AcceptedAt']),
      completedAt: _asDate(json['completedAt'] ?? json['CompletedAt']),
      rejectionReason: _asString(json['rejectionReason'] ?? json['RejectionReason']),
      completedNote: _asString(json['completedNote'] ?? json['CompletedNote']),
      createdByUserName: _asString(json['createdByUserName'] ?? json['CreatedByUserName']),
      employeeName: _asString(json['employeeName'] ?? json['EmployeeName']),
    );
  }

  String get taskTypeLabel {
    switch (taskType) {
      case 1:
        return 'تنصيب مشترك';
      case 2:
        return 'صيانة مشترك';
      case 3:
        return 'أخرى';
      case 4:
        return 'استلام مبلغ';
      default:
        return 'مهمة';
    }
  }

  String get statusLabel {
    switch (status) {
      case 1:
        return 'معلقة';
      case 2:
        return 'مقبولة';
      case 3:
        return 'مكتملة';
      case 4:
        return 'مرفوضة';
      default:
        return '—';
    }
  }

  String get maintenanceTypeLabel {
    switch (maintenanceType) {
      case 1:
        return 'قطع كيبل';
      case 2:
        return 'مشكلة في الخدمة';
      case 3:
        return 'تغيير رمز الراوتر';
      case 4:
        return 'أخرى';
      case 5:
        return 'تبديل مسار';
      case 6:
        return 'استبدال راوتر';
      default:
        return '—';
    }
  }

  String get displayTitle {
    if (taskTitle != null && taskTitle!.trim().isNotEmpty) return taskTitle!.trim();
    if (subscriberDisplayName != null && subscriberDisplayName!.trim().isNotEmpty) {
      return '$taskTypeLabel — ${subscriberDisplayName!.trim()}';
    }
    if (newSubscriberName != null && newSubscriberName!.trim().isNotEmpty) {
      return '$taskTypeLabel — ${newSubscriberName!.trim()}';
    }
    return taskTypeLabel;
  }

  bool get isPending => status == 1;
  bool get isAccepted => status == 2;
  bool get isCompleted => status == 3;
  bool get isRejected => status == 4;
  bool get isMaintenance => taskType == 2;
  bool get isInstallation => taskType == 1;
  bool get isAmountReception => taskType == 4;
}

class PaginatedTasks {
  final List<EmployeeTask> data;
  final int currentPage;
  final int pageSize;
  final int totalItems;
  final int totalPages;

  const PaginatedTasks({
    required this.data,
    required this.currentPage,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
  });

  factory PaginatedTasks.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] ?? json['Data'] ?? [];
    final list = <EmployeeTask>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          list.add(EmployeeTask.fromJson(item));
        }
      }
    }
    return PaginatedTasks(
      data: list,
      currentPage: _asInt(json['currentPage'] ?? json['CurrentPage']) ?? 1,
      pageSize: _asInt(json['pageSize'] ?? json['PageSize']) ?? 20,
      totalItems: _asInt(json['totalItems'] ?? json['TotalItems']) ?? list.length,
      totalPages: _asInt(json['totalPages'] ?? json['TotalPages']) ?? 1,
    );
  }
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

String? _asString(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}
