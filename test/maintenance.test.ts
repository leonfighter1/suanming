// 维护通知 (S35; the owner, 2026-10-31: 「添加正在维护的通知，admin可以toggle 告知用户何时能够登录 by default 3-4 小时，
// 可以自己定时。这个可以在dashboard中操作」): an admin switches it in 设置; anyone but staff waits, told until when.
import { beforeAll, describe, expect, it } from "vitest";
import { InMemoryStore } from "../src/api/store.js";
import { buildAuth } from "../src/service/runtime.js";
import { problemOf, Settings, settingSpec } from "../src/settings/index.js";
import { staffApi } from "./api.js";
import { DRAW_KEY, PEPPER } from "./helpers.js";

let clock = new Date("2026-10-31T08:00:00.000Z");
const store = new InMemoryStore();
const settings = new Settings(store, {});
const auth = buildAuth(
  { digestPepper: PEPPER, drawKey: DRAW_KEY, ephemeral: true } as never,
  true,
  undefined,
  undefined,
  settings,
);
const { start, call, sessions } = staffApi(
  { auth, store, settings, admins: ["boss"], now: () => clock },
  ["boss", "mgr", "alice"],
  { mgr: "manager" },
);
const signIn = (login: string) => call(null, "/v1/auth/login", "POST", { login, password: login });
const set = (key: string, value: unknown) =>
  call("boss", `/v1/admin/settings/${key}`, "PUT", { value });

describe("维护 (S35)", () => {
  beforeAll(start);

  it("a time setting takes a date and time, or none", () => {
    const spec = settingSpec("maintenance.until")!;
    expect(problemOf(spec, "2026-10-31T12:00:00.000Z")).toBeUndefined();
    expect(problemOf(spec, null)).toBeUndefined();
    expect(problemOf(spec, "tomorrow")).toBe("要一个时间（日期和几点几分）");
    expect(problemOf(spec, "2026-10-31")).toBe("要一个时间（日期和几点几分）");
  });

  it("off: everyone is served, and the status says so", async () => {
    expect(await (await call(null, "/v1/status")).json()).toEqual({ maintenance: null });
    expect((await call("alice", "/v1/me")).status).toBe(200);
  });

  it("on: anyone but staff waits, told three to four hours from the switch; staff work as usual", async () => {
    expect((await set("maintenance.on", true)).status).toBe(200);
    const window = {
      since: "2026-10-31T08:00:00.000Z",
      ends_from: "2026-10-31T11:00:00.000Z",
      ends_by: "2026-10-31T12:00:00.000Z",
    };
    // An hour on, the window still counts from the switch.
    clock = new Date("2026-10-31T09:00:00.000Z");
    expect(await (await call(null, "/v1/status")).json()).toEqual({ maintenance: window });

    const me = await call("alice", "/v1/me");
    expect(me.status).toBe(503);
    expect(await me.json()).toMatchObject({ code: "maintenance", ...window });
    // Signing in and signing up wait too.
    const again = await signIn("alice");
    expect(again.status).toBe(503);
    expect((await again.json()).code).toBe("maintenance");
    const join = await call(null, "/v1/auth/register", "POST", {
      username: "newcomer",
      password: "long enough pw",
      country: "HK",
      locale: "zh-Hans",
      age_confirmed: true,
    });
    expect(join.status).toBe(503);
    // A session already open keeps itself: its refresh goes on, for when it ends.
    const refresh = await call(null, "/v1/auth/refresh", "POST", {
      refresh_token: sessions.alice!.refresh_token,
    });
    expect(refresh.status).toBe(200);

    // Staff: signed in, the app and the 管理后台 as usual.
    expect((await signIn("mgr")).status).toBe(200);
    expect((await call("mgr", "/v1/me")).status).toBe(200);
    expect((await call("boss", "/v1/admin/me")).status).toBe(200);
  });

  it("an end an admin set is the time users are told; switched off, everyone is back", async () => {
    expect((await set("maintenance.until", "2026-10-31T10:30:00.000Z")).status).toBe(200);
    expect((await (await call(null, "/v1/status")).json()).maintenance).toMatchObject({
      ends_from: "2026-10-31T10:30:00.000Z",
      ends_by: "2026-10-31T10:30:00.000Z",
    });
    expect((await set("maintenance.until", "soon")).status).toBe(400);
    expect((await set("maintenance.on", false)).status).toBe(200);
    expect(await (await call(null, "/v1/status")).json()).toEqual({ maintenance: null });
    expect((await signIn("alice")).status).toBe(200);
  });
});
