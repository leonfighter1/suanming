/**
 * 破除運勢 / 改運 plans: a paid, per-topic add-on to a passed report.
 *
 * Remedy agent → Compliance Guard, with the same rule layer, grounding and retry
 * loop as the report pipeline. The plan always names the topic and the periods it
 * targets. Steps must be free or near-free practices (no purchases, rituals,
 * medical or financial advice); the closing note is fixed copy, not model text.
 *
 * Payment is a Phase 4 TODO: the API records a placeholder charge before calling this.
 */
import type { ChartFact } from "../chart-fact/index.js";
import { compileRules, loadRuleSet, type Violation } from "../compliance/index.js";
import {
  modelFacts,
  resolvePointer,
  runAgent,
  scanTexts,
  servedRegion,
  type AgentTrace,
  type PipelineDeps,
  type Report,
  type ReportStatus,
} from "./pipeline.js";
import { guardUser, remedyUser } from "./prompts.js";
import { loadRouting, routeFor } from "./routing.js";
import { guardSchema } from "./schemas.js";
import { glossaryFor, normalizeTerms, type Locale } from "./terms.js";
import { HORIZONS, type AgentName, type GuardOutput, type Topic } from "./types.js";

export interface RemedyContent {
  target: string;
  summary: string;
  focus_periods: string[];
  steps: { title: string; text: string; horizon: (typeof HORIZONS)[number] }[];
  basis: string;
  fact_refs: string[];
}

export interface Remedy {
  status: ReportStatus;
  reasons: string[];
  topic: Topic;
  locale: Locale;
  created_at: string;
  /** Only for "passed" */
  content?: RemedyContent & { closing: string };
  compliance: { rule_violations: Violation[]; review?: GuardOutput; term_fixes: string[] };
  agents: AgentTrace[];
}

const str = { type: "string" } as const;
export const remedySchema = {
  type: "object",
  additionalProperties: false,
  required: ["target", "summary", "focus_periods", "steps", "basis", "fact_refs"],
  properties: {
    target: str,
    summary: str,
    focus_periods: { type: "array", items: str },
    steps: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["title", "text", "horizon"],
        properties: { title: str, text: str, horizon: { type: "string", enum: [...HORIZONS] } },
      },
    },
    basis: str,
    fact_refs: { type: "array", items: str },
  },
};

const CLOSING: Record<Locale, string> = {
  "zh-Hant":
    "以上為傳統命理文化中的調和做法，僅供參考，不保證任何結果；涉及健康、財務或法律的決定，請諮詢相關專業人士。",
  "zh-Hans":
    "以上为传统命理文化中的调和做法，仅供参考，不保证任何结果；涉及健康、财务或法律的决定，请咨询相关专业人士。",
  en: "These are traditional balancing practices offered for reflection only; no outcome is guaranteed. For health, financial or legal decisions, consult a qualified professional.",
};

export async function generateRemedy(
  chart: ChartFact,
  report: Report,
  topic: Topic,
  opts: { country: string },
  deps: PipelineDeps,
): Promise<Remedy> {
  const now = deps.now?.() ?? new Date();
  const locale = report.locale;
  const layers = report.layers;
  if (report.status !== "passed" || !layers) throw new Error("report has no passed layers");
  if (!report.topics.includes(topic)) throw new Error(`topic ${topic} is not in this report`);

  const { region } = servedRegion(opts.country, chart.system);
  const rules = compileRules(loadRuleSet(), region.rule_groups);
  const routing = deps.routing ?? loadRouting();
  const providerFor = (agent: AgentName) => {
    const route = routeFor(routing, agent, locale);
    const provider = deps.providers[route.provider];
    if (!provider) throw new Error(`provider "${route.provider}" not configured`);
    return { route, provider };
  };
  const facts = modelFacts(chart);
  const glossary = glossaryFor(JSON.stringify(facts), locale);
  const trend = layers.trend && {
    dayun: layers.trend.dayun.map((d) => ({
      ganzhi: d.ganzhi,
      years: `${d.start_year}–${d.start_year + 9}`,
      ages: `${d.start_age}–${d.end_age}`,
      score: d.scores[topic],
      note: d.note,
    })),
    liunian: layers.trend.liunian.map((y) => ({
      year: y.year,
      ganzhi: y.ganzhi,
      age: y.age,
      score: y.scores[topic],
    })),
  };
  const termFixes: string[] = [];
  const traces: AgentTrace[] = [];
  const reasons: string[] = [];
  const ruleViolations: Violation[] = [];
  let status: ReportStatus = "passed";
  let review: GuardOutput | undefined;

  const plan = await runAgent<RemedyContent>({
    agent: "remedy",
    ...providerFor("remedy"),
    schema: remedySchema,
    payload: { topic, system: chart.system },
    maxRetries: deps.maxRetries ?? 1,
    onProgress: deps.onProgress,
    user: (feedback) =>
      remedyUser({
        facts,
        topic,
        interpretation: layers.interpretation.filter((s) => s.topic === topic),
        actions: layers.actions.filter((a) => a.topic === topic),
        trend,
        locale,
        glossary,
        feedback,
      }),
    check: (data) => {
      const norm = (t: string) => {
        const { text, fixes } = normalizeTerms(t, locale);
        termFixes.push(...fixes);
        return text;
      };
      const value: RemedyContent = {
        target: norm(data.target),
        summary: norm(data.summary),
        focus_periods: data.focus_periods.map(norm),
        steps: data.steps
          .slice(0, 6)
          .map((s) => ({ ...s, title: norm(s.title), text: norm(s.text) })),
        basis: norm(data.basis),
        fact_refs: data.fact_refs.filter((r) => resolvePointer(facts, r)),
      };
      const feedback: string[] = [];
      if (value.fact_refs.length === 0)
        feedback.push("fact_refs cited no existing chart_facts path");
      if (value.steps.length < 3) feedback.push("give 4–6 steps");
      if (!value.target.trim()) feedback.push("target must name the topic and periods");
      return {
        value,
        feedback,
        ...scanTexts(
          [
            value.target,
            value.summary,
            value.basis,
            ...value.focus_periods,
            ...value.steps.flatMap((s) => [s.title, s.text]),
          ],
          rules,
        ),
      };
    },
  });
  traces.push(plan.trace);

  if (!plan.ok) {
    status = plan.block.length ? "blocked" : "manual_review";
    reasons.push(plan.reason);
    ruleViolations.push(...plan.block);
  } else {
    ruleViolations.push(...plan.review);
    const guard = await runAgent<GuardOutput>({
      agent: "guard",
      ...providerFor("guard"),
      schema: guardSchema,
      payload: plan.value,
      maxRetries: 0,
      onProgress: deps.onProgress,
      user: () =>
        guardUser({
          facts,
          region: {
            code: opts.country.toUpperCase(),
            name: region.name,
            rule_groups: region.rule_groups,
          },
          draft: { remedy_plan: plan.value },
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

  return {
    status,
    reasons,
    topic,
    locale,
    created_at: now.toISOString(),
    ...(status === "passed" && plan.ok && { content: { ...plan.value, closing: CLOSING[locale] } }),
    compliance: {
      rule_violations: ruleViolations,
      ...(review && { review }),
      term_fixes: [...new Set(termFixes)],
    },
    agents: traces,
  };
}
