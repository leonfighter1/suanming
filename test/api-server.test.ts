import type { AddressInfo } from "node:net";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { MockProvider } from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import { AuthService } from "../src/auth/service.js";
import { TokenService } from "../src/auth/tokens.js";
import { DRAW_KEY, PEPPER } from "./helpers.js";

const mock = new MockProvider();
const api = createApiServer({
  secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
  providers: { deepseek: mock, anthropic: mock },
  devMode: true,
  log: () => {},
});
let base = "";

beforeAll(async () => {
  await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
  base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
});
afterAll(() => new Promise<void>((r) => api.close(() => r())));

const H = (country = "HK", user = "u1", extra: Record<string, string> = {}) => ({
  "content-type": "application/json",
  "x-dev-country": country,
  "x-dev-user": user,
  ...extra,
});
const post = (path: string, body: unknown, headers = H()) =>
  fetch(base + path, { method: "POST", headers, body: JSON.stringify(body) });
const get = (path: string, headers = H()) => fetch(base + path, { headers });

const bazi = {
  system: "bazi",
  local: "1990-03-15T14:30",
  timezone: "Asia/Hong_Kong",
  longitude: 114.17,
  gender: "male",
};

describe("v1 API", () => {
  it("health needs no auth and reports versions", async () => {
    const res = await fetch(base + "/v1/health");
    const data = await res.json();
    expect(res.status).toBe(200);
    expect(data.versions).toMatchObject({ chart_fact_schema: "0.1.0", geo_rule_matrix: "0.1.0" });
  });

  it("creates a chart, then a report that completes asynchronously", async () => {
    const c = await post("/v1/charts", bazi);
    expect(c.status).toBe(201);
    const { chart_id, chart_fact } = await c.json();
    expect(chart_fact.system).toBe("bazi");

    const r = await post("/v1/reports", {
      chart_id,
      locale: "zh-Hant",
      topics: ["wuxing", "health"],
    });
    expect(r.status).toBe(202);
    expect(r.headers.get("location")).toMatch(/^\/v1\/reports\//);
    const pending = await r.json();
    expect(pending.status).toBe("pending");
    expect(pending.layers).toBeUndefined();

    await api.drain();
    const done = await get(`/v1/reports/${pending.report_id}`);
    expect(done.headers.get("x-ai-generated")).toBe("true");
    const view = await done.json();
    expect(view.status).toBe("passed");
    expect(view.layers.interpretation.map((s: { topic: string }) => s.topic)).toEqual([
      "wuxing",
      "health",
    ]);
    expect(view.ai_disclosure.prompt_version).toBe("narrative@1,action@1,guard@1");
    // internal details never reach the client
    for (const k of ["draft", "agents", "compliance"]) expect(view).not.toHaveProperty(k);
  });

  it("scopes charts and reports to their owner", async () => {
    const { chart_id } = await (await post("/v1/charts", bazi)).json();
    const other = await post("/v1/reports", { chart_id, locale: "zh-Hant" }, H("HK", "u2"));
    expect(other.status).toBe(404);
    const { report_id } = await (await post("/v1/reports", { chart_id, locale: "en" })).json();
    expect((await get(`/v1/reports/${report_id}`, H("HK", "u2"))).status).toBe(404);
    await api.drain();
  });

  it("refuses unserved regions with 451 before computing", async () => {
    const res = await post("/v1/charts", bazi, H("CN"));
    expect(res.status).toBe(451);
    expect(res.headers.get("content-type")).toMatch(/problem\+json/);
  });

  it("validates input: 400 for bad fields, 422 for a DST-gap birth time", async () => {
    expect((await post("/v1/charts", { ...bazi, gender: "x" })).status).toBe(400);
    expect((await post("/v1/charts", { system: "nope" })).status).toBe(400);
    const gap = await post(
      "/v1/charts",
      { ...bazi, local: "2021-03-14T02:30", timezone: "America/New_York", longitude: -74 },
      H("US"),
    );
    expect(gap.status).toBe(422);
    const { chart_id } = await (
      await post("/v1/charts", { system: "tarot", spread: "single" })
    ).json();
    expect(
      (await post("/v1/reports", { chart_id, locale: "zh-Hant", topics: ["wuxing"] })).status,
    ).toBe(400);
    expect((await post("/v1/reports", { chart_id, locale: "fr" })).status).toBe(400);
  });

  it("replays Idempotency-Key requests instead of creating twice", async () => {
    const h = H("HK", "u1", { "idempotency-key": "abc-123" });
    const a = await (await post("/v1/charts", bazi, h)).json();
    const b = await (await post("/v1/charts", bazi, h)).json();
    expect(b.chart_id).toBe(a.chart_id);
  });

  it("requires the dev country header and rejects non-dev callers", async () => {
    expect((await fetch(base + "/v1/charts", { method: "POST", body: "{}" })).status).toBe(400);
    expect(() =>
      createApiServer({ secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY }, providers: {} }),
    ).toThrow(/auth is required/);
    const prod = createApiServer({
      secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
      providers: {},
      auth: new AuthService({ pepper: PEPPER, tokens: new TokenService(PEPPER) }),
      log: () => {},
    });
    await new Promise<void>((r) => prod.listen(0, "127.0.0.1", r));
    const url = `http://127.0.0.1:${(prod.address() as AddressInfo).port}`;
    expect((await fetch(url + "/v1/charts", { method: "POST", body: "{}" })).status).toBe(401);
    expect((await fetch(url + "/v1/health")).status).toBe(200);
    await new Promise<void>((r) => prod.close(() => r()));
  });

  it("marks a report failed (not manual_review) when the provider is down", async () => {
    const down = createApiServer({
      secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
      providers: {
        deepseek: {
          name: "down",
          generateJson: async () => {
            throw new Error("boom");
          },
        },
      },
      devMode: true,
      log: () => {},
    });
    await new Promise<void>((r) => down.listen(0, "127.0.0.1", r));
    const url = `http://127.0.0.1:${(down.address() as AddressInfo).port}`;
    const p = (path: string, body: unknown) =>
      fetch(url + path, { method: "POST", headers: H(), body: JSON.stringify(body) });
    const { chart_id } = await (await p("/v1/charts", bazi)).json();
    const { report_id } = await (await p("/v1/reports", { chart_id, locale: "zh-Hant" })).json();
    await down.drain();
    const view = await (await fetch(`${url}/v1/reports/${report_id}`, { headers: H() })).json();
    expect(view.status).toBe("failed");
    await new Promise<void>((r) => down.close(() => r()));
  });
});
