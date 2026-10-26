import { describe, expect, it } from "vitest";
import { validateChartFact } from "../src/chart-fact/index.js";
import { DECK, SPREADS, type SpreadId } from "../src/engines/tarot/deck.js";
import { HmacDrbg } from "../src/engines/tarot/drbg.js";
import { computeTarot, deriveSeed, drawWithSeed, verifyDraw } from "../src/engines/tarot/index.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";

const ctx = (id: string) => ({
  drawKey: DRAW_KEY,
  digestPepper: PEPPER,
  now: FIXED_NOW,
  newDrawId: () => id,
});
const uuid = (i: number) => `00000000-0000-4000-8000-${String(i).padStart(12, "0")}`;

/** Wilson–Hilferty approximation of the chi-square upper quantile. */
function chi2Critical(df: number, z: number) {
  const a = 2 / (9 * df);
  return df * (1 - a + z * Math.sqrt(a)) ** 3;
}
const Z_99 = 2.326;

describe("deck", () => {
  it("has 78 unique RWS cards with RWS numbering", () => {
    expect(DECK).toHaveLength(78);
    expect(new Set(DECK.map((c) => c.id)).size).toBe(78);
    expect(DECK.filter((c) => c.arcana === "major")).toHaveLength(22);
    expect(DECK.find((c) => c.id === "major_08")!.name.en).toBe("Strength");
    expect(DECK.find((c) => c.id === "major_11")!.name.en).toBe("Justice");
  });
});

describe("draw", () => {
  it("produces schema-valid ChartFact for every spread", () => {
    for (const spread of Object.keys(SPREADS) as SpreadId[]) {
      expect(validateChartFact(computeTarot({ spread }, ctx(uuid(1))))).toEqual({ ok: true });
    }
  });

  it("is reproducible from drawKey + draw_id and passes audit replay", () => {
    const a = computeTarot({ spread: "celtic_cross" }, ctx(uuid(42)));
    const b = computeTarot({ spread: "celtic_cross" }, ctx(uuid(42)));
    expect(a.facts).toEqual(b.facts);
    expect(verifyDraw(a, DRAW_KEY)).toBe(true);
    expect(verifyDraw(a, Buffer.alloc(32, 1))).toBe(false);
  });

  it("audit replay rejects tampered stored cards", () => {
    const a = computeTarot({ spread: "three_card" }, ctx(uuid(43)));
    const t = structuredClone(a);
    const cards = (t.facts as { cards: { reversed: boolean }[] }).cards;
    cards[0]!.reversed = !cards[0]!.reversed;
    expect(verifyDraw(t, DRAW_KEY)).toBe(false);
  });

  it("never repeats a card within a spread", () => {
    for (let i = 0; i < 200; i++) {
      const cards = drawWithSeed(deriveSeed(DRAW_KEY, uuid(i)), "celtic_cross");
      expect(new Set(cards.map((c) => c.card_id)).size).toBe(10);
    }
  });
});

describe("randomness (1000 three-card draws)", () => {
  const draws = Array.from({ length: 1000 }, (_, i) =>
    drawWithSeed(deriveSeed(DRAW_KEY, uuid(i)), "three_card"),
  );

  it.each([0, 1, 2])("position %i card distribution passes chi-square (α=0.01)", (pos) => {
    const counts = new Map<string, number>(DECK.map((c) => [c.id, 0]));
    for (const d of draws) counts.set(d[pos]!.card_id, counts.get(d[pos]!.card_id)! + 1);
    const expected = draws.length / 78;
    const chi2 = [...counts.values()].reduce((s, o) => s + (o - expected) ** 2 / expected, 0);
    expect(chi2).toBeLessThan(chi2Critical(77, Z_99));
  });

  it("reversal rate is ~0.5 (|z| < 3)", () => {
    const n = draws.length * 3;
    const rev = draws.flat().filter((c) => c.reversed).length;
    expect(Math.abs((rev - n / 2) / Math.sqrt(n / 4))).toBeLessThan(3);
  });
});

describe("HmacDrbg", () => {
  it("nextInt is unbiased for a non-power-of-two range", () => {
    const rng = new HmacDrbg(Buffer.alloc(32, 3));
    const n = 7;
    const N = 70_000;
    const counts = new Array<number>(n).fill(0);
    for (let i = 0; i < N; i++) counts[rng.nextInt(n)]!++;
    const chi2 = counts.reduce((s, o) => s + (o - N / n) ** 2 / (N / n), 0);
    expect(chi2).toBeLessThan(chi2Critical(n - 1, Z_99));
  });
});
