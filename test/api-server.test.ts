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
    expect(view.ai_disclosure.prompt_version).toBe("narrative@4,trend@2,action@3,guard@2");
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

describe("GET /v1/calendar/lunar", () => {
  it("returns the 農曆 date without auth and validates input", async () => {
    const ok = await fetch(base + "/v1/calendar/lunar?date=2023-03-22");
    expect(ok.status).toBe(200);
    expect((await ok.json()).lunar).toMatchObject({ month_name: "闰二月", day_name: "初一" });
    expect((await fetch(base + "/v1/calendar/lunar?date=2023-02-30")).status).toBe(400);
    expect((await fetch(base + "/v1/calendar/lunar?date=x")).status).toBe(400);
  });
});

describe("history and live progress", () => {
  it("lists the owner's readings and charts newest first, and reopens a chart", async () => {
    const h = H("HK", "hist");
    const c1 = await (await post("/v1/charts", bazi, h)).json();
    const c2 = await (
      await post("/v1/charts", { system: "tarot", spread: "three_card" }, h)
    ).json();
    const r1 = await (
      await post("/v1/reports", { chart_id: c1.chart_id, locale: "zh-Hant" }, h)
    ).json();
    await api.drain();

    const reports = (await (await get("/v1/reports", h)).json()).items;
    expect(reports).toHaveLength(1);
    expect(reports[0]).toMatchObject({
      report_id: r1.report_id,
      status: "passed",
      chart_id: c1.chart_id,
    });
    expect(reports[0].chart).toMatchObject({ system: "bazi", four_pillars: "庚午 己卯 己卯 辛未" });
    expect(reports[0]).not.toHaveProperty("layers"); // list stays light; open the report for content

    const charts = (await (await get("/v1/charts", h)).json()).items;
    expect(charts.map((c: { chart_id: string }) => c.chart_id)).toEqual([c2.chart_id, c1.chart_id]);
    expect(charts[0].chart.cards).toHaveLength(3);

    const again = await (await get(`/v1/charts/${c1.chart_id}`, h)).json();
    expect(again.chart_fact.system).toBe("bazi");
    expect((await get(`/v1/charts/${c1.chart_id}`, H("HK", "someone-else"))).status).toBe(404);
    expect((await (await get("/v1/reports", H("HK", "someone-else"))).json()).items).toEqual([]);
  });

  it("a pending report exposes the stage the pipeline is in", async () => {
    let release!: () => void;
    const gate = new Promise<void>((r) => (release = r));
    const slow = {
      name: "slow",
      generateJson: async (req: Parameters<MockProvider["generateJson"]>[0]) => {
        if (req.agent === "action") await gate;
        return mock.generateJson(req);
      },
    };
    const s = createApiServer({
      secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
      providers: { deepseek: slow, anthropic: slow },
      devMode: true,
      log: () => {},
    });
    await new Promise<void>((r) => s.listen(0, "127.0.0.1", r));
    const url = `http://127.0.0.1:${(s.address() as AddressInfo).port}`;
    const p = (path: string, body: unknown) =>
      fetch(url + path, { method: "POST", headers: H(), body: JSON.stringify(body) });
    const { chart_id } = await (await p("/v1/charts", bazi)).json();
    const { report_id } = await (await p("/v1/reports", { chart_id, locale: "zh-Hant" })).json();
    let view: { status: string; progress?: { stage: string; attempt: number } } = { status: "" };
    for (let i = 0; i < 50 && view.progress?.stage !== "action"; i++) {
      view = await (await fetch(`${url}/v1/reports/${report_id}`, { headers: H() })).json();
      await new Promise((r) => setTimeout(r, 10));
    }
    expect(view).toMatchObject({ status: "pending", progress: { stage: "action", attempt: 1 } });
    release();
    await s.drain();
    const done = await (await fetch(`${url}/v1/reports/${report_id}`, { headers: H() })).json();
    expect(done.status).toBe("passed");
    expect(done).not.toHaveProperty("progress");
    await new Promise<void>((r) => s.close(() => r()));
  });
});

describe("calendar endpoints for 農曆 / 時辰 pickers", () => {
  it("lunar-months, solar conversion and 時辰 list", async () => {
    const months = await (await fetch(base + "/v1/calendar/lunar-months?year=2023")).json();
    expect(months.months.map((m: { name: string }) => m.name).slice(0, 4)).toEqual([
      "正月",
      "二月",
      "闰二月",
      "三月",
    ]);
    const solar = await (
      await fetch(base + "/v1/calendar/solar?year=2023&month=2&day=1&leap=true")
    ).json();
    expect(solar).toMatchObject({
      date: "2023-03-22",
      lunar: { month_name: "闰二月", day_name: "初一" },
    });
    expect(
      (await fetch(base + "/v1/calendar/solar?year=2024&month=2&day=1&leap=true")).status,
    ).toBe(400);
    const day = await (await fetch(base + "/v1/calendar/lunar?date=1990-03-15")).json();
    expect(day.shichen).toHaveLength(13);
    expect(day.shichen.find((s: { zhi: string }) => s.zhi === "未").ganzhi).toBe("辛未");
  });

  it("bad inputBasis is a 400, not a 500", async () => {
    const res = await post("/v1/charts", {
      ...bazi,
      options: { inputBasis: { date: "gregorian", time: "shichen", shichen: "X" } },
    });
    expect(res.status).toBe(400);
  });
});
