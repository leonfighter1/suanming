/**
 * 一生运势报告: a whole-life report from a 八字 ChartFact plus the 易经本命卦,
 * 梅花易数 and 八宅 facts (src/engines/yijing). Deterministic facts first; two agents
 * write the interpretation in parallel (life_methods: the three methods,
 * life_topics: topics, life stages and summary); then the rule layer and the guard,
 * exactly as for reports.
 */
import type { ChartFact } from "../chart-fact/index.js";
import { compileRules, loadRuleSet, type Violation } from "../compliance/index.js";
import { yearGanZhi } from "../engines/bazi/index.js";
import { yijingFacts } from "../engines/yijing/index.js";
import type { UserContext } from "./context.js";
import { expectationLayer } from "./layers.js";
import {
  modelFacts,
  resolvePointer,
  runAgent,
  scanTexts,
  servedRegion,
  type AgentTrace,
  type PipelineDeps,
  type ReportStatus,
} from "./pipeline.js";
import { guardUser, lifeUser, todayLine } from "./prompts.js";
import { engineTrend } from "./trend.js";
import { loadRouting, routeFor } from "./routing.js";
import { guardSchema } from "./schemas.js";
import { glossaryFor, normalizeTerms, type Locale } from "./terms.js";
import type { AgentName, GuardOutput } from "./types.js";

export const LIFE_TOPICS = [
  "personality",
  "career",
  "wealth",
  "relationships",
  "children",
  "parents",
  "health",
] as const;
export type LifeTopic = (typeof LIFE_TOPICS)[number];

export interface LifeMethods {
  yijing: {
    meaning: string;
    ming_yao: string;
    zhi_gua: string;
    stages: { line: number; reading: string }[];
  };
  meihua: { season: string; early: string; middle: string; late: string; conclusion: string };
  wuxing: { analysis: string; favorable: string[]; unfavorable: string[]; note: string };
  bazhai: { summary: string; daily: string };
  fact_refs: string[];
}

export interface LifeTopics {
  topics: {
    key: LifeTopic;
    summary: string;
    points: { period: string; text: string }[];
    fact_refs: string[];
  }[];
  stages: { dayun_index: number; label: string; score: number; focus: string }[];
  summary: { verdict: string; advice: { area: string; text: string }[]; closing: string };
}

export interface LifeReport {
  status: ReportStatus;
  reasons: string[];
  locale: Locale;
  created_at: string;
  /** Deterministic: what the methods computed (shown as tables and drawings). */
  facts: ReturnType<typeof lifeFacts>;
  /** Kept when held, for the review console; never shown unless released. */
  held_layers?: LifeReport["layers"];
  /** Only for "passed" */
  layers?: {
    methods: LifeMethods;
    topics: LifeTopics["topics"];
    /** Stage rows joined with the 大运 they belong to */
    stages: (LifeTopics["stages"][number] & {
      ganzhi: string;
      start_year: number;
      start_age: number;
      end_age: number;
    })[];
    summary: LifeTopics["summary"];
    expectation: { text: string; ai_label: string; label_required: boolean };
  };
  ai_disclosure: {
    generated: true;
    model: string;
    prompt_version: string;
    label_required: boolean;
    generated_at: string;
  };
  compliance: { rule_violations: Violation[]; review?: GuardOutput; term_fixes: string[] };
  agents: AgentTrace[];
}

interface BaziFacts {
  time_basis: { civil_local: string; pillar_clock: string; true_solar_time_applied: boolean };
  dayun: {
    cycles: {
      index: number;
      ganzhi: string;
      start_year: number;
      start_age: number;
      start_age_xu?: number;
    }[];
  };
}

/**
 * The 八字 facts the life agents read (WP2.3): all of them but 流月 and the 流年 scores, which
 * no life prompt uses (stage scores come from trend.dayun).
 */
function lifeBazi(chart: ChartFact): Record<string, unknown> {
  const {
    liuyue: _months,
    trend,
    ...bazi
  } = modelFacts(chart) as Record<string, unknown> & {
    trend?: Record<string, unknown>;
  };
  if (!trend) return bazi;
  const { liunian: _years, ...lifeTrend } = trend;
  return { ...bazi, trend: lifeTrend };
}

/** Everything the life report shows and the model reads: 八字 facts + 易经 / 梅花 / 八宅. */
export function lifeFacts(chart: ChartFact, locale: Locale) {
  const f = chart.facts as unknown as Parameters<typeof yijingFacts>[0] & BaziFacts;
  const civilYear = Number(f.time_basis.civil_local.slice(0, 4));
  const y = yijingFacts(f, civilYear, yearGanZhi);
  // Classical text in the reader's script (English readers get 简体).
  const k = locale === "zh-Hant" ? "zh-Hant" : "zh-Hans";
  const hex = (h: (typeof y.benming)["hexagram"]) => ({
    id: h.id,
    upper: h.upper,
    lower: h.lower,
    name: h.name[k],
    full_name: h.full_name[k],
    gua_ci: h.gua_ci[k],
    da_xiang: h.da_xiang[k],
  });
  return {
    birth: {
      civil_local: f.time_basis.civil_local,
      pillar_clock: f.time_basis.pillar_clock,
      true_solar_time_applied: f.time_basis.true_solar_time_applied,
    },
    benming: {
      method: y.benming.method,
      steps: y.benming.steps,
      hexagram: hex(y.benming.hexagram),
      moving_line: y.benming.moving_line,
      changed: hex(y.benming.changed),
      nuclear: hex(y.benming.nuclear),
      lines: y.benming.lines.map((l) => ({ ...l, text: l.text[k] })),
      ...(y.benming.leap_month_note && { leap_month_note: y.benming.leap_month_note }),
    },
    meihua: y.meihua,
    bazhai: {
      ...y.bazhai,
      directions: y.bazhai.directions.map((d) => ({ ...d, direction: d.direction[k] })),
    },
    trigrams: Object.fromEntries(
      Object.entries(y.trigrams).map(([id, x]) => [
        id,
        { name: x.name[k], image: x.image[k], wuxing: x.wuxing },
      ]),
    ),
  };
}

const str = { type: "string" } as const;
const strs = { type: "array", items: str } as const;
const obj = (props: Record<string, unknown>) => ({
  type: "object",
  additionalProperties: false,
  required: Object.keys(props),
  properties: props,
});

export const lifeMethodsSchema = obj({
  yijing: obj({
    meaning: str,
    ming_yao: str,
    zhi_gua: str,
    stages: { type: "array", items: obj({ line: { type: "integer" }, reading: str }) },
  }),
  meihua: obj({ season: str, early: str, middle: str, late: str, conclusion: str }),
  wuxing: obj({ analysis: str, favorable: strs, unfavorable: strs, note: str }),
  bazhai: obj({ summary: str, daily: str }),
  fact_refs: strs,
});

export const lifeTopicsSchema = obj({
  topics: {
    type: "array",
    items: obj({
      key: { type: "string", enum: [...LIFE_TOPICS] },
      summary: str,
      points: { type: "array", items: obj({ period: str, text: str }) },
      fact_refs: strs,
    }),
  },
  stages: {
    type: "array",
    items: obj({
      dayun_index: { type: "integer" },
      label: str,
      score: { type: "integer" },
      focus: str,
    }),
  },
  summary: obj({
    verdict: str,
    advice: { type: "array", items: obj({ area: str, text: str }) },
    closing: str,
  }),
});

export async function generateLifeReport(
  chart: ChartFact,
  opts: { locale: Locale; country: string; context?: UserContext },
  deps: PipelineDeps,
): Promise<LifeReport> {
  if (chart.system !== "bazi") throw new Error("life reports need a 八字 chart");
  const now = deps.now?.() ?? new Date();
  const { region } = servedRegion(opts.country, chart.system);
  const rules = compileRules(loadRuleSet(), region.rule_groups);
  const routing = deps.routing ?? loadRouting();
  const providerFor = (agent: AgentName) => {
    const route = routeFor(routing, agent, opts.locale);
    const provider = deps.providers[route.provider];
    if (!provider) throw new Error(`provider "${route.provider}" not configured`);
    return { route, provider };
  };
  const facts = lifeFacts(chart, opts.locale);
  const cycles = (chart.facts as unknown as BaziFacts).dayun.cycles;
  // 虚岁 from the civil birth year (v1.3.0); older charts: the library's start_age, the same count.
  const xu = (c: (typeof cycles)[number]) => c.start_age_xu ?? c.start_age;
  const endAge = (i: number) => (cycles[i + 1] ? xu(cycles[i + 1]!) : xu(cycles[i]!) + 10) - 1;
  // Ready-made period labels, so the model never works out age ranges itself
  // (a live run wrote 36–44 岁 for a 大运 that runs 36–45).
  const sui = { "zh-Hans": "虚岁", "zh-Hant": "虛歲", en: "nominal age" }[opts.locale];
  const periods = cycles.map((c, i) => ({
    dayun_index: c.index,
    ganzhi: c.ganzhi,
    label:
      opts.locale === "en"
        ? `${sui} ${xu(c)}–${endAge(i)} (${c.start_year}–${c.start_year + 9})`
        : `${sui} ${xu(c)}–${endAge(i)}（${c.start_year}–${c.start_year + 9}）`,
  }));
  // Stage scores are the engine's (v2.0.0), the same as the 运势走势 chart's.
  const engine = engineTrend(chart);
  const engineScore = (index: number) =>
    engine.dayun.find((d) => d.index === index)?.scores.dayun_liunian;
  const modelInput = { bazi: lifeBazi(chart), ...facts, periods };
  const glossary = glossaryFor(JSON.stringify(modelInput), opts.locale);
  const today = todayLine(now);
  const termFixes: string[] = [];
  const norm = (s: string) => {
    const { text, fixes } = normalizeTerms(s, opts.locale);
    termFixes.push(...fixes);
    return text;
  };
  const refsOk = (refs: string[]) => refs.filter((r) => resolvePointer(modelInput, r));
  const enforce = deps.review !== false;
  const common = { maxRetries: deps.maxRetries ?? 1, onProgress: deps.onProgress, enforce };
  const user = (part: "methods" | "topics") => (feedback: string[]) =>
    lifeUser({
      part,
      facts: modelInput,
      context: opts.context,
      today,
      locale: opts.locale,
      glossary,
      feedback,
    });

  const [methods, topics] = await Promise.all([
    runAgent<LifeMethods>({
      agent: "life_methods",
      ...providerFor("life_methods"),
      ...common,
      schema: lifeMethodsSchema,
      payload: { part: "methods", lines: facts.benming.lines.length },
      user: user("methods"),
      check: (d) => {
        const value: LifeMethods = {
          yijing: {
            meaning: norm(d.yijing.meaning),
            ming_yao: norm(d.yijing.ming_yao),
            zhi_gua: norm(d.yijing.zhi_gua),
            stages: d.yijing.stages
              .filter((s) => s.line >= 1 && s.line <= 6)
              .map((s) => ({ line: s.line, reading: norm(s.reading) })),
          },
          meihua: {
            season: norm(d.meihua.season),
            early: norm(d.meihua.early),
            middle: norm(d.meihua.middle),
            late: norm(d.meihua.late),
            conclusion: norm(d.meihua.conclusion),
          },
          wuxing: {
            analysis: norm(d.wuxing.analysis),
            favorable: d.wuxing.favorable.map(norm),
            unfavorable: d.wuxing.unfavorable.map(norm),
            note: norm(d.wuxing.note),
          },
          bazhai: { summary: norm(d.bazhai.summary), daily: norm(d.bazhai.daily) },
          fact_refs: refsOk(d.fact_refs),
        };
        const feedback: string[] = [];
        if (value.yijing.stages.length !== 6) feedback.push("yijing.stages must cover lines 1–6");
        if (!value.fact_refs.length) feedback.push("fact_refs cited no existing path");
        return { value, feedback, ...scanTexts(methodsTexts(value), rules) };
      },
    }),
    runAgent<LifeTopics>({
      agent: "life_topics",
      ...providerFor("life_topics"),
      ...common,
      schema: lifeTopicsSchema,
      payload: { part: "topics", dayun: cycles.map((c) => c.index) },
      user: user("topics"),
      check: (d) => {
        const indices = new Set(cycles.map((c) => c.index));
        const value: LifeTopics = {
          topics: LIFE_TOPICS.flatMap((key) => {
            const t = d.topics.find((x) => x.key === key);
            return t
              ? [
                  {
                    key,
                    summary: norm(t.summary),
                    points: t.points.map((p) => ({ period: norm(p.period), text: norm(p.text) })),
                    fact_refs: refsOk(t.fact_refs),
                  },
                ]
              : [];
          }),
          stages: d.stages
            .filter((s) => indices.has(s.dayun_index))
            .map((s) => ({
              ...s,
              label: norm(s.label),
              focus: norm(s.focus),
              score: engineScore(s.dayun_index) ?? Math.min(100, Math.max(0, Math.round(s.score))),
            })),
          summary: {
            verdict: norm(d.summary.verdict),
            advice: d.summary.advice.map((a) => ({ area: norm(a.area), text: norm(a.text) })),
            closing: norm(d.summary.closing),
          },
        };
        const feedback: string[] = [];
        const missing = LIFE_TOPICS.filter((k) => !value.topics.some((t) => t.key === k));
        if (missing.length) feedback.push(`missing topics: ${missing.join(", ")}`);
        const gaps = [...indices].filter((i) => !value.stages.some((s) => s.dayun_index === i));
        if (gaps.length) feedback.push(`missing stages for dayun indices: ${gaps.join(", ")}`);
        return { value, feedback, ...scanTexts(topicsTexts(value), rules) };
      },
    }),
  ]);

  const traces = [methods.trace, topics.trace];
  const reasons: string[] = [];
  const ruleViolations: Violation[] = [];
  let status: ReportStatus = "passed";
  let review: GuardOutput | undefined;
  for (const part of [methods, topics]) {
    if (!part.ok) {
      status = status === "blocked" || part.block.length ? "blocked" : "manual_review";
      reasons.push(part.reason);
      ruleViolations.push(...part.block);
    } else ruleViolations.push(...part.review, ...part.block);
  }

  if (enforce && methods.ok && topics.ok) {
    const guard = await runAgent<GuardOutput>({
      agent: "guard",
      ...providerFor("guard"),
      schema: guardSchema,
      payload: {},
      maxRetries: 0,
      onProgress: deps.onProgress,
      user: () =>
        guardUser({
          facts: modelInput,
          region: {
            code: opts.country.toUpperCase(),
            name: region.name,
            rule_groups: region.rule_groups,
          },
          draft: { life_report: { methods: methods.value, topics: topics.value } },
          context: opts.context,
          today,
        }),
      check: (value) => ({ value, feedback: [], block: [], review: [] }),
    });
    traces.push(guard.trace);
    if (!guard.ok) {
      status = "manual_review";
      reasons.push(guard.reason);
    } else {
      review = guard.value;
      if (!review.pass) {
        status = "manual_review";
        reasons.push(`guard: ${review.violations.length} issue(s) flagged`);
      }
    }
    if (status === "passed" && ruleViolations.some((v) => v.action === "review")) {
      status = "manual_review";
      reasons.push("rule layer: review-level patterns present");
    }
  }

  const labelRequired = region.ai_disclosure.visible_label === "required";
  const report: LifeReport = {
    status,
    reasons,
    locale: opts.locale,
    created_at: now.toISOString(),
    facts,
    ai_disclosure: {
      generated: true,
      model: [...new Set(traces.map((t) => t.model))].join(","),
      prompt_version: traces.map((t) => t.prompt_version).join(","),
      label_required: labelRequired,
      generated_at: now.toISOString(),
    },
    compliance: {
      rule_violations: ruleViolations,
      ...(review && { review }),
      term_fixes: [...new Set(termFixes)],
    },
    agents: traces,
  };
  const m = methods.ok ? methods.value : methods.held;
  const t = topics.ok ? topics.value : topics.held;
  const candidate = m &&
    t && {
      methods: m,
      topics: t.topics,
      stages: cycles.flatMap((c, i) => {
        const s = t.stages.find((x) => x.dayun_index === c.index);
        return s
          ? [
              {
                ...s,
                ganzhi: c.ganzhi,
                start_year: c.start_year,
                start_age: xu(c),
                end_age: endAge(i),
              },
            ]
          : [];
      }),
      summary: t.summary,
      expectation: expectationLayer(opts.locale, labelRequired),
    };
  if (status === "passed" && methods.ok && topics.ok && candidate) report.layers = candidate;
  else if (candidate) report.held_layers = candidate;
  return report;
}

function methodsTexts(m: LifeMethods): string[] {
  return [
    m.yijing.meaning,
    m.yijing.ming_yao,
    m.yijing.zhi_gua,
    ...m.yijing.stages.map((s) => s.reading),
    ...Object.values(m.meihua),
    m.wuxing.analysis,
    ...m.wuxing.favorable,
    ...m.wuxing.unfavorable,
    m.wuxing.note,
    m.bazhai.summary,
    m.bazhai.daily,
  ];
}

function topicsTexts(t: LifeTopics): string[] {
  return [
    ...t.topics.flatMap((x) => [x.summary, ...x.points.flatMap((p) => [p.period, p.text])]),
    ...t.stages.flatMap((s) => [s.label, s.focus]),
    t.summary.verdict,
    ...t.summary.advice.flatMap((a) => [a.area, a.text]),
    t.summary.closing,
  ];
}
