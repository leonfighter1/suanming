import { describe, expect, it } from "vitest";
import {
  checkFaithfulness,
  generateReport,
  MockProvider,
  type NarrativeOutput,
} from "../src/ai/index.js";
import { computeTarot } from "../src/engines/tarot/index.js";
import { DRAW_KEY, FIXED_NOW, PEPPER, sampleBazi } from "./helpers.js";

const bazi = sampleBazi();
const tarot = computeTarot(
  { spread: "three_card" },
  {
    drawKey: DRAW_KEY,
    digestPepper: PEPPER,
    now: FIXED_NOW,
    newDrawId: () => "00000000-0000-4000-8000-000000000001",
  },
);
const cards = (tarot.facts as { cards: { card_id: string; reversed: boolean }[] }).cards;

async function reportWith(chart: typeof bazi, texts: string[]) {
  // A tarot reading has its own sections since v2.3.0; the whole-spread one fits any text.
  const topic = chart.system === "tarot" ? "tarot_synthesis" : "personality";
  const narrative: NarrativeOutput = {
    sections: [
      {
        topic,
        paragraphs: texts.map((text) => ({
          text,
          source_level: "traditional_text",
          fact_refs: [chart.system === "bazi" ? "/day_master" : "/cards/0"],
        })),
      },
    ],
  };
  // Run the real pipeline (mock model); stay clear of the rule layer by using neutral text.
  const scripted = new MockProvider({ narrative: [{ kind: "ok", data: narrative }] });
  return generateReport(
    chart,
    { locale: "zh-Hant", country: "HK", topics: [topic] },
    {
      // Under both keys: whichever provider the routes name answers with this narrative.
      providers: { deepseek: scripted, anthropic: scripted },
      now: FIXED_NOW,
    },
  );
}

describe("checkFaithfulness", () => {
  it("accepts text that only uses chart data", async () => {
    const r = await reportWith(bazi, ["日柱己卯，2026丙午流年與時支六合，目前大運壬午。"]);
    expect(r.status).toBe("passed");
    expect(checkFaithfulness(bazi, r)).toEqual([]);
  });

  it("knows the 干支 of 胎元 and of every 流月 (facts since v1.3.0)", async () => {
    // 2026's 寅月 is 庚寅 (五虎遁: a 丙 year starts at 庚寅), in no pillar, 大運 or 流年 of this
    // chart; 胎元 = 己 + 1, 卯 + 3 = 庚午.
    const r = await reportWith(bazi, ["寅月（庚寅）宜放慢腳步；胎元庚午。"]);
    expect(r.status).toBe("passed");
    expect(checkFaithfulness(bazi, r)).toEqual([]);
  });

  it("flags 干支 not in the chart and wrong year 干支", async () => {
    const r = await reportWith(bazi, ["日柱甲子，2027年丙午。"]);
    const kinds = checkFaithfulness(bazi, r).map((i) => i.kind);
    // 甲子 isn't in this chart's pillars, 大運, 流年 or 流月. It is 2044 (2040 mod 10 = 0 → 甲,
    // mod 12 = 0 → 子), one of the dayun_years (v3.3.0), which the check leaves out on purpose.
    expect((bazi.facts as any).dayun_years.map((y: any) => y.ganzhi)).toContain("甲子");
    expect(kinds).toContain("unknown_ganzhi");
    expect(kinds).toContain("wrong_year_ganzhi"); // 2027 is 丁未
  });

  it("flags 今年/明年/去年 paired with the wrong year's 干支 (report dated 2026)", async () => {
    // FIXED_NOW is in 2026: 去年 2025 乙巳, 今年 2026 丙午, 明年 2027 丁未.
    const wrong = await reportWith(bazi, ["明年的流年（每年輪到的干支）是丙午，會讓你想動。"]);
    const issues = checkFaithfulness(bazi, wrong).filter((i) => i.kind === "wrong_relative_year");
    expect(issues.map((i) => i.detail)).toEqual(["明年 is 2027 丁未, not 丙午"]);
    const right = await reportWith(bazi, ["今年丙午火旺；明年丁未，去年乙巳。"]);
    expect(checkFaithfulness(bazi, right).filter((i) => i.kind === "wrong_relative_year")).toEqual(
      [],
    );
  });

  it("flags tarot cards not in the spread and wrong 正位/逆位", async () => {
    const { DECK } = await import("../src/engines/tarot/deck.js");
    const name = (id: string) => DECK.find((d) => d.id === id)!.name["zh-Hant"];
    const first = cards[0]!;
    const missing = DECK.find((d) => !cards.some((c) => c.card_id === d.id))!.name["zh-Hant"];
    const wrongSide = first.reversed ? "正位" : "逆位";
    const r = await reportWith(tarot, [
      `${name(first.card_id)}（${wrongSide}）提醒你，另見${missing}。`,
    ]);
    const kinds = checkFaithfulness(tarot, r).map((i) => i.kind);
    expect(kinds).toContain("wrong_orientation");
    expect(kinds).toContain("card_not_in_spread");
  });

  it("knows the deck's earlier names, and 「寶劍一樣」 is no card", async () => {
    const { DECK, NAME_ALIASES } = await import("../src/engines/tarot/deck.js");
    const drawn = (id: string) => cards.some((c) => c.card_id === id);
    // A major arcana card with an earlier name (愚者, 女皇) and an ace, neither drawn here.
    const [, earlier] = Object.entries(NAME_ALIASES).find(
      ([id]) => id.startsWith("major") && !drawn(id),
    )!;
    const ace = DECK.find((d) => d.arcana === "minor" && d.rank === 1 && !drawn(d.id))!.name[
      "zh-Hant"
    ]; // e.g. 寶劍一
    const r = await reportWith(tarot, [
      `另見${earlier[0]}。`,
      `像${ace}樣銳利地思考。`, // 寶劍 + 一樣 ("like a sword")
      `${ace}（逆位）也值得一看。`,
    ]);
    const details = checkFaithfulness(tarot, r)
      .filter((i) => i.kind === "card_not_in_spread")
      .map((i) => i.detail);
    expect(details).toEqual([
      `${earlier[0]} is not in this spread`,
      `${ace} is not in this spread`,
    ]);
  });
});
