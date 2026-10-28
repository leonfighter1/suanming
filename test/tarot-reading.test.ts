import { describe, expect, it } from "vitest";
import {
  generateReport,
  MockProvider,
  PROMPTS,
  promptHash,
  type LLMJsonRequest,
  type LLMProvider,
} from "../src/ai/index.js";
import { factsLayer } from "../src/ai/layers.js";
import { spreadBrief } from "../src/ai/tarot.js";
import { computeBazi } from "../src/engines/bazi/index.js";
import { DECK } from "../src/engines/tarot/deck.js";
import { computeTarot } from "../src/engines/tarot/index.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";

const draw = (spread: "single" | "three_card" | "celtic_cross") =>
  computeTarot(
    { spread },
    { drawKey: DRAW_KEY, digestPepper: PEPPER, now: FIXED_NOW, newDrawId: () => "draw-1" },
  );
const celtic = draw("celtic_cross");
const cards = (celtic.facts as { cards: { card_id: string; reversed: boolean }[] }).cards;

/** Records what each agent was sent, answering with the mock. */
function spy(): LLMProvider & { sent: LLMJsonRequest[] } {
  const mock = new MockProvider();
  const sent: LLMJsonRequest[] = [];
  return { name: "spy", sent, generateJson: (req) => (sent.push(req), mock.generateJson(req)) };
}

describe("tarot reading, the classic way", () => {
  it("<spread> lists the Celtic Cross in dealing order: position, meaning, place, card, path", () => {
    const brief = spreadBrief(celtic, "zh-Hans");
    expect(brief.spread_id).toBe("celtic_cross");
    expect(brief.cards.map((c) => [c.n, c.path, c.position])).toEqual([
      [1, "/cards/0", "现在"],
      [2, "/cards/1", "挑战"],
      [3, "/cards/2", "根基"],
      [4, "/cards/3", "近期过去"],
      [5, "/cards/4", "潜能"],
      [6, "/cards/5", "近期未来"],
      [7, "/cards/6", "自我"],
      [8, "/cards/7", "环境"],
      [9, "/cards/8", "希望与恐惧"],
      [10, "/cards/9", "结果"],
    ]);
    // Card 2 crosses card 1; card 5 is the crown; the staff runs from the bottom (7) to the top (10).
    expect(brief.cards[1]!.place).toBe("cross: laid across card 1");
    expect(brief.cards[4]!.place).toBe("cross: above card 1 (the crown)");
    expect([brief.cards[6]!.place, brief.cards[9]!.place]).toEqual(["staff: bottom", "staff: top"]);
    // Names and orientation are the drawn cards', in the reader's language.
    cards.forEach((c, i) => {
      expect(brief.cards[i]!.card).toBe(DECK.find((d) => d.id === c.card_id)!.name["zh-Hans"]);
      expect(brief.cards[i]!.orientation).toBe(c.reversed ? "逆位" : "正位");
      expect(brief.cards[i]!.meaning).not.toBe("");
    });
  });

  it("each method keeps its own prompt: tarot reads with narrative_tarot, 八字 is untouched", async () => {
    const tarotAi = spy();
    const tarot = await generateReport(
      celtic,
      { locale: "zh-Hans", country: "HK", topics: ["career_wealth"], question: "我该不该换工作？" },
      { providers: { deepseek: tarotAi, anthropic: tarotAi }, now: FIXED_NOW },
    );
    expect(tarot.ai_disclosure.prompt_version).toBe("narrative_tarot@1,action@3,guard@2");
    const reading = tarotAi.sent.find((r) => r.agent === "narrative")!;
    expect(reading.system).toBe(PROMPTS.narrative_tarot.system);
    expect(reading.user).toContain("<spread>");
    expect(reading.user).toContain("<user_question>\n我该不该换工作？");

    const baziAi = spy();
    const bazi = computeBazi(
      { local: "1990-03-15T14:30", timezone: "Asia/Hong_Kong", longitude: 114.17, gender: "male" },
      { digestPepper: PEPPER, now: FIXED_NOW },
    );
    await generateReport(
      bazi,
      { locale: "zh-Hans", country: "HK", topics: ["personality"] },
      { providers: { deepseek: baziAi, anthropic: baziAi }, now: FIXED_NOW },
    );
    const baziReading = baziAi.sent.find((r) => r.agent === "narrative")!;
    // 八字 reads with its own prompt too (v2.0.0); the shared narrative@4 stays byte for byte
    // what it was, for astrology.
    expect(baziReading.system).toBe(PROMPTS.narrative_bazi.system);
    expect(PROMPTS.narrative_bazi.system).not.toBe(PROMPTS.narrative.system);
    expect(PROMPTS.narrative.id).toBe("narrative@4");
    expect(promptHash(PROMPTS.narrative)).toBe("49007c9a8aba351e");
    expect(baziReading.user).not.toContain("<spread>");
  });

  it("the tarot prompt stands on its own: no 八字 rules in it", () => {
    const p = PROMPTS.narrative_tarot.system;
    for (const bazi of ["day_master", "wuxing_weighted", "input_basis", "liunian"]) {
      expect(p).not.toContain(bazi);
    }
    expect(p).toContain("celtic_cross");
    expect(p).toContain("three_card");
  });

  it("the facts layer numbers the cards in dealing order", () => {
    const lines = factsLayer(draw("three_card"), "zh-Hans", 2026);
    expect(lines.map((l) => l.slice(0, 5))).toEqual(["1. 过去", "2. 现在", "3. 未来"]);
  });
});
