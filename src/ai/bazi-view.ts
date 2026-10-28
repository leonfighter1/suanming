/**
 * What a 八字 agent reads (tech plan WP2.3): every natal fact, every 大运 and 流年 by name, and
 * a period's full detail (its relations, 神煞 and score basis) only for the periods in focus.
 * Arrays keep their length and order, so a cited path such as /liunian/3 names the same year as
 * in the stored chart. 流月 and the years of each 大运 (dayun_years, v3.3.0) are left out: no
 * 八字 prompt reads them.
 */
import type { TrendLayer } from "./trend.js";
import type { Topic } from "./types.js";

export interface Focus {
  /** 流年 years shown in full. */
  years: number[];
  /** 大运 cycle indices shown in full. */
  cycles: number[];
}

type Entry = Record<string, unknown>;
type Cycle = Entry & { index: number; start_year: number };
type Year = Entry & { year: number };
interface Periods {
  dayun?: Entry & { cycles: Cycle[] };
  liunian?: Year[];
  trend?: Entry & { dayun: (Entry & { index: number })[]; liunian: Year[] };
}

/** What only a period in focus carries. */
const DETAIL = new Set(["relations", "shensha", "branch_relations"]);
const without = <T extends Entry>(e: T, keys: Set<string>) =>
  Object.fromEntries(Object.entries(e).filter(([k]) => !keys.has(k))) as T;
const BASIS = new Set(["basis"]);

const VIEW_NOTE =
  "Only the periods in focus carry relations, shensha and branch_relations (and a trend basis where trend is given). Every other 大运 and 流年 keeps only its 干支, years, ages and, for a 流年, its 十神: say nothing about its relations or 神煞.";

/**
 * The facts a 八字 agent reads, from modelFacts(chart). `trend: false` leaves the scores out (a
 * plan gets its topic's scores in <trend> instead).
 */
export function baziView(
  facts: Record<string, unknown>,
  focus: Focus,
  opts: { trend: boolean },
): Record<string, unknown> {
  const {
    liuyue: _months,
    dayun_years: _decades,
    trend,
    dayun,
    liunian,
    ...natal
  } = facts as Entry & Periods;
  return {
    ...natal,
    ...(dayun && {
      dayun: {
        ...dayun,
        cycles: dayun.cycles.map((c) => (focus.cycles.includes(c.index) ? c : without(c, DETAIL))),
      },
    }),
    ...(liunian && {
      liunian: liunian.map((y) => (focus.years.includes(y.year) ? y : without(y, DETAIL))),
    }),
    ...(opts.trend &&
      trend && {
        trend: {
          ...trend,
          dayun: trend.dayun.map((d) => (focus.cycles.includes(d.index) ? d : without(d, BASIS))),
          liunian: trend.liunian.map((y) => (focus.years.includes(y.year) ? y : without(y, BASIS))),
        },
      }),
    view: { focus_cycles: focus.cycles, focus_years: focus.years, note: VIEW_NOTE },
  };
}

/**
 * A reading's focus: the current 大运 and the next (the first two before the first one starts),
 * this year and the next two, and any 流年 year the question names.
 */
export function readingFocus(
  facts: Record<string, unknown>,
  nowYear: number,
  question?: string,
): Focus {
  const { dayun, liunian } = facts as Periods;
  const cycles = dayun?.cycles ?? [];
  const started = cycles.filter((c) => c.start_year <= nowYear).length;
  const first = Math.max(0, started - 1);
  const asked = [...(question ?? "").matchAll(/(?:19|20|21)\d{2}/g)].map((m) => Number(m[0]));
  return {
    cycles: cycles.slice(first, first + 2).map((c) => c.index),
    years: (liunian ?? [])
      .map((y) => y.year)
      .filter((y) => (y >= nowYear && y <= nowYear + 2) || asked.includes(y)),
  };
}

/**
 * A plan's focus: the two 大运 and the three 流年 where its topic scores lowest from now on
 * (the earlier period first on a tie), in time order.
 */
export function planFocus(trend: TrendLayer | undefined, topic: Topic, nowYear: number): Focus {
  if (!trend) return { years: [], cycles: [] };
  const lowest = <T>(xs: T[], score: (x: T) => number, n: number) =>
    [...xs].sort((a, b) => score(a) - score(b)).slice(0, n);
  const ahead = trend.dayun.filter((d) => d.start_year + 9 >= nowYear);
  const years = trend.liunian.filter((y) => y.year >= nowYear);
  return {
    cycles: lowest(ahead, (d) => d.scores[topic] ?? 50, 2)
      .map((d) => d.index)
      .sort((a, b) => a - b),
    years: lowest(years, (y) => y.scores[topic] ?? 50, 3)
      .map((y) => y.year)
      .sort((a, b) => a - b),
  };
}
