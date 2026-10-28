// WP2.3 (docs/tech-plan.md): what a 八字 agent reads. The sample is 庚午 己卯 己卯 辛未 (male,
// born 1990), read in 2026: its 大运 start in 1997 (1), 2007 (2), 2017 (3), 2027 (4), … and its
// 流年 run 2026–2035.
import { describe, expect, it } from "vitest";
import {
  generateLifeReport,
  generateRemedy,
  generateReport,
  MockProvider,
  modelFacts,
} from "../src/ai/index.js";
import { baziView, planFocus, readingFocus } from "../src/ai/bazi-view.js";
import { computeBazi } from "../src/engines/bazi/index.js";
import { FIXED_NOW, PEPPER } from "./helpers.js";

const chart = computeBazi(
  { local: "1990-03-15T14:30", timezone: "Asia/Hong_Kong", longitude: 114.17, gender: "male" },
  { digestPepper: PEPPER, now: FIXED_NOW },
);
const full = modelFacts(chart) as any;
const deps = (mock: MockProvider) => ({
  providers: { deepseek: mock, anthropic: mock },
  now: FIXED_NOW,
});

describe("the focused 八字 view", () => {
  it("a reading's focus: the current 大运 and the next, this year and two more, years asked about", () => {
    // In 2026 three 大运 have started (1997, 2007, 2017): the current one is 3, the next 4.
    expect(readingFocus(chart.facts, 2026)).toEqual({ cycles: [3, 4], years: [2026, 2027, 2028] });
    expect(readingFocus(chart.facts, 2026, "2031年适合换工作吗？2040年呢？")).toEqual({
      cycles: [3, 4],
      years: [2026, 2027, 2028, 2031], // 2040 is not among this chart's 流年
    });
    // Before the first 大运 starts (1997): the first two.
    expect(readingFocus(chart.facts, 1992).cycles).toEqual([1, 2]);
  });

  it("keeps every period at its place; only the focus ones keep their detail; no 流月", () => {
    const view = baziView(
      full,
      { cycles: [3, 4], years: [2026, 2027, 2028] },
      { trend: true },
    ) as any;
    expect(view.liuyue).toBeUndefined();
    expect(view.view.focus_years).toEqual([2026, 2027, 2028]);
    // Same lengths and order as the stored chart, so /liunian/3 or /dayun/cycles/5 mean the same.
    expect(view.dayun.cycles.map((c: any) => [c.index, c.ganzhi])).toEqual(
      full.dayun.cycles.map((c: any) => [c.index, c.ganzhi]),
    );
    expect(view.liunian.map((y: any) => [y.year, y.ganzhi, y.age_xu, y.shishen_gan])).toEqual(
      full.liunian.map((y: any) => [y.year, y.ganzhi, y.age_xu, y.shishen_gan]),
    );
    for (const [i, c] of view.dayun.cycles.entries()) {
      if ([3, 4].includes(c.index)) expect(c).toEqual(full.dayun.cycles[i]);
      else
        expect(Object.keys(c)).toEqual([
          "index",
          "ganzhi",
          "start_year",
          "start_age",
          "start_age_xu",
        ]);
    }
    for (const [i, y] of view.liunian.entries()) {
      if (y.year <= 2028) expect(y).toEqual(full.liunian[i]);
      else
        expect(Object.keys(y).sort()).toEqual([
          "age",
          "age_xu",
          "dayun_index",
          "ganzhi",
          "shishen_gan",
          "shishen_zhi",
          "year",
        ]);
    }
    // Scores for every period, the basis only in focus.
    expect(view.trend.liunian).toHaveLength(10);
    expect(view.trend.liunian.filter((y: any) => y.basis).map((y: any) => y.year)).toEqual([
      2026, 2027, 2028,
    ]);
    expect(view.trend.dayun.filter((d: any) => d.basis).map((d: any) => d.index)).toEqual([3, 4]);
    expect(view.trend.liunian[5].scores).toEqual(full.trend.liunian[5].scores);
    // Natal facts untouched.
    for (const k of ["pillars", "day_master", "strength", "relations", "shensha", "kongwang"])
      expect(view[k]).toEqual(full[k]);
  });

  it("a plan's focus: where its topic scores lowest from now on, never a past 大运", async () => {
    const report = await generateReport(
      chart,
      { locale: "zh-Hans", country: "HK" },
      deps(new MockProvider()),
    );
    const trend = report.layers!.trend!;
    for (const topic of report.topics) {
      const f = planFocus(trend, topic, 2026);
      const score = (p: { scores: Record<string, number | undefined> }) => p.scores[topic]!;
      const ahead = trend.dayun.filter((d) => d.start_year + 9 >= 2026); // 3 (2017–2026) onwards
      expect(f.cycles).toHaveLength(2);
      expect(f.years).toHaveLength(3);
      expect(f.cycles.every((i) => i >= 3)).toBe(true);
      const picked = ahead.filter((d) => f.cycles.includes(d.index));
      const rest = ahead.filter((d) => !f.cycles.includes(d.index));
      expect(Math.max(...picked.map(score))).toBeLessThanOrEqual(Math.min(...rest.map(score)));
      const pickedY = trend.liunian.filter((y) => f.years.includes(y.year));
      const restY = trend.liunian.filter((y) => !f.years.includes(y.year));
      expect(Math.max(...pickedY.map(score))).toBeLessThanOrEqual(Math.min(...restY.map(score)));
      expect([...f.years].sort((a, b) => a - b)).toEqual(f.years);
    }
  });

  it("each 八字 agent reads its view: reading, plan and life report", async () => {
    const mock = new MockProvider();
    const report = await generateReport(
      chart,
      { locale: "zh-Hans", country: "HK", question: "2031年怎么样？" },
      deps(mock),
    );
    const reading = mock.calls.find((c) => c.agent === "narrative")!.user;
    expect(reading).toContain('"focus_years": [\n   2026,\n   2027,\n   2028,\n   2031\n  ]');
    expect(reading).not.toContain('"liuyue"');
    expect(reading).not.toContain('"path": "/liuyue"'); // provenance only for paths it can see

    await generateRemedy(chart, report, "health", { country: "HK" }, deps(mock));
    const plan = mock.calls.filter((c) => c.agent === "remedy").at(-1)!.user;
    const focus = planFocus(report.layers!.trend, "health", 2026);
    expect(plan).toContain(`"focus_cycles": [\n   ${focus.cycles.join(",\n   ")}\n  ]`);
    expect(plan).not.toContain('"trend": {\n  "method"'); // the plan gets its scores in <trend>

    await generateLifeReport(chart, { locale: "zh-Hans", country: "HK" }, deps(mock));
    const life = mock.calls.find((c) => c.agent === "life_methods")!.user;
    expect(life).not.toContain('"liuyue"');
    expect(life).toContain('"dayun_liunian"'); // the stage scores (trend.dayun) are still there
  });
});
