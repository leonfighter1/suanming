import { describe, expect, it } from "vitest";
import { throwOf } from "../src/engines/qiuqian/index.js";
import { qiuqianBattery, realQiuqianDraw, type QiuqianDrawFn } from "./oracle/qiuqian-stats.js";

describe(
  "求籤 statistical battery (fast subset; `npm run verify:qiuqian` runs 100 000 draws)",
  { timeout: 60_000 },
  () => {
    it("the production draw passes every check on 20 000 draws", () => {
      const r = qiuqianBattery(20_000);
      expect(r.checks.filter((c) => !c.pass).map((c) => c.name)).toEqual([]);
    });

    describe("is not vacuous: biased draws are caught", () => {
      const real = realQiuqianDraw();
      const failing = (draw: QiuqianDrawFn) =>
        qiuqianBattery(20_000, draw)
          .checks.filter((c) => !c.pass)
          .map((c) => c.name);

      it("the first block always lands flat", () => {
        // Then a round is 聖筊 only when the second lands round: still ½, but 陰筊 never comes.
        const biased: QiuqianDrawFn = (id) =>
          real(id).map((r) => {
            const blocks: typeof r.blocks = ["flat", r.blocks[1]];
            return { ...r, blocks, result: throwOf(blocks) };
          });
        const f = failing(biased);
        expect(f).toContain("each block lands flat half the time");
        expect(f).toContain("throws are 聖筊 ½, 笑筊 ¼, 陰筊 ¼");
      });

      it("one draw in 25 lands on lot 1", () => {
        const biased: QiuqianDrawFn = (id) => {
          const rs = real(id);
          if (parseInt(id.slice(-4), 16) % 25 === 0) rs[rs.length - 1] = { ...rs.at(-1)!, lot: 1 };
          return rs;
        };
        expect(failing(biased)).toContain("the confirmed lot is uniform over 100 lots");
      });

      it("the first throw always confirms", () => {
        const biased: QiuqianDrawFn = (id) => {
          const r = real(id).at(-1)!;
          return [r];
        };
        expect(failing(biased)).toContain("rounds per draw are geometric (½)");
      });
    });
  },
);
