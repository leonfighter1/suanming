import { describe, expect, it } from "vitest";
import { dayGanZhi } from "./oracle/bazi-oracle.js";
import { compareOne, edgeCases, randomCases, summarize } from "./oracle/compare.js";

describe("independent oracle", () => {
  it("day-pillar anchors agree with each other and with well-known dates", () => {
    expect(dayGanZhi(1900, 1, 1)).toBe("甲戌");
    expect(dayGanZhi(2000, 1, 1)).toBe("戊午");
    expect(dayGanZhi(1984, 2, 2)).toBe("丙寅"); // 春節 1984
  });
});

describe("BaziEngine vs independent oracle (fast subset; `npm run verify:bazi` runs 7000)", () => {
  it("300 random births 1901–2099: no unexplained mismatch", () => {
    const s = summarize(randomCases(300, 7).map((c) => compareOne(c)));
    expect(s.error).toBe(0);
  });

  it("200 edge cases (±30 min of real 節, 23:00–01:00): no unexplained mismatch", () => {
    const s = summarize(edgeCases(8, 100).map((c) => compareOne(c)));
    expect(s.error).toBe(0);
  });
});

describe("the comparison is not vacuous: deliberately wrong engine input is caught", () => {
  const cases = randomCases(200, 9);
  const errors = (mutate: (c: (typeof cases)[number]) => (typeof cases)[number]) =>
    cases.filter((c) => compareOne(c, mutate(c)).status === "error").length;

  it("time shifted by one hour → hour pillar mismatches", () => {
    const plusHour = (c: (typeof cases)[number]) => {
      const d = new Date(`${c.local}:00Z`);
      d.setUTCHours(d.getUTCHours() + 1);
      return { ...c, local: d.toISOString().slice(0, 16) };
    };
    expect(errors(plusHour)).toBeGreaterThan(80);
  });

  it("true solar time flipped → mismatches where the correction crosses a 時辰", () => {
    // Urumqi-like longitudes shift ~2 h, so a good share of cases must change.
    expect(errors((c) => ({ ...c, trueSolarTime: !c.trueSolarTime }))).toBeGreaterThan(20);
  });

  it("gender flipped → 大運 direction mismatches", () => {
    expect(errors((c) => ({ ...c, gender: c.gender === "male" ? "female" : "male" }))).toBe(200);
  });

  it("子時 school flipped → late-子 day pillars mismatch", () => {
    const late = edgeCases(10, 100).filter(
      (c) => !c.trueSolarTime && c.local.slice(11, 13) === "23",
    );
    expect(late.length).toBeGreaterThan(10);
    const wrong = late.filter(
      (c) => compareOne(c, { ...c, ziHourSect: c.ziHourSect === 1 ? 2 : 1 }).status === "error",
    );
    expect(wrong.length).toBe(late.length);
  });
});
