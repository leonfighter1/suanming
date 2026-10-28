// WP1.6 (日主旺衰 + 喜用) and WP1.7 (engine trend scores), docs/tech-plan.md. Every expected
// value is worked out by hand from the rules in strength.ts / trend-scores.ts.
import { describe, expect, it } from "vitest";
import { computeBazi } from "../src/engines/bazi/index.js";
import { strength } from "../src/engines/bazi/strength.js";
import { scorePeriod, TREND_TOPICS } from "../src/engines/bazi/trend-scores.js";
import { trendNote } from "../src/ai/trend.js";
import { PEPPER } from "./helpers.js";

const P = (gz: string) => ({ gan: gz[0]!, zhi: gz[1]! });
const natal = (y: string, m: string, d: string, h: string) => ({
  year: P(y),
  month: P(m),
  day: P(d),
  hour: P(h),
});
const ctx = { digestPepper: PEPPER, now: () => new Date("2026-10-25T00:00:00Z") };
const sampleFacts = () =>
  computeBazi(
    {
      local: "1990-03-15T14:30",
      timezone: "Asia/Hong_Kong",
      longitude: 114.17,
      gender: "male",
      options: { liunianFrom: 2026 },
    },
    ctx,
  ).facts as any;

describe("日主旺衰 (扶抑法, 100 points: 年干 8 月干 12 时干 12, 年支 4 月支 40 日支 12 时支 12)", () => {
  it("庚午 己卯 己卯 辛未: 己土 weak in a 卯 month", () => {
    // Support = 土 + 火. Stems: 月干 己 12. 午 (4): 丁 2.8 + 己 1.2 = 4. 卯 (40, 12): 乙 木, none.
    // 未 (12): 己 7.2 + 丁 3.6 = 10.8 (乙 1.2 is 木). 12 + 4 + 10.8 = 26.8 ≤ 45 → 身弱.
    // 木 = 40 + 12 + 1.2 = 53.2; 火 = 2.8 + 3.6 = 6.4; 土 = 12 + 1.2 + 7.2 = 20.4; 金 = 8 + 12 = 20.
    const s = strength(natal("庚午", "己卯", "己卯", "辛未"));
    expect(s).toMatchObject({
      support: 26.8,
      by_element: { 木: 53.2, 火: 6.4, 土: 20.4, 金: 20, 水: 0 },
      verdict: "身弱",
      de_ling: false, // 卯's 本气 乙 is 木
      tong_gen: ["year", "hour"], // 午 and 未 hide 己
      favorable: ["火", "土"], // 印, 比劫
      unfavorable: ["金", "水", "木"], // 食伤, 财, 官杀
    });
    expect(s.special).toBeUndefined();
  });

  it("壬子 壬寅 甲寅 丙寅: 甲木 strong, 得令", () => {
    // Support = 木 + 水. Stems 壬 8 + 壬 12 = 20 (丙 12 is 火). 子 (4): 癸 4. 寅 (40): 甲 24;
    // 寅 (12) ×2: 甲 7.2 each. 20 + 4 + 24 + 14.4 = 62.4 ≥ 55 → 身强.
    const s = strength(natal("壬子", "壬寅", "甲寅", "丙寅"));
    expect(s).toMatchObject({
      support: 62.4,
      by_element: { 木: 38.4, 水: 24, 火: 31.2, 土: 6.4, 金: 0 },
      verdict: "身强",
      de_ling: true,
      tong_gen: ["month", "day", "hour"],
      favorable: ["火", "土", "金"],
      unfavorable: ["水", "木"],
    });
  });

  it("flags a possible 专旺 or 从格 and sets no 喜用", () => {
    // 壬寅 壬寅 甲子 甲子: stems 8 + 12 + 12 = 32; 寅 (4) 甲 2.4, 寅 (40) 甲 24, 子 (12) ×2: 24 → 82.4 ≥ 80.
    const strong = strength(natal("壬寅", "壬寅", "甲子", "甲子"));
    expect(strong).toMatchObject({
      support: 82.4,
      verdict: "身强",
      special: "专旺候选",
      favorable: [],
      unfavorable: [],
    });
    // 庚申 辛酉 甲戌 庚午: only 申's 壬 (4 × 0.3 = 1.2) supports 甲 → 1.2 ≤ 15.
    const weak = strength(natal("庚申", "辛酉", "甲戌", "庚午"));
    expect(weak).toMatchObject({
      support: 1.2,
      verdict: "身弱",
      special: "从格候选",
      favorable: [],
      unfavorable: [],
    });
  });

  it("is in the chart facts", () => {
    expect(sampleFacts().strength).toEqual(strength(natal("庚午", "己卯", "己卯", "辛未")));
  });
});

describe("运势走势 from the engine", () => {
  it("2026 丙午 for 庚午 己卯 己卯 辛未, worked out by hand", () => {
    // favour: 丙 火 1 + 午 丁 0.7 火, 己 0.3 土 → all 喜用 → (1.7 + 0.3) / 2 = 1.0.
    // relations (v1.3.0 test): 丙辛 合 +0.04, 壬丙 冲 (大运) −0.05, 午午 自刑 ×2 −0.16,
    //   卯午 破 ×2 −0.06, 午未 合 土 (喜) +0.06 → −0.17. Day branch: 破 (first), adds nothing.
    // 十神 groups: 丙 and 午's 丁 are both 印 for 己土.
    // personality: 1.0 × (1 + 0.25 × 2) − 0.17 = 1.33 → 50 + 46.6 → capped 85.
    // career_wealth / relationships / dayun_liunian: 1.0 − 0.17 = 0.83 → 50 + 29.05 → 79.
    // health: 0.5 − 0.17 × 1.5 = 0.245 → 50 + 8.575 → 59.
    // wuxing: elements 木 53.2 火 6.4 土 20.4 金 20 水 0 (sd 18.370) + 火 17, 土 3 → sd 17.002;
    //   balance (18.370 − 17.002) / 18.370 × 2 = 0.149; 0.4 + 0.149 = 0.549 → 50 + 19.2 → 69.
    const f = sampleFacts();
    const y2026 = f.trend.liunian.find((y: any) => y.year === 2026);
    expect(y2026.scores).toEqual({
      wuxing: 69,
      personality: 85,
      career_wealth: 79,
      relationships: 79,
      dayun_liunian: 79,
      health: 59,
    });
    expect(y2026.basis).toEqual({
      favour: 1,
      relations: -0.17,
      families: ["印", "印"],
      day_branch: "相破",
    });
    // The note names the day-branch relation as it is: 卯午 is 相破, not 刑 or 害.
    expect(trendNote("丙午", y2026.basis, "zh-Hans")).toBe(
      "丙午：印星当头（学习和支持你的人）；五行多为对你有利的一方，与日支相破，宜多沟通。",
    );
    expect(trendNote("丙午", { ...y2026.basis, day_branch: "六害" }, "zh-Hant")).toBe(
      "丙午：印星當頭（學習和支持你的人）；五行多為對你有利的一方，與日支相害，宜多溝通。",
    );
  });

  it("the same chart always scores the same; every score is within 20–85", () => {
    expect(sampleFacts().trend).toEqual(sampleFacts().trend);
    const all = [...sampleFacts().trend.dayun, ...sampleFacts().trend.liunian];
    expect(all.length).toBe(8 + 10);
    for (const p of all)
      for (const t of TREND_TOPICS) expect(p.scores[t]).toBeGreaterThanOrEqual(20);
    for (const p of all) for (const t of TREND_TOPICS) expect(p.scores[t]).toBeLessThanOrEqual(85);
  });

  it("a period of favourable elements scores above one of unfavourable ones", () => {
    // 身弱 己土 (喜 火土): 丙午 is all 火土 (favour 1.0 → 85); 庚申 is 金 1.6, 水 0.3, 土 0.1
    // (favour (−1.6 − 0.3 + 0.1) / 2 = −0.9 → 50 − 31.5 → capped 20). No relations either way.
    const s = strength(natal("庚午", "己卯", "己卯", "辛未"));
    expect(scorePeriod("己", s, "丙午", []).scores.dayun_liunian).toBe(85);
    expect(scorePeriod("己", s, "庚申", []).scores.dayun_liunian).toBe(20);
  });
});
