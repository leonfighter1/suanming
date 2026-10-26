import lunar, { type EightChar } from "lunar-javascript";
import {
  inputDigest,
  SCHEMA_VERSION,
  type ChartFact,
  type Provenance,
} from "../../chart-fact/index.js";
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
  };
}

type Normalized = Required<Omit<BaziInput, "options">> & {
  options: Required<Omit<NonNullable<BaziInput["options"]>, "liunianFrom">> & {
    liunianFrom?: number;
  };
};

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

  const yun = instant.getYun(input.gender === "male" ? 1 : 0, 2);
  const cycles = yun
    .getDaYun(9)
    .filter((d) => d.getIndex() > 0)
    .map((d) => ({
      index: d.getIndex(),
      ganzhi: d.getGanZhi(),
      start_year: d.getStartYear(),
      start_age: d.getStartAge(),
    }));

  const natal = { year, month, day, hour };
  const birthYear = Number(input.local.slice(0, 4));
  const liunian = Array.from({ length: LIUNIAN_YEARS }, (_, i) => {
    const y = input.options.liunianFrom + i;
    const gz = yearGanZhi(y);
    const [gan, zhi] = [gz[0]!, gz[1]!];
    const dy = [...cycles].reverse().find((c) => c.start_year <= y);
    return {
      year: y,
      ganzhi: gz,
      age: y - birthYear,
      shishen_gan: tenGod(day.gan, gan),
      shishen_zhi: tenGod(day.gan, HIDDEN_MAIN[zhi]!),
      dayun_index: dy?.index ?? 0,
      branch_relations: branchRelations(zhi, natal),
    };
  });

  const rule_versions = { tzdb: process.versions.tz ?? "unknown", jieqi_clock: "utc+8" };
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
      note: "流年干支以立春为界；十神对日主；地支与原局六冲、六合（不含刑害、三合）",
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
