// 起名 (tech plan WP6.4, the owner's Phase 3 spec): the 字义库 (a draft awaiting the owner's 人工校订), the
// 音律 rules one by one, the elements from a 八字 chart, and the candidates.
import { readFileSync } from "node:fs";
import type { AddressInfo } from "node:net";
import OpenCC from "opencc-js";
import { pinyin } from "pinyin-pro";
import { describe, expect, it } from "vitest";
import { GeoRefusedError, generateReport, MockProvider } from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import type { ChartFact } from "../src/chart-fact/index.js";
import { loadGeoMatrix, resolveRegion } from "../src/compliance/geo.js";
import { NAME_CHARS, RADICALS, SURNAMES } from "../src/engines/naming/characters.js";
import { computeTarot } from "../src/engines/tarot/index.js";
import {
  computeNaming,
  LIBRARY,
  MAX_CANDIDATES,
  soundRejects,
  soundScore,
  syllable,
  targetElements,
  type Candidate,
} from "../src/engines/naming/index.js";
import { DRAW_KEY, FIXED_NOW, PEPPER, withNaming, withNamingOn } from "./helpers.js";

const toHans = OpenCC.Converter({ from: "tw", to: "cn" });
const s = (p: string) => p.split(" ").map(syllable);

describe("the 字义库 (draft)", () => {
  it("has enough characters per element for a full list, each once, with a meaning in three languages", () => {
    // The draft has 100, 20 per element; the owner's review may drop some, never below a list's worth.
    expect(new Set(NAME_CHARS.map((c) => c.hant)).size).toBe(NAME_CHARS.length);
    for (const e of ["木", "火", "土", "金", "水"]) {
      expect(NAME_CHARS.filter((c) => c.element === e).length, e).toBeGreaterThanOrEqual(
        MAX_CANDIDATES,
      );
    }
    for (const c of NAME_CHARS) {
      for (const l of ["zh-Hant", "zh-Hans", "en"] as const)
        expect(c.meaning[l].trim(), c.hant).not.toBe("");
    }
  });

  it("is on in no region of the shipped matrix until the owner has reviewed it", () => {
    const matrix = loadGeoMatrix("compliance/geo_rule_matrix.json");
    for (const cc of Object.keys(matrix.regions)) {
      const on = resolveRegion(matrix, cc)?.systems.naming?.available ?? false;
      if (on) expect(LIBRARY.reviewed, `${cc} offers 起名`).toBe(true);
    }
    if (matrix.defaults.systems.naming?.available) expect(LIBRARY.reviewed).toBe(true);
  });

  it("reads each element from the character's radical (字形五行)", () => {
    for (const c of NAME_CHARS)
      expect(RADICALS[c.element], `${c.hant} ${c.radical}`).toContain(c.radical);
  });

  it("gives every character pinyin-pro's reading, and every surname its reading as a surname (G4)", () => {
    for (const c of NAME_CHARS)
      expect(c.pinyin, c.hant).toBe(pinyin(c.hans, { toneType: "symbol" }));
    for (const [hant, hans, p] of SURNAMES) {
      expect(p, hant).toBe(pinyin(hans, { toneType: "symbol", surname: "head" }));
    }
  });

  it("writes 简体 as OpenCC does, characters and meanings (G18)", () => {
    for (const c of NAME_CHARS) {
      expect(c.hans, c.hant).toBe(toHans(c.hant));
      expect(c.meaning["zh-Hans"], c.meaning["zh-Hant"]).toBe(toHans(c.meaning["zh-Hant"]));
    }
    for (const [hant, hans] of SURNAMES) expect(hans, hant).toBe(toHans(hant));
  });
});

describe("音律", () => {
  it("splits a syllable into tone, initial and final", () => {
    expect(syllable("zhāng")).toEqual({ base: "zhang", tone: 1, initial: "zh", final: "ang" });
    expect(syllable("lǚ")).toEqual({ base: "lü", tone: 3, initial: "l", final: "ü" });
    expect(syllable("ōu")).toEqual({ base: "ou", tone: 1, initial: "", final: "ou" });
    expect(syllable("xī")).toEqual({ base: "xi", tone: 1, initial: "x", final: "i" });
  });

  it("rejects two like syllables side by side, and three syllables in one tone", () => {
    expect(soundRejects(s("lín lín"))).toBe(true);
    expect(soundRejects(s("xī xī"))).toBe(true); // 溪 and 曦: one syllable, one tone
    expect(soundRejects(s("wáng hán lín"))).toBe(true); // 2, 2, 2
    expect(soundRejects(s("wáng zǐ hán"))).toBe(false); // 2, 3, 2
    expect(soundRejects(s("lín lán"))).toBe(false); // two syllables in one tone: scored, not rejected
  });

  it("scores rise and fall, a level ending, and 双声 / 叠韵", () => {
    // 张梓涵 zhāng zǐ hán: 1→3 平仄 +1; 3→2 平仄 +1; ends on 2 (平) +0.5; no 双声 (zh/z, z/h), no 叠韵 → 2.5.
    expect(soundScore(s("zhāng zǐ hán"))).toEqual({ score: 2.5, notes: ["pingze", "ends_level"] });
    // 林岚 lín lán: one tone −1; 双声 l/l −0.5; finals in/an differ; ends on 2 +0.5 → −1.
    expect(soundScore(s("lín lán"))).toEqual({
      score: -1,
      notes: ["same_tone", "shuangsheng", "ends_level"],
    });
    // 王洋 wáng yáng: one tone −1; initials w/y differ; 叠韵 ang/ang −0.5; ends on 2 +0.5 → −1.
    expect(soundScore(s("wáng yáng"))).toEqual({
      score: -1,
      notes: ["same_tone", "dieyun", "ends_level"],
    });
    // 李沛 lǐ pèi: 3→4 both 仄, a change of tone but not of 平仄 → 0; ends on 4 → nothing.
    expect(soundScore(s("lǐ pèi"))).toEqual({ score: 0, notes: [] });
  });
});

describe("the elements", () => {
  it("are the 八字 chart's 喜用, or else its two weakest elements (a balance)", () => {
    expect(targetElements({ strength: { favorable: ["火", "土"] } })).toEqual({
      elements: ["火", "土"],
      basis: "favorable",
    });
    // 中和: no 喜用. Weakest by wuxing_weighted: 金 0.5, then 火 1.
    const scores = { 木: 2, 火: 1, 土: 3, 金: 0.5, 水: 4 };
    expect(targetElements({ strength: { favorable: [] }, wuxing_weighted: { scores } })).toEqual({
      elements: ["金", "火"],
      basis: "balance",
    });
    // A chart flagged for a closer look keeps to balance even with 喜用.
    expect(
      targetElements({
        strength: { favorable: ["水"], special: "从格候选" },
        wuxing_weighted: { scores },
      }),
    ).toEqual({ elements: ["金", "火"], basis: "balance" });
  });
});

describe("the candidates", () => {
  const bazi = JSON.parse(readFileSync("app/test/fixtures/chart_bazi.json", "utf8"))
    .chart_fact as ChartFact;
  const ctx = { digestPepper: PEPPER, now: FIXED_NOW };
  const names = (surname: string, length: 1 | 2) =>
    (computeNaming(bazi, { surname, length }, ctx).facts as { candidates: Candidate[] }).candidates;

  it("serve the 喜用, avoid the surname, vary their characters and come in score order", () => {
    // The fixture's 喜用: 火, 土 (身弱).
    const list = names("張", 2);
    expect(list.length).toBe(MAX_CANDIDATES);
    const uses = new Map<string, number>();
    for (const c of list) {
      expect(
        c.elements.every((e) => e === "火" || e === "土"),
        c.given["zh-Hant"],
      ).toBe(true);
      expect([...c.given["zh-Hant"]]).toHaveLength(2);
      expect(c.given["zh-Hant"]).not.toContain("張");
      expect(c.source_level).toBe("simplified_rule");
      for (const ch of c.given["zh-Hant"]) uses.set(ch, (uses.get(ch) ?? 0) + 1);
    }
    expect(Math.max(...uses.values())).toBeLessThanOrEqual(2);
    expect(list.map((c) => c.score)).toEqual([...list.map((c) => c.score)].sort((a, b) => b - a));
    // Reproducible, and the same in 简体 input.
    expect(names("張", 2)).toEqual(list);
    expect(names("张", 2)).toEqual(list);
  });

  it("knows a common surname's reading; an unknown surname still gets names", () => {
    const known = computeNaming(bazi, { surname: "陳", length: 1 }, ctx).facts as {
      surname: { pinyin?: string };
    };
    expect(known.surname.pinyin).toBe("chén");
    const other = computeNaming(bazi, { surname: "鍾離", length: 1 }, ctx).facts as {
      surname: { pinyin?: string };
      candidates: Candidate[];
    };
    expect(other.surname.pinyin).toBeUndefined();
    expect(other.candidates.length).toBeGreaterThan(0);
    expect(() => computeNaming(bazi, { surname: "Lee", length: 1 }, ctx)).toThrow();
  });
});

describe("a 起名 reading and the API", () => {
  const bazi = JSON.parse(readFileSync("app/test/fixtures/chart_bazi.json", "utf8"))
    .chart_fact as ChartFact;
  const naming = computeNaming(
    bazi,
    { surname: "張", length: 2 },
    { digestPepper: PEPPER, now: FIXED_NOW },
  );
  const providers = (m: MockProvider) => ({ deepseek: m, anthropic: m });

  it("is refused while the matrix keeps 起名 off, and reads the names with its own prompts once it's on", async () => {
    await expect(
      withNaming(false, () =>
        generateReport(
          naming,
          { locale: "zh-Hant", country: "HK" },
          { providers: providers(new MockProvider()), now: FIXED_NOW },
        ),
      ),
    ).rejects.toThrow(GeoRefusedError);
    const mock = new MockProvider();
    const report = await withNamingOn(() =>
      generateReport(
        naming,
        { locale: "zh-Hant", country: "HK" },
        { providers: providers(mock), now: FIXED_NOW },
      ),
    );
    expect(report.status).toBe("passed");
    expect(report.topics).toEqual(["naming_candidates", "naming_advice"]);
    expect(report.ai_disclosure.prompt_version).toBe("narrative_naming@2,action_naming@1,guard@2");
    const first = (naming.facts as { candidates: Candidate[] }).candidates[0]!;
    expect(mock.calls.find((c) => c.agent === "narrative")!.user).toContain(
      `張${first.given["zh-Hant"]}`,
    );
    expect(report.layers!.facts[0]).toBe("張氏 · 火、土");
    expect(report.layers!.expectation.ai_label).toContain("不決定任何人的命運");
  });

  it("holds a name said to decide fate in a 起名 reading, and only there (v5.2.0, rule 8)", async () => {
    const text = "好名字決定一生的命運。";
    const narrative = (
      topics: string[],
      refs: (i: number) => string,
      n: (t: string) => number,
    ) => ({
      sections: topics.map((topic) => ({
        topic,
        summary: "（示範）重點。",
        paragraphs: Array.from({ length: n(topic) }, (_, i) => ({
          text,
          source_level: "simplified_rule",
          fact_refs: [refs(i)],
        })),
      })),
    });
    const names = narrative(
      ["naming_candidates", "naming_advice"],
      () => "/candidates/0",
      () => 1,
    );
    const held = await withNamingOn(() =>
      generateReport(
        naming,
        { locale: "zh-Hant", country: "HK" },
        {
          providers: providers(
            new MockProvider({
              narrative: [
                { kind: "ok", data: names },
                { kind: "ok", data: names },
              ],
            }),
          ),
          now: FIXED_NOW,
        },
      ),
    );
    expect(held.status).toBe("blocked");
    expect(held.compliance.rule_violations.map((v) => v.rule_id)).toContain("N001");

    // The same sentence in a three-card tarot reading (one paragraph per card): not 起名's rule.
    const cards = narrative(
      ["tarot_cards", "tarot_synthesis", "tarot_advice"],
      (i) => `/cards/${i}`,
      (t) => (t === "tarot_cards" ? 3 : 1),
    );
    const tarot = await generateReport(
      computeTarot(
        { spread: "three_card" },
        { drawKey: DRAW_KEY, digestPepper: PEPPER, now: FIXED_NOW, newDrawId: () => "draw-1" },
      ),
      { locale: "zh-Hant", country: "HK" },
      {
        providers: providers(new MockProvider({ narrative: [{ kind: "ok", data: cards }] })),
        now: FIXED_NOW,
      },
    );
    expect(tarot.compliance.rule_violations.map((v) => v.rule_id)).not.toContain("N001");
    expect(tarot.status).toBe("passed");
  });

  it("reads only the caller's own 八字 chart, and is off for everyone while the matrix says so", async () => {
    const H = (user: string) => ({
      "content-type": "application/json",
      "x-dev-country": "HK",
      "x-dev-user": user,
    });
    const serve = async () => {
      const api = createApiServer({
        secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
        providers: providers(new MockProvider()),
        devMode: true,
        log: () => {},
      });
      await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
      const base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
      const post = async (path: string, body: unknown, user = "n1") =>
        fetch(base + path, { method: "POST", headers: H(user), body: JSON.stringify(body) });
      return { api, base, post };
    };
    const BAZI = {
      system: "bazi",
      local: "1990-03-15T14:30",
      timezone: "Asia/Hong_Kong",
      longitude: 114.17,
      gender: "male",
    };

    await withNamingOn(async () => {
      const { api, post } = await serve();
      try {
        const own = (await (await post("/v1/charts", BAZI)).json()).chart_id;
        const res = await post("/v1/charts", {
          system: "naming",
          bazi_chart_id: own,
          surname: "陳",
          length: 2,
        });
        expect(res.status).toBe(201);
        expect((await res.json()).chart_fact.facts.surname["zh-Hant"]).toBe("陳");
        // Another account's chart is as if it weren't there; a tarot chart isn't a 八字 chart.
        const theirs = (await (await post("/v1/charts", BAZI, "n2")).json()).chart_id;
        expect(
          (await post("/v1/charts", { system: "naming", bazi_chart_id: theirs, surname: "陳" }))
            .status,
        ).toBe(404);
        const tarot = (
          await (
            await post("/v1/charts", {
              system: "tarot",
              spread: "single",
              question: "最近的工作会顺利吗？",
            })
          ).json()
        ).chart_id;
        expect(
          (await post("/v1/charts", { system: "naming", bazi_chart_id: tarot, surname: "陳" }))
            .status,
        ).toBe(400);
        expect(
          (await post("/v1/charts", { system: "naming", bazi_chart_id: own, surname: "Lee" }))
            .status,
        ).toBe(400);
      } finally {
        await new Promise<void>((r) => api.close(() => r()));
      }
    });

    // Off (as shipped, until the review): refused everywhere, and not among the methods.
    await withNaming(false, async () => {
      const { api, base, post } = await serve();
      try {
        const own = (await (await post("/v1/charts", BAZI)).json()).chart_id;
        expect(
          (await post("/v1/charts", { system: "naming", bazi_chart_id: own, surname: "陳" }))
            .status,
        ).toBe(451);
        const methods = await (await fetch(`${base}/v1/methods`, { headers: H("n1") })).json();
        expect(methods.methods.map((m: { system: string }) => m.system)).not.toContain("naming");
      } finally {
        await new Promise<void>((r) => api.close(() => r()));
      }
    });
  });
});
