import { APP_NAME } from '../constants/branding';

type RouteTitleRule = {
  test: (pathname: string) => boolean;
  title: string;
};

const ROUTE_TITLE_RULES: RouteTitleRule[] = [
  { test: (p) => p === '/' || p === '', title: 'الرئيسية' },
  { test: (p) => p === '/login', title: 'تسجيل الدخول' },
  { test: (p) => p === '/register-agent', title: 'تسجيل وكيل' },
  { test: (p) => p === '/system-pricing', title: 'أسعار النظام' },
  { test: (p) => p === '/subscriber-info', title: 'معلومات المشترك' },
  { test: (p) => p === '/admin/dashboard', title: 'لوحة التحكم' },
  { test: (p) => /^\/admin\/subscribers\/[^/]+$/.test(p), title: 'تفاصيل المشترك' },
  { test: (p) => p === '/admin/subscribers', title: 'المشتركين' },
  { test: (p) => p === '/admin/maintenance-requests', title: 'طلبات الصيانة' },
  { test: (p) => p === '/admin/packages', title: 'الباقات' },
  { test: (p) => p === '/admin/materials', title: 'إدارة المواد' },
  { test: (p) => p === '/admin/materials/disbursed', title: 'شاشة البيع' },
  { test: (p) => p === '/admin/materials/sales-history', title: 'سجل المبيعات' },
  { test: (p) => p === '/admin/agents', title: 'الوكلاء' },
  { test: (p) => p === '/admin/employees', title: 'الموظفين' },
  { test: (p) => p === '/admin/employees/tasks', title: 'مهام الموظفين' },
  { test: (p) => p === '/admin/users', title: 'المستخدمين' },
  { test: (p) => p === '/admin/system-message', title: 'رسالة النظام' },
  { test: (p) => p === '/admin/reports', title: 'الحسابات' },
  { test: (p) => p === '/admin/receipts', title: 'التفعيلات' },
  { test: (p) => p === '/admin/balance', title: 'الرصيد' },
  { test: (p) => p === '/admin/activity-log', title: 'سجل الحركات' },
  { test: (p) => p === '/admin/receipt-handover', title: 'الاستلام والتسليم' },
  { test: (p) => p === '/admin/customer-invoices', title: 'فواتير العملاء' },
  { test: (p) => p === '/admin/debts', title: 'الديون' },
  { test: (p) => p === '/admin/expenses/office', title: 'المصاريف العامة' },
  { test: (p) => p === '/admin/expenses/salary-sheet', title: 'كشوفات الموظفين' },
  { test: (p) => p === '/admin/settings', title: 'الإعدادات' },
  { test: (p) => p === '/admin/excel-import', title: 'الاستيراد' },
  { test: (p) => p === '/admin/resellers', title: 'الرسيلرات' },
  { test: (p) => p === '/admin/main-agent/sub-agents', title: 'المكاتب الفرعية' },
  { test: (p) => p === '/admin/main-agent/sub-agents/new', title: 'إضافة مكتب فرعي' },
  { test: (p) => /^\/admin\/main-agent\/sub-agents\/[^/]+\/edit$/.test(p), title: 'تعديل مكتب فرعي' },
  { test: (p) => p === '/admin/main-agent/sub-agents/subscribers', title: 'مشتركي المكاتب الفرعية' },
  { test: (p) => p === '/admin/main-agent/sub-agents/renewals', title: 'تفعيلات المكاتب الفرعية' },
  { test: (p) => p === '/admin/main-agent/sub-agents/debts', title: 'ديون المكاتب الفرعية' },
  { test: (p) => p === '/admin/main-agent/sub-agents/daily-account', title: 'حسابات المكاتب الفرعية' },
];

export function getPageTitle(pathname: string): string {
  const normalized = pathname.replace(/\/+$/, '') || '/';
  const rule = ROUTE_TITLE_RULES.find((r) => r.test(normalized));
  return rule?.title ?? APP_NAME;
}

export function formatDocumentTitle(pathname: string): string {
  const pageTitle = getPageTitle(pathname);
  return pageTitle === APP_NAME ? APP_NAME : `${pageTitle} | ${APP_NAME}`;
}
