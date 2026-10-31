// ☰ → 管理后台 without a second sign-in (S33; the owner, 2026-10-31: 「如果当前登录进去的用户有dashboard access，那么不需要
// 重复登录了」, 「不需要重复登录dashboard 页面了」): the app asks for a one-time code, the dashboard signs in with it.
import { beforeAll, describe, expect, it } from "vitest";
import { InMemoryStore } from "../src/api/store.js";
import { AuthService, HANDOFF_TTL_MS } from "../src/auth/service.js";
import { TokenService } from "../src/auth/tokens.js";
import { buildAuth } from "../src/service/runtime.js";
import { staffApi } from "./api.js";
import { DRAW_KEY, PEPPER } from "./helpers.js";

const auth = buildAuth({ digestPepper: PEPPER, drawKey: DRAW_KEY, ephemeral: true } as never, true);
const { start, call, sessions } = staffApi(
  { auth, store: new InMemoryStore(), admins: ["boss"] },
  ["boss", "mgr", "alice"],
  { mgr: "manager" },
);

describe("the one-time code, through the API", () => {
  beforeAll(start);

  it("signs the dashboard in with a session of its own, once", async () => {
    const asked = await call("mgr", "/v1/account/handoff", "POST", {});
    expect(asked.status).toBe(201);
    const { code, expires_at } = (await asked.json()) as { code: string; expires_at: string };
    expect(code).toMatch(/^[\w-]{43}$/);
    expect(Date.parse(expires_at) - Date.now()).toBeLessThanOrEqual(HANDOFF_TTL_MS);

    const signed = await call(null, "/v1/auth/handoff", "POST", { code });
    expect(signed.status).toBe(200);
    sessions.dashboard = (await signed.json()) as { access_token: string; refresh_token: string };
    const me = (await (await call("dashboard", "/v1/admin/me")).json()) as {
      login: string;
      role: string;
    };
    expect([me.login, me.role]).toEqual(["mgr", "manager"]);
    // Its own session: the app's stays signed in.
    expect((await call("mgr", "/v1/me")).status).toBe(200);

    const again = await call(null, "/v1/auth/handoff", "POST", { code });
    expect([again.status, ((await again.json()) as { code: string }).code]).toEqual([
      401,
      "handoff_invalid",
    ]);
  });

  it("is for staff alone; a code nobody gave signs nobody in", async () => {
    const user = await call("alice", "/v1/account/handoff", "POST", {});
    expect([user.status, ((await user.json()) as { code: string }).code]).toEqual([
      403,
      "not_staff",
    ]);
    for (const code of ["nope", "", 7]) {
      expect((await call(null, "/v1/auth/handoff", "POST", { code })).status, String(code)).toBe(
        401,
      );
    }
  });
});

describe("a code's life", () => {
  it("is two minutes", async () => {
    let clock = Date.parse("2026-10-31T08:00:00.000Z");
    const now = () => new Date(clock);
    const service = new AuthService({
      pepper: PEPPER,
      tokens: new TokenService(Buffer.alloc(32, 3), now),
      now,
    });
    await service.seedDevUser({
      login: "staff1",
      password: "staff1",
      country: "HK",
      locale: "zh-Hans",
    });
    const user = (await service.findLogin("username", "staff1"))!;

    const late = service.handoff(user.id);
    clock += HANDOFF_TTL_MS + 1;
    await expect(service.redeemHandoff(late.code)).rejects.toMatchObject({
      status: 401,
      code: "handoff_invalid",
    });
    const fresh = service.handoff(user.id);
    clock += HANDOFF_TTL_MS - 1000;
    expect((await service.redeemHandoff(fresh.code)).access_token).toBeTruthy();
  });
});
