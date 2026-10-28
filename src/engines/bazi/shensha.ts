/**
 * 神煞, 空亡, 胎元 and 流月 (WP1.4, docs/tech-plan.md). Fixed tables from their 歌诀; the
 * engine only lists which pillars and periods hold them, the AI interprets.
 *
 * - 天乙贵人 (day stem): 甲戊庚牛羊，乙己鼠猴乡，丙丁猪鸡位，壬癸兔蛇藏，六辛逢马虎.
 * - 文昌 (day stem): 甲乙巳午报君知，丙戊申宫丁己鸡，庚猪辛鼠壬逢虎，癸人见卯入云梯.
 * - 禄神 (day stem): 甲寅 乙卯 丙戊巳 丁己午 庚申 辛酉 壬亥 癸子.
 * - 羊刃 (阳干 only): 甲卯 丙戊午 庚酉 壬子.
 * - By the 三合 group of the year and of the day branch: 桃花 (咸池) 申子辰酉 寅午戌卯 巳酉丑午
 *   亥卯未子; 驿马 寅 申 亥 巳; 华盖 辰 戌 丑 未.
 * - 空亡: the two branches a 旬 leaves out (甲子旬 → 戌亥).
 * - 胎元: 月干进一位，月支进三位.
 * - 流月: the twelve 节令 months of a year, 寅月 stem by 五虎遁, from 立春 to 小寒 (UTC+8).
 */
import lunar from "lunar-javascript";

const GANS = "甲乙丙丁戊己庚辛壬癸";
const ZHIS = "子丑寅卯辰巳午未申酉戌亥";
type Natal = Record<"year" | "month" | "day" | "hour", { gan: string; zhi: string }>;
const PILLARS = ["year", "month", "day", "hour"] as const;

const TIAN_YI: Record<string, string> = {
  甲: "丑未",
  戊: "丑未",
  庚: "丑未",
  乙: "子申",
  己: "子申",
  丙: "亥酉",
  丁: "亥酉",
  壬: "卯巳",
  癸: "卯巳",
  辛: "午寅",
};
const WEN_CHANG: Record<string, string> = {
  甲: "巳",
  乙: "午",
  丙: "申",
  丁: "酉",
  戊: "申",
  己: "酉",
  庚: "亥",
  辛: "子",
  壬: "寅",
  癸: "卯",
};
const LU: Record<string, string> = {
  甲: "寅",
  乙: "卯",
  丙: "巳",
  丁: "午",
  戊: "巳",
  己: "午",
  庚: "申",
  辛: "酉",
  壬: "亥",
  癸: "子",
};
const YANG_REN: Record<string, string> = { 甲: "卯", 丙: "午", 戊: "午", 庚: "酉", 壬: "子" };
const GROUP_OF = (zhi: string) =>
  ["申子辰", "寅午戌", "巳酉丑", "亥卯未"].find((g) => g.includes(zhi))!;
const BY_GROUP: Record<"桃花" | "驿马" | "华盖", Record<string, string>> = {
  桃花: { 申子辰: "酉", 寅午戌: "卯", 巳酉丑: "午", 亥卯未: "子" },
  驿马: { 申子辰: "寅", 寅午戌: "申", 巳酉丑: "亥", 亥卯未: "巳" },
  华盖: { 申子辰: "辰", 寅午戌: "戌", 巳酉丑: "丑", 亥卯未: "未" },
};

export type ShenshaName = "天乙贵人" | "文昌" | "禄神" | "羊刃" | "桃花" | "驿马" | "华盖";
export interface Shensha {
  name: ShenshaName;
  /** What it is looked up from: the day stem, or the year / day branch. */
  basis: "day_gan" | "year_zhi" | "day_zhi";
  /** The branches that carry it. */
  targets: string;
  /** The natal pillars whose branch is one of them. */
  pillars: ("year" | "month" | "day" | "hour")[];
}

/** Every 神煞 rule for a chart, with its target branches. */
function rules(dayGan: string, yearZhi: string, dayZhi: string) {
  const out: Omit<Shensha, "pillars">[] = [
    { name: "天乙贵人", basis: "day_gan", targets: TIAN_YI[dayGan]! },
    { name: "文昌", basis: "day_gan", targets: WEN_CHANG[dayGan]! },
    { name: "禄神", basis: "day_gan", targets: LU[dayGan]! },
  ];
  if (YANG_REN[dayGan]) out.push({ name: "羊刃", basis: "day_gan", targets: YANG_REN[dayGan] });
  for (const [basis, zhi] of [
    ["year_zhi", yearZhi],
    ["day_zhi", dayZhi],
  ] as const) {
    for (const name of ["桃花", "驿马", "华盖"] as const)
      out.push({ name, basis, targets: BY_GROUP[name][GROUP_OF(zhi)]! });
  }
  return out;
}

/**
 * The 神煞 a natal chart holds. Day-stem ones look at all four branches; year- and
 * day-branch ones at the other three pillars.
 */
export function natalShensha(p: Natal): Shensha[] {
  return rules(p.day.gan, p.year.zhi, p.day.zhi).flatMap((r) => {
    const base = r.basis === "year_zhi" ? "year" : r.basis === "day_zhi" ? "day" : undefined;
    const pillars = PILLARS.filter((k) => k !== base && r.targets.includes(p[k].zhi));
    return pillars.length ? [{ ...r, pillars }] : [];
  });
}

/** The 神煞 a period's branch (a 大运 or 流年) brings to this chart. */
export function periodShensha(p: Natal, zhi: string): ShenshaName[] {
  const names = rules(p.day.gan, p.year.zhi, p.day.zhi)
    .filter((r) => r.targets.includes(zhi))
    .map((r) => r.name);
  return [...new Set(names)];
}

/** 旬空 of a 干支: the two branches its 旬 leaves out (甲子旬 → 戌亥). */
export function xunKong(ganzhi: string): string {
  const head = (ZHIS.indexOf(ganzhi[1]!) - GANS.indexOf(ganzhi[0]!) + 12) % 12; // the 甲 of the 旬
  return ZHIS[(head + 10) % 12]! + ZHIS[(head + 11) % 12]!;
}

/** 空亡 from the day and year pillars, and the natal pillars that fall in the day's. */
export function kongWang(p: Natal) {
  const byDay = xunKong(p.day.gan + p.day.zhi);
  return {
    by_day: byDay,
    by_year: xunKong(p.year.gan + p.year.zhi),
    pillars: PILLARS.filter((k) => k !== "day" && byDay.includes(p[k].zhi)),
  };
}

/** 胎元: 月干进一位，月支进三位. */
export function taiYuan(month: { gan: string; zhi: string }): string {
  return GANS[(GANS.indexOf(month.gan) + 1) % 10]! + ZHIS[(ZHIS.indexOf(month.zhi) + 3) % 12]!;
}

const JIE = [
  "立春",
  "惊蛰",
  "清明",
  "立夏",
  "芒种",
  "小暑",
  "立秋",
  "白露",
  "寒露",
  "立冬",
  "大雪",
];

/** The twelve months of 流年 `year`, from 立春: 干支 (五虎遁) and when each begins (UTC+8). */
export function liuyue(year: number, yearGan: string) {
  const table = (
    lunar as unknown as {
      Lunar: {
        fromYmd(
          y: number,
          m: number,
          d: number,
        ): { getJieQiTable(): Record<string, { toYmdHms(): string }> };
      };
    }
  ).Lunar.fromYmd(year, 6, 1).getJieQiTable();
  // 寅月 stem: 甲己 → 丙, 乙庚 → 戊, 丙辛 → 庚, 丁壬 → 壬, 戊癸 → 甲.
  const first = ((GANS.indexOf(yearGan) % 5) * 2 + 2) % 10;
  return [...JIE, "XIAO_HAN"].map((jie, i) => ({
    month: i + 1,
    ganzhi: GANS[(first + i) % 10]! + ZHIS[(2 + i) % 12]!,
    jie: jie === "XIAO_HAN" ? "小寒" : jie,
    starts: table[jie]!.toYmdHms().slice(0, 16),
  }));
}
