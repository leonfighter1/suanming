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
import { computeQiuqian } from "../src/engines/qiuqian/index.js";
import { computeTarot } from "../src/engines/tarot/index.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";

// The versions older than v2.1.0 were hashed from the committed prompts.ts before WP2.1 touched
// it; later ones are pinned as released. Changing a prompt's text needs a new version. A version
// replaced in the registry stays in the file as the base of its successor's text (narrative_bazi@5
// of @6, remedy_bazi@3 of @4, each tarot @1 of its @2, narrative_tarot@2 of @3), so its text stays
// pinned through the successor's hash: an edit changes that hash, or makes swap() throw.
const HASHES: Record<string, string> = {
  "narrative@4": "49007c9a8aba351e",
  "narrative_bazi@6": "d7c2c79e4aed5cc0",
  "narrative_tarot@3": "afa57d4daa579c11",
  "action@3": "87f6e73c8dd8d3de",
  "trend@2": "80a95937498e19fc",
  "remedy@2": "8a54bed1ea13dffa",
  "life_methods@2": "b2b508fa866af9fc",
  "life_topics@2": "6aee44c00e02b6a5",
  "guard@2": "49e59c41bbcd38bb",
  "narrative_astrology@1": "65a19de24e0f0c90",
  "action_bazi@4": "effdf6065ae231c6",
  "action_tarot@2": "33ab0ed8c7aa7a27",
  "action_astrology@1": "3da662668915d1f0",
  "remedy_bazi@4": "1953c4f923cf05ab",
  "remedy_tarot@2": "5ea0b8e2f95f8ce9",
  // v4.3.0 (WP6.1)
  "narrative_qiuqian@1": "0c3e3d0e3fb24f68",
  "action_qiuqian@1": "4d491e5caa9e0306",
  // v4.4.0 (WP6.3)
  "narrative_fengshui@1": "6bc0422cc8d0cead",
  "action_fengshui@1": "146ae68566106766",
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
    // No 破除運勢 plan for astrology (its chart has no houses or transits to rest one on), 求籤 (a lot
    // is read once, for the question asked) or 风水 (its principles are the plan).
    const noPlan = Object.entries(METHOD_PROMPTS).filter(([, own]) => !own.remedy);
    expect(noPlan.map(([system]) => system)).toEqual(["astrology", "qiuqian", "fengshui"]);
  });

  it("every report is written with its own method's prompts", async () => {
    for (const [system, chart] of Object.entries(charts)) {
      const mock = new MockProvider();
      const report = await generateReport(
        chart,
        { locale: "zh-Hans", country: "HK" },
        { providers: { deepseek: mock, anthropic: mock }, now: FIXED_NOW },
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
