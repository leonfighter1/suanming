// 算卦's 直說 (tech plan WP10.2): one for every 卦辭 and 爻辭, said straight out, in both scripts; the built table
// matches its source; tendency, never fate (the global rules find nothing); 乾 kept from OpenCC (G18).
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { buildPlain } from "../scripts/build-liuyao.js";
import { compileRules, loadRuleSet, scan } from "../src/compliance/index.js";
import { plainOf } from "../src/engines/liuyao/plain.js";
import { zhouyiText } from "../src/engines/yijing/index.js";

type Text = { "zh-Hant": string; "zh-Hans": string };
const built = JSON.parse(readFileSync("data/liuyao/plain.json", "utf8"));
const texts = (built.hexagrams as { gua: Text; lines: Text[] }[]).flatMap((h) => [
  h.gua,
  ...h.lines,
]);

describe("the 直說", () => {
  it("is the table its source builds (npm run build:liuyao)", () => {
    expect(built).toEqual(buildPlain());
  });

  it("covers every 卦辭 and 爻辭, 用九 and 用六 included, in both scripts", () => {
    expect(built.hexagrams).toHaveLength(64);
    expect(texts).toHaveLength(64 + 384 + 2);
    for (const t of texts) {
      expect(t["zh-Hant"].trim()).not.toBe("");
      expect(t["zh-Hans"].trim()).not.toBe("");
    }
    // 乾 and 坤 each have a seventh, for 用九 and 用六.
    expect(zhouyiText("111111").yao_ci).toHaveLength(7);
    expect(plainOf("111111", 7)["zh-Hant"]).toMatch(/大家一起做/);
    expect(plainOf("000000", 7)["zh-Hant"]).toMatch(/長期守住正道/);
    expect(() => plainOf("100111", 7)).toThrow();
  });

  it("says it straight: short sentences, no quotation marks, no fatalism the rules would hold", () => {
    const rules = compileRules(loadRuleSet(), ["global"]);
    for (const t of texts) {
      expect([...t["zh-Hant"]].length, t["zh-Hant"]).toBeLessThanOrEqual(40);
      expect(t["zh-Hans"], t["zh-Hans"]).not.toMatch(/[「」『』]/);
      for (const s of [t["zh-Hant"], t["zh-Hans"]]) expect(scan(s, rules), s).toEqual([]);
    }
  });

  it("keeps 乾 where OpenCC would write 干 (G18), and converts everything else", () => {
    for (const t of texts) {
      [...t["zh-Hant"]].forEach((ch, i) => {
        if (ch === "乾") expect([...t["zh-Hans"]][i]).toBe("乾");
      });
    }
    // A plain conversion: 無妄 六二.
    expect(plainOf("100111", 2)).toEqual({
      "zh-Hant": "別只想收穫，把眼前該做的做好，往前走就順。",
      "zh-Hans": "别只想收获，把眼前该做的做好，往前走就顺。",
    });
  });
});
