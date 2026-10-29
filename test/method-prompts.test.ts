// WP2.1 (docs/tech-plan.md, rule 8): every method reads, writes its actions and writes its plans
// with its own prompts, and a released prompt version never changes.
import { describe, expect, it } from "vitest";
import {
  generateReport,
  METHOD_PROMPTS,
  MockProvider,
  PROMPTS,
  promptHash,
} from "../src/ai/index.js";
import { computeAstrology } from "../src/engines/astrology/index.js";
import { computeBazi } from "../src/engines/bazi/index.js";
import { computeFengshui } from "../src/engines/fengshui/index.js";
import { computeLiuyao } from "../src/engines/liuyao/index.js";
import { computeNaming } from "../src/engines/naming/index.js";
import { computeQiuqian } from "../src/engines/qiuqian/index.js";
import { computeTarot } from "../src/engines/tarot/index.js";
import { DRAW_KEY, FIXED_NOW, PEPPER, withNamingOn } from "./helpers.js";

// The versions older than v2.1.0 were hashed from the committed prompts.ts before WP2.1 touched
// it; later ones are pinned as released. Changing a prompt's text needs a new version. A version
// replaced in the registry stays in the file as the base of its successor's text (narrative_bazi@5
// of @6, remedy_bazi@3 of @4, each tarot @1 of its @2, narrative_tarot@2 of @3; since v6.2.0 every
// method's previous reading prompt of its 术语 → 评论 → 例子 version, and life_*@2 of @3), so its text
// stays pinned through the successor's hash: an edit changes that hash, or makes swap() throw.
const HASHES: Record<string, string> = {
  "narrative@4": "49007c9a8aba351e",
  "narrative_bazi@7": "5b0438907f183cd3",
  "narrative_tarot@4": "6bbf24df455a522a",
  "action@3": "87f6e73c8dd8d3de",
  "trend@2": "80a95937498e19fc",
  "remedy@2": "8a54bed1ea13dffa",
  "life_methods@3": "13e0ffa66978ef9a",
  "life_topics@3": "6063894dbf8135d2",
  "guard@2": "49e59c41bbcd38bb",
  "narrative_astrology@2": "6103a67a383504f2",
  "action_bazi@4": "effdf6065ae231c6",
  "action_tarot@2": "33ab0ed8c7aa7a27",
  "action_astrology@1": "3da662668915d1f0",
  "remedy_bazi@4": "1953c4f923cf05ab",
  "remedy_tarot@2": "5ea0b8e2f95f8ce9",
  // v4.3.0 (WP6.1)
  "narrative_qiuqian@2": "50793c67dabf468d",
  "action_qiuqian@1": "4d491e5caa9e0306",
  // v4.4.0 (WP6.3)
  "narrative_fengshui@2": "5d880d4dbbfbfa33",
  "action_fengshui@1": "146ae68566106766",
  // v4.5.0 (WP6.4)
  "narrative_naming@2": "65d36ae6e56a3b4f",
  "action_naming@1": "34493bd83790f328",
  // v5.3.0 (S10)
  "narrative_liuyao@2": "193c6eda8248674b",
  "action_liuyao@1": "82a59b90dfa30a15",
};

const charts = {
  bazi: computeBazi(
    { local: "1990-03-15T14:30", timezone: "Asia/Hong_Kong", longitude: 114.17, gender: "male" },
    { digestPepper: PEPPER, now: FIXED_NOW },
  ),
  tarot: computeTarot(
    { spread: "three_card" },
    { drawKey: DRAW_KEY, digestPepper: PEPPER, now: FIXED_NOW, newDrawId: () => "draw-1" },
  ),
  astrology: computeAstrology(
    { local: "1990-03-15T14:30", timezone: "Asia/Hong_Kong", latitude: 22.3, longitude: 114.17 },
    { digestPepper: PEPPER, now: FIXED_NOW },
  ),
  qiuqian: computeQiuqian(
    {},
    {
      drawKey: DRAW_KEY,
      digestPepper: PEPPER,
      now: FIXED_NOW,
      newDrawId: () => "00000000-0000-4000-8000-000000000001",
    },
  ),
  fengshui: computeFengshui({ room: "living" }, { digestPepper: PEPPER, now: FIXED_NOW }),
  liuyao: computeLiuyao(
    { mode: "auto", timezone: "Asia/Hong_Kong" },
    {
      drawKey: DRAW_KEY,
      digestPepper: PEPPER,
      now: FIXED_NOW,
      newDrawId: () => "00000000-0000-4000-8000-000000000002",
    },
  ),
};
// 起名 reads a 八字 chart; it ships off in the matrix, so its reading runs with it switched on.
const allCharts = {
  ...charts,
  naming: computeNaming(
    charts.bazi,
    { surname: "陳", length: 2 },
    { digestPepper: PEPPER, now: FIXED_NOW },
  ),
};

describe("each method's own prompts (rule 8)", () => {
  it("every released prompt version keeps its hash", () => {
    const now = Object.fromEntries(Object.values(PROMPTS).map((p) => [p.id, promptHash(p)]));
    expect(now).toEqual(HASHES);
  });

  it("no two methods share a reading, action or plan prompt", () => {
    for (const agent of ["narrative", "action", "remedy"] as const) {
      const ids = Object.entries(METHOD_PROMPTS).flatMap(([system, own]) =>
        own[agent] ? [[system, own[agent]!.id] as const] : [],
      );
      expect(new Set(ids.map(([, id]) => id)).size).toBe(ids.length);
      for (const [system, id] of ids) expect(id).toMatch(new RegExp(`^${agent}_${system}@`));
    }
    // No 破除運勢 plan for astrology (its chart has no houses or transits to rest one on), 求籤 and 算卦
    // (a lot or a cast is read once, for the question asked), 风水 (its principles are the plan) or 起名
    // (a name is chosen, not worked on).
    const noPlan = Object.entries(METHOD_PROMPTS).filter(([, own]) => !own.remedy);
    expect(noPlan.map(([system]) => system)).toEqual([
      "astrology",
      "qiuqian",
      "fengshui",
      "naming",
      "liuyao",
    ]);
  });

  it("every report is written with its own method's prompts", async () => {
    for (const [system, chart] of Object.entries(allCharts)) {
      const mock = new MockProvider();
      const report = await withNamingOn(() =>
        generateReport(
          chart,
          { locale: "zh-Hans", country: "HK" },
          { providers: { deepseek: mock, anthropic: mock }, now: FIXED_NOW },
        ),
      );
      const own = METHOD_PROMPTS[system as keyof typeof METHOD_PROMPTS];
      expect(report.ai_disclosure.prompt_version, system).toBe(
        `${own.narrative.id},${own.action.id},guard@2`,
      );
      expect(mock.calls.find((c) => c.agent === "narrative")!.system).toBe(own.narrative.system);
      expect(mock.calls.find((c) => c.agent === "action")!.system).toBe(own.action.system);
    }
  });

  it("tarot, astrology, 求籤 and 风水 prompts carry no 八字 instructions; 八字 plans use the engine's 喜用", () => {
    const others = [
      PROMPTS.action_tarot,
      PROMPTS.remedy_tarot,
      PROMPTS.narrative_astrology,
      PROMPTS.action_astrology,
      PROMPTS.narrative_qiuqian,
      PROMPTS.action_qiuqian,
      PROMPTS.narrative_fengshui,
      PROMPTS.action_fengshui,
      PROMPTS.narrative_naming,
      PROMPTS.action_naming,
      PROMPTS.narrative_liuyao,
      PROMPTS.action_liuyao,
    ];
    for (const p of others) {
      for (const bazi of [
        "生剋",
        "favourable colours, directions",
        "wuxing_weighted",
        "day_master",
      ]) {
        expect(p.system, `${p.id} has ${bazi}`).not.toContain(bazi);
      }
      expect(p.system, p.id).not.toContain("<trend>");
    }
    expect(PROMPTS.narrative_astrology.system).toContain("never mention houses");
    expect(PROMPTS.remedy_tarot.system).toContain("focus_periods: always an empty list");

    const plan = PROMPTS.remedy_bazi.system;
    expect(plan).toContain("chart_facts.strength.favorable");
    expect(plan).toContain("虛歲 38–47");
    expect(plan).not.toContain("塔羅");
    expect(PROMPTS.action_bazi.system).toContain(
      "favourable elements (喜用) given in <chart_summary>",
    );
  });
});
