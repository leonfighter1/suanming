// WP13.1 (docs/tech-plan.md, the owner's 术语在前，评论在后): every reading paragraph comes as the term (the facts it
// rests on, said the tradition's way), then the plain commentary, then an everyday example.
import { describe, expect, it } from "vitest";
import {
  checkFaithfulness,
  CONCLUSION_PARTS,
  generateReport,
  METHOD_PROMPTS,
  MockProvider,
  PROMPTS,
  type NarrativeOutput,
  type Paragraph,
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
const tarot = computeTarot(
  { spread: "three_card" },
  { drawKey: DRAW_KEY, digestPepper: PEPPER, now: FIXED_NOW, newDrawId: () => "draw-1" },
);
/** A three-card tarot narrative (tarot still writes 举例): every paragraph neutral, the first card's as given. */
const tarotWith = (first: Partial<Paragraph>) => ({
  kind: "ok" as const,
  data: {
    sections: (["tarot_cards", "tarot_synthesis", "tarot_advice"] as const).map((topic) => ({
      topic,
      paragraphs: (topic === "tarot_cards" ? [0, 1, 2] : [0]).map((i) => ({
        term: `第 ${i + 1} 張`,
        text: "這張牌說的是你此刻的狀態。",
        source_level: "traditional_text" as const,
        fact_refs: [`/cards/${i}`],
        ...(topic === "tarot_cards" && i === 0 ? first : {}),
      })),
    })),
  } satisfies NarrativeOutput,
});

describe("术语在前，评论在后 (WP13.1)", () => {
  it("every method's reading prompt asks for the term and the commentary; all but 八字 for an example", () => {
    for (const [system, own] of Object.entries(METHOD_PROMPTS)) {
      expect(own.narrative.system, system).toContain("term (术语)");
      expect(own.narrative.system, system).toContain("text (评论)");
      // 八字 since v9.3.0 (the owner: 「比如XXX 这样的例子可以不用做了」).
      if (system === "bazi")
        expect(own.narrative.system).toContain("No 比如 or 例如 example scenes");
      else expect(own.narrative.system, system).toContain("example (举例)");
    }
    for (const p of [PROMPTS.life_methods, PROMPTS.life_topics]) {
      expect(p.system, p.id).toContain("the term first, then the commentary, then an example");
    }
  });

  it("keeps a paragraph's term, normalised, and leaves out an empty one (八字)", async () => {
    const mock = new MockProvider({
      narrative: [
        personality([
          {
            term: "月柱劫财",
            text: "你很重視朋友。",
            source_level: "traditional_text",
            fact_refs: ["/day_master"],
          },
          {
            term: " ",
            text: "做事有自己的節奏。",
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
    expect(r.agents[0]!.attempts).toBe(1); // the script itself, not a retry
    const [first, second] = r.layers!.interpretation[0]!.paragraphs;
    // 劫财 is the 简体 form of a protected term: a zh-Hant reading gets 劫財, in the term as in the text.
    expect(first).toEqual({
      term: "月柱劫財",
      text: "你很重視朋友。",
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

  it("keeps an example, normalised, and leaves out an empty one (a method that still writes them)", async () => {
    const withExample = await generateReport(
      tarot,
      { locale: "zh-Hant", country: "HK" },
      deps(new MockProvider({ narrative: [tarotWith({ example: "比如朋友找你訴說劫财的事。" })] })),
    );
    expect(withExample.agents[0]!.attempts).toBe(1);
    expect(withExample.layers!.interpretation[0]!.paragraphs[0]!.example).toBe(
      "比如朋友找你訴說劫財的事。",
    );
    const empty = await generateReport(
      tarot,
      { locale: "zh-Hant", country: "HK" },
      deps(new MockProvider({ narrative: [tarotWith({ example: "" })] })),
    );
    expect(empty.layers!.interpretation[0]!.paragraphs[0]).not.toHaveProperty("example");
    expect(empty.layers!.interpretation[0]!.paragraphs[0]!.text).toBe("這張牌說的是你此刻的狀態。");
  });

  it("scans the term, the example and the 总结 with the rule layer", async () => {
    // 注定 (G003, fatalism) only in one place each time: the reading is sent back once with the rule's feedback.
    const fatal = "你注定會失去這段感情。";
    const inTerm = new MockProvider({
      narrative: [
        personality([
          {
            term: fatal,
            text: "你做事踏實。",
            source_level: "traditional_text",
            fact_refs: ["/day_master"],
          },
        ]),
      ],
    });
    const inExample = new MockProvider({ narrative: [tarotWith({ example: `比如${fatal}` })] });
    const neutral = personality([
      { text: "你做事踏實。", source_level: "traditional_text", fact_refs: ["/day_master"] },
    ]);
    const inConclusion = new MockProvider({
      narrative: [
        {
          ...neutral,
          data: {
            ...neutral.data,
            conclusion: Object.fromEntries(
              CONCLUSION_PARTS.map((p) => [
                p,
                { text: p === "future" ? fatal : "整體平穩。", fact_refs: ["/day_master"] },
              ]),
            ),
          },
        },
      ],
    });
    for (const [mock, chart] of [
      [inTerm, bazi],
      [inExample, tarot],
      [inConclusion, bazi],
    ] as const) {
      const r = await generateReport(
        chart,
        {
          locale: "zh-Hant",
          country: "HK",
          ...(chart === bazi && { topics: ["personality" as const] }),
        },
        deps(mock),
      );
      expect(r.agents[0]!.attempts).toBe(2);
      expect(mock.calls.filter((c) => c.agent === "narrative")[1]!.user).toContain("G003");
    }
  });

  it("the faithfulness checks read the term", async () => {
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

  it("the mock writes what each method asks for, so a demo reading shows it (IS_AI_MOCK=TRUE)", async () => {
    const t = await generateReport(
      tarot,
      { locale: "zh-Hans", country: "HK" },
      deps(new MockProvider()),
    );
    for (const p of t.layers!.interpretation.flatMap((s) => s.paragraphs)) {
      expect((p.term ?? "").trim()).not.toBe("");
      expect(p.text.trim()).not.toBe("");
      expect((p.example ?? "").trim()).not.toBe("");
    }
    // 八字 (v9.3.0): the term and the commentary, no example, and the 总结 in all nine parts.
    const b = await generateReport(
      bazi,
      { locale: "zh-Hans", country: "HK" },
      deps(new MockProvider()),
    );
    for (const p of b.layers!.interpretation.flatMap((s) => s.paragraphs)) {
      expect((p.term ?? "").trim()).not.toBe("");
      expect(p.text.trim()).not.toBe("");
      expect(p).not.toHaveProperty("example");
    }
    for (const part of CONCLUSION_PARTS)
      expect(b.layers!.conclusion![part]!.text.trim()).not.toBe("");
  });
});
