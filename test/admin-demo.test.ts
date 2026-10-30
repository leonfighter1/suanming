// S22 WP22.3 (docs/tech-plan.md, the owner 2026-10-29): 「为了展示效果，可以设置一些preset的data 到各个用户，这样我们可以只管的再
// 数据表里看见」. Demo accounts with 90 days of history, from a fixed seed, charged as the server charges.
import { randomBytes } from "node:crypto";
import { describe, expect, it } from "vitest";
import { adminDemoOn, seedAdminDemo } from "../src/admin/demo.js";
import { overview, series, type AdminData } from "../src/admin/stats.js";
import { InMemoryStore, type Store } from "../src/api/store.js";
import { AuthService } from "../src/auth/service.js";
import { TokenService } from "../src/auth/tokens.js";
import { PgStore } from "../src/db/pg-store.js";
import { loadPointsConfig, pointsFor } from "../src/points/index.js";
import { PEPPER } from "./helpers.js";

const config = loadPointsConfig();
const NOW = new Date("2026-10-30T04:00:00.000Z");
const DAY = 86_400_000;

function fresh(users?: PgStore) {
  const auth = new AuthService({
    pepper: PEPPER,
    tokens: new TokenService(randomBytes(32)),
    ...(users && { users }),
  });
  return auth;
}

async function adminData(store: Store, auth: AuthService): Promise<AdminData> {
  return {
    users: await auth.users.list(),
    entries: await store.allPoints(),
    usage: await store.listUsage(),
    balances: await store.allBalances(),
    config,
    now: NOW,
    tz: "Asia/Shanghai",
  };
}

describe("preset data for the dashboard (WP22.3)", () => {
  it("36 demo accounts with 90 days of history, the same every time, given once", async () => {
    const [a, b] = [new InMemoryStore(), new InMemoryStore()];
    const [authA, authB] = [fresh(), fresh()];
    const summary = await seedAdminDemo({ auth: authA, store: a, config, now: NOW });
    expect(summary).toMatchObject({ accounts: 36 });
    expect(summary!.jobs).toBeGreaterThan(200);
    expect(summary!.topups).toBeGreaterThan(36);
    await seedAdminDemo({ auth: authB, store: b, config, now: NOW });
    expect(await b.listUsage()).toEqual(await a.listUsage());
    // Entry ids are the ledger's own; every amount, balance, time and purpose is the same.
    const strip = (rows: { id: string }[]) => rows.map(({ id: _id, ...r }) => r);
    expect(strip(await b.allPoints())).toEqual(strip(await a.allPoints()));
    // Once: a store with demo accounts gets none again.
    expect(await seedAdminDemo({ auth: authA, store: a, config, now: NOW })).toBeUndefined();
    expect((await authA.users.list()).filter((u) => u.demo)).toHaveLength(36);
  });

  it("is charged as the server charges: each delivered request its measured cost, a 深度分析 its fee; balances never below nothing", async () => {
    const store = new InMemoryStore();
    const auth = fresh();
    await seedAdminDemo({ auth, store, config, now: NOW });
    const usage = await store.listUsage();
    const entries = await store.allPoints();
    expect(usage.every((r) => r.demo && r.model === "claude-opus-5-5")).toBe(true);
    expect(
      usage.every(
        (r) =>
          r.created_at >= new Date(NOW.getTime() - 90 * DAY).toISOString() &&
          r.created_at < NOW.toISOString(),
      ),
    ).toBe(true);
    const usd = new Map<string, number>();
    for (const r of usage) usd.set(r.job_id, (usd.get(r.job_id) ?? 0) + r.usd);
    const delivered = new Set(usage.filter((r) => r.delivered).map((r) => r.job_id));
    const charges = entries.filter((e) => e.kind === "charge");
    expect(charges.length).toBeGreaterThan(100);
    for (const c of charges) {
      expect(delivered.has(c.for!.id)).toBe(true);
      // The 深度分析's 统一收费 at Claude Opus 5.5 is 747 (test/points.test.ts).
      expect(-c.points).toBe(c.basis === "flat" ? 747 : pointsFor(config, usd.get(c.for!.id)!));
    }
    // A job that didn't deliver is charged nothing.
    const charged = new Set(charges.map((c) => c.for!.id));
    for (const id of usd.keys()) if (!delivered.has(id)) expect(charged.has(id)).toBe(false);
    // Every account's changes, in time order, follow one another, and its balance is the last one's.
    const byOwner = new Map<string, typeof entries>();
    for (const e of entries) byOwner.set(e.owner, [...(byOwner.get(e.owner) ?? []), e]);
    for (const [owner, list] of byOwner) {
      let balance = 0;
      for (const e of list) {
        balance += e.points;
        expect(e.balance).toBe(balance);
        expect(balance).toBeGreaterThanOrEqual(0);
      }
      expect((await store.pointsOf(owner)).balance).toBe(balance);
    }
  });

  it("looks like a growing service: accounts with demo marks, some suspended, some active just now", async () => {
    const store = new InMemoryStore();
    const auth = fresh();
    await seedAdminDemo({ auth, store, config, now: NOW });
    const d = await adminData(store, auth);
    // Demo accounts have no password: they can't sign in.
    expect(d.users.every((u) => u.demo && !u.password_hash)).toBe(true);
    await expect(
      auth.login({ login: "demo-01", password: "demo-01" }, "1.1.1.1"),
    ).rejects.toMatchObject({ status: 401 });
    const o = overview(d, 90);
    expect(o.accounts).toMatchObject({ total: 36, suspended: 2, demo: 36 });
    expect(d.users.filter((u) => u.permissions?.ai === false)).toHaveLength(1);
    expect(o.active.now).toBeGreaterThanOrEqual(3);
    expect(o.active.day).toBeGreaterThanOrEqual(9);
    expect(o.money.topup_cny).toBeGreaterThan(0);
    expect(o.money.cost_cny).toBeGreaterThan(0);
    expect(o.money.profit_cny).toBeGreaterThan(0);
    // More AI jobs in the last 30 days than in the first 30.
    const days = series(d, 90);
    const jobs = (from: number, to: number) => days.slice(from, to).reduce((n, r) => n + r.jobs, 0);
    expect(jobs(60, 90)).toBeGreaterThan(jobs(0, 30));
    expect(adminDemoOn({})).toBe(true);
    expect(adminDemoOn({ MINGLI_ADMIN_DEMO: "off" })).toBe(false);
  });

  it("the database store takes the same history", async () => {
    const pg = await PgStore.open({ kek: randomBytes(32), pepper: PEPPER });
    const memory = new InMemoryStore();
    await seedAdminDemo({ auth: fresh(pg), store: pg, config, now: NOW }, { accounts: 5 });
    await seedAdminDemo({ auth: fresh(), store: memory, config, now: NOW }, { accounts: 5 });
    const strip = <T extends { id?: string }>(rows: T[]) => rows.map(({ id: _id, ...r }) => r);
    expect(await pg.listUsage()).toEqual(await memory.listUsage());
    // Entry ids are the stores' own; every amount, balance, time and purpose is the same.
    expect(strip(await pg.allPoints())).toEqual(strip(await memory.allPoints()));
    expect(await pg.allBalances()).toEqual(await memory.allBalances());
    await pg.close();
  }, 60_000);
});
