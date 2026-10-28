/**
 * The report's trend chart (八字 only). Since v2.0.0 the scores are the engine's
 * (chart_facts.trend, src/engines/bazi/trend-scores.ts): the same chart always gives the
 * same chart, and no model is asked. Charts made before carry no trend facts; their scores
 * are computed here from their pillars with the same engine functions. The one-line note
 * of each period is written from its basis, in the reader's language.
 */
import type { ChartFact } from "../chart-fact/index.js";
import { periodRelations, type Relation } from "../engines/bazi/relations.js";
import { strength } from "../engines/bazi/strength.js";
import {
  TREND_TOPICS,
  trendScores,
  type Family,
  type PeriodScore,
  type TrendTopic,
} from "../engines/bazi/trend-scores.js";
import type { Locale } from "./terms.js";
import type { Topic } from "./types.js";

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

type Natal = Record<"year" | "month" | "day" | "hour", { gan: string; zhi: string }>;
interface Facts {
  pillars: Natal;
  dayun: {
    cycles: {
      index: number;
      ganzhi: string;
      start_year: number;
      start_age: number;
      start_age_xu?: number;
      relations?: Relation[];
    }[];
  };
  liunian: { year: number; ganzhi: string; age: number; age_xu?: number; relations?: Relation[] }[];
  trend?: ReturnType<typeof trendScores>;
}

/** 虚岁 for every age shown (v1.3.0); charts made earlier lack the field: age + 1 is the same count. */
const xuCycle = (c: Facts["dayun"]["cycles"][number]) => c.start_age_xu ?? c.start_age;
const xuYear = (y: Facts["liunian"][number]) => y.age_xu ?? y.age + 1;

/** The engine's scores: from the chart's facts, or worked out for a chart made before v2.0.0. */
export function engineTrend(chart: ChartFact): ReturnType<typeof trendScores> {
  const f = chart.facts as unknown as Facts;
  if (f.trend) return f.trend;
  const cycles = f.dayun.cycles;
  const dayunAt = (year: number) => [...cycles].reverse().find((c) => c.start_year <= year)?.ganzhi;
  return trendScores(f.pillars.day.gan, strength(f.pillars), {
    dayun: cycles.map((c) => ({
      ...c,
      relations: c.relations ?? periodRelations(f.pillars, { place: "dayun", ganzhi: c.ganzhi }),
    })),
    liunian: f.liunian.map((y) => ({
      ...y,
      relations:
        y.relations ??
        periodRelations(f.pillars, { place: "liunian", ganzhi: y.ganzhi }, dayunAt(y.year)),
    })),
  });
}

const FAMILY: Record<Family, Record<Locale, [name: string, plain: string]>> = {
  比劫: {
    "zh-Hans": ["比劫", "自己和同辈"],
    "zh-Hant": ["比劫", "自己和同輩"],
    en: ["Companions", "yourself and peers"],
  },
  食伤: {
    "zh-Hans": ["食伤", "表达和才华"],
    "zh-Hant": ["食傷", "表達和才華"],
    en: ["Output", "expression and talent"],
  },
  财: {
    "zh-Hans": ["财星", "钱财和实际收获"],
    "zh-Hant": ["財星", "錢財和實際收穫"],
    en: ["Wealth", "money and practical gains"],
  },
  官杀: {
    "zh-Hans": ["官杀", "规则、压力和事业"],
    "zh-Hant": ["官殺", "規則、壓力和事業"],
    en: ["Officers", "rules, pressure and career"],
  },
  印: {
    "zh-Hans": ["印星", "学习和支持你的人"],
    "zh-Hant": ["印星", "學習和支持你的人"],
    en: ["Resources", "learning and people who support you"],
  },
};
const FAVOUR: Record<"up" | "down" | "even", Record<Locale, string>> = {
  up: {
    "zh-Hans": "五行多为对你有利的一方",
    "zh-Hant": "五行多為對你有利的一方",
    en: "its elements mostly work in your favour",
  },
  down: {
    "zh-Hans": "五行多为需要多留意的一方",
    "zh-Hant": "五行多為需要多留意的一方",
    en: "its elements mostly call for care",
  },
  even: {
    "zh-Hans": "五行有利与不利大致相当",
    "zh-Hant": "五行有利與不利大致相當",
    en: "its elements are about evenly balanced",
  },
};
const DAY: Record<"clash" | "combine" | "strain", Record<Locale, string>> = {
  clash: {
    "zh-Hans": "，与日支相冲，变动较多",
    "zh-Hant": "，與日支相沖，變動較多",
    en: "; it clashes with your day branch, a time of change",
  },
  combine: {
    "zh-Hans": "，与日支相合，相处较顺",
    "zh-Hant": "，與日支相合，相處較順",
    en: "; it combines with your day branch, an easier time with others",
  },
  // {rel}: the relation by its own name (相刑, 自刑, 相害, 相破), never lumped together as 刑害.
  strain: {
    "zh-Hans": "，与日支{rel}，宜多沟通",
    "zh-Hant": "，與日支{rel}，宜多溝通",
    en: "; it strains your day branch, so talk things through",
  },
};

/** The plain one-line note of a period, from what its scores rest on. */
export function trendNote(ganzhi: string, basis: PeriodScore["basis"], locale: Locale): string {
  const [name, plain] = FAMILY[basis.families[0]][locale];
  const favour =
    FAVOUR[basis.favour >= 0.25 ? "up" : basis.favour <= -0.25 ? "down" : "even"][locale];
  const t = basis.day_branch;
  const day =
    t === "六冲"
      ? DAY.clash[locale]
      : t && ["六合", "三合", "半合", "三会"].includes(t)
        ? DAY.combine[locale]
        : t
          ? DAY.strain[locale].replace("{rel}", t === "六害" ? "相害" : t)
          : "";
  if (locale === "en") return `${ganzhi}: ${name} lead (${plain}); ${favour}${day}.`;
  const lead = locale === "zh-Hant" ? "當頭" : "当头";
  return `${ganzhi}：${name}${lead}（${plain}）；${favour}${day}。`;
}

const METHOD_NOTE: Record<Locale, string> = {
  "zh-Hant":
    "分數由排盤引擎計算：大運、流年的五行對你的喜忌（簡化扶抑法），加上與原局的刑沖合害，按主題加權；0–100，50 為平穩，同一命盤每次相同；是參考指數，不是預測。「綜合」為所選項目的平均，「總分」為各大運綜合分的平均。",
  "zh-Hans":
    "分数由排盘引擎计算：大运、流年的五行对你的喜忌（简化扶抑法），加上与原局的刑冲合害，按主题加权；0–100，50 为平稳，同一命盘每次相同；是参考指数，不是预测。“综合”为所选项目的平均，“总分”为各大运综合分的平均。",
  en: "Scores are computed by the chart engine: how each luck pillar's and year's elements suit your chart (a simplified strength method), plus its combinations and clashes with the natal chart, weighted per topic. 0–100, 50 = steady, the same every time for the same chart; a reference index, not a prediction. 'Combined' is the mean of the selected topics; 'total' is the mean of the luck-pillar combined scores.",
};

const mean = (xs: number[]) =>
  xs.length ? Math.round(xs.reduce((a, b) => a + b, 0) / xs.length) : 0;

export function trendLayer(
  chart: ChartFact,
  requested: readonly Topic[],
  locale: Locale,
): TrendLayer {
  const f = chart.facts as unknown as Facts;
  const engine = engineTrend(chart);
  // A 八字 report's topics are all the engine's (TREND_TOPICS); nothing else gets a score.
  const topics = requested.filter((t): t is TrendTopic =>
    (TREND_TOPICS as readonly string[]).includes(t),
  );
  const point = (gz: string, p: PeriodScore): TrendPoint => {
    const scores = Object.fromEntries(topics.map((t) => [t, p.scores[t]])) as TrendPoint["scores"];
    return {
      scores,
      overall: mean(topics.map((t) => p.scores[t])),
      note: trendNote(gz, p.basis, locale),
    };
  };
  const cycles = f.dayun.cycles;
  const dayun = cycles.flatMap((c, i) => {
    const d = engine.dayun.find((x) => x.index === c.index);
    if (!d) return [];
    const next = cycles[i + 1];
    return [
      {
        index: c.index,
        ganzhi: c.ganzhi,
        start_year: c.start_year,
        start_age: xuCycle(c),
        end_age: (next ? xuCycle(next) : xuCycle(c) + 10) - 1,
        ...point(c.ganzhi, d),
      },
    ];
  });
  const liunian = f.liunian.flatMap((y) => {
    const d = engine.liunian.find((x) => x.year === y.year);
    return d ? [{ year: y.year, age: xuYear(y), ganzhi: y.ganzhi, ...point(y.ganzhi, d) }] : [];
  });
  return {
    topics: [...topics],
    dayun,
    liunian,
    total: mean(dayun.map((d) => d.overall)),
    method_note: METHOD_NOTE[locale],
  };
}
