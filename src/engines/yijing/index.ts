/**
 * 易经 / 梅花易数 / 八宅 facts for the 一生运势报告, computed from a 八字 ChartFact.
 * Deterministic: the AI only interprets what is here.
 *
 * - 本命卦 (先天数起卦, 梅花易数年月日时法): upper = (年支数 + 农历月 + 农历日) mod 8,
 *   lower = (+ 时支数) mod 8, 动爻 = same total mod 6 (0 → 8 / 6). 先天数 乾1 兑2 离3
 *   震4 巽5 坎6 艮7 坤8; 地支数 子1 … 亥12. Year branch = 农历年 (春节); hour branch =
 *   the 时柱 after 真太阳时. 闰月 counts as its month number.
 * - 六爻配年: 初爻 0–14 岁, then 15 years per line; 上爻 75 岁后.
 * - 梅花: 体卦 = the trigram without the moving line, 用卦 = with it; 用主早年,
 *   互卦主中年, 变卦主晚年; 五行生克 against 体, and 体's strength in the birth month
 *   (旺相休囚死).
 * - 八宅: 命卦 from the 干支 year (立春) and gender; stars by the 大游年 line flips.
 *
 * Lines are bottom (初爻) first, 1 = yang, matching data/yijing/hexagrams.json ids.
 */
import { readFileSync } from "node:fs";

type Names = { "zh-Hant": string; "zh-Hans": string; en: string };
type Element = "木" | "火" | "土" | "金" | "水";

export interface Trigram {
  /** Lines bottom first, e.g. 震 "100" */
  id: string;
  name: Names;
  image: Names;
  xiantian: number;
  wuxing: Element;
  /** 后天八卦方位 */
  direction: Names;
}

const t = (
  id: string,
  hant: string,
  hans: string,
  en: string,
  imgHant: string,
  imgHans: string,
  imgEn: string,
  xiantian: number,
  wuxing: Element,
  dir: [string, string, string],
): Trigram => ({
  id,
  name: { "zh-Hant": hant, "zh-Hans": hans, en },
  image: { "zh-Hant": imgHant, "zh-Hans": imgHans, en: imgEn },
  xiantian,
  wuxing,
  direction: { "zh-Hant": dir[0], "zh-Hans": dir[1], en: dir[2] },
});

export const TRIGRAMS: Trigram[] = [
  t("111", "乾", "乾", "Qian", "天", "天", "Heaven", 1, "金", ["西北", "西北", "northwest"]),
  t("110", "兌", "兑", "Dui", "澤", "泽", "Lake", 2, "金", ["西", "西", "west"]),
  t("101", "離", "离", "Li", "火", "火", "Fire", 3, "火", ["南", "南", "south"]),
  t("100", "震", "震", "Zhen", "雷", "雷", "Thunder", 4, "木", ["東", "东", "east"]),
  t("011", "巽", "巽", "Xun", "風", "风", "Wind", 5, "木", ["東南", "东南", "southeast"]),
  t("010", "坎", "坎", "Kan", "水", "水", "Water", 6, "水", ["北", "北", "north"]),
  t("001", "艮", "艮", "Gen", "山", "山", "Mountain", 7, "土", ["東北", "东北", "northeast"]),
  t("000", "坤", "坤", "Kun", "地", "地", "Earth", 8, "土", ["西南", "西南", "southwest"]),
];
const byId = (id: string) => TRIGRAMS.find((x) => x.id === id)!;
const byXiantian = (n: number) => TRIGRAMS.find((x) => x.xiantian === n)!;

const ZHI = "子丑寅卯辰巳午未申酉戌亥";
export const branchNumber = (zhi: string) => {
  const i = ZHI.indexOf(zhi);
  if (i < 0) throw new Error(`not a branch: ${zhi}`);
  return i + 1;
};
const mod = (n: number, m: number) => n % m || m;

// ---- hexagram texts ----

interface HexText {
  id: string;
  name: Record<"zh-Hant" | "zh-Hans", string>;
  gua_ci: Record<"zh-Hant" | "zh-Hans", string>;
  yao_ci: Record<"zh-Hant" | "zh-Hans", string>[];
  da_xiang: Record<"zh-Hant" | "zh-Hans", string>;
}
let texts: HexText[] | undefined;
function hexText(id: string): HexText {
  texts ??= (
    JSON.parse(
      readFileSync(new URL("../../../data/yijing/hexagrams.json", import.meta.url), "utf8"),
    ) as { hexagrams: HexText[] }
  ).hexagrams;
  return texts.find((h) => h.id === id)!;
}

export interface Hexagram {
  /** Six lines bottom first */
  id: string;
  upper: string;
  lower: string;
  /** 卦名, e.g. 无妄 */
  name: Record<"zh-Hant" | "zh-Hans", string>;
  /** 全名, e.g. 天雷无妄, 乾为天 */
  full_name: Record<"zh-Hant" | "zh-Hans", string>;
  gua_ci: Record<"zh-Hant" | "zh-Hans", string>;
  da_xiang: Record<"zh-Hant" | "zh-Hans", string>;
}

export function hexagram(lines: string): Hexagram {
  const lower = byId(lines.slice(0, 3));
  const upper = byId(lines.slice(3));
  const tx = hexText(lines);
  const full = (k: "zh-Hant" | "zh-Hans") =>
    upper === lower
      ? `${tx.name[k]}${k === "zh-Hant" ? "為" : "为"}${upper.image[k]}`
      : `${upper.image[k]}${lower.image[k]}${tx.name[k]}`;
  return {
    id: lines,
    upper: upper.id,
    lower: lower.id,
    name: tx.name,
    full_name: { "zh-Hant": full("zh-Hant"), "zh-Hans": full("zh-Hans") },
    gua_ci: tx.gua_ci,
    da_xiang: tx.da_xiang,
  };
}

const flip = (lines: string, i: number) =>
  lines.slice(0, i) + (lines[i] === "1" ? "0" : "1") + lines.slice(i + 1);

// ---- 本命卦 ----

export interface BenmingInput {
  /** 农历年的年支 */
  yearZhi: string;
  lunarMonth: number;
  lunarDay: number;
  /** 时柱地支 (after 真太阳时) */
  hourZhi: string;
}

const STAGES = [
  [0, 14],
  [15, 29],
  [30, 44],
  [45, 59],
  [60, 74],
  [75, null],
] as const;

export function benmingGua(input: BenmingInput) {
  const y = branchNumber(input.yearZhi);
  const h = branchNumber(input.hourZhi);
  const s1 = y + input.lunarMonth + input.lunarDay;
  const s2 = s1 + h;
  const upper = byXiantian(mod(s1, 8));
  const lower = byXiantian(mod(s2, 8));
  const moving = mod(s2, 6);
  const lines = lower.id + upper.id;
  const changedLines = flip(lines, moving - 1);
  const nuclearLines = lines.slice(1, 4) + lines.slice(2, 5);
  const tx = hexText(lines);
  return {
    method: "先天数起卦（年月日时）",
    steps: {
      year_branch: { zhi: input.yearZhi, number: y },
      lunar_month: input.lunarMonth,
      lunar_day: input.lunarDay,
      hour_branch: { zhi: input.hourZhi, number: h },
      upper_sum: s1,
      upper_remainder: s1 % 8,
      lower_sum: s2,
      lower_remainder: s2 % 8,
      moving_remainder: s2 % 6,
    },
    hexagram: hexagram(lines),
    moving_line: moving,
    changed: hexagram(changedLines),
    nuclear: hexagram(nuclearLines),
    /** 六爻配人生阶段 (初爻 → 上爻) */
    lines: STAGES.map(([from, to], i) => ({
      line: i + 1,
      yang: lines[i] === "1",
      moving: i + 1 === moving,
      age_from: from,
      age_to: to,
      text: tx.yao_ci[i]!,
    })),
  };
}

// ---- 梅花易数 体用 ----

const GENERATES: Record<Element, Element> = { 木: "火", 火: "土", 土: "金", 金: "水", 水: "木" };
const CONTROLS: Record<Element, Element> = { 木: "土", 土: "水", 水: "火", 火: "金", 金: "木" };

/** How `other` stands to 体: 比和, 生体 (other generates 体), 体生 (体 feeds other), 体克, 克体. */
export function relationToTi(ti: Element, other: Element) {
  if (ti === other) return "比和" as const;
  if (GENERATES[other] === ti) return "生体" as const;
  if (GENERATES[ti] === other) return "体生" as const;
  if (CONTROLS[ti] === other) return "体克" as const;
  return "克体" as const;
}

const SEASON: Record<string, Element> = {
  寅: "木",
  卯: "木",
  巳: "火",
  午: "火",
  申: "金",
  酉: "金",
  亥: "水",
  子: "水",
  辰: "土",
  戌: "土",
  丑: "土",
  未: "土",
};

/** 旺相休囚死 of `x` in a month whose ruling element is `w`. */
export function seasonalStrength(x: Element, w: Element) {
  if (x === w) return "旺" as const;
  if (GENERATES[w] === x) return "相" as const;
  if (GENERATES[x] === w) return "休" as const;
  if (CONTROLS[x] === w) return "囚" as const;
  return "死" as const;
}

export function meihua(b: ReturnType<typeof benmingGua>, monthZhi: string) {
  const movingInLower = b.moving_line <= 3;
  const ti = byId(movingInLower ? b.hexagram.upper : b.hexagram.lower);
  const yong = byId(movingInLower ? b.hexagram.lower : b.hexagram.upper);
  const bian = byId(movingInLower ? b.changed.lower : b.changed.upper);
  const hu = [byId(b.nuclear.upper), byId(b.nuclear.lower)];
  const rel = (x: Trigram) => ({
    trigram: x.id,
    wuxing: x.wuxing,
    relation: relationToTi(ti.wuxing, x.wuxing),
  });
  const season = SEASON[monthZhi]!;
  return {
    ti: { trigram: ti.id, wuxing: ti.wuxing },
    /** 早年 */
    yong: { ...rel(yong), stage: "早年" },
    /** 中年: both 互卦 trigrams */
    hu: { hexagram: b.nuclear.id, trigrams: hu.map(rel), stage: "中年" },
    /** 晚年: the changed trigram of the 变卦 */
    bian: { hexagram: b.changed.id, ...rel(bian), stage: "晚年" },
    season: {
      month_zhi: monthZhi,
      ruling: season,
      ti_strength: seasonalStrength(ti.wuxing, season),
    },
  };
}

// ---- 八宅 ----

/** 命卦 number (洛书): 1坎 2坤 3震 4巽 6乾 7兑 8艮 9离; 5 → 2 (male) / 8 (female). */
export function kuaNumber(year: number, gender: "male" | "female"): number {
  const r = gender === "male" ? (11 - (year % 9)) % 9 : ((year % 9) + 4) % 9;
  const k = r === 0 ? 9 : r;
  return k === 5 ? (gender === "male" ? 2 : 8) : k;
}

const LUOSHU: Record<number, string> = {
  1: "010",
  2: "000",
  3: "100",
  4: "011",
  6: "111",
  7: "110",
  8: "001",
  9: "101",
};

/** 大游年: from 伏位, flip 上 中 下 中 上 中 下 → 生气 五鬼 延年 六煞 祸害 天医 绝命. */
const YOUNIAN: [number, string][] = [
  [2, "生气"],
  [1, "五鬼"],
  [0, "延年"],
  [1, "六煞"],
  [2, "祸害"],
  [1, "天医"],
  [0, "绝命"],
];
export const STAR_RANK = ["生气", "天医", "延年", "伏位", "祸害", "六煞", "五鬼", "绝命"] as const;
const STAR_LUCK: Record<string, string> = {
  生气: "大吉",
  天医: "吉",
  延年: "吉",
  伏位: "小吉",
  祸害: "凶",
  六煞: "凶",
  五鬼: "凶",
  绝命: "大凶",
};

export function bazhai(year: number, gender: "male" | "female") {
  const kua = kuaNumber(year, gender);
  const self = LUOSHU[kua]!;
  const stars: Record<string, string> = { 伏位: self };
  let cur = self;
  for (const [i, star] of YOUNIAN) {
    cur = flip(cur, i);
    stars[star] = cur;
  }
  return {
    year,
    gender,
    kua,
    trigram: self,
    wuxing: byId(self).wuxing,
    group: [1, 3, 4, 9].includes(kua) ? ("东四命" as const) : ("西四命" as const),
    directions: STAR_RANK.map((star) => ({
      star,
      luck: STAR_LUCK[star]!,
      trigram: stars[star]!,
      direction: byId(stars[star]!).direction,
    })),
  };
}

// ---- from a 八字 ChartFact ----

type LunarForYijing = { year_ganzhi: string; month: number; day: number; is_leap_month: boolean };
interface BaziFactsForYijing {
  pillars: Record<"year" | "month" | "day" | "hour", { gan: string; zhi: string }>;
  lunar: LunarForYijing;
  /** The 农历 of the pillar day (charts since v1.3.0); older charts have only `lunar`. */
  lunar_pillar_day?: LunarForYijing;
  dayun: { gender: "male" | "female" };
  time_basis?: { civil_local: string };
}

/** The 干支 year (立春) of the year pillar, near the civil birth year. */
export function ganzhiYear(
  civilYear: number,
  yearPillar: string,
  yearGanZhi: (y: number) => string,
) {
  return yearGanZhi(civilYear) === yearPillar ? civilYear : civilYear - 1;
}

export function yijingFacts(
  f: BaziFactsForYijing,
  civilYear: number,
  yearGanZhi: (y: number) => string,
) {
  // Date and hour from the same day: the 时支 is read after 真太阳时, so is the 农历 day.
  const day = f.lunar_pillar_day ?? f.lunar;
  const b = benmingGua({
    yearZhi: day.year_ganzhi[1]!,
    lunarMonth: day.month,
    lunarDay: day.day,
    hourZhi: f.pillars.hour.zhi,
  });
  const year = ganzhiYear(civilYear, f.pillars.year.gan + f.pillars.year.zhi, yearGanZhi);
  return {
    benming: { ...b, leap_month_note: day.is_leap_month ? "闰月按本月数起卦" : undefined },
    meihua: meihua(b, f.pillars.month.zhi),
    bazhai: bazhai(year, f.dayun.gender),
    trigrams: Object.fromEntries(
      TRIGRAMS.map((x) => [
        x.id,
        { name: x.name, image: x.image, wuxing: x.wuxing, direction: x.direction },
      ]),
    ),
  };
}
