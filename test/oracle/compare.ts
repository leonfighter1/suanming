/**
 * Differential test: BaziEngine (lunar-javascript based) vs the independent oracle.
 * Mismatches within ephemeris precision of a 節 or a 時辰 boundary are counted as
 * "boundary" (both answers defensible), everything else as "error".
 */
import sweph from "sweph";
import { computeBazi } from "../../src/engines/bazi/index.js";
import { oracleBazi, type OracleInput } from "./bazi-oracle.js";

export const ZONES: [string, number][] = [
  ["Asia/Hong_Kong", 114.17],
  ["Asia/Shanghai", 121.47],
  ["Asia/Shanghai", 87.62], // Urumqi on Beijing time: large true-solar offset
  ["Asia/Taipei", 121.56],
  ["Asia/Singapore", 103.82],
  ["America/New_York", -74.01],
  ["America/Vancouver", -123.12],
  ["Europe/London", -0.13],
  ["Australia/Sydney", 151.21],
];

/** Deterministic PRNG (mulberry32). */
export function rng(seed: number) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function localIn(tz: string, utcMs: number): string {
  return new Intl.DateTimeFormat("sv-SE", {
    timeZone: tz,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  })
    .format(new Date(utcMs))
    .replace(" ", "T");
}

export interface CaseResult {
  input: OracleInput;
  status: "match" | "boundary" | "error";
  diffs: string[];
}

const PEPPER = Buffer.alloc(32, 1);
const NOW = () => new Date("2026-01-01T00:00:00Z");

/**
 * Compare the oracle on `input` with the engine on `engineInput` (default: the
 * same input). Mutation tests pass a deliberately wrong `engineInput`.
 */
export function compareOne(input: OracleInput, engineInput: OracleInput = input): CaseResult {
  const o = oracleBazi(input);
  const e = engineInput;
  const f = computeBazi(
    {
      local: e.local,
      timezone: e.timezone,
      longitude: e.longitude,
      gender: e.gender,
      options: { trueSolarTime: e.trueSolarTime, ziHourSect: e.ziHourSect },
    },
    { digestPepper: PEPPER, now: NOW },
  ).facts as unknown as {
    pillars: Record<string, { gan: string; zhi: string }>;
    dayun: {
      direction: string;
      start_offset: { years: number; months: number; days: number; hours: number };
    };
  };
  const engine = ["year", "month", "day", "hour"].map((k) => f.pillars[k]!.gan + f.pillars[k]!.zhi);
  const so = f.dayun.start_offset;
  const engineMinutes = so.years * 4320 + so.months * 360 + so.days * 12 + so.hours / 2;

  const diffs: string[] = [];
  ["year", "month", "day", "hour"].forEach((k, i) => {
    if (engine[i] !== o.pillars[i])
      diffs.push(`${k}: engine ${engine[i]} vs oracle ${o.pillars[i]}`);
  });
  if ((f.dayun.direction === "forward") !== o.dayun.forward) diffs.push("dayun direction");
  if (Math.abs(engineMinutes - o.dayun.startMinutes) > 5) {
    diffs.push(`dayun start: engine ${engineMinutes} min vs oracle ${o.dayun.startMinutes} min`);
  }
  if (!diffs.length) return { input, status: "match", diffs };
  // Near a 節 (lunar-javascript is within ~2 min of Swiss Ephemeris) or a 時辰 edge.
  const nearJie = o.minutesToJie < 3;
  const nearHour = o.minutesToHourBoundary < 1;
  const explained = diffs.every((d) =>
    d.startsWith("year") || d.startsWith("month") || d.startsWith("dayun")
      ? nearJie
      : d.startsWith("hour") || d.startsWith("day")
        ? nearHour
        : false,
  );
  return { input, status: explained ? "boundary" : "error", diffs };
}

/** Random births 1901–2099 in all zones, both sects, true solar on/off. */
export function randomCases(n: number, seed: number): OracleInput[] {
  const r = rng(seed);
  const lo = Date.UTC(1901, 0, 1);
  const hi = Date.UTC(2099, 11, 31);
  return Array.from({ length: n }, () => {
    const [tz, lon] = ZONES[Math.floor(r() * ZONES.length)]!;
    return {
      local: localIn(tz, lo + Math.floor((r() * (hi - lo)) / 60_000) * 60_000),
      timezone: tz,
      longitude: lon,
      gender: r() < 0.5 ? "male" : "female",
      trueSolarTime: r() < 0.5,
      ziHourSect: r() < 0.5 ? 1 : 2,
    };
  });
}

/** Exact 節 instant (UTC ms) of solar longitude 315° + 30°·k in year y, from Swiss Ephemeris. */
function jieInstant(y: number, k: number): number {
  const jd = Date.UTC(y, 0, 1) / 86_400_000 + 2440587.5;
  const r = sweph.solcross_ut((315 + 30 * k) % 360, jd, sweph.constants.SEFLG_MOSEPH);
  return (r.date - 2440587.5) * 86_400_000;
}

/** Births within ±30 minutes of real 節 instants, and in the 23:00–01:00 window — where bugs hide. */
export function edgeCases(seed: number, perKind: number): OracleInput[] {
  const r = rng(seed);
  const out: OracleInput[] = [];
  for (let i = 0; i < perKind; i++) {
    const [tz, lon] = ZONES[i % ZONES.length]!;
    const t =
      jieInstant(1950 + Math.floor(r() * 100), Math.floor(r() * 12)) +
      Math.round((r() - 0.5) * 60) * 60_000;
    out.push({
      local: localIn(tz, t),
      timezone: tz,
      longitude: lon,
      gender: r() < 0.5 ? "male" : "female",
      trueSolarTime: r() < 0.5,
      ziHourSect: r() < 0.5 ? 1 : 2,
    });
    const day = Date.UTC(
      1950 + Math.floor(r() * 100),
      Math.floor(r() * 12),
      1 + Math.floor(r() * 28),
    );
    const local =
      new Date(day).toISOString().slice(0, 10) +
      `T${r() < 0.5 ? "23" : "00"}:${String(Math.floor(r() * 60)).padStart(2, "0")}`;
    out.push({
      local,
      timezone: tz,
      longitude: lon,
      gender: r() < 0.5 ? "male" : "female",
      trueSolarTime: false,
      ziHourSect: r() < 0.5 ? 1 : 2,
    });
  }
  return out;
}

export function summarize(results: CaseResult[]) {
  const count = (s: CaseResult["status"]) => results.filter((x) => x.status === s).length;
  return {
    total: results.length,
    match: count("match"),
    boundary: count("boundary"),
    error: count("error"),
  };
}
