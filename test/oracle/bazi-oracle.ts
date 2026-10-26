/**
 * Independent 八字 calculator used only for verification. It shares no code or
 * data with lunar-javascript:
 * - 節 instants and the sun's position from Swiss Ephemeris (Moshier);
 * - 日柱 from the Julian Day Number, anchored on two well-known dates
 *   (1900-01-01 = 甲戌, 2000-01-01 = 戊午 — consistent with each other);
 * - month and hour stems from 五虎遁 / 五鼠遁;
 * - 真太陽時 from Swiss Ephemeris' equation of time.
 * Civil time → UTC still uses the platform tzdb (the engine does too), so DST
 * handling is not independently checked here.
 */
import sweph from "sweph";
import { localToUtc } from "../../src/engines/bazi/time.js";

const C = sweph.constants;
const GAN = "甲乙丙丁戊己庚辛壬癸";
const ZHI = "子丑寅卯辰巳午未申酉戌亥";
const gz = (i: number) => GAN[(((i % 60) + 60) % 60) % 10]! + ZHI[(((i % 60) + 60) % 60) % 12]!;
const MIN = 60_000;

/** Days since 1900-01-01 for a civil date, without time zones. */
function dayNumber(y: number, m: number, d: number) {
  return Math.round((Date.UTC(y, m - 1, d) - Date.UTC(1900, 0, 1)) / 86_400_000);
}
/** 1900-01-01 was 甲戌 (index 10). */
export const dayGanZhi = (y: number, m: number, d: number) => gz(10 + dayNumber(y, m, d));

const jdOf = (utcMs: number) => utcMs / 86_400_000 + 2440587.5;
const msOf = (jd: number) => (jd - 2440587.5) * 86_400_000;

function sunLongitude(utcMs: number): number {
  return sweph.calc_ut(jdOf(utcMs), C.SE_SUN, C.SEFLG_MOSEPH).data[0];
}

/** Next instant (UTC ms) after `utcMs` when the sun reaches longitude `lon`. */
function nextCrossing(lon: number, utcMs: number): number {
  return msOf(sweph.solcross_ut(lon, jdOf(utcMs), C.SEFLG_MOSEPH).date);
}

/** Last 節 (multiple of 30° from 315°) before `utcMs`, and the next one after it. */
function surroundingJie(utcMs: number) {
  const lambda = sunLongitude(utcMs);
  const k = Math.floor(((((lambda - 315) % 360) + 360) % 360) / 30); // 0 = 寅 month (立春)
  const prevLon = (315 + 30 * k) % 360;
  const nextLon = (prevLon + 30) % 360;
  // Search the previous crossing from ~40 days back; the next from now.
  const prev = nextCrossing(prevLon, utcMs - 40 * 86_400_000);
  return { k, prev, next: nextCrossing(nextLon, utcMs) };
}

export interface OracleInput {
  local: string;
  timezone: string;
  longitude: number;
  gender: "male" | "female";
  trueSolarTime: boolean;
  ziHourSect: 1 | 2;
}

export function oracleBazi(i: OracleInput) {
  const { utcMs } = localToUtc(i.local, i.timezone);

  // Year: 立春 (315°) of the Gregorian year of the instant.
  const y = new Date(utcMs).getUTCFullYear();
  const lichun = nextCrossing(315, Date.UTC(y, 0, 1));
  const baziYear = utcMs >= lichun ? y : y - 1;
  const yearIdx = baziYear - 1984; // 1984 = 甲子
  const yearPillar = gz(yearIdx);

  // Month: branch from the sun's longitude; stem by 五虎遁 (寅月 stem from the year stem).
  const { k, prev, next } = surroundingJie(utcMs);
  const yearStem = ((yearIdx % 10) + 10) % 10;
  const yinStem = [2, 4, 6, 8, 0][yearStem % 5]!; // 甲己→丙, 乙庚→戊, 丙辛→庚, 丁壬→壬, 戊癸→甲
  const monthPillar = GAN[(yinStem + k) % 10]! + ZHI[(2 + k) % 12]!;

  // Day and hour: from the local (true solar or civil) clock.
  let clockMs: number;
  if (i.trueSolarTime) {
    const eotMin = sweph.time_equ(jdOf(utcMs)).data * 1440;
    clockMs = utcMs + (i.longitude * 4 + eotMin) * MIN;
  } else {
    const [d, t] = i.local.split("T") as [string, string];
    const [yy, mm, dd] = d.split("-").map(Number) as [number, number, number];
    const [hh, mi] = t.split(":").map(Number) as [number, number];
    clockMs = Date.UTC(yy, mm - 1, dd, hh, mi);
  }
  const c = new Date(Math.round(clockMs / 1000) * 1000);
  const [cy, cm, cd, ch] = [
    c.getUTCFullYear(),
    c.getUTCMonth() + 1,
    c.getUTCDate(),
    c.getUTCHours(),
  ];
  const lateZi = ch === 23;
  const nextDay = new Date(Date.UTC(cy, cm - 1, cd + 1));
  const sameDay = dayGanZhi(cy, cm, cd);
  const followingDay = dayGanZhi(
    nextDay.getUTCFullYear(),
    nextDay.getUTCMonth() + 1,
    nextDay.getUTCDate(),
  );
  // sect 1: day changes at 23:00; sect 2: at 00:00. The late-子 hour stem always uses the next day.
  const dayPillar = lateZi && i.ziHourSect === 1 ? followingDay : sameDay;
  const hourBranch = Math.floor((ch + 1) / 2) % 12;
  const stemDay = GAN.indexOf((lateZi ? followingDay : sameDay)[0]!);
  const ziStem = [0, 2, 4, 6, 8][stemDay % 5]!; // 甲己→甲子, 乙庚→丙子, 丙辛→戊子, 丁壬→庚子, 戊癸→壬子
  const hourPillar = GAN[(ziStem + hourBranch) % 10]! + ZHI[hourBranch]!;

  // 大運: direction by year stem polarity and gender; start = minutes to the 節 / 4320 per year.
  const yang = yearStem % 2 === 0;
  const forward = (yang && i.gender === "male") || (!yang && i.gender === "female");
  const minutes = Math.floor((forward ? next - utcMs : utcMs - prev) / MIN);

  return {
    pillars: [yearPillar, monthPillar, dayPillar, hourPillar] as const,
    dayun: { forward, startYears: Math.floor(minutes / 4320), startMinutes: minutes },
    /** Minutes from the birth instant to the nearest 節 (or 立春) — boundary proximity. */
    minutesToJie:
      Math.min(Math.abs(utcMs - prev), Math.abs(next - utcMs), Math.abs(utcMs - lichun)) / MIN,
    /** Minutes from the local clock to the nearest 時辰 boundary (odd hours). */
    minutesToHourBoundary: (() => {
      const m = c.getUTCMinutes() + c.getUTCSeconds() / 60;
      const sinceOdd = ((ch % 2 === 1 ? 0 : 60) + m) % 120;
      return Math.min(sinceOdd, 120 - sinceOdd);
    })(),
  };
}
