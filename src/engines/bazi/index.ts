import lunar, { type EightChar } from "lunar-javascript";
import {
  inputDigest,
  SCHEMA_VERSION,
  type ChartFact,
  type Provenance,
} from "../../chart-fact/index.js";
import { natalRelations, periodRelations } from "./relations.js";
import { kongWang, liuyue, natalShensha, periodShensha, taiYuan } from "./shensha.js";
import {
  beijingMs,
  formatWallClock,
  localToUtc,
  parseLocal,
  trueSolarMs,
  wallClockOf,
  type CivilAmbiguity,
  type WallClock,
} from "./time.js";

const { Solar } = lunar;

export const BAZI_ENGINE_VERSION = "0.1.0+lunar-javascript.1.7.7";

export interface BaziInput {
  /** Civil wall-clock time at birthplace, YYYY-MM-DDTHH:mm[:ss] */
  local: string;
  /** IANA zone of birthplace, e.g. Asia/Hong_Kong */
  timezone: string;
  /** Degrees, east positive. Required for true solar time. */
  longitude: number;
  gender: "male" | "female";
  options?: {
    /** Default true. Product decision — see docs/poc/bazi.md */
    trueSolarTime?: boolean;
    /** 1: 晚子时日柱算明天; 2: 晚子时日柱算当天 (lunar-javascript sect). Default 2. */
    ziHourSect?: 1 | 2;
    /** First 流年 year listed. Default: the year of ctx.now(). */
    liunianFrom?: number;
    /**
     * How the user entered the birth moment. Doesn't change the computation;
     * it's recorded in facts.input_basis so the UI and the AI know the precision.
     */
    inputBasis?: InputBasis;
  };
}

export interface InputBasis {
  date: "gregorian" | "lunar";
  time: "exact" | "shichen";
  /** The 時辰 branch the user picked, when time = shichen. */
  shichen?: string;
}

type Normalized = Required<Omit<BaziInput, "options">> & {
  options: Required<Omit<NonNullable<BaziInput["options"]>, "liunianFrom" | "inputBasis">> & {
    liunianFrom?: number;
    inputBasis: InputBasis;
  };
};

const ZHI_ORDER = "子丑寅卯辰巳午未申酉戌亥";

function normalizeInputBasis(b: InputBasis | undefined): InputBasis {
  const date = b?.date === "lunar" ? "lunar" : "gregorian";
  if (b?.time !== "shichen") return { date, time: "exact" };
  if (!b.shichen || !ZHI_ORDER.includes(b.shichen) || b.shichen.length !== 1) {
    throw new Error("inputBasis.shichen must be one 地支 when time is shichen");
  }
  return { date, time: "shichen", shichen: b.shichen };
}

export const LIUNIAN_YEARS = 10;

export function normalizeBaziInput(input: BaziInput): Normalized {
  if (!(input.longitude >= -180 && input.longitude <= 180))
    throw new Error("longitude out of range");
  return {
    local: input.local.length === 16 ? `${input.local}:00` : input.local,
    timezone: input.timezone,
    longitude: Math.round(input.longitude * 1e4) / 1e4,
    gender: input.gender,
    options: {
      trueSolarTime: input.options?.trueSolarTime ?? true,
      ziHourSect: input.options?.ziHourSect ?? 2,
      ...(input.options?.liunianFrom !== undefined && {
        liunianFrom: input.options.liunianFrom,
      }),
      inputBasis: normalizeInputBasis(input.options?.inputBasis),
    },
  };
}

const GAN_WUXING: Record<string, string> = {
  甲: "木",
  乙: "木",
  丙: "火",
  丁: "火",
  戊: "土",
  己: "土",
  庚: "金",
  辛: "金",
  壬: "水",
  癸: "水",
};
const ZHI_MAIN_WUXING: Record<string, string> = {
  子: "水",
  丑: "土",
  寅: "木",
  卯: "木",
  辰: "土",
  巳: "火",
  午: "火",
  未: "土",
  申: "金",
  酉: "金",
  戌: "土",
  亥: "水",
};

function eightCharAt(w: WallClock, sect: 1 | 2): EightChar {
  const ec = Solar.fromYmdHms(w.y, w.m, w.d, w.h, w.mi, w.s).getLunar().getEightChar();
  ec.setSect(sect);
  return ec;
}

type PillarKey = "Year" | "Month" | "Day" | "Time";

function pillar(ec: EightChar, k: PillarKey) {
  const call = <T>(name: string): T =>
    (ec as unknown as Record<string, () => T>)[`get${k}${name}`]!.call(ec);
  return {
    gan: call<string>("Gan"),
    zhi: call<string>("Zhi"),
    hidden_gan: call<string[]>("HideGan"),
    shishen_gan: call<string>("ShiShenGan"),
    shishen_zhi: call<string[]>("ShiShenZhi"),
    dishi: call<string>("DiShi"),
    nayin: call<string>("NaYin"),
  };
}

export interface BaziContext {
  /** >= 32 bytes, from secrets manager */
  digestPepper: Buffer;
  now?: () => Date;
  /** Pins rule_versions.tzdb (default: Node's bundled tzdb). For reproducible fixtures. */
  tzdb?: string;
}

/**
 * Clock policy (the main precision decision in this engine):
 * - Year & month pillars and 大运 depend on the *instant* relative to 节气.
 *   lunar-javascript tabulates 节气 in UTC+8, so we feed it the UTC+8 wall
 *   clock of the birth instant. Feeding a non-UTC+8 local clock would shift
 *   month boundaries by the offset difference (up to 13 h for the Americas).
 * - Day & hour pillars depend on the local sun, so they use true solar time
 *   (or civil local time if disabled).
 * The day stem (from the local clock) is the 日主 for all 十神 / 十二长生, so
 * year/month 十神 are recomputed against it rather than taken from the UTC+8 chart.
 */
export function computeBazi(rawInput: BaziInput, ctx: BaziContext): ChartFact {
  const now = ctx.now?.() ?? new Date();
  const normalized = normalizeBaziInput(rawInput);
  // 流年 depend on the base year, so it is part of the input (and the digest).
  const input = {
    ...normalized,
    options: {
      ...normalized.options,
      liunianFrom: normalized.options.liunianFrom ?? now.getUTCFullYear(),
    },
  };
  const { utcMs, ambiguity } = localToUtc(input.local, input.timezone);

  const solar = trueSolarMs(utcMs, input.longitude);
  const civil = parseLocal(input.local);
  const civilMs = Date.UTC(civil.y, civil.m - 1, civil.d, civil.h, civil.mi, civil.s);
  const pillarMs = input.options.trueSolarTime ? solar.ms : civilMs;
  const pillarClock = wallClockOf(pillarMs);
  const jieqiClock = wallClockOf(beijingMs(utcMs));

  const sect = input.options.ziHourSect;
  const local = eightCharAt(pillarClock, sect);
  const instant = eightCharAt(jieqiClock, sect);

  const day = pillar(local, "Day");
  const hour = pillar(local, "Time");
  const year = rebaseOnDayMaster(pillar(instant, "Year"), day.gan);
  const month = rebaseOnDayMaster(pillar(instant, "Month"), day.gan);

  const counts: Record<string, number> = { 木: 0, 火: 0, 土: 0, 金: 0, 水: 0 };
  for (const p of [year, month, day, hour]) {
    counts[GAN_WUXING[p.gan]!]! += 1;
    counts[ZHI_MAIN_WUXING[p.zhi]!]! += 1;
  }

  const natal = { year, month, day, hour };
  const birthYear = Number(input.local.slice(0, 4));
  const yun = instant.getYun(input.gender === "male" ? 1 : 0, 2);
  const cycles = yun
    .getDaYun(9)
    .filter((d) => d.getIndex() > 0)
    .map((d) => ({
      index: d.getIndex(),
      ganzhi: d.getGanZhi(),
      start_year: d.getStartYear(),
      start_age: d.getStartAge(),
      // 虚岁 from the civil birth year, the count 流年 age_xu uses too (WP1.1).
      start_age_xu: d.getStartYear() - birthYear + 1,
      relations: periodRelations(natal, { place: "dayun", ganzhi: d.getGanZhi() }),
      shensha: periodShensha(natal, d.getGanZhi()[1]!),
    }));

  const liunian = Array.from({ length: LIUNIAN_YEARS }, (_, i) => {
    const y = input.options.liunianFrom + i;
    const gz = yearGanZhi(y);
    const [gan, zhi] = [gz[0]!, gz[1]!];
    const dy = [...cycles].reverse().find((c) => c.start_year <= y);
    return {
      year: y,
      ganzhi: gz,
      age: y - birthYear,
      age_xu: y - birthYear + 1,
      shishen_gan: tenGod(day.gan, gan),
      shishen_zhi: tenGod(day.gan, HIDDEN_MAIN[zhi]!),
      dayun_index: dy?.index ?? 0,
      branch_relations: branchRelations(zhi, natal),
      relations: periodRelations(natal, { place: "liunian", ganzhi: gz }, dy?.ganzhi),
      shensha: periodShensha(natal, zhi),
    };
  });

  const liuyueYear = input.options.liunianFrom;
  const months = liuyue(liuyueYear, yearGanZhi(liuyueYear)[0]!).map((m) => ({
    ...m,
    shishen_gan: tenGod(day.gan, m.ganzhi[0]!),
    shishen_zhi: tenGod(day.gan, HIDDEN_MAIN[m.ganzhi[1]!]!),
  }));

  const rule_versions = {
    tzdb: ctx.tzdb ?? process.versions.tz ?? "unknown",
    jieqi_clock: "utc+8",
  };
  const facts = {
    time_basis: {
      civil_local: input.local,
      utc: new Date(utcMs).toISOString(),
      civil_ambiguity: ambiguity satisfies CivilAmbiguity,
      true_solar_time_applied: input.options.trueSolarTime,
      ...(input.options.trueSolarTime && {
        equation_of_time_min: round(solar.eotMin, 2),
        longitude_correction_min: round(solar.longitudeCorrectionMin, 2),
      }),
      pillar_clock: formatWallClock(pillarClock),
      jieqi_clock: formatWallClock(jieqiClock),
      zi_hour_sect: sect,
    },
    pillars: natal,
    lunar: lunarDate(civil.y, civil.m, civil.d),
    // The 农历 of the day the pillars are read on (true solar day when applied), so the
    // 本命卦 takes its date and its hour from the same day (WP1.2).
    lunar_pillar_day: {
      ...lunarDate(pillarClock.y, pillarClock.m, pillarClock.d),
      basis: "pillar_clock_date" as const,
    },
    relations: natalRelations(natal),
    shensha: natalShensha(natal),
    kongwang: kongWang(natal),
    taiyuan: taiYuan(month),
    liuyue: { year: liuyueYear, clock: "utc+8", months },
    input_basis: {
      ...input.options.inputBasis,
      // A 時辰 picked by the clock can land in the neighbouring one after 真太陽時.
      ...(input.options.inputBasis.time === "shichen" && {
        shichen_after_correction: hour.zhi,
      }),
    },
    day_master: {
      gan: day.gan,
      wuxing: GAN_WUXING[day.gan]!,
      yin_yang: GANS.indexOf(day.gan) % 2 === 0 ? "阳" : "阴",
    },
    month_command: { zhi: month.zhi, wuxing: ZHI_MAIN_WUXING[month.zhi]! },
    wuxing_count: { method: "stems_and_branch_main_qi", counts },
    wuxing_weighted: {
      method: "stems_1_hidden_stems_by_qi",
      scores: weightedWuxing(natal),
    },
    dayun: {
      gender: input.gender,
      direction: yun.isForward() ? "forward" : "backward",
      start_offset: {
        years: yun.getStartYear(),
        months: yun.getStartMonth(),
        days: yun.getStartDay(),
        hours: yun.getStartHour(),
      },
      start_date: yun.getStartSolar().toYmd(),
      cycles,
    },
    liunian,
  };

  const provenance: Provenance[] = [
    { path: "/time_basis", source_level: "derived", note: "IANA tzdb + Meeus equation of time" },
    {
      path: "/pillars",
      source_level: "traditional_text",
      note: "立春换年、节令换月、日柱干支纪日",
    },
    {
      path: "/pillars/hour",
      source_level: "common_consensus",
      note: `子时流派: sect ${sect}${input.options.trueSolarTime ? "; 真太阳时" : "; 民用时"}`,
    },
    {
      path: "/wuxing_count",
      source_level: "simplified_rule",
      note: "天干+地支本气各计 1，不计藏干与月令旺衰",
    },
    {
      path: "/dayun",
      source_level: "traditional_text",
      note: "三日折一年，分钟级换算 (lunar-javascript sect 2)",
    },
    {
      path: "/input_basis",
      source_level: "derived",
      note: "用户输入方式：公历/农历日期，精确时间/时辰（时辰取中点；时柱只精确到两小时）",
    },
    {
      path: "/lunar",
      source_level: "derived",
      note: "农历按出生地民用日期换算（寿星天文历）；农历年以春节为界，八字年柱以立春为界",
    },
    { path: "/day_master", source_level: "traditional_text", note: "日干为日主" },
    { path: "/month_command", source_level: "traditional_text", note: "月支本气为月令" },
    {
      path: "/wuxing_weighted",
      source_level: "simplified_rule",
      note: "天干各 1；地支按藏干本气/中气/余气 0.6/0.3/0.1（两藏干 0.7/0.3）；未计月令加权、通根、合化",
    },
    {
      path: "/liunian",
      source_level: "traditional_text",
      note: "流年干支以立春为界；十神对日主；branch_relations 只含六冲、六合，relations 含全部合冲刑害破；age_xu 为虚岁",
    },
    {
      path: "/relations",
      source_level: "traditional_text",
      note: "天干五合、相冲；地支六合、六冲、三合、半合、三会、相刑、自刑、六害、相破",
    },
    {
      path: "/shensha",
      source_level: "traditional_text",
      note: "天乙贵人、文昌、禄神、羊刃（阳干）以日干查；桃花、驿马、华盖以年支、日支查",
    },
    { path: "/kongwang", source_level: "traditional_text", note: "旬空：日柱、年柱所在旬缺的两支" },
    { path: "/taiyuan", source_level: "traditional_text", note: "月干进一位，月支进三位" },
    {
      path: "/liuyue",
      source_level: "traditional_text",
      note: "流月以节令为界（立春至小寒，北京时间）；寅月天干按五虎遁",
    },
  ];

  return {
    schema_version: SCHEMA_VERSION,
    engine: { name: "bazi", version: BAZI_ENGINE_VERSION },
    system: "bazi",
    input_digest: inputDigest(
      { input, engine_version: BAZI_ENGINE_VERSION, rule_versions },
      ctx.digestPepper,
    ),
    rule_versions,
    computed_at: now.toISOString(),
    facts,
    provenance,
  };
}

/** Thrown for a 農曆 date that doesn't exist (e.g. a leap month the year lacks). */
export class CalendarInputError extends Error {}

/** The months of a 農曆 year, in order, including its leap month if any. */
export function lunarMonths(year: number) {
  const ms = (
    lunar as unknown as {
      LunarYear: {
        fromYear(y: number): {
          getMonthsInYear(): { getMonth(): number; getDayCount(): number; isLeap(): boolean }[];
        };
      };
    }
  ).LunarYear.fromYear(year).getMonthsInYear();
  return ms.map((m) => {
    const month = Math.abs(m.getMonth());
    const leap = m.isLeap();
    return { month, is_leap: leap, days: m.getDayCount(), name: lunarMonthName(month, leap) };
  });
}

const MONTH_ZH = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"];
const lunarMonthName = (m: number, leap: boolean) => `${leap ? "闰" : ""}${MONTH_ZH[m - 1]}月`;

/** 公曆 date of a 農曆 date. */
export function lunarToSolar(year: number, month: number, day: number, leap: boolean) {
  const info = lunarMonths(year).find((m) => m.month === month && m.is_leap === leap);
  if (!info)
    throw new CalendarInputError(`${year} has no ${leap ? "leap " : ""}lunar month ${month}`);
  if (!(day >= 1 && day <= info.days)) {
    throw new CalendarInputError(`lunar ${year}-${leap ? "L" : ""}${month} has ${info.days} days`);
  }
  const s = (
    lunar as unknown as {
      Lunar: { fromYmd(y: number, m: number, d: number): { getSolar(): { toYmd(): string } } };
    }
  ).Lunar.fromYmd(year, leap ? -month : month, day).getSolar();
  return s.toYmd();
}

/**
 * The 時辰 of a civil date with their 干支, for time pickers. 子時 straddles
 * midnight, so it is split: 早子 (00:00–00:59, this day's 子時) and 晚子
 * (23:00–23:59, the next day's 子時). `mid` is the time a pick resolves to.
 */
export function shichenOptions(y: number, m: number, d: number) {
  const zhi = "子丑寅卯辰巳午未申酉戌亥";
  const slots = [
    { key: "zi_early", zhi: "子", start: "00:00", end: "00:59", mid: [0, 30] },
    ...Array.from({ length: 11 }, (_, i) => {
      const h = 1 + i * 2; // 丑 01:00–02:59 … 亥 21:00–22:59
      const p = (n: number) => String(n).padStart(2, "0");
      return {
        key: zhi[i + 1]!,
        zhi: zhi[i + 1]!,
        start: `${p(h)}:00`,
        end: `${p(h + 1)}:59`,
        mid: [h + 1, 0],
      };
    }),
    { key: "zi_late", zhi: "子", start: "23:00", end: "23:59", mid: [23, 30] },
  ];
  return slots.map((s) => {
    const [h, mi] = s.mid as [number, number];
    const l = Solar.fromYmdHms(y, m, d, h, mi, 0).getLunar() as unknown as {
      getTimeInGanZhi(): string;
    };
    return {
      key: s.key,
      zhi: s.zhi,
      ganzhi: l.getTimeInGanZhi(),
      start: s.start,
      end: s.end,
      mid: `${String(h).padStart(2, "0")}:${String(mi).padStart(2, "0")}`,
    };
  });
}

/**
 * 農曆 date for a civil calendar date (the date people know as their 農曆生日).
 * Note the 農曆 year turns at 春節, while the 八字 year pillar turns at 立春.
 */
export function lunarDate(y: number, m: number, d: number) {
  const l = Solar.fromYmdHms(y, m, d, 12, 0, 0).getLunar() as unknown as {
    getYear(): number;
    getYearInGanZhi(): string;
    getYearShengXiao(): string;
    getMonth(): number;
    getMonthInChinese(): string;
    getDay(): number;
    getDayInChinese(): string;
  };
  const leap = l.getMonth() < 0;
  return {
    basis: "civil_local_date" as const,
    year: l.getYear(),
    year_ganzhi: l.getYearInGanZhi(),
    shengxiao: l.getYearShengXiao(),
    month: Math.abs(l.getMonth()),
    is_leap_month: leap,
    // lunar-javascript already prefixes 闰 for leap months
    month_name: `${l.getMonthInChinese()}月`,
    day: l.getDay(),
    day_name: l.getDayInChinese(),
  };
}

const JIAZI = Array.from(
  { length: 60 },
  (_, i) => "甲乙丙丁戊己庚辛壬癸"[i % 10]! + "子丑寅卯辰巳午未申酉戌亥"[i % 12]!,
);

/** 干支 of the 流年 that begins at 立春 of `year` (1984 = 甲子). */
export function yearGanZhi(year: number): string {
  return JIAZI[(((year - 1984) % 60) + 60) % 60]!;
}

/** 地支藏干, 本气 first — lunar-javascript's table, not a copy. */
const HIDDEN = lunar.LunarUtil.ZHI_HIDE_GAN as Record<string, string[]>;
const HIDDEN_MAIN = Object.fromEntries(Object.entries(HIDDEN).map(([z, g]) => [z, g[0]!]));
const QI_WEIGHTS: Record<number, number[]> = { 1: [1], 2: [0.7, 0.3], 3: [0.6, 0.3, 0.1] };

export function weightedWuxing(pillars: Record<string, { gan: string; zhi: string }>) {
  const s: Record<string, number> = { 木: 0, 火: 0, 土: 0, 金: 0, 水: 0 };
  for (const p of Object.values(pillars)) {
    s[GAN_WUXING[p.gan]!]! += 1;
    const hidden = HIDDEN[p.zhi]!;
    hidden.forEach((g, i) => (s[GAN_WUXING[g]!]! += QI_WEIGHTS[hidden.length]![i]!));
  }
  for (const k of Object.keys(s)) s[k] = round(s[k]!, 2);
  return s;
}

const CHONG = ["子午", "丑未", "寅申", "卯酉", "辰戌", "巳亥"];
const HE = ["子丑", "寅亥", "卯戌", "辰酉", "巳申", "午未"];

/** 六冲 / 六合 between a 流年 branch and each natal branch. */
export function branchRelations(zhi: string, pillars: Record<string, { zhi: string }>) {
  const out: { pillar: string; type: "六冲" | "六合" }[] = [];
  for (const [name, p] of Object.entries(pillars)) {
    const pair = (list: string[]) => list.some((x) => x === zhi + p.zhi || x === p.zhi + zhi);
    if (pair(CHONG)) out.push({ pillar: name, type: "六冲" });
    if (pair(HE)) out.push({ pillar: name, type: "六合" });
  }
  return out;
}

const TEN_GODS = ["比肩", "劫财", "食神", "伤官", "偏财", "正财", "七杀", "正官", "偏印", "正印"];
const GANS = "甲乙丙丁戊己庚辛壬癸";
const ZHANGSHENG = [
  "长生",
  "沐浴",
  "冠带",
  "临官",
  "帝旺",
  "衰",
  "病",
  "死",
  "墓",
  "绝",
  "胎",
  "养",
];
const ZHIS = "子丑寅卯辰巳午未申酉戌亥";
/** 长生 branch index per day stem (阳顺阴逆) */
const ZHANGSHENG_START: Record<string, number> = {
  甲: 11,
  乙: 6,
  丙: 2,
  丁: 9,
  戊: 2,
  己: 9,
  庚: 5,
  辛: 0,
  壬: 8,
  癸: 3,
};

export function tenGod(dayGan: string, other: string): string {
  const d = GANS.indexOf(dayGan);
  const o = GANS.indexOf(other);
  const rel = ((Math.floor(o / 2) - Math.floor(d / 2) + 5) % 5) * 2;
  return TEN_GODS[rel + (d % 2 === o % 2 ? 0 : 1)]!;
}

export function diShi(dayGan: string, zhi: string): string {
  const g = GANS.indexOf(dayGan);
  const z = ZHIS.indexOf(zhi);
  const start = ZHANGSHENG_START[dayGan]!;
  const step = g % 2 === 0 ? (z - start + 12) % 12 : (start - z + 12) % 12;
  return ZHANGSHENG[step]!;
}

function rebaseOnDayMaster(p: ReturnType<typeof pillar>, dayGan: string) {
  return {
    ...p,
    shishen_gan: tenGod(dayGan, p.gan),
    shishen_zhi: p.hidden_gan.map((g) => tenGod(dayGan, g)),
    dishi: diShi(dayGan, p.zhi),
  };
}

function round(x: number, dp: number) {
  const f = 10 ** dp;
  return Math.round(x * f) / f;
}
