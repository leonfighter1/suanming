import type { AddressInfo } from "node:net";
import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT, type JWK } from "jose";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { MockProvider } from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import { InMemoryStore } from "../src/api/store.js";
import {
  CAPTCHA_AFTER,
  FailureLimiter,
  LOCK_AFTER,
  type CaptchaVerifier,
} from "../src/auth/limits.js";
import { AuthService } from "../src/auth/service.js";
import { SocialVerifier } from "../src/auth/social.js";
import { TokenService } from "../src/auth/tokens.js";
import { DRAW_KEY, PEPPER } from "./helpers.js";

// Clock the tests can move forward (token expiry).
let clock = Date.parse("2026-10-26T00:00:00Z");
const now = () => new Date(clock);

// Local "Apple" keys: sign ID tokens the way Apple would.
const apple = await generateKeyPair("RS256");
const appleJwk: JWK = { ...(await exportJWK(apple.publicKey)), kid: "k1", alg: "RS256" };
const appleIdToken = (claims: Record<string, unknown>, aud = "com.mingli.app") =>
  new SignJWT(claims)
    .setProtectedHeader({ alg: "RS256", kid: "k1" })
    .setIssuer("https://appleid.apple.com")
    .setAudience(aud)
    .setIssuedAt(Math.floor(clock / 1000))
    .setExpirationTime(Math.floor(clock / 1000) + 600)
    .sign(apple.privateKey);

const captcha: CaptchaVerifier = { name: "test", verify: async (t) => t === "ok" };
const store = new InMemoryStore();
const tokens = new TokenService(Buffer.alloc(32, 5), now);
const auth = new AuthService({
  pepper: PEPPER,
  tokens,
  captcha,
  limiter: new FailureLimiter(() => clock),
  social: new SocialVerifier({
    audiences: { apple: ["com.mingli.app"] },
    keys: { apple: createLocalJWKSet({ keys: [appleJwk] }) },
    now,
  }),
  now,
});
const mock = new MockProvider();
const api = createApiServer({
  secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
  providers: { deepseek: mock, anthropic: mock },
  store,
  auth,
  now,
  log: () => {},
});
let base = "";
beforeAll(async () => {
  await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
  base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
});
afterAll(() => new Promise<void>((r) => api.close(() => r())));

const json = { "content-type": "application/json" };
const post = (path: string, body: unknown, token?: string) =>
  fetch(base + path, {
    method: "POST",
    headers: { ...json, ...(token && { authorization: `Bearer ${token}` }) },
    body: JSON.stringify(body),
  });
const authed = (token: string, path: string, method = "GET") =>
  fetch(base + path, { method, headers: { authorization: `Bearer ${token}` } });

const profile = { country: "TW", locale: "zh-Hant", age_confirmed: true };
const register = async (email: string, password = "long enough pw", p = profile) =>
  post("/v1/auth/register", { email, password, ...p });

describe("registration", () => {
  it("creates an account and returns a token pair", async () => {
    const res = await register("a@example.com");
    expect(res.status).toBe(201);
    const t = await res.json();
    expect(t).toMatchObject({ token_type: "Bearer", expires_in: 900 });
    const me = await (await authed(t.access_token, "/v1/me")).json();
    expect(me).toMatchObject({
      email: "a@example.com",
      country: "TW",
      sign_in_methods: ["password"],
    });
  });

  it("rejects duplicates, weak passwords, bad emails", async () => {
    expect((await register("A@Example.com ")).status).toBe(409); // case/space-insensitive
    expect((await register("b@example.com", "short")).status).toBe(400);
    expect((await register("not-an-email")).status).toBe(400);
  });

  it("enforces Geo-Rule and the age gate at sign-up", async () => {
    const cn = await register("c@example.com", "long enough pw", { ...profile, country: "CN" });
    expect(cn.status).toBe(451);
    expect((await cn.json()).code).toBe("region");
    const young = await register("d@example.com", "long enough pw", {
      ...profile,
      age_confirmed: false,
    });
    expect(young.status).toBe(400);
    expect((await young.json()).code).toBe("age");
  });

  it("never stores the plain email as the lookup key", async () => {
    const u = await auth.users.byEmailLookup(auth.emailLookup("a@example.com"));
    expect(u!.email_lookup).toMatch(/^[0-9a-f]{64}$/);
    expect(u!.password_hash).toMatch(/^\$argon2id\$/);
  });
});

describe("login protection", () => {
  it("logs in with the right password", async () => {
    await register("e@example.com");
    const res = await post("/v1/auth/login", {
      email: "e@example.com",
      password: "long enough pw",
    });
    expect(res.status).toBe(200);
  });

  it(`requires a captcha after ${CAPTCHA_AFTER} failures and locks after ${LOCK_AFTER}`, async () => {
    await register("f@example.com");
    const bad = { email: "f@example.com", password: "wrong password" };
    for (let i = 0; i < CAPTCHA_AFTER; i++)
      expect((await post("/v1/auth/login", bad)).status).toBe(401);
    const needs = await post("/v1/auth/login", bad);
    expect(needs.status).toBe(400);
    expect((await needs.json()).code).toBe("captcha_required");
    for (let i = CAPTCHA_AFTER; i < LOCK_AFTER; i++) {
      expect((await post("/v1/auth/login", { ...bad, captcha_token: "ok" })).status).toBe(401);
    }
    const locked = await post("/v1/auth/login", {
      ...bad,
      password: "long enough pw",
      captcha_token: "ok",
    });
    expect(locked.status).toBe(429);
    clock += 16 * 60_000; // window passes
    const ok = await post("/v1/auth/login", { email: "f@example.com", password: "long enough pw" });
    expect(ok.status).toBe(200);
  });

  it("does not reveal whether an account exists", async () => {
    const res = await post("/v1/auth/login", {
      email: "nobody@example.com",
      password: "whatever pw",
    });
    expect(res.status).toBe(401);
    expect((await res.json()).detail).toBe("email or password is incorrect");
  });
});

describe("tokens", () => {
  it("rotates refresh tokens and revokes the family on reuse", async () => {
    const t1 = await (await register("g@example.com")).json();
    const t2 = await (await post("/v1/auth/refresh", { refresh_token: t1.refresh_token })).json();
    expect(t2.refresh_token).not.toBe(t1.refresh_token);
    // Replaying the old token = theft signal: the whole session dies.
    expect((await post("/v1/auth/refresh", { refresh_token: t1.refresh_token })).status).toBe(401);
    expect((await post("/v1/auth/refresh", { refresh_token: t2.refresh_token })).status).toBe(401);
  });

  it("expires access tokens after 15 minutes", async () => {
    const t = await (await register("h@example.com")).json();
    expect((await authed(t.access_token, "/v1/me")).status).toBe(200);
    clock += 16 * 60_000;
    expect((await authed(t.access_token, "/v1/me")).status).toBe(401);
  });

  it("logout revokes the refresh token", async () => {
    const t = await (await register("i@example.com")).json();
    expect((await post("/v1/auth/logout", { refresh_token: t.refresh_token })).status).toBe(204);
    expect((await post("/v1/auth/refresh", { refresh_token: t.refresh_token })).status).toBe(401);
  });

  it("outside dev headers, the region comes from the account", async () => {
    const t = await (
      await register("j@example.com", "long enough pw", { ...profile, country: "DE" })
    ).json();
    const chart = await (
      await post("/v1/charts", { system: "tarot", spread: "single" }, t.access_token)
    ).json();
    const r = await (
      await post("/v1/reports", { chart_id: chart.chart_id, locale: "en" }, t.access_token)
    ).json();
    await api.drain();
    const view = await (await authed(t.access_token, `/v1/reports/${r.report_id}`)).json();
    expect(view.ai_disclosure.label_required).toBe(true); // DE → EU rules
  });
});

describe("Sign in with Apple", () => {
  it("creates the account on first sign-in, then signs the same user in", async () => {
    const id_token = await appleIdToken({
      sub: "apple-001",
      email: "x@privaterelay.appleid.com",
      email_verified: "true",
    });
    const first = await post("/v1/auth/oauth", { provider: "apple", id_token, ...profile });
    expect(first.status).toBe(200);
    const me1 = await (await authed((await first.json()).access_token, "/v1/me")).json();
    expect(me1.sign_in_methods).toEqual(["apple"]);
    const again = await post("/v1/auth/oauth", {
      provider: "apple",
      id_token: await appleIdToken({ sub: "apple-001" }),
    });
    const me2 = await (await authed((await again.json()).access_token, "/v1/me")).json();
    expect(me2.id).toBe(me1.id);
  });

  it("rejects wrong audience, unconfigured providers, and first sign-in without a profile", async () => {
    const wrongAud = await appleIdToken({ sub: "apple-002" }, "com.someone.else");
    expect(
      (await post("/v1/auth/oauth", { provider: "apple", id_token: wrongAud, ...profile })).status,
    ).toBe(401);
    expect(
      (await post("/v1/auth/oauth", { provider: "google", id_token: "x", ...profile })).status,
    ).toBe(401);
    const noProfile = await post("/v1/auth/oauth", {
      provider: "apple",
      id_token: await appleIdToken({ sub: "apple-003" }),
    });
    expect(noProfile.status).toBe(400);
  });
});

describe("DELETE /v1/account", () => {
  it("deletes the account and everything it owns, immediately", async () => {
    const t = await (await register("k@example.com")).json();
    const chart = await (
      await post("/v1/charts", { system: "tarot", spread: "single" }, t.access_token)
    ).json();
    const r = await (
      await post("/v1/reports", { chart_id: chart.chart_id, locale: "zh-Hant" }, t.access_token)
    ).json();
    await api.drain();

    const res = await authed(t.access_token, "/v1/account", "DELETE");
    expect(res.status).toBe(200);
    expect((await res.json()).deleted).toEqual({
      account: true,
      charts: 1,
      reports: 1,
      remedies: 1, // the tarot reading's one plan (on its 建议) was preloaded
      life_reports: 0,
    });
    expect((await authed(t.access_token, "/v1/me")).status).toBe(401);
    expect((await post("/v1/auth/refresh", { refresh_token: t.refresh_token })).status).toBe(401);
    expect(await store.getReport(r.report_id)).toBeUndefined();
    expect(
      (await post("/v1/auth/login", { email: "k@example.com", password: "long enough pw" })).status,
    ).toBe(401);
  });

  it("a report still generating when the account is deleted is not written back", async () => {
    const t = await (await register("l@example.com")).json();
    const chart = await (
      await post("/v1/charts", { system: "tarot", spread: "single" }, t.access_token)
    ).json();
    const r = await (
      await post("/v1/reports", { chart_id: chart.chart_id, locale: "zh-Hant" }, t.access_token)
    ).json();
    await authed(t.access_token, "/v1/account", "DELETE"); // before the job finishes
    await api.drain();
    expect(await store.getReport(r.report_id)).toBeUndefined();
  });
});

describe("dev accounts", () => {
  it("admin / admin can sign in after seeding; seeding is refused outside dev mode", async () => {
    const { seedDevAccounts } = await import("../src/service/runtime.js");
    await expect(seedDevAccounts(auth, false)).rejects.toThrow(/dev mode/);
    await seedDevAccounts(auth, true);
    await seedDevAccounts(auth, true); // idempotent
    const res = await post("/v1/auth/login", { email: "admin", password: "admin" });
    expect(res.status).toBe(200);
    const me = await (await authed((await res.json()).access_token, "/v1/me")).json();
    expect(me).toMatchObject({ email: "admin", country: "HK" });
    // Normal registration rules still apply to everyone else.
    expect((await register("admin2", "admin")).status).toBe(400);
  });
});
