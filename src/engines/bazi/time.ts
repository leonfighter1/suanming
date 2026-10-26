/**
 * Civil-time ↔ UTC conversion and true solar time.
 *
 * Historical DST matters: e.g. Asia/Shanghai observed DST 1986–1991, Hong Kong
 * until 1979, Taiwan in the 1940s–70s. We rely on the IANA tzdb bundled with
 * Node's ICU; its version goes into ChartFact.rule_versions.tzdb.
 */

const MIN = 60_000;

export interface WallClock {
  y: number;
  m: number;
  d: number;
  h: number;
  mi: number;
  s: number;
}

export function parseLocal(local: string): WallClock {
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?$/.exec(local);
  if (!m) throw new Error(`invalid local datetime "${local}", expected YYYY-MM-DDTHH:mm[:ss]`);
  const [y, mo, d, h, mi, s] = m.slice(1).map((x) => (x === undefined ? 0 : Number(x))) as [
    number,
    number,
    number,
    number,
    number,
    number,
  ];
  return { y, m: mo, d, h, mi, s };
}

/** Wall clock of a UTC-epoch ms, read with UTC getters (i.e. the ms already carries the offset). */
export function wallClockOf(ms: number): WallClock {
  const t = new Date(ms);
  return {
    y: t.getUTCFullYear(),
    m: t.getUTCMonth() + 1,
    d: t.getUTCDate(),
    h: t.getUTCHours(),
    mi: t.getUTCMinutes(),
    s: t.getUTCSeconds(),
  };
}

export function formatWallClock(w: WallClock): string {
  const p = (n: number, l = 2) => String(n).padStart(l, "0");
  return `${p(w.y, 4)}-${p(w.m)}-${p(w.d)}T${p(w.h)}:${p(w.mi)}:${p(w.s)}`;
}

/** Offset (ms) of `tz` at the UTC instant `utcMs`. */
export function tzOffsetMs(tz: string, utcMs: number): number {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: tz,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  }).formatToParts(new Date(utcMs));
  const get = (type: string) => Number(parts.find((p) => p.type === type)?.value);
  const asUtc = Date.UTC(
    get("year"),
    get("month") - 1,
    get("day"),
    get("hour"),
    get("minute"),
    get("second"),
  );
  return asUtc - Math.floor(utcMs / 1000) * 1000;
}

export type CivilAmbiguity = "none" | "ambiguous_earlier";

/**
 * Resolve a civil local time in `tz` to a UTC instant.
 * - Nonexistent (DST gap) local times throw: the client must ask the user.
 * - Ambiguous (DST fold) local times resolve to the earlier instant and are flagged.
 */
export function localToUtc(
  local: string,
  tz: string,
): { utcMs: number; ambiguity: CivilAmbiguity } {
  const w = parseLocal(local);
  const naive = Date.UTC(w.y, w.m - 1, w.d, w.h, w.mi, w.s);
  // Candidate offsets: those in effect a day either side cover any single transition.
  const offsets = new Set([
    tzOffsetMs(tz, naive - 86_400_000),
    tzOffsetMs(tz, naive),
    tzOffsetMs(tz, naive + 86_400_000),
  ]);
  const hits = [...offsets]
    .map((off) => naive - off)
    .filter((utc) => tzOffsetMs(tz, utc) === naive - utc)
    .sort((a, b) => a - b);
  if (hits.length === 0) throw new Error(`local time ${local} does not exist in ${tz} (DST gap)`);
  return { utcMs: hits[0]!, ambiguity: hits.length > 1 ? "ambiguous_earlier" : "none" };
}

export function julianDayUt(utcMs: number): number {
  return utcMs / 86_400_000 + 2440587.5;
}

/**
 * Equation of time in minutes (apparent − mean solar time), Meeus eq. 28.3
 * with low-precision solar terms. Accuracy ~±3 s over 1900–2100, verified
 * against Swiss Ephemeris swe_time_equ in test/bazi-time.test.ts.
 */
export function equationOfTimeMinutes(utcMs: number): number {
  const rad = Math.PI / 180;
  const T = (julianDayUt(utcMs) - 2451545.0) / 36525;
  const L0 = (280.46646 + 36000.76983 * T + 0.0003032 * T * T) * rad;
  const M = (357.52911 + 35999.05029 * T - 0.0001537 * T * T) * rad;
  const e = 0.016708634 - 0.000042037 * T - 0.0000001267 * T * T;
  const eps = (23.439291 - 0.0130042 * T) * rad;
  const y = Math.tan(eps / 2) ** 2;
  const E =
    y * Math.sin(2 * L0) -
    2 * e * Math.sin(M) +
    4 * e * y * Math.sin(M) * Math.cos(2 * L0) -
    0.5 * y * y * Math.sin(4 * L0) -
    1.25 * e * e * Math.sin(2 * M);
  return (E / rad) * 4;
}

/**
 * True (apparent) solar time at `longitude` (east positive) as a ms value whose
 * UTC getters read the local apparent solar wall clock.
 */
export function trueSolarMs(utcMs: number, longitude: number) {
  const longitudeCorrectionMin = longitude * 4;
  const eotMin = equationOfTimeMinutes(utcMs);
  return {
    ms: Math.round(utcMs + (longitudeCorrectionMin + eotMin) * MIN),
    longitudeCorrectionMin,
    eotMin,
  };
}

/** UTC+8 wall clock of an instant — the clock lunar-javascript's 节气 table is expressed in. */
export function beijingMs(utcMs: number): number {
  return utcMs + 8 * 60 * MIN;
}
