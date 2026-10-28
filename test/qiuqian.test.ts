// 求籤 (tech plan WP6.1): the lot set's text and the draw. The text's evidence is
// docs/verification/qiuqian-guandi-100.md; the expected lines below are copied from its tables.
import { describe, expect, it } from "vitest";
import { validateChartFact } from "../src/chart-fact/index.js";
import {
  computeQiuqian,
  MAX_ROUNDS,
  throwOf,
  verifyDraw,
  type QiuqianFacts,
} from "../src/engines/qiuqian/index.js";
import { lotSet } from "../src/engines/qiuqian/lots.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";

const set = lotSet("guandi_100");
const line = (n: number, i: number, script: "zh-Hant" | "zh-Hans" = "zh-Hant") =>
  set.lots[n - 1]!.poem[script][i - 1];

describe("the 關聖帝君一百籤", () => {
  it("has 100 lots of four seven-character lines in both scripts, inside the BMP", () => {
    expect(set.lots.map((l) => l.n)).toEqual(Array.from({ length: 100 }, (_, i) => i + 1));
    for (const lot of set.lots) {
      for (const script of ["zh-Hant", "zh-Hans"] as const) {
        expect(lot.poem[script], `#${lot.n} ${script}`).toHaveLength(4);
        for (const l of lot.poem[script]) expect(l).toMatch(/^\p{Script=Han}{7}$/u);
      }
    }
    // Every character fits common CJK fonts (the app, the share image): nothing past U+FFFF.
    expect([...JSON.stringify(set)].filter((c) => c.codePointAt(0)! > 0xffff)).toEqual([]);
  });

  it("labels lot n with 天干[(n−1) ÷ 10] + 天干[(n−1) mod 10], as the print's headings do", () => {
    // 天干 甲0 乙1 丙2 丁3 戊4 己5 庚6 辛7 壬8 癸9. #1: (0, 0) 甲甲; #10: (0, 9) 甲癸; #11: (1, 0) 乙甲;
    // #55: (5, 4) 己戊; #100: (9, 9) 癸癸. Read in the print: #13 乙丙 (1, 2), #35 丁戊 (3, 4), #76 辛己 (7, 5),
    // #99 癸壬 (9, 8).
    const want: Record<number, string> = {
      1: "甲甲",
      10: "甲癸",
      11: "乙甲",
      13: "乙丙",
      35: "丁戊",
      55: "己戊",
      76: "辛己",
      99: "癸壬",
      100: "癸癸",
    };
    for (const [n, g] of Object.entries(want))
      expect(set.lots[Number(n) - 1]!.ganzhi, `#${n}`).toBe(g);
  });

  it("keeps the temples' text, with the print's reading where they disagree or plainly err", () => {
    // A and B disagree; the print decides (#35: neither A 分折 nor B 分析 has the print's 分拆).
    expect(line(35, 3)).toBe("誰料半途分拆去");
    expect(line(76, 2)).toBe("此事如何說與君");
    expect(line(99, 4)).toBe("驊騮應得驟康莊");
    // A and B agree on a plain error; the print's reading.
    expect(line(25, 1)).toBe("寅午戌年多阻滯");
    expect(line(47, 2)).toBe("祇欲平和雪爾冤");
    expect(line(50, 2)).toBe("也須步步要周旋");
    expect(line(87, 2)).toBe("舟中敵國笑中刀");
    expect(line(90, 4)).toBe("徒勞生事苦咨嗟");
    // A variant: the temples' 千官 stays (the print has 仙官).
    expect(set.lots[0]!.poem["zh-Hant"]).toEqual([
      "巍巍獨步向雲間",
      "玉殿千官第一班",
      "富貴榮華天付汝",
      "福如東海壽如山",
    ]);
  });

  it("writes 简体 with 乾 kept where it is the trigram, and without OpenCC's slips", () => {
    expect(line(78, 2, "zh-Hans")).toBe("也须肚里立乾坤");
    expect(line(79, 1, "zh-Hans")).toBe("乾亥来龙仔细看");
    expect(line(93, 2, "zh-Hans")).toBe("入夏晴干雨又愆"); // 晴乾 is "dry"
    expect(line(47, 2, "zh-Hans")).toBe("只欲平和雪尔冤");
    expect(line(94, 2, "zh-Hans")).toBe("巧斫轮舆梓匠工");
    expect(line(83, 1, "zh-Hans")).toBe("随分堂前赴粥饘");
  });
});

describe("擲筊", () => {
  it("reads one of each face as 聖筊, both flat as 笑筊, both round as 陰筊", () => {
    expect(throwOf(["flat", "round"])).toBe("sheng");
    expect(throwOf(["round", "flat"])).toBe("sheng");
    expect(throwOf(["flat", "flat"])).toBe("xiao");
    expect(throwOf(["round", "round"])).toBe("yin");
  });
});

describe("a draw", () => {
  const draw = (id: string) =>
    computeQiuqian(
      {},
      { drawKey: DRAW_KEY, digestPepper: PEPPER, now: FIXED_NOW, newDrawId: () => id },
    );
  const facts = (id: string) => draw(id).facts as unknown as QiuqianFacts;

  it("is a schema-valid ChartFact whose lot is the stick the last throw confirmed", () => {
    for (let i = 0; i < 200; i++) {
      const id = `00000000-0000-4000-8000-${String(i).padStart(12, "0")}`;
      const chart = draw(id);
      expect(validateChartFact(chart)).toEqual({ ok: true });
      const f = chart.facts as unknown as QiuqianFacts;
      expect(f.rounds.at(-1)!.result).toBe("sheng");
      expect(f.rounds.slice(0, -1).every((r) => r.result !== "sheng")).toBe(true);
      for (const r of f.rounds) expect(r.result).toBe(throwOf(r.blocks));
      const lot = set.lots[f.rounds.at(-1)!.lot - 1]!;
      expect(f.lot).toEqual({ n: lot.n, ganzhi: lot.ganzhi, poem: lot.poem["zh-Hant"] });
    }
  });

  it("replays from the key and the draw id, and audit replay rejects a changed lot or round", () => {
    const id = "00000000-0000-4000-8000-000000000001";
    expect(draw(id)).toEqual(draw(id));
    const chart = draw(id);
    expect(verifyDraw(chart, DRAW_KEY)).toBe(true);
    expect(verifyDraw(chart, Buffer.alloc(32, 1))).toBe(false);
    const f = chart.facts as unknown as QiuqianFacts;
    const otherLot = { ...chart, facts: { ...f, lot: { ...f.lot, n: (f.lot.n % 100) + 1 } } };
    expect(verifyDraw(otherLot, DRAW_KEY)).toBe(false);
    const rounds = f.rounds.map((r, i) => (i === 0 ? { ...r, lot: (r.lot % 100) + 1 } : r));
    expect(verifyDraw({ ...chart, facts: { ...f, rounds } }, DRAW_KEY)).toBe(false);
  });

  it("confirms half the throws, splits the rest between 笑筊 and 陰筊, and lets every stick fall (4000 draws)", () => {
    // Fair blocks: a round ends in 聖筊 with p = ½, so rounds per draw are geometric, mean 1/p = 2, variance
    // (1 − p)/p² = 2. Over N = 4000 draws the mean's sd is √(2/4000) ≈ 0.0224: |mean − 2| < 3 sd ≈ 0.067.
    // A non-聖筊 round is 笑筊 or 陰筊 with ½ each: |z| < 3. All 100 sticks fall among the 8000-odd rounds
    // (a given stick misses them all with (0.99)^8000 ≈ e^−80).
    const N = 4000;
    let rounds = 0;
    let xiao = 0;
    let other = 0;
    const fell = new Set<number>();
    for (let i = 0; i < N; i++) {
      const f = facts(`10000000-0000-4000-8000-${String(i).padStart(12, "0")}`);
      expect(f.rounds.length).toBeLessThanOrEqual(MAX_ROUNDS);
      rounds += f.rounds.length;
      for (const r of f.rounds) {
        fell.add(r.lot);
        if (r.result !== "sheng") {
          other++;
          if (r.result === "xiao") xiao++;
        }
      }
    }
    expect(Math.abs(rounds / N - 2)).toBeLessThan(0.067);
    expect(Math.abs(xiao - other / 2) / Math.sqrt(other / 4)).toBeLessThan(3);
    expect(fell.size).toBe(100);
  }, 30_000);
});
