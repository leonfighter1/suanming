// S18 (docs/tech-plan.md, the owner 2026-10-29): 八字's AI reading is the AI's own, beside the engine's. It reads the
// 排盘 and the person without the engine's judgements, writes no 举例 and no 行动建议, and always gives a 总结.
import { describe, expect, it } from "vitest";
import { baziView } from "../src/ai/bazi-view.js";
import {
  checkFaithfulness,
  CONCLUSION_LABELS,
  CONCLUSION_PARTS,
  generateFollowUp,
  generateReport,
  MockProvider,
  modelFacts,
  readingInputs,
  type ConclusionPart,
  type Paragraph,
} from "../src/ai/index.js";
import { readingDocument } from "../src/export/report-doc.js";
import { FIXED_NOW, sampleBazi } from "./helpers.js";

const chart = sampleBazi();
const deps = (mock: MockProvider) => ({
  providers: { deepseek: mock, anthropic: mock },
  now: FIXED_NOW,
});
const zhHansHK = { locale: "zh-Hans" as const, country: "HK" };
const ENGINE_JUDGEMENTS = ["strength", "wuxing_weighted", "trend"];

/** A scripted 八字 narrative: one personality paragraph and a 总结 whose parts cite cite(part). */
const scripted = (cite: (p: ConclusionPart) => string[]) => ({
  kind: "ok" as const,
  data: {
    sections: [
      {
        topic: "personality",
        paragraphs: [{ text: "你做事踏实。", source_level: "derived", fact_refs: ["/day_master"] }],
      },
    ],
    conclusion: Object.fromEntries(
      CONCLUSION_PARTS.map((p) => [p, { text: `${p}：整体平稳。`, fact_refs: cite(p) }]),
    ),
  },
});

describe("what the AI reads (WP18.1)", () => {
  it("the 排盘 and the person, without the engine's judgements; the paths name what the stored chart names", () => {
    const { facts } = readingInputs(chart, "zh-Hans", FIXED_NOW());
    const f = facts as Record<string, unknown>;
    for (const k of ENGINE_JUDGEMENTS) expect(f, k).not.toHaveProperty(k);
    for (const k of [
      "pillars",
      "day_master",
      "month_command",
      "wuxing_count",
      "relations",
      "shensha",
      "kongwang",
      "taiyuan",
      "dayun",
      "liunian",
      "input_basis",
      "view",
    ]) {
      expect(f, k).toHaveProperty(k);
    }
    const stored = chart.facts as { liunian: { year: number }[]; strength: unknown };
    expect((f.liunian as { year: number }[])[1]!.year).toBe(stored.liunian[1]!.year);
    // The engine's own reading keeps them: the stored chart, and a 破除运势 plan's view (the engine's 喜用).
    expect(stored.strength).toBeDefined();
    const plan = baziView(modelFacts(chart), { years: [2026], cycles: [3] }, { trend: false });
    expect(plan).toHaveProperty("strength");
    expect(plan).toHaveProperty("wuxing_weighted");
  });

  it("the model is sent no verdict or score, and asked for a 总结 and no 举例", async () => {
    const mock = new MockProvider();
    await generateReport(chart, zhHansHK, deps(mock));
    const call = mock.calls.find((c) => c.agent === "narrative")!;
    const sent = JSON.parse(call.user.split("<chart_facts>\n")[1]!.split("\n</chart_facts>")[0]!);
    for (const k of ENGINE_JUDGEMENTS) expect(sent, k).not.toHaveProperty(k);
    // The strength object's keys (身弱, its 喜用 and 忌) are nowhere in what the model reads.
    expect(call.user).not.toContain('"verdict"');
    expect(call.user).not.toContain('"favorable"');
    expect((call.schema as { required: string[] }).required).toEqual(["sections", "conclusion"]);
    expect(JSON.stringify(call.schema)).not.toContain('"example"');
    expect(mock.calls.map((c) => c.agent)).not.toContain("action");
  });
});

describe("what the AI writes (WP18.2)", () => {
  it("the 总结: every part, in order; a part that cites nothing is sent back, then left out", async () => {
    const good = scripted(() => ["/day_master"]);
    const bad = scripted((p) => (p === "caution" ? ["/nowhere"] : ["/day_master"]));
    const fixed = new MockProvider({ narrative: [bad, good] });
    const r = await generateReport(chart, { ...zhHansHK, topics: ["personality"] }, deps(fixed));
    expect(r.agents[0]!.attempts).toBe(2);
    const second = fixed.calls.filter((c) => c.agent === "narrative")[1]!.user;
    expect(second).toContain("conclusion: write every part");
    expect(second).toContain("missing: caution");
    expect(Object.keys(r.layers!.conclusion!)).toEqual([...CONCLUSION_PARTS]);
    expect(r.compliance.dropped_ungrounded).toBe(0);

    // Still ungrounded after the retry: the reading stands without that part, and says how many it dropped.
    const stubborn = new MockProvider({ narrative: [bad, bad] });
    const s = await generateReport(chart, { ...zhHansHK, topics: ["personality"] }, deps(stubborn));
    expect(s.status).toBe("passed");
    expect(Object.keys(s.layers!.conclusion!)).toEqual(
      CONCLUSION_PARTS.filter((p) => p !== "caution"),
    );
    expect(s.compliance.dropped_ungrounded).toBe(1);
  });

  it("大运流年 keeps up to six paragraphs, one per period in focus; the other sections four", async () => {
    const paragraphs = (ref: string): Paragraph[] =>
      Array.from({ length: 8 }, (_, i) => ({
        text: `第 ${i + 1} 段。`,
        source_level: "derived",
        fact_refs: [ref],
      }));
    const mock = new MockProvider({
      narrative: [
        {
          kind: "ok",
          data: {
            sections: [
              { topic: "personality", paragraphs: paragraphs("/day_master") },
              { topic: "dayun_liunian", paragraphs: paragraphs("/dayun") },
            ],
          },
        },
      ],
    });
    const r = await generateReport(
      chart,
      { ...zhHansHK, topics: ["personality", "dayun_liunian"] },
      deps(mock),
    );
    const count = Object.fromEntries(
      r.layers!.interpretation.map((s) => [s.topic, s.paragraphs.length]),
    );
    expect(count).toEqual({ personality: 4, dayun_liunian: 6 });
  });

  it("the faithfulness checks read the 总结: a year named with the wrong 干支 is caught", async () => {
    const r = await generateReport(chart, zhHansHK, deps(new MockProvider()));
    expect(checkFaithfulness(chart, r)).toEqual([]);
    // 2027 is 丁未 (2026 丙午 + 1).
    r.layers!.conclusion!.caution!.text = "2027 丙午年起要注意工作上的压力。";
    expect(checkFaithfulness(chart, r).map((i) => i.kind)).toEqual(["wrong_year_ganzhi"]);
  });
});

describe("where the 总结 goes", () => {
  it("追问 reads it, by its parts' labels", async () => {
    const mock = new MockProvider();
    const report = await generateReport(chart, zhHansHK, deps(mock));
    await generateFollowUp(
      chart,
      { kind: "report", report },
      "我什么时候该发力？",
      [],
      { country: "HK" },
      deps(mock),
    );
    const call = mock.calls.find((c) => c.agent === "followup")!;
    expect(call.user).toContain(CONCLUSION_LABELS.momentum["zh-Hans"]);
    expect(call.user).toContain(report.layers!.conclusion!.momentum!.text);
  });

  it("the mailed document has it after the engine's facts and before the sections, and no 行动建议", async () => {
    const report = await generateReport(chart, zhHansHK, deps(new MockProvider()));
    const doc = readingDocument(report, {
      system: "bazi",
      locale: "zh-Hans",
      region: "HK",
      created_at: report.created_at,
    });
    const h2 = doc.blocks.flatMap((b) => (b.type === "h2" ? [b.text] : []));
    const at = (t: string) => h2.indexOf(t);
    expect(at("命盘事实 · 引擎计算，非 AI")).toBeGreaterThanOrEqual(0);
    expect(at("总结 · AI 生成")).toBeGreaterThan(at("命盘事实 · 引擎计算，非 AI"));
    expect(at("解读 · AI 生成")).toBeGreaterThan(at("总结 · AI 生成"));
    expect(h2).not.toContain("行动建议 · AI 生成");
    const h3 = doc.blocks.flatMap((b) => (b.type === "h3" ? [b.text] : []));
    expect(h3.slice(0, CONCLUSION_PARTS.length)).toEqual(
      CONCLUSION_PARTS.map((p) => CONCLUSION_LABELS[p]["zh-Hans"]),
    );
  });
});
