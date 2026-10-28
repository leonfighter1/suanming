import type { AddressInfo } from "node:net";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { generateLifeReport, LIFE_TOPICS, MockProvider } from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import { computeBazi } from "../src/engines/bazi/index.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";

// The owner's sample: 吴勇, male, 1987-11-23 03:30, 江苏靖江 (120.26°E).
const chart = computeBazi(
  { local: "1987-11-23T03:30", timezone: "Asia/Shanghai", longitude: 120.2625, gender: "male" },
  { digestPepper: PEPPER, now: FIXED_NOW },
);
const deps = (mock: MockProvider) => ({
  providers: { deepseek: mock, anthropic: mock },
  now: FIXED_NOW,
});
const opts = { locale: "zh-Hans" as const, country: "HK" };

describe("generateLifeReport", () => {
  it("engine facts + two parallel agents + guard; every 大运 gets a stage row", async () => {
    const mock = new MockProvider();
    const r = await generateLifeReport(chart, opts, deps(mock));
    expect(r.status).toBe("passed");
    expect(mock.calls.map((c) => c.agent).sort()).toEqual(["guard", "life_methods", "life_topics"]);
    expect(r.ai_disclosure.prompt_version).toBe("life_methods@2,life_topics@2,guard@2");
    // Deterministic facts, shown as computed.
    expect(r.facts.benming.hexagram.full_name).toBe("天雷无妄");
    expect(r.facts.benming.changed.full_name).toBe("天泽履");
    expect(r.facts.bazhai.kua).toBe(4);
    expect(r.facts.bazhai.directions[0]).toMatchObject({ star: "生气", direction: "北" });
    // Layers.
    expect(r.layers!.topics.map((t) => t.key)).toEqual([...LIFE_TOPICS]);
    const cycles = (chart.facts as { dayun: { cycles: { index: number; ganzhi: string }[] } }).dayun
      .cycles;
    expect(r.layers!.stages.map((s) => s.ganzhi)).toEqual(cycles.map((c) => c.ganzhi));
    // Stage scores are the engine's (v2.0.0), the same as the 运势走势 chart's.
    const engine = (chart.facts as any).trend.dayun;
    for (const s of r.layers!.stages) {
      expect(s.score).toBe(engine.find((d: any) => d.index === s.dayun_index).scores.dayun_liunian);
    }
    expect(r.layers!.methods.yijing.stages).toHaveLength(6);
  });

  it("the model reads the engine facts and today's date; the classical text is in the reader's script", async () => {
    const mock = new MockProvider();
    await generateLifeReport(chart, { ...opts, locale: "zh-Hant" }, deps(mock));
    const call = mock.calls.find((c) => c.agent === "life_methods")!;
    expect(call.user).toContain("<life_facts>");
    expect(call.user).toContain("天雷無妄");
    expect(call.user).toMatch(/<today>\n2026-10-25\. 去年/);
    expect(call.system).toMatch(/Never predict death or lifespan/);
  });

  it("period labels come ready-made from the 大运, so the model never computes ages", async () => {
    const mock = new MockProvider();
    await generateLifeReport(chart, opts, deps(mock));
    const cycles = (
      chart.facts as { dayun: { cycles: { start_age_xu: number; start_year: number }[] } }
    ).dayun.cycles;
    const [a, b] = [cycles[3]!, cycles[4]!];
    // 虚岁 (v2.0.0), from the civil birth year.
    const label = `虚岁 ${a.start_age_xu}–${b.start_age_xu - 1}（${a.start_year}–${a.start_year + 9}）`;
    const user = mock.calls.find((c) => c.agent === "life_topics")!.user;
    expect(user).toContain(label);
  });

  it("context reaches both writers and the reviewer", async () => {
    const mock = new MockProvider();
    await generateLifeReport(
      chart,
      { ...opts, context: { name: "吴勇", marital: "married" } },
      deps(mock),
    );
    for (const c of mock.calls) expect(c.user).toContain("<user_context>");
  });

  it("blocks a report whose text keeps predicting lifespan", async () => {
    const bad = {
      kind: "ok" as const,
      data: {
        topics: LIFE_TOPICS.map((key) => ({
          key,
          summary: "寿命只到七十岁。",
          points: [],
          fact_refs: ["/bazi/day_master"],
        })),
        stages: [],
        summary: { verdict: "x", advice: [], closing: "x" },
      },
    };
    const mock = new MockProvider({ life_topics: [bad, bad] });
    const r = await generateLifeReport(chart, opts, deps(mock));
    expect(r.status).toBe("blocked");
    expect(r.layers).toBeUndefined();
    expect(r.compliance.rule_violations.map((v) => v.rule_id)).toContain("G004");
    expect(mock.calls.some((c) => c.agent === "guard")).toBe(false);
  });

  it("refuses tarot charts", async () => {
    const tarot = { ...chart, system: "tarot" } as typeof chart;
    await expect(generateLifeReport(tarot, opts, deps(new MockProvider()))).rejects.toThrow(/八字/);
  });
});

describe("life report API", () => {
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

  it("202, then the passed report with facts and layers; listed in history", async () => {
    const { chart_id } = await (
      await post("/v1/charts", {
        system: "bazi",
        local: "1987-11-23T03:30",
        timezone: "Asia/Shanghai",
        longitude: 120.2625,
        gender: "male",
      })
    ).json();
    const r = await post("/v1/life-reports", {
      chart_id,
      locale: "zh-Hans",
      context: { name: "吴勇" },
    });
    expect(r.status).toBe(202);
    const pending = await r.json();
    expect(r.headers.get("location")).toBe(`/v1/life-reports/${pending.life_report_id}`);
    await api.drain();
    const done = await get(`/v1/life-reports/${pending.life_report_id}`);
    expect(done.headers.get("x-ai-generated")).toBe("true");
    const view = await done.json();
    expect(view.status).toBe("passed");
    expect(view.facts.benming.hexagram.full_name).toBe("天雷无妄");
    expect(view.layers.summary.verdict).toBeTruthy();
    const list = await (await get("/v1/life-reports")).json();
    expect(list.items[0]).toMatchObject({
      life_report_id: pending.life_report_id,
      status: "passed",
    });
    expect(list.items[0].layers).toBeUndefined();
    // Owner only.
    expect((await get(`/v1/life-reports/${pending.life_report_id}`, "u2")).status).toBe(404);
  });

  it("400 for a tarot chart or a bad locale", async () => {
    const { chart_id } = await (
      await post("/v1/charts", { system: "tarot", spread: "single" })
    ).json();
    expect((await post("/v1/life-reports", { chart_id, locale: "zh-Hans" })).status).toBe(400);
    const b = await (
      await post("/v1/charts", {
        system: "bazi",
        local: "1990-03-15T14:30",
        timezone: "Asia/Hong_Kong",
        longitude: 114.17,
        gender: "male",
      })
    ).json();
    expect((await post("/v1/life-reports", { chart_id: b.chart_id, locale: "fr" })).status).toBe(
      400,
    );
  });
});
