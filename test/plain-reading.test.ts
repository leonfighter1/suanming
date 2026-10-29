// WP13.1 (docs/tech-plan.md, the owner's 术语在前，评论在后): every reading paragraph comes as the term (the facts it
// rests on, said the tradition's way), then the plain commentary, then an everyday example.
import { describe, expect, it } from "vitest";
import {
  checkFaithfulness,
  generateReport,
  METHOD_PROMPTS,
  MockProvider,
  PROMPTS,
  type NarrativeOutput,
} from "../src/ai/index.js";
import { computeBazi } from "../src/engines/bazi/index.js";
import { DECK } from "../src/engines/tarot/deck.js";
import { computeTarot } from "../src/engines/tarot/index.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";

const bazi = computeBazi(
  { local: "1990-03-15T14:30", timezone: "Asia/Hong_Kong", longitude: 114.17, gender: "male" },
  { digestPepper: PEPPER, now: FIXED_NOW },
);
const deps = (mock: MockProvider) => ({
  providers: { deepseek: mock, anthropic: mock },
  now: FIXED_NOW,
});
const personality = (paragraphs: NarrativeOutput["sections"][number]["paragraphs"]) => ({
  kind: "ok" as const,
  data: { sections: [{ topic: "personality", paragraphs }] } satisfies NarrativeOutput,
});

describe("术语在前，评论在后 (WP13.1)", () => {
  it("every method's reading prompt asks for the term, the commentary and an example", () => {
    for (const [system, own] of Object.entries(METHOD_PROMPTS)) {
      expect(own.narrative.system, system).toContain("term (术语)");
      expect(own.narrative.system, system).toContain("text (评论)");
      expect(own.narrative.system, system).toContain("example (举例)");
    }
    for (const p of [PROMPTS.life_methods, PROMPTS.life_topics]) {
      expect(p.system, p.id).toContain("the term first, then the commentary, then an example");
    }
  });

  it("keeps a paragraph's term and example, normalised, and leaves out empty ones", async () => {
    const mock = new MockProvider({
      narrative: [
        personality([
          {
            term: "月柱劫财",
            text: "你很重視朋友。",
            example: "比如朋友搬家時，你總是第一個到。",
            source_level: "traditional_text",
            fact_refs: ["/day_master"],
          },
          {
            term: " ",
            text: "做事有自己的節奏。",
            example: "",
            source_level: "traditional_text",
            fact_refs: ["/day_master"],
          },
        ]),
      ],
    });
    const r = await generateReport(
      bazi,
      { locale: "zh-Hant", country: "HK", topics: ["personality"] },
      deps(mock),
    );
    const [first, second] = r.layers!.interpretation[0]!.paragraphs;
    // 劫财 is the 简体 form of a protected term: a zh-Hant reading gets 劫財, in the term as in the text.
    expect(first).toEqual({
      term: "月柱劫財",
      text: "你很重視朋友。",
      example: "比如朋友搬家時，你總是第一個到。",
      source_level: "traditional_text",
      fact_refs: ["/day_master"],
    });
    expect(r.compliance.term_fixes).toContain("劫财→劫財");
    expect(second).toEqual({
      text: "做事有自己的節奏。",
      source_level: "traditional_text",
      fact_refs: ["/day_master"],
    });
  });

  it("scans the term and the example with the rule layer", async () => {
    // 注定 (G003, fatalism) only in the example: the paragraph is sent back once with the rule's feedback.
    const mock = new MockProvider({
      narrative: [
        personality([
          {
            term: "日主己土",
            text: "你做事踏實。",
            example: "比如你注定會失去這段感情。",
            source_level: "traditional_text",
            fact_refs: ["/day_master"],
          },
        ]),
      ],
    });
    const r = await generateReport(
      bazi,
      { locale: "zh-Hant", country: "HK", topics: ["personality"] },
      deps(mock),
    );
    expect(r.agents[0]!.attempts).toBe(2);
    expect(mock.calls.filter((c) => c.agent === "narrative")[1]!.user).toContain("G003");
  });

  it("the faithfulness checks read the term", async () => {
    const tarot = computeTarot(
      { spread: "three_card" },
      { drawKey: DRAW_KEY, digestPepper: PEPPER, now: FIXED_NOW, newDrawId: () => "draw-1" },
    );
    const drawn = new Set(
      (tarot.facts as { cards: { card_id: string }[] }).cards.map((c) => c.card_id),
    );
    const other = DECK.find((c) => !drawn.has(c.id))!.name["zh-Hans"];
    const r = await generateReport(
      tarot,
      { locale: "zh-Hans", country: "HK" },
      deps(new MockProvider()),
    );
    expect(checkFaithfulness(tarot, r)).toEqual([]);
    r.layers!.interpretation[0]!.paragraphs[0]!.term = `第 1 张·过去：${other}（正位）`;
    expect(checkFaithfulness(tarot, r).map((i) => i.kind)).toEqual(["card_not_in_spread"]);
  });

  it("the mock writes all three, so a demo reading shows them (IS_AI_MOCK=TRUE)", async () => {
    const r = await generateReport(
      bazi,
      { locale: "zh-Hans", country: "HK" },
      deps(new MockProvider()),
    );
    for (const p of r.layers!.interpretation.flatMap((s) => s.paragraphs)) {
      expect((p.term ?? "").trim()).not.toBe("");
      expect(p.text.trim()).not.toBe("");
      expect((p.example ?? "").trim()).not.toBe("");
    }
  });
});
