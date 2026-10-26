import { describe, expect, it } from "vitest";
import { realDraw, tarotBattery, type DrawFn } from "./oracle/tarot-stats.js";

describe(
  "tarot statistical battery (fast subset; `npm run verify:tarot` runs 100 000 per spread)",
  { timeout: 60_000 },
  () => {
    it("the production draw passes every check on 20 000 draws per spread", () => {
      const r = tarotBattery(20_000);
      expect(r.checks.filter((c) => !c.pass).map((c) => c.name)).toEqual([]);
    });

    describe("is not vacuous: biased draws are caught", () => {
      const real = realDraw();
      const failing = (draw: DrawFn) =>
        tarotBattery(20_000, draw)
          .checks.filter((c) => !c.pass)
          .map((c) => c.name);

      it("never reversed", () => {
        const f = failing((id, s) => real(id, s).map((c) => ({ ...c, reversed: false })));
        expect(f.some((n) => n.includes("reversal rate"))).toBe(true);
      });

      it("first card slightly favours the Major Arcana (modulo-bias style)", () => {
        const biased: DrawFn = (id, s) => {
          const cards = real(id, s);
          // 1 draw in 25 swaps the first card for a fixed major card that isn't already in the spread.
          if (
            parseInt(id.slice(-4), 16) % 25 === 0 &&
            !cards.some((c) => c.card_id === "major_00")
          ) {
            cards[0] = { ...cards[0]!, card_id: "major_00" };
          }
          return cards;
        };
        expect(failing(biased).some((n) => n.includes("position 1 uniform"))).toBe(true);
      });

      it("a repeated card within a spread", () => {
        const dup: DrawFn = (id, s) => {
          const cards = real(id, s);
          if (cards.length > 1 && id.endsWith("7"))
            cards[1] = { ...cards[1]!, card_id: cards[0]!.card_id };
          return cards;
        };
        expect(failing(dup).some((n) => n.includes("no repeated card"))).toBe(true);
      });
    });
  },
);
