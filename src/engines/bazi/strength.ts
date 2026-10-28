/**
 * 日主旺衰 + 喜用 (WP1.6, docs/tech-plan.md): a simplified 扶抑法 on the 100-point position
 * scheme. Points: 年干 8, 月干 12, 时干 12, 年支 4, 月支 40, 日支 12, 时支 12 (the day stem is
 * the 日主 itself). A branch's points are split over its hidden stems 0.6 / 0.3 / 0.1 (two
 * stems 0.7 / 0.3, one stem 1). Support = the points of the 日主's own element (比劫) and of
 * the element that generates it (印).
 * - support ≥ 55: 身强; ≤ 45: 身弱; between: 中和. ≥ 80 or ≤ 15: flagged as a possible
 *   专旺 / 从格 for a practitioner, and no 喜用 is set.
 * - 喜用 (扶抑): 身弱 → 印 and 比劫 favourable; 食伤, 财 and 官杀 unfavourable. 身强 → the
 *   reverse. 中和 → none set.
 * Not considered: 调候, 合化, the 从格 itself.
 */
import lunar from "lunar-javascript";

export type Element = "木" | "火" | "土" | "金" | "水";
type Natal = Record<"year" | "month" | "day" | "hour", { gan: string; zhi: string }>;

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
export const GENERATES: Record<Element, Element> = {
  木: "火",
  火: "土",
  土: "金",
  金: "水",
  水: "木",
};
export const CONTROLS: Record<Element, Element> = {
  木: "土",
  土: "水",
  水: "火",
  火: "金",
  金: "木",
};
const generatorOf = (e: Element) =>
  (Object.keys(GENERATES) as Element[]).find((k) => GENERATES[k] === e)!;
const controllerOf = (e: Element) =>
  (Object.keys(CONTROLS) as Element[]).find((k) => CONTROLS[k] === e)!;

/** 地支藏干, 本气 first: lunar-javascript's table, not a copy. */
export const hiddenStems = (zhi: string) =>
  (lunar.LunarUtil.ZHI_HIDE_GAN as Record<string, string[]>)[zhi]!;
/** How a branch's points split over its hidden stems. */
export const QI_SHARES: Record<number, number[]> = { 1: [1], 2: [0.7, 0.3], 3: [0.6, 0.3, 0.1] };

export const POINTS = {
  stems: { year: 8, month: 12, hour: 12 },
  branches: { year: 4, month: 40, day: 12, hour: 12 },
} as const;

const round1 = (x: number) => Math.round(x * 10) / 10;

export interface Strength {
  method: "fuyi_100";
  points: typeof POINTS;
  /** Points of each element over the eight characters bar the 日主 (sum 100). */
  by_element: Record<Element, number>;
  support: number;
  verdict: "身强" | "身弱" | "中和";
  /** The month branch's 本气 is the 日主's element or the one generating it. */
  de_ling: boolean;
  /** Pillars whose branch hides a stem of the 日主's element (its roots). */
  tong_gen: ("year" | "month" | "day" | "hour")[];
  favorable: Element[];
  unfavorable: Element[];
  special?: "专旺候选" | "从格候选";
}

export function strength(p: Natal): Strength {
  const dm = GAN_ELEMENT[p.day.gan]!;
  const supporters = new Set<Element>([dm, generatorOf(dm)]);
  const by: Record<Element, number> = { 木: 0, 火: 0, 土: 0, 金: 0, 水: 0 };
  for (const k of ["year", "month", "hour"] as const) by[GAN_ELEMENT[p[k].gan]!] += POINTS.stems[k];
  for (const k of ["year", "month", "day", "hour"] as const) {
    const hs = hiddenStems(p[k].zhi);
    hs.forEach((g, i) => (by[GAN_ELEMENT[g]!] += POINTS.branches[k] * QI_SHARES[hs.length]![i]!));
  }
  for (const e of Object.keys(by) as Element[]) by[e] = round1(by[e]);
  const support = round1(by[dm] + by[generatorOf(dm)]);

  const verdict = support >= 55 ? "身强" : support <= 45 ? "身弱" : "中和";
  const special = support >= 80 ? "专旺候选" : support <= 15 ? "从格候选" : undefined;
  const helps = [generatorOf(dm), dm];
  const drains = [GENERATES[dm], CONTROLS[dm], controllerOf(dm)];
  const [favorable, unfavorable] =
    special || verdict === "中和"
      ? [[], []]
      : verdict === "身弱"
        ? [helps, drains]
        : [drains, helps];

  return {
    method: "fuyi_100",
    points: POINTS,
    by_element: by,
    support,
    verdict,
    de_ling: supporters.has(GAN_ELEMENT[hiddenStems(p.month.zhi)[0]!]!),
    tong_gen: (["year", "month", "day", "hour"] as const).filter((k) =>
      hiddenStems(p[k].zhi).some((g) => GAN_ELEMENT[g] === dm),
    ),
    favorable,
    unfavorable,
    ...(special && { special }),
  };
}
