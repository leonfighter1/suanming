/**
 * Trend scores (八字 only): the "trend" agent rates every 大運 period and every
 * listed 流年 year per topic on 0–100, for the report's trend chart.
 *
 * The model gives only per-topic scores and a one-line note per period. Which
 * periods exist comes from the ChartFact; the combined score per period (mean of
 * the topics) and the total (mean of the 大運 combined scores) are computed here,
 * so they are reproducible and never model-invented.
 */
import type { ChartFact } from "../chart-fact/index.js";
import type { Locale } from "./terms.js";
import type { Topic } from "./types.js";

export interface TrendOutput {
  dayun: { index: number; scores: Record<string, number>; note: string }[];
  liunian: { year: number; scores: Record<string, number>; note: string }[];
}

interface TrendPoint {
  scores: Partial<Record<Topic, number>>;
  /** Mean of the topic scores, rounded */
  overall: number;
  note: string;
}

export interface TrendLayer {
  topics: Topic[];
  dayun: (TrendPoint & {
    index: number;
    ganzhi: string;
    start_year: number;
    start_age: number;
    end_age: number;
  })[];
  liunian: (TrendPoint & { year: number; age: number; ganzhi: string })[];
  /** Mean of the 大運 overall scores, rounded */
  total: number;
  method_note: string;
}

interface Periods {
  cycles: { index: number; ganzhi: string; start_year: number; start_age: number }[];
  years: { year: number; ganzhi: string; age: number }[];
}

function periodsOf(chart: ChartFact): Periods {
  const f = chart.facts as {
    dayun: { cycles: Periods["cycles"] };
    liunian: Periods["years"];
  };
  return { cycles: f.dayun.cycles, years: f.liunian };
}

/** What the mock provider and the prompt need: the periods to score. */
export function trendPayload(chart: ChartFact, topics: readonly Topic[]) {
  const p = periodsOf(chart);
  return {
    topics,
    dayun: p.cycles.map((c) => c.index),
    liunian: p.years.map((y) => y.year),
  };
}

export function trendSchema(topics: readonly Topic[]) {
  const scores = {
    type: "object",
    additionalProperties: false,
    required: [...topics],
    properties: Object.fromEntries(topics.map((t) => [t, { type: "integer" }])),
  };
  const point = (key: string) => ({
    type: "object",
    additionalProperties: false,
    required: [key, "scores", "note"],
    properties: { [key]: { type: "integer" }, scores, note: { type: "string" } },
  });
  return {
    type: "object",
    additionalProperties: false,
    required: ["dayun", "liunian"],
    properties: {
      dayun: { type: "array", items: point("index") },
      liunian: { type: "array", items: point("year") },
    },
  };
}

const clamp = (n: number) => Math.min(100, Math.max(0, Math.round(n)));

/** Keep only periods that exist in the chart; report gaps and out-of-range scores. */
export function checkTrend(
  chart: ChartFact,
  topics: readonly Topic[],
  data: TrendOutput,
): { value: TrendOutput; feedback: string[] } {
  const p = periodsOf(chart);
  const feedback: string[] = [];
  const fix = (s: Record<string, number>) => {
    if (Object.values(s).some((v) => v < 0 || v > 100)) feedback.push("scores must be 0–100");
    return Object.fromEntries(topics.map((t) => [t, clamp(s[t] ?? 50)]));
  };
  const indices = new Set(p.cycles.map((c) => c.index));
  const years = new Set(p.years.map((y) => y.year));
  const dayun = data.dayun
    .filter((d) => indices.has(d.index))
    .map((d) => ({ ...d, scores: fix(d.scores) }));
  const liunian = data.liunian
    .filter((y) => years.has(y.year))
    .map((y) => ({ ...y, scores: fix(y.scores) }));
  const missD = [...indices].filter((i) => !dayun.some((d) => d.index === i));
  const missY = [...years].filter((y) => !liunian.some((d) => d.year === y));
  if (missD.length) feedback.push(`missing dayun indices: ${missD.join(", ")}`);
  if (missY.length) feedback.push(`missing liunian years: ${missY.join(", ")}`);
  return { value: { dayun, liunian }, feedback: [...new Set(feedback)] };
}

const METHOD_NOTE: Record<Locale, string> = {
  "zh-Hant":
    "分數是 AI 依傳統命理（大運、流年與原局的十神、刑沖合會、五行平衡）給出的參考指數，0–100，50 為平穩；不是預測。「綜合」為所選項目的平均，「總分」為各大運綜合分的平均。",
  "zh-Hans":
    "分数是 AI 根据传统命理（大运、流年与原局的十神、刑冲合会、五行平衡）给出的参考指数，0–100，50 为平稳；不是预测。“综合”为所选项目的平均，“总分”为各大运综合分的平均。",
  en: "Scores are an AI reference index (0–100, 50 = steady) based on traditional readings of each luck pillar and year against the natal chart (Ten Gods, branch relations, element balance). They are not predictions. 'Combined' is the mean of the selected topics; 'total' is the mean of the luck-pillar combined scores.",
};

const mean = (xs: number[]) =>
  xs.length ? Math.round(xs.reduce((a, b) => a + b, 0) / xs.length) : 0;

export function trendLayer(
  chart: ChartFact,
  topics: readonly Topic[],
  out: TrendOutput,
  locale: Locale,
): TrendLayer {
  const p = periodsOf(chart);
  const point = (s: Record<string, number>, note: string): TrendPoint => ({
    scores: s as TrendPoint["scores"],
    overall: mean(topics.map((t) => s[t]!)),
    note,
  });
  const dayun = p.cycles.flatMap((c, i) => {
    const d = out.dayun.find((x) => x.index === c.index);
    if (!d) return [];
    const next = p.cycles[i + 1];
    return [
      {
        index: c.index,
        ganzhi: c.ganzhi,
        start_year: c.start_year,
        start_age: c.start_age,
        end_age: (next?.start_age ?? c.start_age + 10) - 1,
        ...point(d.scores, d.note),
      },
    ];
  });
  const liunian = p.years.flatMap((y) => {
    const d = out.liunian.find((x) => x.year === y.year);
    return d ? [{ year: y.year, age: y.age, ganzhi: y.ganzhi, ...point(d.scores, d.note) }] : [];
  });
  return {
    topics: [...topics],
    dayun,
    liunian,
    total: mean(dayun.map((d) => d.overall)),
    method_note: METHOD_NOTE[locale],
  };
}
