import { describe, expect, it } from "vitest";
import { validateChartFact } from "../src/chart-fact/index.js";
import { computeAstrology } from "../src/engines/astrology/index.js";
import { FIXED_NOW, PEPPER } from "./helpers.js";

const ctx = { digestPepper: PEPPER, now: FIXED_NOW };

describe("AstrologyEngine (POC)", () => {
  const fact = computeAstrology(
    {
      local: "1990-03-15T14:30",
      timezone: "Asia/Hong_Kong",
      latitude: 22.3193,
      longitude: 114.1694,
    },
    ctx,
  );
  const facts = fact.facts as { bodies: { body: string; sign: string; longitude: number }[] };

  it("validates against ChartFact schema", () => {
    expect(validateChartFact(fact)).toEqual({ ok: true });
  });

  it("resolves the birthplace time zone (Sun ≈ 354.41° at 06:30 UTC, not 354.75° at 14:30 UTC)", () => {
    const sun = facts.bodies.find((b) => b.body === "sun")!;
    expect(sun.sign).toBe("pisces");
    expect(Math.abs(sun.longitude - 354.4115)).toBeLessThan(0.01);
  });

  it("returns ten bodies", () => {
    expect(facts.bodies).toHaveLength(10);
  });
});
