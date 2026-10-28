// WP3.4 (docs/tech-plan.md): every card's three keywords, as painted on the art, in three scripts.
import OpenCC from "opencc-js";
import { describe, expect, it } from "vitest";
import { DECK } from "../src/engines/tarot/deck.js";
import { KEYWORDS } from "../src/engines/tarot/keywords.js";

const toHant = OpenCC.Converter({ from: "cn", to: "tw" });
// Reviewed one-to-many fixes (scripts/build-tarot-keywords.ts HANT_FIXES, rule G18).
const FIXED: Record<string, string> = { 疗愈: "療癒" };

describe("牌义图鉴 keywords", () => {
  it("all 78 cards have three keywords in each script, none twice on a card", () => {
    expect(Object.keys(KEYWORDS)).toEqual(DECK.map((c) => c.id));
    for (const c of DECK) {
      for (const locale of ["zh-Hans", "zh-Hant", "en"] as const) {
        const words = KEYWORDS[c.id]![locale];
        expect(words, `${c.id} ${locale}`).toHaveLength(3);
        expect(new Set(words).size, `${c.id} ${locale}`).toBe(3);
        for (const w of words) expect(w.trim(), `${c.id} ${locale}`).not.toBe("");
      }
    }
  });

  it("繁體 is OpenCC's 简体→繁體 except the reviewed fixes, and stays put when converted again", () => {
    for (const c of DECK) {
      const k = KEYWORDS[c.id]!;
      k["zh-Hans"].forEach((w, i) =>
        expect(k["zh-Hant"][i], `${c.id} ${w}`).toBe(FIXED[w] ?? toHant(w)),
      );
      for (const w of k["zh-Hant"]) expect(toHant(w), `${c.id} ${w}`).toBe(w);
    }
    expect(KEYWORDS.major_17!["zh-Hant"]).toContain("療癒"); // the one fix (疗愈)
  });

  it("the painted keywords of a few cards, as on the art", () => {
    expect(KEYWORDS.major_00!["zh-Hans"]).toEqual(["新的开始", "自由", "冒险"]);
    expect(KEYWORDS.cups_02!["zh-Hant"]).toEqual(["結合", "吸引", "夥伴"]);
    expect(KEYWORDS.pentacles_14!.en).toEqual(["success", "stability", "wealth"]);
  });
});
