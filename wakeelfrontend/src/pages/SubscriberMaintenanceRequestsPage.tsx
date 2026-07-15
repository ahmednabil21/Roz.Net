import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useAuth } from '../contexts/AuthContext';
import { useMaintenanceNotifications } from '../contexts/MaintenanceNotificationsContext';
import { useDigits } from '../contexts/DigitsContext';
import { apiService } from '../services/api';
import { hasPageAction } from '../utils/employeePermissions';
import {
  AgentSubscriberMaintenanceRequestDto,
  EmployeeTaskCreateRequest,
  EmployeeTaskType,
  SubscriberAppProblemType,
  SubscriberMaintenanceKind,
  SubscriberMaintenanceRequestStatusCode,
  User,
  UserRole,
} from '../types';
import { showError, showSuccess } from '../utils/notifications';
import {
  CheckCircle2,
  MessageSquare,
  Phone,
  RefreshCw,
  User as UserIcon,
  Wrench,
  X,
  XCircle,
  ArrowRightLeft,
} from 'lucide-react';

const DASHBOARD_MAINTENANCE_AGENT_KEY = 'wakeel_maintenance_requests_agentId';

const PROBLEM_TYPE_LABELS: Record<number, string> = {
  [SubscriberAppProblemType.SubscriptionRenewal]: 'تجديد اشتراك',
  [SubscriberAppProblemType.WeakInternet]: 'ضعف بالانترنت',
  [SubscriberAppProblemType.NetworkPasswordChange]: 'تغيير رمز الشبكة',
  [SubscriberAppProblemType.CableCut]: 'قطع في الكيبل',
  [SubscriberAppProblemType.Other]: 'أخرى',
};

const STATUS_LABELS: Record<number, string> = {
  [SubscriberMaintenanceRequestStatusCode.Pending]: 'قيد الانتظار',
  [SubscriberMaintenanceRequestStatusCode.Accepted]: 'تم قبول الطلب من قبل الشركة',
  [SubscriberMaintenanceRequestStatusCode.TechnicianAssigned]: 'تم تعيين موظف فني وهو في طريقه اليك',
  [SubscriberMaintenanceRequestStatusCode.Completed]: 'تم اكمال الطلب',
  [SubscriberMaintenanceRequestStatusCode.Rejected]: 'مرفوض',
};

const problemTypeLabel = (req: AgentSubscriberMaintenanceRequestDto) =>
  req.problemTypeLabel || PROBLEM_TYPE_LABELS[Number(req.problemType)] || '—';

const statusLabel = (req: AgentSubscriberMaintenanceRequestDto) =>
  req.statusLabel || STATUS_LABELS[Number(req.status)] || '—';

const statusBadgeClass = (status: number) => {
  if (status === SubscriberMaintenanceRequestStatusCode.Pending) {
    return 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300';
  }
  if (status === SubscriberMaintenanceRequestStatusCode.Accepted) {
    return 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300';
  }
  if (status === SubscriberMaintenanceRequestStatusCode.TechnicianAssigned) {
    return 'bg-indigo-100 text-indigo-700 dark:bg-indigo-900/30 dark:text-indigo-300';
  }
  if (status === SubscriberMaintenanceRequestStatusCode.Completed) {
    return 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300';
  }
  if (status === SubscriberMaintenanceRequestStatusCode.Rejected) {
    return 'bg-rose-100 text-rose-700 dark:bg-rose-900/30 dark:text-rose-300';
  }
  return 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300';
};

const mapProblemTypeToMaintenanceKind = (problemType: number): SubscriberMaintenanceKind => {
  switch (problemType) {
    case SubscriberAppProblemType.CableCut:
      return SubscriberMaintenanceKind.CableCut;
    case SubscriberAppProblemType.WeakInternet:
      return SubscriberMaintenanceKind.ServiceProblem;
    case SubscriberAppProblemType.NetworkPasswordChange:
      return SubscriberMaintenanceKind.RouterPasswordChange;
    default:
      return SubscriberMaintenanceKind.Other;
  }
};

const maintenanceQueryKey = (status: '' | number, agentId?: string) =>
  ['agent-subscriber-maintenance', status === '' ? null : status, agentId ?? null] as const;

const matchesStatusFilter = (req: AgentSubscriberMaintenanceRequestDto, status: '' | number) =>
  status === '' || Number(req.status) === status;

type NoteModalMode = 'reject' | 'reply';

const SubscriberMaintenanceRequestsPage: React.FC = () => {
  const { user } = useAuth();
  const { formatDate } = useDigits();
  const queryClient = useQueryClient();
  const { markAsRead, refreshPendingCount } = useMaintenanceNotifications();
  const isAdmin = user?.role === UserRole.Admin;
  const isEmployee = user?.role === UserRole.Employee;

  const canAccept = !isEmployee || hasPageAction(user, 'MaintenanceRequests', 'accept');
  const canReject = !isEmployee || hasPageAction(user, 'MaintenanceRequests', 'reject');
  const canReply = !isEmployee || hasPageAction(user, 'MaintenanceRequests', 'reply');
  const canConvert = !isEmployee || hasPageAction(user, 'MaintenanceRequests', 'convert');

  const [statusFilter, setStatusFilter] = useState<'' | SubscriberMaintenanceRequestStatusCode>('');
  const [selectedAgentId, setSelectedAgentId] = useState('');
  const [actionId, setActionId] = useState<string | null>(null);

  const [noteModal, setNoteModal] = useState<{ mode: NoteModalMode; request: AgentSubscriberMaintenanceRequestDto } | null>(null);
  const [noteText, setNoteText] = useState('');

  const [convertRequest, setConvertRequest] = useState<AgentSubscriberMaintenanceRequestDto | null>(null);
  const [convertForm, setConvertForm] = useState<EmployeeTaskCreateRequest>({
    employeeUserId: '',
    taskType: EmployeeTaskType.SubscriberMaintenance,
    subscriberId: '',
    maintenanceType: SubscriberMaintenanceKind.CableCut,
    note: '',
  });

  const statusFilterRef = useRef(statusFilter);
  useEffect(() => {
    statusFilterRef.current = statusFilter;
  }, [statusFilter]);

  useEffect(() => {
    markAsRead();
  }, [markAsRead]);

  const { data: agentsResponse } = useQuery({
    queryKey: ['agents-for-maintenance', 1, 100],
    queryFn: () => apiService.getAllAgents({ page: 1, pageSize: 100 }),
    enabled: isAdmin,
  });
  const agents = useMemo(() => agentsResponse?.data ?? [], [agentsResponse]);

  const { data: myAgent } = useQuery({
    queryKey: ['my-agent-maintenance'],
    queryFn: () => apiService.getMyAgent(),
    enabled: !isAdmin,
  });

  useEffect(() => {
    if (!isAdmin || !agents.length) return;
    const saved = localStorage.getItem(DASHBOARD_MAINTENANCE_AGENT_KEY);
    if (saved && agents.some((a) => a.id === saved)) {
      setSelectedAgentId(saved);
    } else {
      setSelectedAgentId(agents[0]?.id ?? '');
    }
  }, [isAdmin, agents]);

  useEffect(() => {
    if (!isAdmin || !selectedAgentId) return;
    localStorage.setItem(DASHBOARD_MAINTENANCE_AGENT_KEY, selectedAgentId);
  }, [isAdmin, selectedAgentId]);

  const effectiveAgentId = isAdmin ? selectedAgentId : myAgent?.id;
  const canLoadData = isAdmin ? !!effectiveAgentId : true;

  const queryParams = useMemo(
    () => ({
      status: statusFilter === '' ? undefined : statusFilter,
      agentId: isAdmin ? effectiveAgentId || undefined : undefined,
    }),
    [statusFilter, isAdmin, effectiveAgentId]
  );

  const { data: requests = [], isLoading, refetch, isFetching } = useQuery({
    queryKey: maintenanceQueryKey(statusFilter, queryParams.agentId),
    queryFn: () => apiService.getAgentSubscriberMaintenanceRequests(queryParams),
    enabled: canLoadData,
  });

  const { data: myEmployees = [] } = useQuery<User[]>({
    queryKey: ['my-employees-for-maintenance-convert'],
    queryFn: () => apiService.getMyEmployees(),
    enabled: !!convertRequest && !isAdmin,
  });

  const { data: adminEmployees = [] } = useQuery<User[]>({
    queryKey: ['agent-employees-for-maintenance-convert', effectiveAgentId],
    queryFn: () => apiService.getAgentEmployees(effectiveAgentId!),
    enabled: !!convertRequest && isAdmin && !!effectiveAgentId,
  });

  const employeesOptions = isAdmin ? adminEmployees : myEmployees;

  const upsertRequestInCache = useCallback(
    (request: AgentSubscriberMaintenanceRequestDto) => {
      queryClient.setQueriesData<AgentSubscriberMaintenanceRequestDto[]>(
        { queryKey: ['agent-subscriber-maintenance'] },
        (old) => {
          if (!old) return old;
          const filter = statusFilterRef.current;
          const idx = old.findIndex((r) => r.id === request.id);
          if (idx >= 0) {
            if (!matchesStatusFilter(request, filter)) {
              return old.filter((r) => r.id !== request.id);
            }
            const next = [...old];
            next[idx] = request;
            return next;
          }
          if (!matchesStatusFilter(request, filter)) return old;
          return [request, ...old];
        }
      );
    },
    [queryClient]
  );

  const acceptMutation = useMutation({
    mutationFn: (id: string) => apiService.acceptSubscriberMaintenanceRequest(id),
    onMutate: (id) => setActionId(id),
    onSuccess: (updated) => {
      upsertRequestInCache(updated);
      refreshPendingCount();
      showSuccess('تم القبول', 'تم قبول الطلب من قبل الشركة');
    },
    onError: (err: Error) => showError('فشل القبول', err.message || 'تعذّر قبول الطلب'),
    onSettled: () => setActionId(null),
  });

  const rejectMutation = useMutation({
    mutationFn: ({ id, note }: { id: string; note?: string }) =>
      apiService.rejectSubscriberMaintenanceRequest(id, note),
    onMutate: ({ id }) => setActionId(id),
    onSuccess: (updated) => {
      upsertRequestInCache(updated);
      refreshPendingCount();
      setNoteModal(null);
      setNoteText('');
      showSuccess('تم الرفض', 'تم رفض طلب الصيانة');
    },
    onError: (err: Error) => showError('فشل الرفض', err.message || 'تعذّر رفض الطلب'),
    onSettled: () => setActionId(null),
  });

  const replyMutation = useMutation({
    mutationFn: ({ id, note }: { id: string; note: string }) =>
      apiService.replySubscriberMaintenanceRequest(id, note),
    onMutate: ({ id }) => setActionId(id),
    onSuccess: (updated) => {
      upsertRequestInCache(updated);
      setNoteModal(null);
      setNoteText('');
      showSuccess('تم الرد', 'ظهرت الملاحظة للمشترك');
    },
    onError: (err: Error) => showError('فشل الرد', err.message || 'تعذّر إرسال الملاحظة'),
    onSettled: () => setActionId(null),
  });

  const convertMutation = useMutation({
    mutationFn: (payload: EmployeeTaskCreateRequest) => apiService.createEmployeeTask(payload),
    onSuccess: (_task, variables) => {
      queryClient.invalidateQueries({ queryKey: ['agent-subscriber-maintenance'] });
      queryClient.invalidateQueries({ queryKey: ['employee-tasks'] });
      refreshPendingCount();
      setConvertRequest(null);
      showSuccess('تم التحويل', 'تم إنشاء المهمة وتعيين الموظف الفني');
      if (variables.maintenanceRequestId) {
        // الحالة تتحدث عبر SignalR أو الـ invalidate أعلاه
      }
    },
    onError: (err: Error) => showError('فشل التحويل', err.message || 'تعذّر إنشاء المهمة'),
  });

  const openConvertModal = (req: AgentSubscriberMaintenanceRequestDto) => {
    setConvertRequest(req);
    setConvertForm({
      employeeUserId: '',
      taskType: EmployeeTaskType.SubscriberMaintenance,
      subscriberId: req.subscriberId || '',
      maintenanceRequestId: req.id,
      maintenanceType: mapProblemTypeToMaintenanceKind(Number(req.problemType)),
      note: req.description || '',
      taskDetails: req.description || undefined,
    });
  };

  const submitNoteModal = () => {
    if (!noteModal) return;
    const trimmed = noteText.trim();
    if (noteModal.mode === 'reply') {
      if (!trimmed) {
        showError('الملاحظة مطلوبة', 'أدخل ملاحظة تظهر للمشترك');
        return;
      }
      replyMutation.mutate({ id: noteModal.request.id, note: trimmed });
      return;
    }
    rejectMutation.mutate({ id: noteModal.request.id, note: trimmed || undefined });
  };

  const submitConvert = () => {
    if (!convertForm.employeeUserId) {
      showError('الموظف مطلوب', 'اختر الموظف الفني');
      return;
    }
    if (!convertForm.subscriberId || !convertForm.maintenanceRequestId) {
      showError('بيانات ناقصة', 'تعذّر تحديد المشترك أو طلب الصيانة');
      return;
    }
    convertMutation.mutate({
      ...convertForm,
      taskType: EmployeeTaskType.SubscriberMaintenance,
    });
  };

  const pendingCount = requests.filter(
    (r) => Number(r.status) === SubscriberMaintenanceRequestStatusCode.Pending
  ).length;

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white flex items-center gap-2">
            <Wrench className="h-7 w-7 text-primary-600" />
            طلبات صيانة المشتركين
          </h1>
          <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">
            متابعة طلبات الصيانة الواردة من تطبيق المشترك
            {pendingCount > 0 ? ` · ${pendingCount} بانتظار القبول` : ''}
          </p>
        </div>
        <button
          type="button"
          onClick={() => refetch()}
          disabled={isFetching}
          className="inline-flex items-center gap-2 px-4 py-2 bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 rounded-md text-gray-700 dark:text-gray-200 disabled:opacity-60"
        >
          <RefreshCw className={`h-4 w-4 ${isFetching ? 'animate-spin' : ''}`} />
          تحديث
        </button>
      </div>

      <div className="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700 p-4">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          {isAdmin && (
            <select
              value={selectedAgentId}
              onChange={(e) => setSelectedAgentId(e.target.value)}
              className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
            >
              <option value="">اختر الوكيل</option>
              {agents.map((agent) => (
                <option key={agent.id} value={agent.id}>
                  {agent.companyName || agent.fullName || agent.username}
                </option>
              ))}
            </select>
          )}
          <select
            value={statusFilter}
            onChange={(e) => {
              const v = e.target.value;
              setStatusFilter(v === '' ? '' : (parseInt(v, 10) as SubscriberMaintenanceRequestStatusCode));
            }}
            className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
          >
            <option value="">كل الحالات</option>
            <option value={SubscriberMaintenanceRequestStatusCode.Pending}>قيد الانتظار</option>
            <option value={SubscriberMaintenanceRequestStatusCode.Accepted}>تم قبول الطلب من قبل الشركة</option>
            <option value={SubscriberMaintenanceRequestStatusCode.TechnicianAssigned}>
              تم تعيين موظف فني وهو في طريقه اليك
            </option>
            <option value={SubscriberMaintenanceRequestStatusCode.Completed}>تم اكمال الطلب</option>
            <option value={SubscriberMaintenanceRequestStatusCode.Rejected}>مرفوض</option>
          </select>
        </div>
      </div>

      <div className="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700 overflow-hidden">
        {isAdmin && !effectiveAgentId ? (
          <div className="px-4 py-10 text-center text-gray-500 dark:text-gray-400">
            يرجى اختيار الوكيل لعرض الطلبات.
          </div>
        ) : isLoading ? (
          <div className="px-4 py-10 text-center text-gray-500 dark:text-gray-400">جاري التحميل...</div>
        ) : requests.length === 0 ? (
          <div className="px-4 py-10 text-center text-gray-500 dark:text-gray-400">لا توجد طلبات صيانة.</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead className="bg-gray-50 dark:bg-gray-900/50">
                <tr>
                  <th className="px-4 py-3 text-right text-xs font-semibold text-gray-600 dark:text-gray-300">المشترك</th>
                  <th className="px-4 py-3 text-right text-xs font-semibold text-gray-600 dark:text-gray-300">المنطقة / الرسيلر</th>
                  <th className="px-4 py-3 text-right text-xs font-semibold text-gray-600 dark:text-gray-300">نوع المشكلة</th>
                  <th className="px-4 py-3 text-right text-xs font-semibold text-gray-600 dark:text-gray-300">الوصف</th>
                  <th className="px-4 py-3 text-right text-xs font-semibold text-gray-600 dark:text-gray-300">ملاحظة الشركة</th>
                  <th className="px-4 py-3 text-right text-xs font-semibold text-gray-600 dark:text-gray-300">الهاتف</th>
                  <th className="px-4 py-3 text-right text-xs font-semibold text-gray-600 dark:text-gray-300">الحالة</th>
                  <th className="px-4 py-3 text-right text-xs font-semibold text-gray-600 dark:text-gray-300">التاريخ</th>
                  <th className="px-4 py-3 text-right text-xs font-semibold text-gray-600 dark:text-gray-300">إجراء</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
                {requests.map((req) => {
                  const statusNum = Number(req.status);
                  const isPending = statusNum === SubscriberMaintenanceRequestStatusCode.Pending;
                  const isAccepted = statusNum === SubscriberMaintenanceRequestStatusCode.Accepted;
                  const canActOnOpen =
                    isPending || isAccepted || statusNum === SubscriberMaintenanceRequestStatusCode.TechnicianAssigned;
                  const phone = req.alternativePhoneNumber || req.subscriberPhoneNumber;
                  const busy = actionId === req.id;

                  return (
                    <tr key={req.id} className="hover:bg-gray-50 dark:hover:bg-gray-700/30">
                      <td className="px-4 py-3 whitespace-nowrap">
                        <div className="flex items-center gap-2">
                          <UserIcon className="h-4 w-4 text-gray-400 flex-shrink-0" />
                          <div className="min-w-0">
                            <p className="font-medium text-gray-900 dark:text-white truncate">
                              {req.subscriberFullName || '—'}
                            </p>
                            <p className="text-xs text-gray-500 dark:text-gray-400 truncate" dir="ltr">
                              {req.subscriberUsername || '—'}
                            </p>
                          </div>
                        </div>
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-600 dark:text-gray-300">
                        <p className="truncate">{req.regionName || '—'}</p>
                        <p className="text-xs text-gray-500 dark:text-gray-400 truncate mt-0.5">
                          {req.agentResellerName || '—'}
                        </p>
                      </td>
                      <td className="px-4 py-3 whitespace-nowrap text-sm text-gray-800 dark:text-gray-200">
                        {problemTypeLabel(req)}
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-600 dark:text-gray-300 max-w-[180px]">
                        <p className="truncate" title={req.description || undefined}>
                          {req.description || '—'}
                        </p>
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-600 dark:text-gray-300 max-w-[180px]">
                        <p className="truncate" title={req.agentNote || undefined}>
                          {req.agentNote || '—'}
                        </p>
                      </td>
                      <td className="px-4 py-3 whitespace-nowrap text-sm text-gray-700 dark:text-gray-300">
                        {phone ? (
                          <span className="inline-flex items-center gap-1" dir="ltr">
                            <Phone className="h-3.5 w-3.5 text-gray-400" />
                            {phone}
                          </span>
                        ) : (
                          '—'
                        )}
                      </td>
                      <td className="px-4 py-3 whitespace-nowrap">
                        <span
                          className={`inline-flex px-2.5 py-1 rounded-full text-xs font-semibold ${statusBadgeClass(statusNum)}`}
                        >
                          {statusLabel(req)}
                        </span>
                      </td>
                      <td className="px-4 py-3 whitespace-nowrap text-sm text-gray-600 dark:text-gray-300">
                        {req.createdAt ? formatDate(req.createdAt) : '—'}
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex flex-wrap items-center gap-1.5">
                          {isPending && canAccept && (
                            <button
                              type="button"
                              onClick={() => acceptMutation.mutate(req.id)}
                              disabled={busy}
                              className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-md text-xs font-semibold bg-primary-600 hover:bg-primary-700 text-white disabled:opacity-60"
                            >
                              <CheckCircle2 className="h-3.5 w-3.5" />
                              {busy && acceptMutation.isPending ? 'جاري...' : 'قبول'}
                            </button>
                          )}
                          {(isPending || isAccepted) && canReject && (
                            <button
                              type="button"
                              onClick={() => {
                                setNoteText('');
                                setNoteModal({ mode: 'reject', request: req });
                              }}
                              disabled={busy}
                              className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-md text-xs font-semibold bg-rose-600 hover:bg-rose-700 text-white disabled:opacity-60"
                            >
                              <XCircle className="h-3.5 w-3.5" />
                              رفض
                            </button>
                          )}
                          {canActOnOpen && canReply && (
                            <button
                              type="button"
                              onClick={() => {
                                setNoteText(req.agentNote || '');
                                setNoteModal({ mode: 'reply', request: req });
                              }}
                              disabled={busy}
                              className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-md text-xs font-semibold bg-slate-600 hover:bg-slate-700 text-white disabled:opacity-60"
                            >
                              <MessageSquare className="h-3.5 w-3.5" />
                              رد بملاحظة
                            </button>
                          )}
                          {isAccepted && canConvert && (
                            <button
                              type="button"
                              onClick={() => openConvertModal(req)}
                              disabled={busy}
                              className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-md text-xs font-semibold bg-indigo-600 hover:bg-indigo-700 text-white disabled:opacity-60"
                            >
                              <ArrowRightLeft className="h-3.5 w-3.5" />
                              تحويل المهمة
                            </button>
                          )}
                          {!isPending && !isAccepted && !canActOnOpen && (
                            <span className="text-xs text-gray-400">—</span>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {noteModal && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-3">
          <div className="w-full max-w-md bg-white dark:bg-gray-800 rounded-lg shadow-xl border border-gray-200 dark:border-gray-700">
            <div className="p-4 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between">
              <h3 className="font-semibold text-gray-900 dark:text-white">
                {noteModal.mode === 'reject' ? 'رفض طلب الصيانة' : 'رد بملاحظة للمشترك'}
              </h3>
              <button
                type="button"
                onClick={() => {
                  setNoteModal(null);
                  setNoteText('');
                }}
                className="p-1.5 rounded-md hover:bg-gray-100 dark:hover:bg-gray-700"
              >
                <X className="h-5 w-5 text-gray-600 dark:text-gray-400" />
              </button>
            </div>
            <div className="p-4 space-y-3">
              <p className="text-sm text-gray-600 dark:text-gray-300">
                المشترك: {noteModal.request.subscriberFullName || '—'} · {problemTypeLabel(noteModal.request)}
              </p>
              <textarea
                value={noteText}
                onChange={(e) => setNoteText(e.target.value)}
                rows={4}
                placeholder={
                  noteModal.mode === 'reject'
                    ? 'سبب الرفض (اختياري) — يظهر للمشترك إن وُجد'
                    : 'اكتب ملاحظة تظهر للمشترك...'
                }
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
              />
              <div className="flex justify-end gap-2">
                <button
                  type="button"
                  onClick={() => {
                    setNoteModal(null);
                    setNoteText('');
                  }}
                  className="px-3 py-2 rounded-md text-sm bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-200"
                >
                  إلغاء
                </button>
                <button
                  type="button"
                  onClick={submitNoteModal}
                  disabled={rejectMutation.isPending || replyMutation.isPending}
                  className={`px-3 py-2 rounded-md text-sm font-semibold text-white disabled:opacity-60 ${
                    noteModal.mode === 'reject' ? 'bg-rose-600 hover:bg-rose-700' : 'bg-primary-600 hover:bg-primary-700'
                  }`}
                >
                  {rejectMutation.isPending || replyMutation.isPending
                    ? 'جاري...'
                    : noteModal.mode === 'reject'
                      ? 'تأكيد الرفض'
                      : 'إرسال الملاحظة'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {convertRequest && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-3">
          <div className="w-full max-w-xl bg-white dark:bg-gray-800 rounded-lg shadow-xl border border-gray-200 dark:border-gray-700">
            <div className="p-4 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between">
              <h3 className="font-semibold text-gray-900 dark:text-white">إضافة مهمة — تحويل طلب صيانة</h3>
              <button
                type="button"
                onClick={() => setConvertRequest(null)}
                className="p-1.5 rounded-md hover:bg-gray-100 dark:hover:bg-gray-700"
              >
                <X className="h-5 w-5 text-gray-600 dark:text-gray-400" />
              </button>
            </div>
            <div className="p-4 grid grid-cols-1 gap-3">
              <div className="rounded-md border border-indigo-200 dark:border-indigo-800 bg-indigo-50/70 dark:bg-indigo-900/20 px-3 py-2 text-sm text-indigo-900 dark:text-indigo-200">
                المشترك: <strong>{convertRequest.subscriberFullName}</strong> · {problemTypeLabel(convertRequest)}
              </div>

              <select
                value={convertForm.employeeUserId}
                onChange={(e) => setConvertForm((p) => ({ ...p, employeeUserId: e.target.value }))}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
              >
                <option value="">اختر الموظف *</option>
                {employeesOptions.map((emp) => (
                  <option key={emp.id} value={emp.id}>
                    {emp.fullName} (@{emp.username})
                  </option>
                ))}
              </select>

              <select
                value={EmployeeTaskType.SubscriberMaintenance}
                disabled
                className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white opacity-80"
              >
                <option value={EmployeeTaskType.SubscriberMaintenance}>صيانة مشترك</option>
              </select>

              <input
                type="text"
                value={convertRequest.subscriberFullName || convertForm.subscriberId || ''}
                disabled
                className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white opacity-80"
              />

              <select
                value={convertForm.maintenanceType ?? SubscriberMaintenanceKind.CableCut}
                onChange={(e) =>
                  setConvertForm((p) => ({
                    ...p,
                    maintenanceType: parseInt(e.target.value, 10) as SubscriberMaintenanceKind,
                  }))
                }
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
              >
                <option value={SubscriberMaintenanceKind.CableCut}>قطع كيبل</option>
                <option value={SubscriberMaintenanceKind.ServiceProblem}>مشكلة في الخدمة</option>
                <option value={SubscriberMaintenanceKind.RouterPasswordChange}>تغيير رمز الراوتر</option>
                <option value={SubscriberMaintenanceKind.Other}>اخرى</option>
              </select>

              <textarea
                value={convertForm.note || ''}
                onChange={(e) => setConvertForm((p) => ({ ...p, note: e.target.value }))}
                rows={3}
                placeholder="ملاحظة للمهمة (اختياري)"
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
              />

              <div className="flex justify-end gap-2 pt-1">
                <button
                  type="button"
                  onClick={() => setConvertRequest(null)}
                  className="px-3 py-2 rounded-md text-sm bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-200"
                >
                  إلغاء
                </button>
                <button
                  type="button"
                  onClick={submitConvert}
                  disabled={convertMutation.isPending}
                  className="px-3 py-2 rounded-md text-sm font-semibold bg-indigo-600 hover:bg-indigo-700 text-white disabled:opacity-60"
                >
                  {convertMutation.isPending ? 'جاري الإنشاء...' : 'إنشاء المهمة'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default SubscriberMaintenanceRequestsPage;
