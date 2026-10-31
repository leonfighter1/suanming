// 设置 (S31; owner, 2026-10-31: 「Move all the configurations into separate files, CMS controlling panel is able to read
// and adjust those values … for instance, identify the users idle time, rightnow, 2 days, but we should be able to
// change it in the dashboard controlling panel」).
import { randomBytes, randomUUID } from "node:crypto";
import { beforeAll, describe, expect, it } from "vitest";
import { InMemoryStore } from "../src/api/store.js";
import { FailureLimiter, failureLimits } from "../src/auth/limits.js";
import { DAY_S, InMemorySessionStore, type RefreshRecord } from "../src/auth/tokens.js";
import { PgStore } from "../src/db/pg-store.js";
import { MemorySms } from "../src/notify/index.js";
import { loadPointsConfig } from "../src/points/index.js";
import { buildAuth, buildProviders, withPanel } from "../src/service/runtime.js";
import {
  isSettingKey,
  loadSettingsFile,
  problemOf,
  SettingError,
  Settings,
  settingSpec,
  SETTINGS,
} from "../src/settings/index.js";
import { staffApi } from "./api.js";
import { DRAW_KEY, PEPPER } from "./helpers.js";

const AT = "2026-10-31T08:00:00.000Z";

describe("the settings and their defaults", () => {
  it("every setting has a default that fits it, from config/settings.json; the file names no other", () => {
    const s = new Settings(undefined, {});
    for (const v of s.list())
      expect(problemOf(settingSpec(v.key)!, v.default), v.key).toBeUndefined();
    expect(s.number("sessions.idle_days")).toBe(2);
    const file = loadSettingsFile();
    for (const [group, values] of Object.entries(file)) {
      if (group === "_readme") continue;
      for (const name of Object.keys(values as object))
        expect(isSettingKey(`${group}.${name}`)).toBe(true);
    }
  });

  it("the packs' default is config/points.json's, their one home (S32); the view leaves its loader out", () => {
    const view = new Settings(undefined, {}).view("points.packs");
    expect(view).toMatchObject({ type: "packs", max: 8, default: loadPointsConfig().packs });
    expect(view).not.toHaveProperty("fallback");
    expect(JSON.parse(JSON.stringify(view)).default).toEqual(loadPointsConfig().packs);
    const spec = settingSpec("points.packs")!;
    expect(problemOf(spec, [{ yuan: 9.99, points: 999 }])).toBeUndefined();
    expect(problemOf(spec, [{ yuan: 9.999, points: 1000 }])).toMatch(/最多两位小数/);
    expect(problemOf(spec, [{ yuan: 10, points: 999 }])).toMatch(/每元至少 100 积分/);
    expect(problemOf(spec, Array(9).fill({ yuan: 1, points: 100 }))).toBe("最多 8 个套餐");
  });

  it("an env variable a setting names is its default; a mistyped one stops the start, saying which", () => {
    const s = new Settings(undefined, { MINGLI_SESSION_IDLE_DAYS: "7" });
    expect(s.number("sessions.idle_days")).toBe(7);
    expect(s.view("sessions.idle_days")).toMatchObject({
      value: 7,
      default: 7,
      env: "MINGLI_SESSION_IDLE_DAYS",
    });
    expect(() => new Settings(undefined, { MINGLI_SESSION_IDLE_DAYS: "two" })).toThrow(
      /MINGLI_SESSION_IDLE_DAYS: 要一个数字/,
    );
    expect(() => new Settings(undefined, { MINGLI_AI_DAILY_PER_USER: "2.5" })).toThrow(
      /要一个整数/,
    );
  });

  it("a change fits its setting or is refused in the panel's words; kept by the store; back to the default", async () => {
    const store = new InMemoryStore();
    const s = new Settings(store, {});
    await s.set("sessions.idle_days", 0.5, undefined, AT);
    expect(s.number("sessions.idle_days")).toBe(0.5);
    await expect(s.set("sessions.idle_days", 0, undefined, AT)).rejects.toThrow(
      "要在 0.01 到 365 之间",
    );
    await expect(s.set("limits.mail_per_user_day", 2.5, undefined, AT)).rejects.toThrow(
      "要一个整数",
    );
    await expect(s.set("no.such", 1, undefined, AT)).rejects.toThrow(SettingError);

    // Another start over the same store: the change holds; one that no longer fits its setting is left out.
    await store.putSetting({ key: "limits.ai_total_day", value: -1, updated_at: AT });
    const again = await new Settings(store, {}).load();
    expect(again.number("sessions.idle_days")).toBe(0.5);
    expect(again.number("limits.ai_total_day")).toBe(100);

    await s.reset("sessions.idle_days");
    expect(s.number("sessions.idle_days")).toBe(2);
    expect(await store.listSettings()).toEqual([
      { key: "limits.ai_total_day", value: -1, updated_at: AT },
    ]);
  });

  it("the database keeps the changes across a restart (rule 78)", async () => {
    const pg = await PgStore.open({ kek: randomBytes(32), pepper: PEPPER });
    const by = randomUUID();
    await new Settings(pg, {}).set("limits.mail_per_user_day", 3, by, AT);
    expect(await pg.listSettings()).toEqual([
      { key: "limits.mail_per_user_day", value: 3, updated_at: AT, updated_by: by },
    ]);
    expect((await new Settings(pg, {}).load()).number("limits.mail_per_user_day")).toBe(3);
    expect(await pg.deleteSetting("limits.mail_per_user_day")).toBe(true);
    expect(await pg.listSettings()).toEqual([]);
    await pg.close();
  }, 30_000);
});

describe("the AI switches in 设置 (WP31.4; the owner's, CLAUDE.md rule 5)", () => {
  // Without the suite's MINGLI_AI_PROVIDER=mock the switch alone decides; no provider is built or called here.
  const dotEnv = {
    mode: () => ({ mock: true, reason: "IS_AI_MOCK=TRUE" }),
    choice: () => ({}),
  };

  it("unset, .env's; an admin's choice wins; the test suite's mock wins over both", async () => {
    const s = new Settings(undefined, {});
    const p = withPanel(s, dotEnv, {});
    expect(p.mode()).toEqual({ mock: true, reason: "IS_AI_MOCK=TRUE" });
    await s.set("ai.mock", false, undefined, AT);
    expect(p.mode()).toEqual({ mock: false });
    await s.set("ai.mock", true, undefined, AT);
    expect(p.mode()).toEqual({ mock: true, reason: "设置: AI 模拟" });
    await s.set("ai.mock", false, undefined, AT);
    expect(withPanel(s, dotEnv, { MINGLI_AI_PROVIDER: "mock" }).mode().mock).toBe(true);
    await s.reset("ai.mock");
    expect(p.mode()).toEqual({ mock: true, reason: "IS_AI_MOCK=TRUE" });
  });

  it("the model: every route on the admin's choice, through the routing (rule 66); unset, .env's", async () => {
    const s = new Settings(undefined, {});
    const p = withPanel(s, dotEnv, {});
    const providers = buildProviders(p.mode, p.choice);
    const models = () =>
      new Set(Object.values(providers.routing().routes).map((r) => r.default.model));
    expect(models()).toEqual(new Set(["claude-opus-5-5"]));
    await s.set("ai.model", "claude-sonnet-5-5", undefined, AT);
    expect(models()).toEqual(new Set(["claude-sonnet-5-5"]));
    expect(providers.models()).toBe("claude-sonnet-5-5");
    await expect(s.set("ai.model", "gpt-9", undefined, AT)).rejects.toThrow("要是其中一个");
    await s.reset("ai.model");
    expect(models()).toEqual(new Set(["claude-opus-5-5"]));
  });
});

/** The sessions, as the server keeps them: the last refresh token given. */
class Sessions extends InMemorySessionStore {
  last?: RefreshRecord;
  override async putRefresh(hash: string, rec: RefreshRecord, now: number) {
    this.last = rec;
    return super.putRefresh(hash, rec, now);
  }
}

const store = new InMemoryStore();
const settings = new Settings(store, {});
const sessions = new Sessions();
const sms = new MemorySms();
const auth = buildAuth(
  { digestPepper: PEPPER, drawKey: DRAW_KEY, ephemeral: true } as never,
  true,
  undefined,
  sessions,
  settings,
);
const { start, call, ids } = staffApi(
  {
    auth,
    store,
    settings,
    sms,
    admins: ["boss"],
    aiServing: () => "mock",
    aiModel: () => "claude-opus-5-5",
    now: () => new Date(AT),
  },
  ["boss", "mgr", "integ", "alice"],
  { mgr: "manager", integ: "integrator" },
);
const signIn = (login: string) => call(null, "/v1/auth/login", "POST", { login, password: login });

describe("设置 in the 管理后台", () => {
  beforeAll(start);

  it("is for admins: a manager and an integrator are refused, a user is no staff", async () => {
    expect((await call("boss", "/v1/admin/settings")).status).toBe(200);
    for (const who of ["mgr", "integ"]) {
      const r = await call(who, "/v1/admin/settings");
      expect([r.status, (await r.json()).code]).toEqual([403, "not_allowed"]);
    }
    const r = await call("alice", "/v1/admin/settings/sessions.idle_days", "PUT", { value: 1 });
    expect([r.status, (await r.json()).code]).toEqual([403, "admin_only"]);
  });

  it("lists every setting with its value, its default and its words, and what answers AI calls now", async () => {
    const { settings: all, ai } = await (await call("boss", "/v1/admin/settings")).json();
    expect(ai).toEqual({ serving: "mock", models: "claude-opus-5-5" });
    expect(all.map((s: { key: string }) => s.key)).toEqual(SETTINGS.map((s) => s.key));
    expect(all.find((s: { key: string }) => s.key === "ai.mock")).toMatchObject({
      type: "boolean",
      optional: true,
      value: null,
    });
    expect(all[0]).toMatchObject({
      key: "sessions.idle_days",
      group: "sessions",
      type: "number",
      unit: "天",
      label: "登录有效期",
      value: 2,
      default: 2,
    });
  });

  it("a change holds from the next request; out of range or unknown is refused; back to the default", async () => {
    const put = await call("boss", "/v1/admin/settings/sessions.idle_days", "PUT", { value: 0.5 });
    expect(put.status).toBe(200);
    expect(await put.json()).toMatchObject({ value: 0.5, default: 2, changed: { updated_at: AT } });

    // A sign-in from now on lasts half a day unused (WP29.5's sessions, the panel's days).
    expect((await signIn("alice")).status).toBe(200);
    expect(sessions.last!.expiresAt - Date.now()).toBeGreaterThan(0.5 * DAY_S * 1000 - 60_000);
    expect(sessions.last!.expiresAt - Date.now()).toBeLessThanOrEqual(0.5 * DAY_S * 1000);

    const far = await call("boss", "/v1/admin/settings/sessions.idle_days", "PUT", { value: 400 });
    expect([far.status, (await far.json()).code]).toEqual([400, "invalid_setting"]);
    const none = await call("boss", "/v1/admin/settings/sessions.nothing", "PUT", { value: 1 });
    expect([none.status, (await none.json()).code]).toEqual([404, "unknown_setting"]);

    const back = await call("boss", "/v1/admin/settings/sessions.idle_days", "DELETE");
    expect(await back.json()).toMatchObject({ value: 2, default: 2 });
    expect(settings.number("sessions.idle_days")).toBe(2);
  });

  it("登录: the failures before a pause are the panel's, from the next sign-in (WP32.1)", async () => {
    await call("boss", "/v1/admin/settings/sessions.lock_after", "PUT", { value: 2 });
    const wrong = () =>
      call(null, "/v1/auth/login", "POST", { login: "alice", password: "not her password" });
    expect((await wrong()).status).toBe(401);
    expect((await wrong()).status).toBe(401);
    const paused = await signIn("alice");
    expect([paused.status, (await paused.json()).code]).toEqual([429, "locked"]);
    // Back to 10: two failures no longer pause, and the right password clears them.
    await call("boss", "/v1/admin/settings/sessions.lock_after", "DELETE");
    expect((await signIn("alice")).status).toBe(200);
  });

  it("验证码: how long a code lasts, as the message says, and the wait for another are the panel's (WP32.2)", async () => {
    const ask = () => call("alice", "/v1/account/phone", "POST", { phone: "+85291234567" });
    await call("boss", "/v1/admin/settings/codes.minutes", "PUT", { value: 3 });
    const first = await ask();
    expect(first.status).toBe(202);
    expect(Date.parse((await first.json()).expires_at) - Date.parse(AT)).toBe(3 * 60_000);
    expect(sms.sent.at(-1)!.text).toContain("3 分钟内有效");
    // A minute's wait by default; none once the panel says 0.
    const again = await ask();
    expect([again.status, (await again.json()).code]).toEqual([429, "wait"]);
    await call("boss", "/v1/admin/settings/codes.resend_seconds", "PUT", { value: 0 });
    expect((await ask()).status).toBe(202);
    for (const key of ["codes.minutes", "codes.resend_seconds"])
      await call("boss", `/v1/admin/settings/${key}`, "DELETE");
  });

  it("限额: 增加积分's most at once is the panel's, and /v1/admin/me says it (WP32.3)", async () => {
    const grant = (points: number) =>
      call("boss", `/v1/admin/users/${ids.alice}/points`, "POST", { points });
    expect((await (await call("boss", "/v1/admin/me")).json()).grant_max).toBe(1_000_000);
    await call("boss", "/v1/admin/settings/limits.grant_max", "PUT", { value: 500 });
    expect((await (await call("mgr", "/v1/admin/me")).json()).grant_max).toBe(500);
    expect((await grant(501)).status).toBe(400);
    expect((await grant(500)).status).toBe(201);
    await call("boss", "/v1/admin/settings/limits.grant_max", "DELETE");
    expect((await grant(501)).status).toBe(201);
  });
});

describe("登录's window (WP32.1)", () => {
  it("is read at each sign-in: a failure older than the panel's minutes no longer counts", async () => {
    const s = new Settings(undefined, {});
    let t = 0;
    const limiter = new FailureLimiter(
      () => t,
      () => failureLimits(s),
    );
    expect(limiter.limits()).toEqual({ windowMs: 15 * 60_000, captchaAfter: 3, lockAfter: 10 });
    limiter.fail("k");
    t = 2 * 60_000;
    expect(limiter.count("k")).toBe(1);
    await s.set("sessions.failure_window_minutes", 1, undefined, AT);
    expect(limiter.count("k")).toBe(0);
  });
});
