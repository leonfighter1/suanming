import type { AddressInfo } from "node:net";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { generateRemedy, generateReport, MockProvider } from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import { computeBazi } from "../src/engines/bazi/index.js";
import { computeTarot } from "../src/engines/tarot/index.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";

const chart = computeBazi(
  {
    local: "1990-03-15T14:30",
    timezone: "Asia/Hong_Kong",
    longitude: 114.17,
    gender: "male",
    options: { liunianFrom: 2026 },
  },
  { digestPepper: PEPPER, now: FIXED_NOW },
);
const deps = (mock: MockProvider) => ({
  providers: { deepseek: mock, anthropic: mock },
  now: FIXED_NOW,
});
const zhHantHK = { locale: "zh-Hant" as const, country: "HK" };
const scores = (n: number) => ({ career_wealth: n, health: n });

describe("trend scores", () => {
  it("drops periods not in the chart, clamps scores and asks again for gaps", async () => {
    const mock = new MockProvider({
      trend: [
        {
          kind: "ok",
          data: {
            dayun: [
              { index: 1, scores: scores(140), note: "甲" },
              { index: 99, scores: scores(60), note: "不存在" },
            ],
            liunian: [{ year: 1900, scores: scores(60), note: "不存在" }],
          },
        },
      ],
    });
    const r = await generateReport(
      chart,
      { ...zhHantHK, topics: ["career_wealth", "health"] },
      deps(mock),
    );
    expect(r.status).toBe("passed");
    const trendCalls = mock.calls.filter((c) => c.agent === "trend");
    expect(trendCalls).toHaveLength(2);
    expect(trendCalls[1]!.user).toContain("scores must be 0–100");
    expect(trendCalls[1]!.user).toContain("missing dayun indices: 2, 3");
    // The retry (mock default) covers every period of the chart.
    expect(r.layers!.trend!.dayun).toHaveLength(8);
    expect(r.layers!.trend!.liunian.map((y) => y.year)).toEqual(
      Array.from({ length: 10 }, (_, i) => 2026 + i),
    );
  });

  it("a blocked trend note drops the trend chart but keeps the report", async () => {
    const bad = {
      kind: "ok" as const,
      data: {
        dayun: [{ index: 1, scores: scores(50), note: "不轉運的話，下半年就會出事。" }],
        liunian: [],
      },
    };
    const mock = new MockProvider({ trend: [bad, bad] });
    const r = await generateReport(
      chart,
      { ...zhHantHK, topics: ["career_wealth", "health"] },
      deps(mock),
    );
    expect(r.status).toBe("passed");
    expect(r.layers!.trend).toBeUndefined();
    expect(r.reasons.join()).toMatch(/trend omitted/);
  });

  it("tarot reports have no trend agent", async () => {
    const tarot = computeTarot(
      { spread: "three_card" },
      { digestPepper: PEPPER, drawKey: DRAW_KEY, now: FIXED_NOW },
    );
    const mock = new MockProvider();
    const r = await generateReport(tarot, zhHantHK, deps(mock));
    expect(r.status).toBe("passed");
    expect(r.layers!.trend).toBeUndefined();
    expect(mock.calls.some((c) => c.agent === "trend")).toBe(false);
  });
});

describe("generateRemedy", () => {
  it("writes a plan for one topic, naming its target, through the guard", async () => {
    const mock = new MockProvider();
    const report = await generateReport(chart, zhHantHK, deps(mock));
    const remedy = await generateRemedy(
      chart,
      report,
      "career_wealth",
      { country: "HK" },
      deps(mock),
    );
    expect(remedy.status).toBe("passed");
    expect(remedy.content!.target).toContain("事業財運");
    expect(remedy.content!.steps.length).toBeGreaterThanOrEqual(3);
    expect(remedy.content!.closing).toMatch(/不保證任何結果/);
    expect(remedy.agents.map((a) => a.agent)).toEqual(["remedy", "guard"]);
    expect(remedy.agents[0]!.prompt_version).toBe("remedy@1");
    // The model sees this topic's trend and only this topic's reading.
    const call = mock.calls.find((c) => c.agent === "remedy")!;
    expect(call.user).toContain("<trend>");
    expect(call.user).toContain('"topic": "career_wealth"');
    expect(call.user).not.toContain('"topic": "health"');
  });

  it("blocks a plan that keeps using paywall-fear language", async () => {
    const mock = new MockProvider();
    const report = await generateReport(chart, zhHantHK, deps(mock));
    const bad = {
      kind: "ok" as const,
      data: {
        target: "事業財運",
        summary: "不化解的話，明年就會破財。",
        focus_periods: [],
        steps: [{ title: "a", text: "b", horizon: "ongoing" }],
        basis: "日主",
        fact_refs: ["/day_master"],
      },
    };
    const m2 = new MockProvider({ remedy: [bad, bad] });
    const remedy = await generateRemedy(
      chart,
      report,
      "career_wealth",
      { country: "HK" },
      deps(m2),
    );
    expect(remedy.status).toBe("blocked");
    expect(remedy.content).toBeUndefined();
    expect(m2.calls.some((c) => c.agent === "guard")).toBe(false);
  });

  it("refuses a topic the report doesn't cover", async () => {
    const mock = new MockProvider();
    const report = await generateReport(chart, { ...zhHantHK, topics: ["health"] }, deps(mock));
    await expect(
      generateRemedy(chart, report, "career_wealth", { country: "HK" }, deps(mock)),
    ).rejects.toThrow(/not in this report/);
  });
});

describe("remedy API", () => {
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
  const H = (user = "u1") => ({
    "content-type": "application/json",
    "x-dev-country": "HK",
    "x-dev-user": user,
  });
  const post = (path: string, body: unknown, user = "u1") =>
    fetch(base + path, { method: "POST", headers: H(user), body: JSON.stringify(body) });
  const get = (path: string, user = "u1") => fetch(base + path, { headers: H(user) });

  async function passedReport() {
    const c = await post("/v1/charts", {
      system: "bazi",
      local: "1990-03-15T14:30",
      timezone: "Asia/Hong_Kong",
      longitude: 114.17,
      gender: "male",
    });
    const { chart_id } = await c.json();
    const r = await (await post("/v1/reports", { chart_id, locale: "zh-Hant" })).json();
    return r.report_id as string;
  }

  it("one paid plan per topic", async () => {
    const id = await passedReport();
    await api.drain();

    const list0 = await (await get(`/v1/reports/${id}/remedies`)).json();
    expect(list0).toEqual({ price: { amount: 18, currency: "HKD" }, items: [] });

    const r1 = await post(`/v1/reports/${id}/remedies`, { topic: "health" });
    expect(r1.status).toBe(202);
    const pending = await r1.json();
    expect(pending).toMatchObject({
      topic: "health",
      status: "pending",
      payment: { status: "placeholder", amount: 18, currency: "HKD" },
    });
    expect(r1.headers.get("location")).toBe(`/v1/remedies/${pending.remedy_id}`);

    await api.drain();
    const done = await (await get(`/v1/remedies/${pending.remedy_id}`)).json();
    expect(done.status).toBe("passed");
    expect(done.content.target).toContain("健康");

    // Buying the same topic again returns the same plan (no second charge).
    const again = await post(`/v1/reports/${id}/remedies`, { topic: "health" });
    expect(again.status).toBe(200);
    expect((await again.json()).remedy_id).toBe(pending.remedy_id);

    const list = await (await get(`/v1/reports/${id}/remedies`)).json();
    expect(list.items.map((x: { topic: string }) => x.topic)).toEqual(["health"]);
  });

  it("409 for a report that did not pass", async () => {
    const bad = {
      kind: "ok" as const,
      data: {
        sections: [
          {
            topic: "health",
            paragraphs: [
              {
                text: "不轉運的話，下半年就會出事。",
                source_level: "derived",
                fact_refs: ["/day_master"],
              },
            ],
          },
        ],
      },
    };
    const m = new MockProvider({ narrative: [bad, bad] });
    const api2 = createApiServer({
      secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
      providers: { deepseek: m, anthropic: m },
      devMode: true,
      log: () => {},
    });
    await new Promise<void>((r) => api2.listen(0, "127.0.0.1", r));
    const b2 = `http://127.0.0.1:${(api2.address() as AddressInfo).port}`;
    const send = (path: string, body?: unknown) =>
      fetch(b2 + path, {
        method: body ? "POST" : "GET",
        headers: H(),
        body: body === undefined ? undefined : JSON.stringify(body),
      });
    const { chart_id } = await (
      await send("/v1/charts", { system: "tarot", spread: "three_card" })
    ).json();
    const r = await (
      await send("/v1/reports", { chart_id, locale: "zh-Hant", topics: ["health"] })
    ).json();
    await api2.drain();
    expect((await (await send(`/v1/reports/${r.report_id}`)).json()).status).not.toBe("passed");
    expect((await send(`/v1/reports/${r.report_id}/remedies`, { topic: "health" })).status).toBe(
      409,
    );
    await new Promise<void>((done) => api2.close(() => done()));
  });

  it("rejects unknown topics and other users", async () => {
    const id = await passedReport();
    await api.drain();
    expect((await post(`/v1/reports/${id}/remedies`, { topic: "nope" })).status).toBe(400);
    expect((await post(`/v1/reports/${id}/remedies`, { topic: "health" }, "u2")).status).toBe(404);
    const mine = await (await post(`/v1/reports/${id}/remedies`, { topic: "wuxing" })).json();
    await api.drain();
    expect((await get(`/v1/remedies/${mine.remedy_id}`, "u2")).status).toBe(404);
  });
});
