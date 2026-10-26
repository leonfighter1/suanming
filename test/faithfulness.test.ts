import { describe, expect, it } from "vitest";
import {
  checkFaithfulness,
  generateReport,
  MockProvider,
  type NarrativeOutput,
} from "../src/ai/index.js";
import { computeBazi } from "../src/engines/bazi/index.js";
import { computeTarot } from "../src/engines/tarot/index.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";

const bazi = computeBazi(
  {
    local: "1990-03-15T14:30",
    timezone: "Asia/Hong_Kong",
    longitude: 114.17,
    gender: "male",
    options: { liunianFrom: 2026 },
  },
  { digestPepper: PEPPER, now: FIXED_NOW },
);
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

async function reportWith(chart: typeof bazi, texts: string[], topic = "personality") {
  const narrative: NarrativeOutput = {
    sections: [
      {
        topic: topic as "personality",
        paragraphs: texts.map((text) => ({
          text,
          source_level: "traditional_text",
          fact_refs: [chart.system === "bazi" ? "/day_master" : "/cards/0"],
        })),
      },
    ],
  };
  // Run the real pipeline (mock model); stay clear of the rule layer by using neutral text.
  return generateReport(
    chart,
    { locale: "zh-Hant", country: "HK", topics: ["personality"] },
    {
      providers: { deepseek: new MockProvider({ narrative: [{ kind: "ok", data: narrative }] }) },
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

  it("flags 干支 not in the chart and wrong year 干支", async () => {
    const r = await reportWith(bazi, ["日柱甲子，2027年丙午。"]);
    const kinds = checkFaithfulness(bazi, r).map((i) => i.kind);
    expect(kinds).toContain("unknown_ganzhi"); // 甲子 isn't in this chart
    expect(kinds).toContain("wrong_year_ganzhi"); // 2027 is 丁未
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
});
