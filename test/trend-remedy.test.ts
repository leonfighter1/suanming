import type { AddressInfo } from "node:net";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { generateRemedy, generateReport, MockProvider, PROMPTS } from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import { computeAstrology } from "../src/engines/astrology/index.js";
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
  it("are the engine's (v2.0.0): no model is asked, and the same chart gives the same chart", async () => {
    const topics = ["career_wealth", "health"] as const;
    const mock = new MockProvider();
    const r = await generateReport(chart, { ...zhHantHK, topics: [...topics] }, deps(mock));
    expect(r.status).toBe("passed");
    expect(mock.calls.some((c) => c.agent === "trend")).toBe(false);
    const engine = (chart.facts as any).trend;
    const trend = r.layers!.trend!;
    expect(trend.dayun).toHaveLength(8);
    expect(trend.liunian.map((y) => y.year)).toEqual(
      Array.from({ length: 10 }, (_, i) => 2026 + i),
    );
    trend.dayun.forEach((d, i) => {
      expect(d.scores).toEqual({
        career_wealth: engine.dayun[i].scores.career_wealth,
        health: engine.dayun[i].scores.health,
      });
    });
    // Notes are written from the basis, in the reader's script (2026 丙午: 印 for 己土).
    expect(trend.liunian[0]!.note).toMatch(/^丙午：印星當頭（學習和支持你的人）；/);
    const again = await generateReport(
      chart,
      { ...zhHantHK, topics: [...topics] },
      deps(new MockProvider()),
    );
    expect(again.layers!.trend).toEqual(trend);
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
    expect(remedy.agents[0]!.prompt_version).toBe("remedy_bazi@4");
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

  it("a tarot plan has its own prompt and closing note; astrology has no plan (v2.1.0)", async () => {
    const tarot = computeTarot(
      { spread: "three_card" },
      { drawKey: DRAW_KEY, digestPepper: PEPPER, now: FIXED_NOW, newDrawId: () => "draw-1" },
    );
    const mock = new MockProvider();
    const report = await generateReport(tarot, zhHantHK, deps(mock));
    const plan = await generateRemedy(tarot, report, "health", { country: "HK" }, deps(mock));
    expect(plan.status).toBe("passed");
    expect(plan.agents[0]!.prompt_version).toBe("remedy_tarot@1");
    expect(mock.calls.find((c) => c.agent === "remedy")!.system).toBe(PROMPTS.remedy_tarot.system);
    expect(mock.calls.find((c) => c.agent === "remedy")!.user).not.toContain("<trend>");
    expect(plan.content!.closing).toMatch(/^以上建議依據所抽塔羅牌的牌義整理/);

    const sky = computeAstrology(
      { local: "1990-03-15T14:30", timezone: "Asia/Hong_Kong", latitude: 22.3, longitude: 114.17 },
      { digestPepper: PEPPER, now: FIXED_NOW },
    );
    const reading = await generateReport(sky, zhHantHK, deps(mock));
    expect(reading.status).toBe("passed");
    await expect(
      generateRemedy(sky, reading, "health", { country: "HK" }, deps(mock)),
    ).rejects.toThrow(/no 破除運勢 plan for astrology/);
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

  it("preloads every topic's plan locked; buying unlocks it at once, never twice", async () => {
    const id = await passedReport();
    await api.drain(); // the report job includes the preloads

    const list0 = await (await get(`/v1/reports/${id}/remedies`)).json();
    expect(list0.price).toEqual({ amount: 18, currency: "HKD" });
    expect(list0.items).toHaveLength(6); // all 八字 topics
    for (const it of list0.items) {
      expect(it).toMatchObject({ status: "passed", locked: true });
      expect(it.content).toBeUndefined(); // nothing readable before purchase
      expect(it.payment).toBeUndefined();
    }

    const r1 = await post(`/v1/reports/${id}/remedies`, { topic: "health" });
    expect(r1.status).toBe(200); // ready: no generation wait
    const bought = await r1.json();
    expect(bought).toMatchObject({
      topic: "health",
      status: "passed",
      locked: false,
      payment: { status: "placeholder", amount: 18, currency: "HKD" },
    });
    expect(bought.content.target).toContain("健康");
    expect((await (await get(`/v1/remedies/${bought.remedy_id}`)).json()).content).toBeDefined();

    // Buying the same topic again returns the same plan (no second charge).
    const again = await post(`/v1/reports/${id}/remedies`, { topic: "health" });
    expect(again.status).toBe(200);
    expect((await again.json()).remedy_id).toBe(bought.remedy_id);

    // Other topics stay locked.
    const list = await (await get(`/v1/reports/${id}/remedies`)).json();
    const locked = list.items.filter((x: { locked: boolean }) => x.locked).length;
    expect(locked).toBe(5);
  });

  it("a preloaded plan the guard held is regenerated on purchase, never sold as is", async () => {
    // Guard: the report passes (1st guard call), the 4 tarot preloads are all held.
    const held = {
      kind: "ok" as const,
      data: { pass: false, violations: [{ quote: "x", category: "other", reason: "test" }] },
    };
    const ok = { kind: "ok" as const, data: { pass: true, violations: [] } };
    const m = new MockProvider({ guard: [ok, held, held, held, held] });
    const logs: string[] = [];
    const api4 = createApiServer({
      secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
      providers: { deepseek: m, anthropic: m },
      devMode: true,
      log: (msg) => logs.push(msg),
    });
    await new Promise<void>((r) => api4.listen(0, "127.0.0.1", r));
    const b4 = `http://127.0.0.1:${(api4.address() as AddressInfo).port}`;
    const send = (path: string, body?: unknown) =>
      fetch(b4 + path, {
        method: body ? "POST" : "GET",
        headers: H(),
        body: body === undefined ? undefined : JSON.stringify(body),
      });
    try {
      const { chart_id } = await (
        await send("/v1/charts", { system: "tarot", spread: "three_card" })
      ).json();
      const r = await (await send("/v1/reports", { chart_id, locale: "zh-Hant" })).json();
      await api4.drain();
      const items = (await (await send(`/v1/reports/${r.report_id}/remedies`)).json()).items;
      expect(
        items.every(
          (x: { status: string; locked: boolean }) => x.status === "manual_review" && x.locked,
        ),
      ).toBe(true);
      // The server log names the guard category, never the quoted text.
      expect(logs.some((l) => /held: .*guard other/.test(l))).toBe(true);
      expect(logs.join("\n")).not.toContain('"x"');

      const p = await send(`/v1/reports/${r.report_id}/remedies`, { topic: "health" });
      expect(p.status).toBe(202); // generated afresh, not the held one
      const fresh = await p.json();
      await api4.drain();
      expect((await (await send(`/v1/remedies/${fresh.remedy_id}`)).json()).status).toBe("passed");
    } finally {
      await new Promise<void>((done) => api4.close(() => done()));
    }
  });

  it("without preloading, buying generates the plan (202, then poll)", async () => {
    const m = new MockProvider();
    const api2 = createApiServer({
      secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
      providers: { deepseek: m, anthropic: m },
      devMode: true,
      preloadRemedies: false,
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
    try {
      const { chart_id } = await (
        await send("/v1/charts", { system: "tarot", spread: "three_card" })
      ).json();
      const r = await (await send("/v1/reports", { chart_id, locale: "zh-Hant" })).json();
      await api2.drain();
      expect((await (await send(`/v1/reports/${r.report_id}/remedies`)).json()).items).toEqual([]);
      const p = await send(`/v1/reports/${r.report_id}/remedies`, { topic: "health" });
      expect(p.status).toBe(202);
      const pending = await p.json();
      expect(pending).toMatchObject({ status: "pending", locked: false });
      expect(p.headers.get("location")).toBe(`/v1/remedies/${pending.remedy_id}`);
      await api2.drain();
      const done = await (await send(`/v1/remedies/${pending.remedy_id}`)).json();
      expect(done.status).toBe("passed");
      expect(done.content.target).toContain("健康");
    } finally {
      await new Promise<void>((done) => api2.close(() => done()));
    }
  });

  it("the user's context reaches every agent that writes text", async () => {
    const m = new MockProvider();
    const api3 = createApiServer({
      secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
      providers: { deepseek: m, anthropic: m },
      devMode: true,
      log: () => {},
    });
    await new Promise<void>((r) => api3.listen(0, "127.0.0.1", r));
    const b3 = `http://127.0.0.1:${(api3.address() as AddressInfo).port}`;
    const send = (path: string, body: unknown) =>
      fetch(b3 + path, { method: "POST", headers: H(), body: JSON.stringify(body) });
    try {
      const { chart_id } = await (
        await send("/v1/charts", {
          system: "bazi",
          local: "1990-03-15T14:30",
          timezone: "Asia/Hong_Kong",
          longitude: 114.17,
          gender: "male",
        })
      ).json();
      const context = {
        name: "小明",
        birthplace: "中國 · 江蘇 · 靖江市",
        residence: "中國 · 廣東 · 深圳",
        marital: "married",
        children: "has",
        occupation: "軟件工程師",
        family: "與父母同住",
        concern: "明年適合轉工嗎？",
      };
      const bad = await send("/v1/reports", {
        chart_id,
        locale: "zh-Hant",
        context: { marital: "x" },
      });
      expect(bad.status).toBe(400);
      expect((await send("/v1/reports", { chart_id, locale: "zh-Hant", context })).status).toBe(
        202,
      );
      await api3.drain();
      for (const agent of ["narrative", "action", "remedy"] as const) {
        const call = m.calls.find((c) => c.agent === agent)!;
        expect(call.user).toContain("<user_context>");
        expect(call.user).toContain("明年適合轉工嗎？");
        expect(call.user).toContain("中國 · 江蘇 · 靖江市"); // birthplace name reaches the reading
      }
      expect(m.calls.some((c) => c.agent === "trend")).toBe(false); // the engine scores (v2.0.0)
      // The reviewer sees the same context (and, for plans, the trend), so true
      // statements about the user aren't flagged as fabricated.
      const guards = m.calls.filter((c) => c.agent === "guard");
      expect(guards.length).toBeGreaterThan(1);
      for (const g of guards) expect(g.user).toContain("<user_context>");
      expect(guards.some((g) => g.user.includes("<trend>"))).toBe(true);
      // Plain-language rules are part of the system prompts.
      expect(m.calls.find((c) => c.agent === "narrative")!.system).toMatch(/Plain language/);
      // Relative years come from the clock, never the model.
      expect(m.calls.find((c) => c.agent === "narrative")!.user).toMatch(
        /<today>\n\d{4}-\d{2}-\d{2}\. 去年/,
      );
    } finally {
      await new Promise<void>((done) => api3.close(() => done()));
    }
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

  it("an astrology reading gets no plan: none preloaded, and buying one is a 400", async () => {
    const c = await post("/v1/charts", {
      system: "astrology",
      local: "1990-03-15T14:30",
      timezone: "Asia/Hong_Kong",
      latitude: 22.3,
      longitude: 114.17,
    });
    const { chart_id } = await c.json();
    const { report_id } = await (await post("/v1/reports", { chart_id, locale: "zh-Hant" })).json();
    await api.drain();
    expect((await (await get(`/v1/reports/${report_id}`)).json()).status).toBe("passed");
    expect((await (await get(`/v1/reports/${report_id}/remedies`)).json()).items).toEqual([]);
    const buy = await post(`/v1/reports/${report_id}/remedies`, { topic: "health" });
    expect(buy.status).toBe(400);
    expect((await (await get(`/v1/reports/${report_id}/remedies`)).json()).items).toEqual([]);
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
