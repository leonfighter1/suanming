import { describe, expect, it } from "vitest";
import type { Face } from "../src/engines/liuyao/index.js";
import {
  liuyaoBattery,
  realLayout,
  realToss,
  type LayoutFn,
  type TossFn,
} from "./oracle/liuyao-stats.js";

describe(
  "算卦 statistical battery (fast subset; `npm run verify:liuyao` runs 100 000 casts)",
  { timeout: 60_000 },
  () => {
    it("the production coins pass every check on 20 000 casts", () => {
      const r = liuyaoBattery(20_000);
      expect(r.checks.filter((c) => !c.pass).map((c) => c.name)).toEqual([]);
    });

    describe("is not vacuous: biased coins are caught", () => {
      const toss = realToss();
      const layout = realLayout();
      const failing = (t: TossFn, l: LayoutFn = layout) =>
        liuyaoBattery(20_000, t, l)
          .checks.filter((c) => !c.pass)
          .map((c) => c.name);

      it("one coin in ten turns to 背", () => {
        const biased: TossFn = (id) =>
          toss(id).map((coins, i) =>
            coins.map((c, j): Face =>
              (i * 3 + j + parseInt(id.slice(-4), 16)) % 10 === 0 ? "bei" : c,
            ),
          );
        const f = failing(biased);
        expect(f).toContain("each coin falls 背 half the time");
        expect(f).toContain("lines are 老陰 1/8, 少陽 3/8, 少陰 3/8, 老陽 1/8");
      });

      it("the 上爻 always copies the 初爻", () => {
        const biased: TossFn = (id) => {
          const t = toss(id);
          t[5] = [...t[0]!];
          return t;
        };
        expect(failing(biased)).toContain("the 64 hexagrams are uniform");
      });

      it("the first laid-out coin is always 字", () => {
        const biased: LayoutFn = (id) => {
          const l = layout(id);
          l[0] = "zi";
          return l;
        };
        const f = failing(toss, biased);
        expect(f).toContain("a laid-out coin doesn't depend on its place");
        expect(f).toContain("a picked line is 1/8, 3/8, 3/8, 1/8");
      });
    });
  },
);
