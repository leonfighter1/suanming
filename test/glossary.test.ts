// The protected-term glossary (i18n/terms.json), for the Phase 3 gate's 「英语扩展：术语表抽检」 (tech plan
// WP9.2): every term has its 繁體, 简体 and English, the key is the 简体 form the engines emit, and the English
// is English. Spot checks pin one term per method, 起名's sound notes (v5.1.0) among them.
import { describe, expect, it } from "vitest";
import { loadTerms } from "../src/ai/terms.js";

const { terms } = loadTerms();

describe("the glossary", () => {
  it("gives every term its 繁體, 简体 and English, keyed by the 简体 form", () => {
    const entries = Object.entries(terms);
    expect(entries.length).toBeGreaterThan(150);
    for (const [key, t] of entries) {
      for (const l of ["zh-Hant", "zh-Hans", "en"] as const)
        expect(t[l].trim(), `${key} ${l}`).not.toBe("");
      expect(t["zh-Hans"], key).toBe(key);
      expect(t.en, key).not.toMatch(/[㐀-鿿]/);
    }
  });

  it("holds the terms each method reads, spot-checked", () => {
    expect(terms["日主"]).toEqual({
      "zh-Hant": "日主",
      "zh-Hans": "日主",
      en: expect.stringMatching(/Day Master/),
    });
    expect(terms["圣筊"]!["zh-Hant"]).toBe("聖筊");
    expect(terms["后天八卦"]).toMatchObject({ "zh-Hant": "後天八卦", en: "Later Heaven Bagua" });
    expect(terms["双声"]).toMatchObject({ "zh-Hant": "雙聲", en: "Alliteration (Shuang Sheng)" });
    expect(terms["叠韵"]).toMatchObject({ "zh-Hant": "疊韻", en: "Rhyming Finals (Die Yun)" });
  });
});
