import { describe, expect, it } from "vitest";
import sweph from "sweph";
import {
  equationOfTimeMinutes,
  localToUtc,
  trueSolarMs,
  wallClockOf,
} from "../src/engines/bazi/time.js";

const iso = (ms: number) => new Date(ms).toISOString();

describe("localToUtc", () => {
  it("converts fixed-offset zones", () => {
    expect(iso(localToUtc("1990-03-15T14:30", "Asia/Hong_Kong").utcMs)).toBe(
      "1990-03-15T06:30:00.000Z",
    );
  });
  it("applies historical China DST (1986–1991)", () => {
    // 1988-06-01 Asia/Shanghai was UTC+9
    expect(iso(localToUtc("1988-06-01T12:00", "Asia/Shanghai").utcMs)).toBe(
      "1988-06-01T03:00:00.000Z",
    );
  });
  it("applies historical Hong Kong DST", () => {
    // 1975-06-01 Hong Kong was on summer time, UTC+9
    expect(iso(localToUtc("1975-06-01T12:00", "Asia/Hong_Kong").utcMs)).toBe(
      "1975-06-01T03:00:00.000Z",
    );
  });
  it("throws for times inside a DST gap", () => {
    expect(() => localToUtc("2021-03-14T02:30", "America/New_York")).toThrow(/DST gap/);
  });
  it("flags DST fold and picks the earlier instant", () => {
    const r = localToUtc("2021-11-07T01:30", "America/New_York");
    expect(r.ambiguity).toBe("ambiguous_earlier");
    expect(iso(r.utcMs)).toBe("2021-11-07T05:30:00.000Z");
  });
});

describe("equation of time", () => {
  it("matches Swiss Ephemeris within 0.1 min across 1900–2100", () => {
    let worst = 0;
    for (let y = 1900; y <= 2100; y += 7) {
      for (let m = 0; m < 12; m++) {
        const ms = Date.UTC(y, m, 1 + ((y + m) % 27), (y * 7 + m) % 24);
        const jd = ms / 86_400_000 + 2440587.5;
        const ref = sweph.time_equ(jd).data * 1440; // days → minutes
        worst = Math.max(worst, Math.abs(equationOfTimeMinutes(ms) - ref));
      }
    }
    expect(worst).toBeLessThan(0.1);
  });
});

describe("trueSolarMs", () => {
  it("Hong Kong (114.17°E) runs ~23 min behind UTC+8 civil time, before EoT", () => {
    const utc = Date.UTC(2024, 5, 13, 4, 0); // EoT ≈ 0 mid-June
    const w = wallClockOf(trueSolarMs(utc, 114.17).ms);
    expect(w.h).toBe(11);
    expect(w.mi).toBeGreaterThanOrEqual(36);
    expect(w.mi).toBeLessThanOrEqual(38);
  });
});
