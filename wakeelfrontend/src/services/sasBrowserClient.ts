/**
 * جلب مشتركي SAS من المتصفح.
 *
 * ملاحظة jt.iq: تسجيل الدخول من دومين Wakeel (cross-origin) يفشل غالباً (500)
 * لأن Laravel يحتاج كوكيز/XSRF من نفس الموقع. الحل: افتح ftth.jt.iq في تبويب،
 * سجّل دخولك، انسخ token من استجابة login، ثم الصقه هنا.
 */

export const SAS_LOGIN_PATH = 'admin/api/index.php/api/login';
export const SAS_USERS_PATH = 'admin/api/index.php/api/index/user';

export function normalizeSasBaseUrl(url: string): string {
  return (url || '').trim().replace(/\/+$/, '');
}

function sasLoginUrl(baseUrl: string): string {
  return `${normalizeSasBaseUrl(baseUrl)}/${SAS_LOGIN_PATH}`;
}

function sasUsersUrl(baseUrl: string): string {
  return `${normalizeSasBaseUrl(baseUrl)}/${SAS_USERS_PATH}`;
}

function sasBrowserHeaders(baseUrl: string): Record<string, string> {
  const b = normalizeSasBaseUrl(baseUrl);
  return {
    Accept: 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9,ar;q=0.8',
    'X-Requested-With': 'XMLHttpRequest',
    Origin: b,
    Referer: `${b}/`,
  };
}

export interface SasBrowserLoginResult {
  token: string;
  status?: number;
}

export interface SasBrowserUsersPage {
  data: unknown[];
  last_page?: number;
  current_page?: number;
  total?: number;
}

function parseJsonSafe(text: string): Record<string, unknown> {
  try {
    return JSON.parse(text) as Record<string, unknown>;
  } catch {
    throw new Error(`استجابة SAS ليست JSON صالحاً: ${text.slice(0, 200)}`);
  }
}

function extractTokenFromBody(body: Record<string, unknown>): string | null {
  const token = body.token ?? body.Token;
  return typeof token === 'string' && token.trim() ? token.trim() : null;
}

/** استخراج توكن من نص لصق (JWT خام أو JSON كامل من Network) */
export function parseSasTokenFromPaste(raw: string): string {
  const text = (raw || '').trim();
  if (!text) throw new Error('التوكن فارغ');

  if (text.toLowerCase().startsWith('bearer ')) {
    return text.slice(7).trim();
  }

  if (text.startsWith('{')) {
    const body = parseJsonSafe(text);
    const token = extractTokenFromBody(body);
    if (token) return token;
    throw new Error('لم يُعثَر على حقل token في JSON');
  }

  if (text.split('.').length === 3) return text;

  throw new Error('صيغة التوكن غير معروفة — الصق JWT أو JSON استجابة login');
}

/** تهيئة جلسة SAS (كوكيز Cloudflare / Laravel) — قد لا تنجح cross-origin */
export async function sasBrowserWarmup(baseUrl: string): Promise<void> {
  const b = normalizeSasBaseUrl(baseUrl);
  const headers = sasBrowserHeaders(baseUrl);
  const paths = [
    '/',
    '/admin/',
    '/sanctum/csrf-cookie',
    '/admin/api/index.php/api/resources/login',
  ];
  for (const path of paths) {
    try {
      await fetch(`${b}${path}`, {
        method: 'GET',
        headers,
        credentials: 'include',
        mode: 'cors',
      });
    } catch {
      /* تجاهل — cross-origin قد يمنع warmup */
    }
  }
}

function readXsrfTokenFromDocument(): string | null {
  try {
    const match = document.cookie.match(/(?:^|;\s*)XSRF-TOKEN=([^;]+)/);
    return match ? decodeURIComponent(match[1]) : null;
  } catch {
    return null;
  }
}

async function sasBrowserLoginAttempt(
  loginUrl: string,
  baseUrl: string,
  username: string,
  password: string,
  mode: 'json' | 'form' | 'multipart',
  userKey: string,
  pwdKey: string
): Promise<string | null> {
  const headers: Record<string, string> = { ...sasBrowserHeaders(baseUrl) };
  const xsrf = readXsrfTokenFromDocument();
  if (xsrf) headers['X-XSRF-TOKEN'] = xsrf;

  let res: Response;
  if (mode === 'json') {
    res = await fetch(loginUrl, {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'application/json' },
      credentials: 'include',
      mode: 'cors',
      body: JSON.stringify({ [userKey]: username, [pwdKey]: password }),
    });
  } else if (mode === 'form') {
    const body = new URLSearchParams();
    body.set(userKey, username);
    body.set(pwdKey, password);
    res = await fetch(loginUrl, {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'application/x-www-form-urlencoded' },
      credentials: 'include',
      mode: 'cors',
      body,
    });
  } else {
    const fd = new FormData();
    fd.append(userKey, username);
    fd.append(pwdKey, password);
    res = await fetch(loginUrl, {
      method: 'POST',
      headers,
      credentials: 'include',
      mode: 'cors',
      body: fd,
    });
  }

  const text = await res.text();
  if (!res.ok) return null;
  try {
    const body = parseJsonSafe(text);
    return extractTokenFromBody(body);
  } catch {
    return null;
  }
}

const LOGIN_FIELD_PAIRS: Array<[string, string]> = [
  ['username', 'password'],
  ['email', 'password'],
  ['username', 'pssword'],
];

const LOGIN_MODES: Array<'json' | 'form' | 'multipart'> = ['json', 'form', 'multipart'];

/**
 * تسجيل دخول SAS — يعمل فقط إن كان الطلب same-origin أو لوحة SAS تسمح CORS+كوكيز.
 * لـ jt.iq استخدم parseSasTokenFromPaste بعد الدخول من تبويب اللوحة.
 */
export async function sasBrowserLogin(
  baseUrl: string,
  username: string,
  password: string
): Promise<SasBrowserLoginResult> {
  await sasBrowserWarmup(baseUrl);
  const loginUrl = sasLoginUrl(baseUrl);
  const user = username.trim();

  for (const mode of LOGIN_MODES) {
    for (const [userKey, pwdKey] of LOGIN_FIELD_PAIRS) {
      const token = await sasBrowserLoginAttempt(loginUrl, baseUrl, user, password, mode, userKey, pwdKey);
      if (token) return { token, status: 200 };
    }
  }

  throw new Error(
    'فشل تسجيل الدخول (500/403). لوحات jt.iq: افتح اللوحة في تبويب جديد، سجّل دخولك، انسخ token من Network → login، ثم الصقه في تبويب «توكن من اللوحة».'
  );
}

async function sasBrowserFetchUsersPageOnce(
  baseUrl: string,
  token: string,
  page: number,
  perPage: number,
  mode: 'json' | 'form' | 'multipart'
): Promise<SasBrowserUsersPage> {
  const url = sasUsersUrl(baseUrl);
  const headers: Record<string, string> = {
    ...sasBrowserHeaders(baseUrl),
    Accept: 'application/json',
    Authorization: `Bearer ${token}`,
  };
  const xsrf = readXsrfTokenFromDocument();
  if (xsrf) headers['X-XSRF-TOKEN'] = xsrf;

  let res: Response;
  if (mode === 'json') {
    res = await fetch(url, {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'application/json' },
      credentials: 'include',
      mode: 'cors',
      body: JSON.stringify({ page, per_page: perPage }),
    });
  } else if (mode === 'form') {
    const body = new URLSearchParams();
    body.set('page', String(page));
    body.set('per_page', String(perPage));
    res = await fetch(url, {
      method: 'POST',
      headers,
      credentials: 'include',
      mode: 'cors',
      body,
    });
  } else {
    const fd = new FormData();
    fd.append('page', String(page));
    fd.append('per_page', String(perPage));
    res = await fetch(url, {
      method: 'POST',
      headers,
      credentials: 'include',
      mode: 'cors',
      body: fd,
    });
  }

  const text = await res.text();
  if (!res.ok) {
    const snippet = text?.trim().slice(0, 300) || `HTTP ${res.status}`;
    throw new Error(snippet);
  }
  const body = parseJsonSafe(text);
  const data = Array.isArray(body.data) ? body.data : [];
  return {
    data,
    last_page: typeof body.last_page === 'number' ? body.last_page : undefined,
    current_page: typeof body.current_page === 'number' ? body.current_page : undefined,
    total: typeof body.total === 'number' ? body.total : undefined,
  };
}

async function sasBrowserFetchUsersPage(
  baseUrl: string,
  token: string,
  page: number,
  perPage: number
): Promise<SasBrowserUsersPage> {
  const modes: Array<'json' | 'form' | 'multipart'> = ['json', 'multipart', 'form'];
  let lastErr: Error | null = null;
  for (const mode of modes) {
    try {
      return await sasBrowserFetchUsersPageOnce(baseUrl, token, page, perPage, mode);
    } catch (e) {
      lastErr = e instanceof Error ? e : new Error(String(e));
    }
  }
  throw lastErr ?? new Error('فشل جلب صفحة المشتركين من SAS');
}

/** جلب كل صفحات المشتركين بتوكن جاهز */
export async function sasBrowserFetchAllUsers(
  baseUrl: string,
  token: string,
  perPage = 100,
  onProgress?: (page: number, totalPages: number, loaded: number) => void
): Promise<unknown[]> {
  const cleanToken = parseSasTokenFromPaste(token);
  const all: unknown[] = [];
  let page = 1;
  let lastPage = 1;

  while (page <= lastPage) {
    const resp = await sasBrowserFetchUsersPage(baseUrl, cleanToken, page, perPage);
    if (resp.data.length) all.push(...resp.data);
    lastPage = resp.last_page ?? page;
    onProgress?.(page, lastPage, all.length);
    if (!resp.data.length || page >= lastPage) break;
    page += 1;
  }

  return all;
}

/** حزمة تصدير جاهزة للباكند — نفس شكل sas_fetch_users.py */
export function buildSasExportPayload(data: unknown[]): Record<string, unknown> {
  return {
    data,
    provider: 'sas',
    mode: 'subscriptions-all',
    includeAllStatuses: true,
  };
}

export function isJtIqPanel(baseUrl: string): boolean {
  return /jt\.iq/i.test(baseUrl || '');
}
