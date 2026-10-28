/**
 * 运势走势 from the engine (WP1.7, docs/tech-plan.md): every 大运 and 流年 scored per topic
 * from the chart facts, the same way every time.
 * - favour (−1…1): the period's elements (stem 1, plus its branch's hidden stems by share:
 *   2 in all) against strength.favorable (+1) and unfavorable (−1). With no 喜用 set (中和,
 *   or a possible 专旺 / 从格) the chart's weakest element counts +0.5, its strongest −0.5.
 * - relations (−0.6…0.3) the period forms: 六冲 −0.25 with the day branch, −0.15 with the
 *   month branch, −0.1 otherwise; 天干相冲 −0.15 with the 日主, −0.05 otherwise; 相刑 / 自刑
 *   −0.08; 六害 −0.05; 相破 −0.03; 六合 / 三合 / 半合 / 三会 +0.06 into a favourable element,
 *   −0.04 into an unfavourable one, +0.02 otherwise; 天干五合 +0.04.
 * - topics: personality = favour × emphasis(比劫, 印) + relations; career_wealth = favour ×
 *   emphasis(官杀, 财, 食伤) + relations; relationships = favour × emphasis(财, 官杀) +
 *   relations + the day branch's (spouse palace) relations again (六冲 −0.15, 合 +0.05,
 *   刑 / 害 −0.05), the same for every gender; health = favour × 0.5 + relations × 1.5;
 *   wuxing = favour × 0.4 + how the period evens out the five elements; dayun_liunian =
 *   favour + relations. emphasis = 1 + 0.25 × how many of the period's two 十神 (stem, branch
 *   本气) belong to those groups.
 * - score = clamp(round(50 + 35 × composite), 20, 85).
 */
import type { Relation } from "./relations.js";
import {
  CONTROLS,
  GENERATES,
  hiddenStems,
  QI_SHARES,
  type Element,
  type Strength,
} from "./strength.js";

export const TREND_TOPICS = [
  "wuxing",
  "personality",
  "career_wealth",
  "relationships",
  "dayun_liunian",
  "health",
] as const;
export type TrendTopic = (typeof TREND_TOPICS)[number];
export type Family = "比劫" | "食伤" | "财" | "官杀" | "印";

const GAN_ELEMENT: Record<string, Element> = {
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
const ELEMENTS: Element[] = ["木", "火", "土", "金", "水"];
const BRANCH_TYPES = new Set([
  "六合",
  "六冲",
  "三合",
  "半合",
  "三会",
  "相刑",
  "自刑",
  "六害",
  "相破",
]);
const HE_TYPES = new Set(["六合", "三合", "半合", "三会"]);

/** The 十神 group of an element to the 日主's. */
export function family(dm: Element, e: Element): Family {
  if (e === dm) return "比劫";
  if (GENERATES[dm] === e) return "食伤";
  if (CONTROLS[dm] === e) return "财";
  if (CONTROLS[e] === dm) return "官杀";
  return "印";
}

/** A period's elements: its stem 1, its branch's hidden stems by share. */
function elementsOf(ganzhi: string): Record<Element, number> {
  const v: Record<Element, number> = { 木: 0, 火: 0, 土: 0, 金: 0, 水: 0 };
  v[GAN_ELEMENT[ganzhi[0]!]!] += 1;
  const hs = hiddenStems(ganzhi[1]!);
  hs.forEach((g, i) => (v[GAN_ELEMENT[g]!] += QI_SHARES[hs.length]![i]!));
  return v;
}

function sd(xs: number[]) {
  const m = xs.reduce((a, b) => a + b, 0) / xs.length;
  return Math.sqrt(xs.reduce((a, b) => a + (b - m) ** 2, 0) / xs.length);
}

const clamp = (x: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, x));
const round2 = (x: number) => Math.round(x * 100) / 100;

export interface PeriodScore {
  scores: Record<TrendTopic, number>;
  /** What the scores rest on, for notes and readings. */
  basis: {
    favour: number;
    relations: number;
    families: [Family, Family];
    /** The first relation the period forms with the day branch, if any. */
    day_branch: string | null;
  };
}

export function scorePeriod(
  dayGan: string,
  s: Strength,
  ganzhi: string,
  relations: Relation[],
): PeriodScore {
  const dm = GAN_ELEMENT[dayGan]!;
  const v = elementsOf(ganzhi);
  const fav: Record<Element, number> = { 木: 0, 火: 0, 土: 0, 金: 0, 水: 0 };
  if (s.favorable.length) {
    for (const e of s.favorable) fav[e] = 1;
    for (const e of s.unfavorable) fav[e] = -1;
  } else {
    const ranked = [...ELEMENTS].sort((a, b) => s.by_element[a] - s.by_element[b]);
    fav[ranked[0]!] = 0.5;
    fav[ranked[4]!] = -0.5;
  }
  const favour = ELEMENTS.reduce((acc, e) => acc + v[e] * fav[e], 0) / 2;

  let rel = 0;
  let dayRel = 0;
  let dayBranch: string | null = null;
  for (const r of relations) {
    const onDay = r.members.some((m) => m.pillar === "day");
    const onMonth = r.members.some((m) => m.pillar === "month");
    const branchOnDay = onDay && BRANCH_TYPES.has(r.type);
    if (branchOnDay && dayBranch === null) dayBranch = r.type;
    if (r.type === "六冲") {
      rel -= onDay ? 0.25 : onMonth ? 0.15 : 0.1;
      if (branchOnDay) dayRel -= 0.15;
    } else if (r.type === "天干相冲") rel -= onDay ? 0.15 : 0.05;
    else if (r.type === "相刑" || r.type === "自刑") {
      rel -= 0.08;
      if (branchOnDay) dayRel -= 0.05;
    } else if (r.type === "六害") {
      rel -= 0.05;
      if (branchOnDay) dayRel -= 0.05;
    } else if (r.type === "相破") rel -= 0.03;
    else if (HE_TYPES.has(r.type)) {
      rel +=
        r.element && fav[r.element] > 0 ? 0.06 : r.element && fav[r.element] < 0 ? -0.04 : 0.02;
      if (branchOnDay) dayRel += 0.05;
    } else if (r.type === "天干五合") rel += 0.04;
  }
  rel = clamp(rel, -0.6, 0.3);

  const families: [Family, Family] = [
    family(dm, GAN_ELEMENT[ganzhi[0]!]!),
    family(dm, GAN_ELEMENT[hiddenStems(ganzhi[1]!)[0]!]!),
  ];
  const emphasis = (groups: Family[]) =>
    1 + 0.25 * families.filter((f) => groups.includes(f)).length;
  const before = ELEMENTS.map((e) => s.by_element[e]);
  const after = ELEMENTS.map((e) => s.by_element[e] + 10 * v[e]);
  const balance = clamp(((sd(before) - sd(after)) / sd(before)) * 2, -0.6, 0.6);

  const composite: Record<TrendTopic, number> = {
    wuxing: favour * 0.4 + balance,
    personality: favour * emphasis(["比劫", "印"]) + rel,
    career_wealth: favour * emphasis(["官杀", "财", "食伤"]) + rel,
    relationships: favour * emphasis(["财", "官杀"]) + rel + dayRel,
    dayun_liunian: favour + rel,
    health: favour * 0.5 + rel * 1.5,
  };
  const scores = Object.fromEntries(
    TREND_TOPICS.map((t) => [t, clamp(Math.round(50 + 35 * composite[t]), 20, 85)]),
  ) as Record<TrendTopic, number>;
  return {
    scores,
    basis: { favour: round2(favour), relations: round2(rel), families, day_branch: dayBranch },
  };
}

/** Scores for every 大运 and 流年 of a chart. */
export function trendScores(
  dayGan: string,
  s: Strength,
  periods: {
    dayun: { index: number; ganzhi: string; relations: Relation[] }[];
    liunian: { year: number; ganzhi: string; relations: Relation[] }[];
  },
) {
  const score = (gz: string, rs: Relation[]) => scorePeriod(dayGan, s, gz, rs);
  return {
    method: "engine_fuyi_v1" as const,
    dayun: periods.dayun.map((c) => ({ index: c.index, ...score(c.ganzhi, c.relations) })),
    liunian: periods.liunian.map((y) => ({ year: y.year, ...score(y.ganzhi, y.relations) })),
  };
}
