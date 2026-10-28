// WP3.6 (docs/tech-plan.md): 洗牌 → 切牌 → 选牌. The engine shuffles the whole deck from the
// draw id; the user cuts it and picks places; the draw replays from the audit.
import { describe, expect, it } from "vitest";
import { validateChartFact } from "../src/chart-fact/index.js";
import { DECK } from "../src/engines/tarot/deck.js";
import {
  computeTarot,
  deriveSeed,
  drawWithRitual,
  drawWithSeed,
  ritualProblem,
  verifyDraw,
} from "../src/engines/tarot/index.js";
import { computeChart, InputError } from "../src/service/charts.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";

const ctx = (id: string) => ({
  drawKey: DRAW_KEY,
  digestPepper: PEPPER,
  now: FIXED_NOW,
  newDrawId: () => id,
});
const ID = "00000000-0000-4000-8000-0000000000aa";
const seed = deriveSeed(DRAW_KEY, ID);

describe("the tarot ritual", () => {
  it("the cards are the ones lying at the picked places of the cut deck", () => {
    // Uncut, place p holds the shuffled deck's card p; cut at c, place p holds card (p + c) % 78.
    const uncut = drawWithRitual(seed, "single", { cut: 0, picks: [0] });
    const all = Array.from(
      { length: 78 },
      (_, p) => drawWithRitual(seed, "single", { cut: 0, picks: [p] })[0]!,
    );
    expect(new Set(all.map((c) => c.card_id)).size).toBe(78); // a full shuffle: every card once
    for (const cut of [1, 26, 52, 77]) {
      for (const p of [0, 5, 77]) {
        const got = drawWithRitual(seed, "single", { cut, picks: [p] })[0]!;
        expect(got.card_id, `cut ${cut} pick ${p}`).toBe(all[(p + cut) % 78]!.card_id);
        expect(got.reversed).toBe(all[(p + cut) % 78]!.reversed); // a card keeps its orientation
      }
    }
    expect(uncut[0]!.card_id).toBe(all[0]!.card_id);
    // Picks in the order made: a three-card spread's past, present and future.
    const three = drawWithRitual(seed, "three_card", { cut: 10, picks: [40, 3, 70] });
    expect(three.map((c) => c.card_id)).toEqual([50, 13, 2].map((i) => all[i]!.card_id));
    expect(three.map((c) => c.position_key)).toEqual(["past", "present", "future"]);
  });

  it("is kept in the audit, so the draw replays; a draw without it is the engine's as before", () => {
    const ritual = { cut: 26, picks: [7, 61, 0] };
    const fact = computeTarot({ spread: "three_card", ritual }, ctx(ID));
    expect(validateChartFact(fact).ok).toBe(true);
    const f = fact.facts as { cards: unknown[]; audit: { ritual?: unknown } };
    expect(f.audit.ritual).toEqual(ritual);
    expect(verifyDraw(fact, DRAW_KEY)).toBe(true);
    // Tampering with the stored picks breaks the replay.
    const tampered = structuredClone(fact);
    (tampered.facts as { audit: { ritual: { picks: number[] } } }).audit.ritual.picks = [8, 61, 0];
    expect(verifyDraw(tampered, DRAW_KEY)).toBe(false);
    // No ritual: the engine's partial shuffle, as every draw before v3.0.0.
    const plain = computeTarot({ spread: "three_card" }, ctx(ID));
    expect((plain.facts as { cards: unknown[] }).cards).toEqual(drawWithSeed(seed, "three_card"));
    expect((plain.facts as { audit: object }).audit).not.toHaveProperty("ritual");
    expect(verifyDraw(plain, DRAW_KEY)).toBe(true);
  });

  it("refuses picks that don't fit the spread, and a bad cut", () => {
    expect(ritualProblem("three_card", { cut: 0, picks: [1, 2, 3] })).toBeNull();
    for (const bad of [
      { cut: 0, picks: [1, 2] }, // too few for three cards
      { cut: 0, picks: [1, 1, 2] }, // the same place twice
      { cut: 0, picks: [1, 2, 78] }, // past the deck
      { cut: 78, picks: [1, 2, 3] },
      { cut: -1, picks: [1, 2, 3] },
      { cut: 0.5, picks: [1, 2, 3] },
      null,
    ]) {
      expect(ritualProblem("three_card", bad), JSON.stringify(bad)).not.toBeNull();
      expect(() =>
        computeChart(
          { system: "tarot", spread: "three_card", ritual: bad },
          {
            digestPepper: PEPPER,
            drawKey: DRAW_KEY,
          },
        ),
      ).toThrow(InputError);
    }
    expect(DECK).toHaveLength(78);
  });
});
