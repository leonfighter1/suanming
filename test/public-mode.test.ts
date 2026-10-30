import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import type { AddressInfo } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { MockProvider } from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import { AuthService } from "../src/auth/service.js";
import { buildAuth } from "../src/service/runtime.js";
import { DRAW_KEY, PEPPER } from "./helpers.js";

// A fake built web app.
const web = mkdtempSync(join(tmpdir(), "mingli-web-"));
writeFileSync(join(web, "index.html"), "<!doctype html><title>app</title>");
writeFileSync(join(web, "main.dart.js"), "console.log(1)");
mkdirSync(join(web, "assets"));
writeFileSync(join(web, "assets", "a.json"), "{}");

const secrets = { digestPepper: PEPPER, drawKey: DRAW_KEY };
const mock = new MockProvider();
let auth: AuthService;
let api: ReturnType<typeof createApiServer>;
let base = "";

beforeAll(async () => {
  auth = buildAuth({ ...secrets, ephemeral: true } as never, true);
  await auth.seedDevUser({ login: "pub", password: "pub", country: "HK", locale: "zh-Hant" });
  api = createApiServer({
    secrets,
    providers: { deepseek: mock, anthropic: mock },
    auth,
    devMode: true,
    devHeaders: false,
    trustProxy: true,
    staticDir: web,
    aiQuota: { perUserPerDay: 2, totalPerDay: 3 },
    preloadRemedies: false, // quota counts here are about reports only
    log: () => {},
  });
  await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
  base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
});
afterAll(() => new Promise<void>((r) => api.close(() => r())));

const login = async (ip: string, password = "pub") =>
  fetch(base + "/v1/auth/login", {
    method: "POST",
    headers: { "content-type": "application/json", "cf-connecting-ip": ip },
    body: JSON.stringify({ email: "pub", password }),
  });

describe("public test mode", () => {
  it("serves the web app on the same origin, with SPA fallback and no traversal", async () => {
    const index = await fetch(base + "/");
    expect(index.status).toBe(200);
    expect(index.headers.get("content-type")).toContain("text/html");
    expect(index.headers.get("cache-control")).toBe("no-cache");
    expect((await fetch(base + "/main.dart.js")).headers.get("content-type")).toContain(
      "javascript",
    );
    expect((await fetch(base + "/assets/a.json")).status).toBe(200);
    // Deep link without an extension → the app; a missing file with one → 404.
    expect(await (await fetch(base + "/history")).text()).toContain("<title>app</title>");
    expect((await fetch(base + "/nope.js")).status).toBe(404);
    expect((await fetch(base + "/..%2f..%2fpackage.json")).status).not.toBe(200);
    // The API still answers under /v1.
    expect((await fetch(base + "/v1/health")).status).toBe(200);
  });

  it("login limits count per client IP from the tunnel header, not per 127.0.0.1", async () => {
    for (let i = 0; i < 10; i++) await login("203.0.113.9", "wrong");
    expect((await login("203.0.113.9", "pub")).status).toBe(429); // locked: same IP + same account
    // Another person (other IP) is not locked out by those failures on the IP key;
    // the account key still counts, so use a fresh account to show the IP split.
    await auth.seedDevUser({ login: "pub2", password: "pub2", country: "HK", locale: "zh-Hant" });
    const other = await fetch(base + "/v1/auth/login", {
      method: "POST",
      headers: { "content-type": "application/json", "cf-connecting-ip": "198.51.100.4" },
      body: JSON.stringify({ email: "pub2", password: "pub2" }),
    });
    expect(other.status).toBe(200);
  });

  it("caps AI jobs per account and in total per day", async () => {
    await auth.seedDevUser({ login: "q1", password: "q1", country: "HK", locale: "zh-Hant" });
    await auth.seedDevUser({ login: "q2", password: "q2", country: "HK", locale: "zh-Hant" });
    const token = async (u: string) =>
      (
        await (
          await fetch(base + "/v1/auth/login", {
            method: "POST",
            headers: {
              "content-type": "application/json",
              "cf-connecting-ip": `192.0.2.${u.length}${u.at(-1)}`,
            },
            body: JSON.stringify({ email: u, password: u }),
          })
        ).json()
      ).access_token as string;
    const report = async (t: string) => {
      const h = { "content-type": "application/json", authorization: `Bearer ${t}` };
      const c = await (
        await fetch(base + "/v1/charts", {
          method: "POST",
          headers: h,
          body: JSON.stringify({
            system: "tarot",
            spread: "three_card",
            question: "最近的工作会顺利吗？",
          }),
        })
      ).json();
      return fetch(base + "/v1/reports", {
        method: "POST",
        headers: h,
        body: JSON.stringify({ chart_id: c.chart_id, locale: "zh-Hant" }),
      });
    };
    const [t1, t2] = [await token("q1"), await token("q2")];
    expect((await report(t1)).status).toBe(202);
    expect((await report(t1)).status).toBe(202);
    const third = await report(t1);
    expect(third.status).toBe(429);
    expect((await third.json()).title).toMatch(/2 per account/);
    expect((await report(t2)).status).toBe(202); // total 3 of 3
    expect((await report(t2)).status).toBe(429); // total cap
    await api.drain();
  });

  it("the X-Dev-User shortcut is off", async () => {
    const res = await fetch(base + "/v1/charts", {
      headers: { "x-dev-user": "u1", "x-dev-country": "HK" },
    });
    expect(res.status).toBe(401);
  });
});
