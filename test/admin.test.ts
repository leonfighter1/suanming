// S22 WP22.1–22.2 (docs/tech-plan.md, the owner 2026-10-29): 管理后台. 「管理app下的所有账户，查看所用的所有token和所有盈利和收益
// 等等数据。除此之外管理员登录后可以查看和管理active user 也可以控制用户权限，还有可以给用户增加积分。还可以导出收益曲线和report」.
import { randomBytes, randomUUID } from "node:crypto";
import type { AddressInfo } from "node:net";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import {
  MockProvider,
  type AgentName,
  type LLMJsonRequest,
  type LLMProvider,
  type Usage,
} from "../src/ai/index.js";
import { createApiServer, SEEN_EVERY_MS } from "../src/api/server.js";
import { InMemoryStore } from "../src/api/store.js";
import {
  activeUsers,
  ACTIVE_WINDOWS,
  breakdown,
  localDay,
  overview,
  queryUsers,
  series,
  userRows,
  type AdminData,
} from "../src/admin/stats.js";
import { seriesCsv } from "../src/admin/report.js";
import type { UsageRow } from "../src/admin/usage.js";
import type { UserRecord } from "../src/auth/service.js";
import { PgStore } from "../src/db/pg-store.js";
import { loadPointsConfig, type PointsEntry } from "../src/points/index.js";
import { buildAuth } from "../src/service/runtime.js";
import { DRAW_KEY, PEPPER } from "./helpers.js";

const config = loadPointsConfig();
const TZ = "Asia/Shanghai";

// ---- the numbers, worked by hand ----

const user = (id: string, created_at: string, more: Partial<UserRecord> = {}): UserRecord => ({
  id,
  social: {},
  country: "HK",
  locale: "zh-Hans",
  age_confirmed_at: created_at,
  created_at,
  ...more,
});
const entry = (
  owner: string,
  kind: PointsEntry["kind"],
  points: number,
  at: string,
  more: Partial<PointsEntry> = {},
): PointsEntry => ({
  id: randomUUID(),
  owner,
  kind,
  points,
  balance: 0,
  created_at: at,
  ...more,
});
const step = (
  job: string,
  owner: string | undefined,
  kind: UsageRow["kind"],
  system: string,
  agent: string,
  input: number,
  output: number,
  at: string,
  delivered = true,
): UsageRow => ({
  job_id: job,
  ...(owner && { owner }),
  kind,
  system,
  agent,
  model: "claude-opus-5-5",
  input_tokens: input,
  output_tokens: output,
  cache_read_tokens: 0,
  cache_write_tokens: 0,
  // Claude Opus 5.5: $4 / $20 per million.
  usd: (input * 4 + output * 20) / 1e6,
  delivered,
  created_at: at,
});

// Now: 2026-10-30 12:00 in Shanghai (04:00 UTC). Days are Shanghai's.
const NOW = new Date("2026-10-30T04:00:00.000Z");
const data: AdminData = {
  users: [
    user("u1", "2026-10-28T02:00:00.000Z", {
      username: "alice",
      last_seen_at: "2026-10-30T03:50:00.000Z",
    }),
    // 17:30 UTC on the 29th is 01:30 on the 30th in Shanghai.
    user("u2", "2026-10-29T17:30:00.000Z", {
      username: "bob",
      last_seen_at: "2026-10-29T05:00:00.000Z",
    }),
    user("u3", "2026-09-01T00:00:00.000Z", {
      email: "carol@example.com",
      status: "suspended",
      last_seen_at: "2026-10-01T05:00:00.000Z",
    }),
    user("u4", "2026-01-01T00:00:00.000Z", { username: "boss" }),
  ],
  entries: [
    entry("u1", "topup", 6250, "2026-10-28T03:00:00.000Z", { pack: { yuan: 50, points: 6250 } }),
    entry("u1", "grant", 500, "2026-10-29T01:00:00.000Z", { reason: "admin:x" }),
    entry("u1", "charge", -665, "2026-10-29T02:00:00.000Z", {
      for: { kind: "report", id: "J1", system: "bazi" },
    }),
    entry("u2", "topup", 1000, "2026-10-29T18:00:00.000Z", { pack: { yuan: 10, points: 1000 } }),
    entry("u2", "charge", -470, "2026-10-30T01:00:00.000Z", {
      for: { kind: "report", id: "J2", system: "tarot" },
    }),
  ],
  usage: [
    step("J1", "u1", "report", "bazi", "narrative", 10_000, 15_000, "2026-10-29T02:00:00.000Z"),
    step("J2", "u2", "report", "tarot", "narrative", 9_000, 7_000, "2026-10-30T01:00:00.000Z"),
    step("J2", "u2", "report", "tarot", "action", 4_000, 2_500, "2026-10-30T01:00:00.000Z"),
    // 20:00 UTC on the 29th is 04:00 on the 30th; a 追问 that didn't deliver still cost.
    step(
      "J3",
      "u3",
      "followup",
      "bazi",
      "followup",
      5_000,
      1_000,
      "2026-10-29T20:00:00.000Z",
      false,
    ),
  ],
  balances: new Map([
    // u1: 6250 + 500 − 665 = 6085; u2: 1000 − 470 = 530.
    ["u1", { balance: 6085, held: 0 }],
    ["u2", { balance: 530, held: 0 }],
  ]),
  config,
  now: NOW,
  tz: TZ,
  configAdmin: (u) => u.username === "boss",
};

describe("the dashboard's numbers (WP22.2)", () => {
  it("days are the dashboard's time zone's", () => {
    expect(localDay("2026-10-29T17:30:00.000Z", TZ)).toBe("2026-10-30");
    expect(localDay("2026-10-29T15:59:59.000Z", TZ)).toBe("2026-10-29");
  });

  it("day by day: 充值, its net, the AI cost, the profit, the tokens and the 积分", () => {
    const [d28, d29, d30] = series(data, 3);
    // The 28th: alice joins and pays 50 元; net 50 × (1 − 0.006 − 0.06) = 46.70; nothing spent.
    expect(d28).toMatchObject({
      day: "2026-10-28",
      new_accounts: 1,
      active_accounts: 1,
      jobs: 0,
      tokens: 0,
    });
    expect(d28).toMatchObject({
      topup_cny: 50,
      net_cny: 46.7,
      cost_cny: 0,
      profit_cny: 46.7,
      margin: 1,
      points_sold: 6250,
    });
    // The 29th: alice's 八字 reading, $0.34 × 7.3 = ¥2.482; no 充值, so a loss of ¥2.48 and no margin; her 500 granted.
    expect(d29).toMatchObject({ day: "2026-10-29", new_accounts: 0, active_accounts: 1, jobs: 1 });
    expect(d29).toMatchObject({ input_tokens: 10_000, output_tokens: 15_000, tokens: 25_000 });
    expect(d29).toMatchObject({
      topup_cny: 0,
      cost_cny: 2.48,
      profit_cny: -2.48,
      margin: null,
      points_granted: 500,
      points_used: 665,
    });
    // The 30th: bob joins (01:30) and pays 10 元 (net 9.34); his 塔罗 ($0.176 + $0.066) and carol's 追问 ($0.04):
    // $0.282 × 7.3 = ¥2.0586; profit 9.34 − 2.0586 = 7.2814; margin 7.2814 / 9.34 = 0.780.
    expect(d30).toMatchObject({ day: "2026-10-30", new_accounts: 1, active_accounts: 2, jobs: 2 });
    expect(d30).toMatchObject({ input_tokens: 18_000, output_tokens: 10_500, tokens: 28_500 });
    expect(d30).toMatchObject({
      topup_cny: 10,
      net_cny: 9.34,
      cost_cny: 2.06,
      profit_cny: 7.28,
      margin: 0.78,
    });
    expect(d30).toMatchObject({ points_sold: 1000, points_used: 470 });
  });

  it("the period's KPIs", () => {
    const o = overview(data, 3);
    expect(o).toMatchObject({ days: 3, from: "2026-10-28", to: "2026-10-30" });
    expect(o.accounts).toEqual({ total: 4, new: 2, suspended: 1, admins: 1, demo: 0 });
    // alice 10 minutes ago; bob 23 hours; carol 29 days.
    expect(o.active).toEqual({ now: 1, day: 2, week: 2, month: 3 });
    // $0.34 + $0.242 + $0.04 = $0.622.
    expect(o.ai).toEqual({
      jobs: 3,
      delivered_jobs: 2,
      input_tokens: 28_000,
      output_tokens: 25_500,
      tokens: 53_500,
      cost_usd: 0.622,
    });
    // 60 元 → net 56.04; cost $0.622 × 7.3 = ¥4.5406; profit 51.4994; margin 51.4994 / 56.04 = 0.919.
    expect(o.money).toEqual({
      topup_cny: 60,
      net_cny: 56.04,
      cost_cny: 4.54,
      profit_cny: 51.5,
      margin: 0.919,
    });
    // Held now: 6085 + 530.
    expect(o.points).toEqual({ sold: 7250, granted: 500, used: 1135, outstanding: 6615 });
  });

  it("by method and by model, the most costly first", () => {
    const b = breakdown(data, 3);
    expect(b.byMethod).toEqual([
      { kind: "report", system: "bazi", jobs: 1, tokens: 25_000, cost_cny: 2.48, points_used: 665 },
      // 9,000 + 7,000 + 4,000 + 2,500 = 22,500; $0.242 × 7.3 = ¥1.7666.
      {
        kind: "report",
        system: "tarot",
        jobs: 1,
        tokens: 22_500,
        cost_cny: 1.77,
        points_used: 470,
      },
      // $0.04 × 7.3 = ¥0.292.
      { kind: "followup", system: "bazi", jobs: 1, tokens: 6_000, cost_cny: 0.29, points_used: 0 },
    ]);
    expect(b.byModel).toEqual([
      {
        model: "claude-opus-5-5",
        jobs: 3,
        input_tokens: 28_000,
        output_tokens: 25_500,
        tokens: 53_500,
        cost_cny: 4.54,
      },
    ]);
  });

  it("every account with its numbers; search, filters, sorting and pages; the active ones", () => {
    const rows = userRows(data);
    const by = Object.fromEntries(rows.map((r) => [r.id, r]));
    expect(by.u1).toMatchObject({
      login: "alice",
      role: "user",
      status: "active",
      balance: 6085,
      topup_cny: 50,
      points_used: 665,
      jobs: 1,
      tokens: 25_000,
      cost_cny: 2.48,
    });
    expect(by.u2).toMatchObject({
      login: "bob",
      balance: 530,
      topup_cny: 10,
      points_used: 470,
      cost_cny: 1.77,
    });
    expect(by.u3).toMatchObject({
      login: "c***@example.com",
      status: "suspended",
      jobs: 1,
      cost_cny: 0.29,
    });
    expect(by.u4).toMatchObject({
      login: "boss",
      role: "admin",
      admin_by_config: true,
      permissions: { ai: true, top_up: true },
    });

    expect(queryUsers(rows, { sort: "cost" }).items.map((r) => r.login)).toEqual([
      "alice",
      "bob",
      "c***@example.com",
      "boss",
    ]);
    expect(queryUsers(rows, { q: "bo" }).items.map((r) => r.id)).toEqual(["u2", "u4"]);
    expect(queryUsers(rows, { status: "suspended" }).items.map((r) => r.id)).toEqual(["u3"]);
    expect(queryUsers(rows, { role: "admin" }).items.map((r) => r.id)).toEqual(["u4"]);
    expect(queryUsers(rows, { demo: "only" }).total).toBe(0);
    // Newest first by default; two a page.
    const page2 = queryUsers(rows, { per_page: 2, page: 2 });
    expect(page2).toMatchObject({ total: 4, page: 2, pages: 2, per_page: 2 });
    expect(page2.items.map((r) => r.id)).toEqual(["u3", "u4"]);

    expect(activeUsers(data, rows, ACTIVE_WINDOWS.now).map((r) => r.id)).toEqual(["u1"]);
    expect(activeUsers(data, rows, ACTIVE_WINDOWS.day).map((r) => r.id)).toEqual(["u1", "u2"]);
  });

  it("the revenue curve as CSV opens in a spreadsheet: UTF-8 with its mark, one row a day", () => {
    const text = seriesCsv(series(data, 3));
    expect(text.charCodeAt(0)).toBe(0xfeff);
    const lines = text.slice(1).trimEnd().split("\r\n");
    expect(lines).toHaveLength(4);
    expect(lines[0]!.split(",")[0]).toBe("日期");
    expect(lines[3]).toBe("2026-10-30,1,2,2,18000,10500,28500,10.00,9.34,2.06,7.28,1000,0,470");
  });
});

// ---- the API ----

/** Answers as the mock does, the 八字 reading's step reporting 10,000 in and 15,000 out on Claude Opus 5.5. */
function billed(usage: Partial<Record<AgentName, Usage>>): LLMProvider {
  const inner = new MockProvider();
  return {
    name: "billed",
    async generateJson(req: LLMJsonRequest) {
      const r = await inner.generateJson(req);
      const u = usage[req.agent];
      return u ? { ...r, model: "claude-opus-5-5", usage: u } : r;
    },
  };
}

const secrets = { digestPepper: PEPPER, drawKey: DRAW_KEY };
const provider = billed({ narrative: { input_tokens: 10_000, output_tokens: 15_000 } });
const store = new InMemoryStore();
const auth = buildAuth({ ...secrets, ephemeral: true } as never, true);
let clock = new Date("2026-10-30T04:00:00.000Z");
const api = createApiServer({
  secrets,
  providers: { deepseek: provider, anthropic: provider },
  auth,
  store,
  devMode: true,
  devHeaders: false,
  review: false,
  admins: ["boss"],
  points: { simulateTopUp: true },
  now: () => clock,
  log: () => {},
});
let base = "";
const sessions: Record<string, { access_token: string; refresh_token: string }> = {};
const ids: Record<string, string> = {};
const LOGINS = ["boss", "alice", "bob"];

async function signIn(login: string) {
  const res = await fetch(base + "/v1/auth/login", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ login, password: login }),
  });
  return res;
}

beforeAll(async () => {
  for (const login of LOGINS) {
    await auth.seedDevUser({ login, password: login, country: "HK", locale: "zh-Hans" });
  }
  await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
  base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
  for (const login of LOGINS) {
    sessions[login] = await (await signIn(login)).json();
    ids[login] = (await auth.findLogin("username", login))!.id;
  }
});
afterAll(() => new Promise<void>((r) => api.close(() => r())));

const call = (who: string, path: string, method = "GET", body?: unknown) =>
  fetch(base + path, {
    method,
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${sessions[who]!.access_token}`,
    },
    ...(body !== undefined && { body: JSON.stringify(body) }),
  });
const json = async (who: string, path: string, method = "GET", body?: unknown) =>
  (await call(who, path, method, body)).json();
const birth = {
  system: "bazi",
  local: "1990-03-15T14:30",
  timezone: "Asia/Hong_Kong",
  longitude: 114.17,
  gender: "male",
};

describe("the admin API (WP22.1–22.2)", () => {
  it("is for admins only: by the server's MINGLI_ADMINS, or by the role an admin gives", async () => {
    const no = await call("alice", "/v1/admin/me");
    expect(no.status).toBe(403);
    expect((await no.json()).code).toBe("admin_only");
    expect((await call("alice", "/v1/admin/overview")).status).toBe(403);
    expect(await json("boss", "/v1/admin/me")).toMatchObject({
      login: "boss",
      role: "admin",
      admin_by_config: true,
    });
    // boss makes bob an admin; bob gets in; boss takes it back.
    expect(
      (await call("boss", `/v1/admin/users/${ids.bob}`, "PATCH", { role: "admin" })).status,
    ).toBe(200);
    expect((await call("bob", "/v1/admin/me")).status).toBe(200);
    expect(
      (await call("boss", `/v1/admin/users/${ids.bob}`, "PATCH", { role: "user" })).status,
    ).toBe(200);
    expect((await call("bob", "/v1/admin/me")).status).toBe(403);
  });

  it("an admin keeps a way in: no suspending or demoting oneself, nor an admin by the server's settings", async () => {
    for (const change of [{ status: "suspended" }, { role: "user" }]) {
      const res = await call("boss", `/v1/admin/users/${ids.boss}`, "PATCH", change);
      expect(res.status, JSON.stringify(change)).toBe(409);
      expect((await res.json()).code).toBe("admin_self");
    }
    await call("boss", `/v1/admin/users/${ids.alice}`, "PATCH", { role: "admin" });
    const res = await call("alice", `/v1/admin/users/${ids.boss}`, "PATCH", { role: "user" });
    expect(res.status).toBe(409);
    expect((await res.json()).code).toBe("admin_by_config");
    await call("boss", `/v1/admin/users/${ids.alice}`, "PATCH", { role: "user" });
  });

  it("增加积分: a grant with a note, which the account sees in 我的积分", async () => {
    const res = await call("boss", `/v1/admin/users/${ids.alice}/points`, "POST", {
      points: 2000,
      note: "活动奖励",
    });
    expect(res.status).toBe(201);
    expect(await res.json()).toMatchObject({
      entry: { kind: "grant", points: 2000, balance: 2000, note: "活动奖励" },
      balance: 2000,
    });
    expect(
      (await call("boss", `/v1/admin/users/${ids.alice}/points`, "POST", { points: 0 })).status,
    ).toBe(400);
    expect(
      (await call("boss", `/v1/admin/users/${ids.alice}/points`, "POST", { points: 1.5 })).status,
    ).toBe(400);
    const mine = await json("alice", "/v1/points");
    expect(mine.balance).toBe(2000);
    expect(mine.entries[0]).toMatchObject({ kind: "grant", points: 2000, note: "活动奖励" });
  });

  it("records every AI job's tokens and cost, and the dashboard shows them with the money", async () => {
    await call("alice", "/v1/points/top-ups", "POST", { yuan: 50 });
    const { chart_id } = await json("alice", "/v1/charts", "POST", birth);
    expect(
      (await call("alice", "/v1/reports", "POST", { chart_id, locale: "zh-Hans" })).status,
    ).toBe(202);
    await api.drain();
    const rows = await store.listUsage();
    expect(rows).toEqual([
      expect.objectContaining({
        owner: ids.alice,
        kind: "report",
        system: "bazi",
        agent: "narrative",
        model: "claude-opus-5-5",
        input_tokens: 10_000,
        output_tokens: 15_000,
        usd: 0.34,
        delivered: true,
      }),
    ]);
    const o = await json("boss", "/v1/admin/overview?days=7");
    expect(o.ai).toMatchObject({ jobs: 1, delivered_jobs: 1, tokens: 25_000, cost_usd: 0.34 });
    // 50 元 → net 46.70; $0.34 × 7.3 = ¥2.48.
    expect(o.money).toMatchObject({
      topup_cny: 50,
      net_cny: 46.7,
      cost_cny: 2.48,
      profit_cny: 44.22,
    });
    const today = (await json("boss", "/v1/admin/series?days=1")).items[0];
    expect(today).toMatchObject({ day: "2026-10-30", jobs: 1, tokens: 25_000, topup_cny: 50 });
    const detail = await json("boss", `/v1/admin/users/${ids.alice}`);
    // 2000 granted + 6250 bought − 665 for the reading ($0.34 → 664.35 → 665).
    expect(detail.user).toMatchObject({
      login: "alice",
      balance: 7585,
      topup_cny: 50,
      points_used: 665,
      jobs: 1,
    });
    expect(detail.jobs[0]).toMatchObject({
      kind: "report",
      system: "bazi",
      tokens: 25_000,
      cost_cny: 2.48,
      delivered: true,
    });
    expect(detail.entries.map((e: { kind: string }) => e.kind)).toEqual([
      "charge",
      "topup",
      "grant",
    ]);
    expect(detail.entries[0].usd).toBe(0.34);
    expect(detail.by_method).toEqual([
      expect.objectContaining({ kind: "report", system: "bazi", jobs: 1, points_used: 665 }),
    ]);
  });

  it("permissions: no AI, no 充值, each refused before anything is held", async () => {
    await call("boss", `/v1/admin/users/${ids.bob}`, "PATCH", { permissions: { ai: false } });
    const { chart_id } = await json("bob", "/v1/charts", "POST", birth);
    const res = await call("bob", "/v1/reports", "POST", { chart_id, locale: "zh-Hans" });
    expect(res.status).toBe(403);
    expect((await res.json()).code).toBe("ai_not_allowed");
    // 充值 still works until it is turned off too.
    expect((await call("bob", "/v1/points/top-ups", "POST", { yuan: 10 })).status).toBe(201);
    const row = await json("boss", `/v1/admin/users/${ids.bob}`, "PATCH", {
      permissions: { top_up: false },
    });
    expect(row.permissions).toEqual({ ai: false, top_up: false });
    const top = await call("bob", "/v1/points/top-ups", "POST", { yuan: 10 });
    expect(top.status).toBe(403);
    expect((await top.json()).code).toBe("top_up_not_allowed");
    expect(
      (await call("boss", `/v1/admin/users/${ids.bob}`, "PATCH", { permissions: { ai: "no" } }))
        .status,
    ).toBe(400);
    // Allowed again, the reading goes ahead: the 1000 bought cover its 688.
    await call("boss", `/v1/admin/users/${ids.bob}`, "PATCH", {
      permissions: { ai: true, top_up: true },
    });
    expect((await call("bob", "/v1/reports", "POST", { chart_id, locale: "zh-Hans" })).status).toBe(
      202,
    );
    await api.drain();
  });

  it("suspending ends every session and every sign-in until the account is active again", async () => {
    const bob = sessions.bob!;
    expect(
      (await call("boss", `/v1/admin/users/${ids.bob}`, "PATCH", { status: "suspended" })).status,
    ).toBe(200);
    const now = await call("bob", "/v1/me");
    expect(now.status).toBe(403);
    expect((await now.json()).code).toBe("account_suspended");
    const again = await signIn("bob");
    expect(again.status).toBe(403);
    expect((await again.json()).code).toBe("account_suspended");
    const refresh = await fetch(base + "/v1/auth/refresh", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ refresh_token: bob.refresh_token }),
    });
    expect(refresh.status).not.toBe(200);
    expect(
      (await json("boss", "/v1/admin/users?status=suspended")).items.map(
        (r: { login: string }) => r.login,
      ),
    ).toEqual(["bob"]);
    await call("boss", `/v1/admin/users/${ids.bob}`, "PATCH", { status: "active" });
    const back = await signIn("bob");
    expect(back.status).toBe(200);
    sessions.bob = await back.json();
  });

  it("sign out everywhere: the account's sessions can't be refreshed", async () => {
    const before = sessions.alice!;
    expect((await call("boss", `/v1/admin/users/${ids.alice}/sign-out`, "POST")).status).toBe(200);
    const refresh = await fetch(base + "/v1/auth/refresh", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ refresh_token: before.refresh_token }),
    });
    expect(refresh.status).toBe(401);
    sessions.alice = await (await signIn("alice")).json();
  });

  it("active users: each account's last request, to the minute, written at most every five minutes", async () => {
    clock = new Date("2026-10-30T05:00:30.000Z");
    await call("alice", "/v1/me");
    await api.drain();
    expect((await auth.users.get(ids.alice!))!.last_seen_at).toBe("2026-10-30T05:00:00.000Z");
    // Within five minutes: not written again.
    clock = new Date(clock.getTime() + SEEN_EVERY_MS - 60_000);
    await call("alice", "/v1/me");
    await api.drain();
    expect((await auth.users.get(ids.alice!))!.last_seen_at).toBe("2026-10-30T05:00:00.000Z");
    const active = await json("boss", "/v1/admin/active");
    expect(active.now.map((r: { login: string }) => r.login)).toContain("alice");
    expect(active.counts.now).toBe(active.now.length);
  });

  it("exports: the revenue curve and the accounts as CSV, the report as Word (and PDF where there is a font)", async () => {
    const curve = await call("boss", "/v1/admin/reports?days=7&format=csv");
    expect(curve.status).toBe(200);
    expect(curve.headers.get("content-type")).toContain("text/csv");
    expect(decodeURIComponent(curve.headers.get("content-disposition")!)).toContain(
      "命理大师-收益曲线-",
    );
    expect((await curve.text()).split("\r\n").length).toBe(9); // a header, 7 days, the last line's end
    const users = await (await call("boss", "/v1/admin/reports?format=csv&kind=users")).text();
    expect(users).toContain("alice");
    const docx = await call("boss", "/v1/admin/reports?days=30&format=docx");
    expect(docx.status).toBe(200);
    expect(
      Buffer.from(await docx.arrayBuffer())
        .subarray(0, 2)
        .toString(),
    ).toBe("PK");
    const pdf = await call("boss", "/v1/admin/reports?days=30&format=pdf");
    expect([200, 503]).toContain(pdf.status);
    if (pdf.status === 200)
      expect(
        Buffer.from(await pdf.arrayBuffer())
          .subarray(0, 4)
          .toString(),
      ).toBe("%PDF");
    expect((await call("boss", "/v1/admin/reports?format=xls")).status).toBe(400);
  });

  it("deleting an account keeps its AI use for the totals, without its owner", async () => {
    const before = (await store.listUsage()).length;
    expect(before).toBeGreaterThan(0);
    await store.deleteOwnerData(ids.alice!);
    const rows = await store.listUsage();
    expect(rows).toHaveLength(before);
    expect(rows.some((r) => r.owner === ids.alice)).toBe(false);
  });
});

// ---- the database store ----

const PG = 30_000;
describe("the database store (WP22.1)", () => {
  it(
    "keeps an account's role, status, permissions, last activity (only moving forward) and demo mark",
    async () => {
      const pg = await PgStore.open({ kek: randomBytes(32), pepper: PEPPER });
      const id = randomUUID();
      const base = user(id, "2026-10-01T00:00:00.000Z", {
        username: "dana",
        username_lookup: randomBytes(32).toString("hex"),
      });
      await pg.put(base);
      expect(await pg.get(id)).toEqual(base);
      await pg.put({
        ...base,
        role: "admin",
        status: "suspended",
        permissions: { ai: false, top_up: true },
        demo: true,
      });
      expect(await pg.get(id)).toMatchObject({
        role: "admin",
        status: "suspended",
        permissions: { ai: false, top_up: true },
        demo: true,
      });
      await pg.touch(id, "2026-10-30T05:00:00.000Z");
      // An older copy written later doesn't move it back.
      await pg.put({ ...base, last_seen_at: "2026-10-29T00:00:00.000Z" });
      expect((await pg.get(id))!.last_seen_at).toBe("2026-10-30T05:00:00.000Z");
      expect((await pg.list()).map((u) => u.id)).toEqual([id]);
      await pg.close();
    },
    PG,
  );

  it(
    "records AI use, lists it with every 积分 change and balance, and keeps it without its owner when the account goes",
    async () => {
      const pg = await PgStore.open({ kek: randomBytes(32), pepper: PEPPER });
      const id = randomUUID();
      await pg.put(
        user(id, "2026-10-01T00:00:00.000Z", { username_lookup: randomBytes(32).toString("hex") }),
      );
      const job = randomUUID();
      await pg.recordUsage([
        step(job, id, "report", "tarot", "narrative", 9_000, 7_000, "2026-10-30T01:00:00.000Z"),
        step(job, id, "report", "tarot", "action", 4_000, 2_500, "2026-10-30T01:00:00.000Z"),
      ]);
      await pg.creditPoints(
        id,
        1000,
        { kind: "grant", reason: "admin:1", note: "补偿" },
        "2026-10-30T02:00:00.000Z",
      );
      expect((await pg.listUsage()).map((r) => [r.agent, r.usd, r.owner])).toEqual([
        ["narrative", 0.176, id],
        ["action", 0.066, id],
      ]);
      expect(await pg.listUsage("2026-10-30T02:00:00.000Z")).toEqual([]);
      expect((await pg.allPoints()).map((e) => [e.kind, e.points, e.note])).toEqual([
        ["grant", 1000, "补偿"],
      ]);
      expect(await pg.allBalances()).toEqual(new Map([[id, { balance: 1000, held: 0 }]]));
      await pg.deleteOwnerData(id);
      const kept = await pg.listUsage();
      expect(kept).toHaveLength(2);
      expect(kept.every((r) => r.owner === undefined)).toBe(true);
      await pg.close();
    },
    PG,
  );
});
