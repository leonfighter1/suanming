/**
 * 管理后台 (v11.2.0, tech plan S22): the dashboard's numbers, worked out from the rows (accounts, 积分 changes, AI
 * use). Pure functions over plain data, so tests pin them by hand.
 *
 * Money is in 元: 充值 is what was paid for the packs; its net leaves out the payment fee and VAT; the AI cost is the
 * usage's dollars at usd_cny; the gross profit is the net less the AI cost (cash in a period against what its AI
 * cost). 积分 flow apart: sold (充值), granted, used (charges), and what accounts hold now.
 */
import {
  permissionsOf,
  type AccountPermissions,
  type AccountRole,
  type UserRecord,
} from "../auth/service.js";
import { maskEmail, maskPhone } from "../auth/identifiers.js";
import type { PointsBalance, PointsConfig, PointsEntry } from "../points/index.js";
import type { UsageRow } from "./usage.js";

export interface AdminData {
  users: UserRecord[];
  /** Every 积分 change, oldest first. */
  entries: PointsEntry[];
  /** Every AI step, oldest first. */
  usage: UsageRow[];
  balances: Map<string, PointsBalance>;
  config: PointsConfig;
  now: Date;
  /** Whose calendar a day is: the dashboard's time zone. */
  tz: string;
  /** Admins named in the server's settings (MINGLI_ADMINS): an admin whatever their record says. */
  configAdmin?: (u: UserRecord) => boolean;
}

const formats = new Map<string, Intl.DateTimeFormat>();

/** The calendar day of an instant in [tz], YYYY-MM-DD. */
export function localDay(iso: string, tz: string): string {
  let f = formats.get(tz);
  if (!f) {
    f = new Intl.DateTimeFormat("en-CA", {
      timeZone: tz,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    });
    formats.set(tz, f);
  }
  return f.format(new Date(iso));
}

/** The last [days] calendar days in [tz], today the last. */
export function windowDays(now: Date, days: number, tz: string): string[] {
  const [y, m, d] = localDay(now.toISOString(), tz).split("-").map(Number) as [
    number,
    number,
    number,
  ];
  return Array.from({ length: days }, (_, i) =>
    new Date(Date.UTC(y, m - 1, d - (days - 1 - i), 12)).toISOString().slice(0, 10),
  );
}

const cents = (x: number) => Math.round(x * 100) / 100;
const tokensOf = (r: UsageRow) =>
  r.input_tokens + r.output_tokens + r.cache_read_tokens + r.cache_write_tokens;

/** 充值's net: what is left of a payment after the payment service's fee and VAT. */
export const netOf = (c: PointsConfig, yuan: number) =>
  yuan * (1 - c.pricing.payment_fee - c.pricing.vat);

export interface Money {
  topup_cny: number;
  net_cny: number;
  cost_cny: number;
  profit_cny: number;
  /** Profit over net; null without any net. */
  margin: number | null;
}

function money(c: PointsConfig, topupYuan: number, costUsd: number): Money {
  const net = netOf(c, topupYuan);
  const cost = costUsd * c.pricing.usd_cny;
  return {
    topup_cny: cents(topupYuan),
    net_cny: cents(net),
    cost_cny: cents(cost),
    profit_cny: cents(net - cost),
    margin: net > 0 ? Math.round(((net - cost) / net) * 1000) / 1000 : null,
  };
}

export interface DayRow extends Money {
  day: string;
  new_accounts: number;
  /** Accounts that ran an AI job or changed their 积分 that day. */
  active_accounts: number;
  /** AI jobs that day (a 深度分析's turns are one job). */
  jobs: number;
  input_tokens: number;
  output_tokens: number;
  tokens: number;
  points_sold: number;
  points_granted: number;
  points_used: number;
}

/** Day by day over the last [days] days, oldest first. */
export function series(d: AdminData, days: number): DayRow[] {
  const keys = windowDays(d.now, days, d.tz);
  const rows = new Map(
    keys.map((day) => [
      day,
      {
        day,
        joined: 0,
        active: new Set<string>(),
        jobs: new Set<string>(),
        input: 0,
        output: 0,
        tokens: 0,
        usd: 0,
        yuan: 0,
        sold: 0,
        granted: 0,
        used: 0,
      },
    ]),
  );
  for (const u of d.users) {
    const r = rows.get(localDay(u.created_at, d.tz));
    if (r) r.joined++;
  }
  for (const u of d.usage) {
    const r = rows.get(localDay(u.created_at, d.tz));
    if (!r) continue;
    r.jobs.add(u.job_id);
    if (u.owner) r.active.add(u.owner);
    r.input += u.input_tokens;
    r.output += u.output_tokens;
    r.tokens += tokensOf(u);
    r.usd += u.usd;
  }
  for (const e of d.entries) {
    const r = rows.get(localDay(e.created_at, d.tz));
    if (!r) continue;
    r.active.add(e.owner);
    if (e.kind === "topup") {
      r.sold += e.points;
      r.yuan += e.pack?.yuan ?? 0;
    } else if (e.kind === "grant") r.granted += e.points;
    else r.used -= e.points;
  }
  return keys.map((day) => {
    const r = rows.get(day)!;
    return {
      day,
      new_accounts: r.joined,
      active_accounts: r.active.size,
      jobs: r.jobs.size,
      input_tokens: r.input,
      output_tokens: r.output,
      tokens: r.tokens,
      points_sold: r.sold,
      points_granted: r.granted,
      points_used: r.used,
      ...money(d.config, r.yuan, r.usd),
    };
  });
}

export interface Overview {
  days: number;
  from: string;
  to: string;
  accounts: { total: number; new: number; suspended: number; admins: number; demo: number };
  /** Accounts active in the last 15 minutes, 24 hours, 7 and 30 days (by their last request). */
  active: { now: number; day: number; week: number; month: number };
  ai: {
    jobs: number;
    delivered_jobs: number;
    input_tokens: number;
    output_tokens: number;
    tokens: number;
    cost_usd: number;
  };
  money: Money;
  /** The period's 积分 flows, and what accounts hold now. */
  points: { sold: number; granted: number; used: number; outstanding: number };
  /** The [days] days before the period, summed alike: what 概览's changes are measured against (v12.3.0). */
  previous: Previous;
}

/**
 * The period before: its new accounts, AI use, money and 积分 flows. No snapshots (who is active, what accounts hold):
 * those are now's.
 */
export interface Previous {
  from: string;
  to: string;
  accounts: { new: number };
  ai: { jobs: number; tokens: number; cost_usd: number };
  money: Money;
  points: { sold: number; granted: number; used: number };
}

/** The [days] days before the last [days], summed as [overview] sums its period. */
function previousOf(d: AdminData, days: number): Previous {
  const day = series(d, days * 2).slice(0, days);
  const from = day[0]!.day;
  const to = day.at(-1)!.day;
  const usage = d.usage.filter((u) => {
    const local = localDay(u.created_at, d.tz);
    return local >= from && local <= to;
  });
  const sum = <K extends keyof DayRow>(k: K) => day.reduce((n, r) => n + (r[k] as number), 0);
  return {
    from,
    to,
    accounts: { new: sum("new_accounts") },
    ai: {
      jobs: new Set(usage.map((u) => u.job_id)).size,
      tokens: sum("tokens"),
      cost_usd: Math.round(usage.reduce((n, u) => n + u.usd, 0) * 1e6) / 1e6,
    },
    money: money(
      d.config,
      day.reduce((n, r) => n + r.topup_cny, 0),
      usage.reduce((n, u) => n + u.usd, 0),
    ),
    points: { sold: sum("points_sold"), granted: sum("points_granted"), used: sum("points_used") },
  };
}

const MINUTE = 60_000;
/** The windows of 活跃用户: 15 minutes, a day, 7 and 30 days. */
export const ACTIVE_WINDOWS = {
  now: 15 * MINUTE,
  day: 24 * 60 * MINUTE,
  week: 7 * 24 * 60 * MINUTE,
  month: 30 * 24 * 60 * MINUTE,
} as const;

const activeWithin = (u: UserRecord, now: Date, ms: number) =>
  !!u.last_seen_at && now.getTime() - Date.parse(u.last_seen_at) < ms;

export const isAdmin = (d: Pick<AdminData, "configAdmin">, u: UserRecord) =>
  u.role === "admin" || !!d.configAdmin?.(u);

export function overview(d: AdminData, days: number): Overview {
  const day = series(d, days);
  const from = day[0]!.day;
  const inWindow = (iso: string) => localDay(iso, d.tz) >= from;
  const usage = d.usage.filter((u) => inWindow(u.created_at));
  const delivered = new Set(usage.filter((u) => u.delivered).map((u) => u.job_id));
  const sum = <K extends keyof DayRow>(k: K) => day.reduce((n, r) => n + (r[k] as number), 0);
  let outstanding = 0;
  for (const b of d.balances.values()) outstanding += b.balance;
  return {
    days,
    from,
    to: day.at(-1)!.day,
    accounts: {
      total: d.users.length,
      new: sum("new_accounts"),
      suspended: d.users.filter((u) => u.status === "suspended").length,
      admins: d.users.filter((u) => isAdmin(d, u)).length,
      demo: d.users.filter((u) => u.demo).length,
    },
    active: {
      now: d.users.filter((u) => activeWithin(u, d.now, ACTIVE_WINDOWS.now)).length,
      day: d.users.filter((u) => activeWithin(u, d.now, ACTIVE_WINDOWS.day)).length,
      week: d.users.filter((u) => activeWithin(u, d.now, ACTIVE_WINDOWS.week)).length,
      month: d.users.filter((u) => activeWithin(u, d.now, ACTIVE_WINDOWS.month)).length,
    },
    ai: {
      jobs: new Set(usage.map((u) => u.job_id)).size,
      delivered_jobs: delivered.size,
      input_tokens: sum("input_tokens"),
      output_tokens: sum("output_tokens"),
      tokens: sum("tokens"),
      cost_usd: Math.round(usage.reduce((n, u) => n + u.usd, 0) * 1e6) / 1e6,
    },
    money: money(
      d.config,
      day.reduce((n, r) => n + r.topup_cny, 0),
      usage.reduce((n, u) => n + u.usd, 0),
    ),
    points: {
      sold: sum("points_sold"),
      granted: sum("points_granted"),
      used: sum("points_used"),
      outstanding,
    },
    previous: previousOf(d, days),
  };
}

export interface BreakdownRow {
  /** report, life_report, followup, inquiry, remedy. */
  kind: string;
  /** The method of the chart; none for a 一生运势报告's 追问 kind of row. */
  system?: string;
  jobs: number;
  tokens: number;
  cost_cny: number;
  points_used: number;
}

export interface ModelRow {
  model: string;
  jobs: number;
  input_tokens: number;
  output_tokens: number;
  tokens: number;
  cost_cny: number;
}

/** The period's AI use by what was asked (kind and method) and by model, the most costly first. */
export function breakdown(
  d: AdminData,
  days: number,
): { byMethod: BreakdownRow[]; byModel: ModelRow[] } {
  const from = windowDays(d.now, days, d.tz)[0]!;
  const usage = d.usage.filter((u) => localDay(u.created_at, d.tz) >= from);
  const methods = new Map<string, BreakdownRow & { ids: Set<string>; usd: number }>();
  const key = (kind: string, system?: string) => `${kind}/${system ?? ""}`;
  const method = (kind: string, system?: string) => {
    const k = key(kind, system);
    let m = methods.get(k);
    if (!m) {
      m = {
        kind,
        ...(system && { system }),
        jobs: 0,
        tokens: 0,
        cost_cny: 0,
        points_used: 0,
        ids: new Set(),
        usd: 0,
      };
      methods.set(k, m);
    }
    return m;
  };
  const models = new Map<string, ModelRow & { ids: Set<string>; usd: number }>();
  for (const u of usage) {
    const m = method(u.kind, u.system);
    m.ids.add(u.job_id);
    m.tokens += tokensOf(u);
    m.usd += u.usd;
    let r = models.get(u.model);
    if (!r) {
      r = {
        model: u.model,
        jobs: 0,
        input_tokens: 0,
        output_tokens: 0,
        tokens: 0,
        cost_cny: 0,
        ids: new Set(),
        usd: 0,
      };
      models.set(u.model, r);
    }
    r.ids.add(u.job_id);
    r.input_tokens += u.input_tokens;
    r.output_tokens += u.output_tokens;
    r.tokens += tokensOf(u);
    r.usd += u.usd;
  }
  for (const e of d.entries) {
    if (e.kind !== "charge" || !e.for || localDay(e.created_at, d.tz) < from) continue;
    method(e.for.kind, e.for.system).points_used -= e.points;
  }
  const rate = d.config.pricing.usd_cny;
  const byCost = (a: { cost_cny: number }, b: { cost_cny: number }) => b.cost_cny - a.cost_cny;
  return {
    byMethod: [...methods.values()]
      .map(({ ids, usd, ...m }) => ({ ...m, jobs: ids.size, cost_cny: cents(usd * rate) }))
      .sort(byCost),
    byModel: [...models.values()]
      .map(({ ids, usd, ...m }) => ({ ...m, jobs: ids.size, cost_cny: cents(usd * rate) }))
      .sort(byCost),
  };
}

export interface UserRow {
  id: string;
  /** The username, else the masked email or phone. */
  login: string;
  country: string;
  role: AccountRole;
  /** An admin by the server's settings: the dashboard can't take the role away. */
  admin_by_config: boolean;
  status: "active" | "suspended";
  permissions: AccountPermissions;
  demo: boolean;
  created_at: string;
  last_seen_at?: string;
  balance: number;
  held: number;
  /** All time: 充值 paid, 积分 used, AI jobs, their tokens and cost. */
  topup_cny: number;
  points_used: number;
  jobs: number;
  tokens: number;
  cost_cny: number;
}

export const loginOf = (u: UserRecord) =>
  u.username ?? (u.email ? maskEmail(u.email) : u.phone ? maskPhone(u.phone) : u.id.slice(0, 8));

/** Every account with its numbers, as the 用户 table lists them. */
export function userRows(d: AdminData): UserRow[] {
  const per = new Map<
    string,
    { yuan: number; used: number; jobs: Set<string>; tokens: number; usd: number }
  >();
  const of = (id: string) => {
    let p = per.get(id);
    if (!p) {
      p = { yuan: 0, used: 0, jobs: new Set(), tokens: 0, usd: 0 };
      per.set(id, p);
    }
    return p;
  };
  for (const e of d.entries) {
    if (e.kind === "topup") of(e.owner).yuan += e.pack?.yuan ?? 0;
    if (e.kind === "charge") of(e.owner).used -= e.points;
  }
  for (const u of d.usage) {
    if (!u.owner) continue;
    const p = of(u.owner);
    p.jobs.add(u.job_id);
    p.tokens += tokensOf(u);
    p.usd += u.usd;
  }
  return d.users.map((u) => {
    const p = per.get(u.id);
    const b = d.balances.get(u.id) ?? { balance: 0, held: 0 };
    const byConfig = !!d.configAdmin?.(u);
    return {
      id: u.id,
      login: loginOf(u),
      country: u.country,
      role: byConfig ? "admin" : (u.role ?? "user"),
      admin_by_config: byConfig,
      status: u.status ?? "active",
      permissions: permissionsOf(u),
      demo: u.demo === true,
      created_at: u.created_at,
      ...(u.last_seen_at && { last_seen_at: u.last_seen_at }),
      balance: b.balance,
      held: b.held,
      topup_cny: cents(p?.yuan ?? 0),
      points_used: p?.used ?? 0,
      jobs: p?.jobs.size ?? 0,
      tokens: p?.tokens ?? 0,
      cost_cny: cents((p?.usd ?? 0) * d.config.pricing.usd_cny),
    };
  });
}

export const USER_SORTS = [
  "created",
  "last_seen",
  "balance",
  "topup",
  "used",
  "jobs",
  "cost",
] as const;
export type UserSort = (typeof USER_SORTS)[number];

export interface UserQuery {
  q?: string;
  status?: "active" | "suspended";
  role?: AccountRole;
  /** include (default), exclude or only the demo accounts. */
  demo?: "include" | "exclude" | "only";
  sort?: UserSort;
  /** Largest first unless asc. */
  asc?: boolean;
  page?: number;
  per_page?: number;
}

/** The 用户 table: filtered, sorted (newest first by default), a page at a time. */
export function queryUsers(rows: UserRow[], q: UserQuery) {
  const needle = q.q?.trim().toLowerCase();
  const kept = rows.filter(
    (r) =>
      (!needle || r.login.toLowerCase().includes(needle) || r.id.startsWith(needle)) &&
      (!q.status || r.status === q.status) &&
      (!q.role || r.role === q.role) &&
      (q.demo !== "exclude" || !r.demo) &&
      (q.demo !== "only" || r.demo),
  );
  const value: Record<UserSort, (r: UserRow) => number | string> = {
    created: (r) => r.created_at,
    last_seen: (r) => r.last_seen_at ?? "",
    balance: (r) => r.balance,
    topup: (r) => r.topup_cny,
    used: (r) => r.points_used,
    jobs: (r) => r.jobs,
    cost: (r) => r.cost_cny,
  };
  const v = value[q.sort ?? "created"];
  kept.sort((a, b) => {
    const [x, y] = [v(a), v(b)];
    const c = x < y ? -1 : x > y ? 1 : a.id < b.id ? -1 : 1;
    return q.asc ? c : -c;
  });
  const per = Math.min(Math.max(Math.floor(q.per_page ?? 25), 1), 100);
  const pages = Math.max(1, Math.ceil(kept.length / per));
  const page = Math.min(Math.max(Math.floor(q.page ?? 1), 1), pages);
  return {
    total: kept.length,
    page,
    pages,
    per_page: per,
    items: kept.slice((page - 1) * per, page * per),
  };
}

/** Accounts active within [ms] of now, the most recent first. */
export function activeUsers(d: AdminData, rows: UserRow[], ms: number): UserRow[] {
  return rows
    .filter((r) => r.last_seen_at && d.now.getTime() - Date.parse(r.last_seen_at) < ms)
    .sort((a, b) => (a.last_seen_at! < b.last_seen_at! ? 1 : -1));
}

export interface JobRow {
  job_id: string;
  created_at: string;
  kind: string;
  system?: string;
  models: string[];
  tokens: number;
  cost_cny: number;
  delivered: boolean;
}

/** One account's latest AI jobs, newest first, each with its steps added up. */
export function jobsOf(d: AdminData, owner: string, limit: number): JobRow[] {
  const jobs = new Map<string, JobRow & { usd: number }>();
  for (const u of d.usage) {
    if (u.owner !== owner) continue;
    let j = jobs.get(u.job_id);
    if (!j) {
      j = {
        job_id: u.job_id,
        created_at: u.created_at,
        kind: u.kind,
        ...(u.system && { system: u.system }),
        models: [],
        tokens: 0,
        cost_cny: 0,
        delivered: false,
        usd: 0,
      };
      jobs.set(u.job_id, j);
    }
    if (!j.models.includes(u.model)) j.models.push(u.model);
    j.tokens += tokensOf(u);
    j.usd += u.usd;
    j.delivered ||= u.delivered;
    if (u.created_at > j.created_at) j.created_at = u.created_at;
  }
  return [...jobs.values()]
    .sort((a, b) => (a.created_at < b.created_at ? 1 : -1))
    .slice(0, limit)
    .map(({ usd, ...j }) => ({ ...j, cost_cny: cents(usd * d.config.pricing.usd_cny) }));
}
