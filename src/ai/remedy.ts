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
import type { ChartFact, ChartSystem } from "../chart-fact/index.js";
import {
  compileRules,
  contentBlockLine,
  loadRuleSet,
  type Violation,
} from "../compliance/index.js";
import { baziView, planFocus } from "./bazi-view.js";
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
import type { UserContext } from "./context.js";
import { guardVerdict, providerOf } from "./envelope.js";
import { guardUser, METHOD_PROMPTS, remedyUser, todayLine } from "./prompts.js";
import { loadRouting } from "./routing.js";
import { guardSchema } from "./schemas.js";
import { glossaryFor, normalizeTerms, type Locale } from "./terms.js";
import { HORIZONS, NO_PLAN_TOPICS, type AgentName, type GuardOutput, type Topic } from "./types.js";

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
  /** Kept when held, for the review console; never shown unless released. */
  held_content?: RemedyContent & { closing: string };
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

/** The fixed closing note, per method (rule 8): a tarot plan isn't a 命理 balancing practice. */
const CLOSING: Partial<Record<ChartSystem, Record<Locale, string>>> = {
  bazi: {
    "zh-Hant":
      "以上為傳統命理中的調和做法，僅供娛樂和玄學學習使用，不保證任何結果；涉及健康、財務或法律的決定，請諮詢相關專業人士。",
    "zh-Hans":
      "以上为传统命理中的调和做法，仅供娱乐和玄学学习使用，不保证任何结果；涉及健康、财务或法律的决定，请咨询相关专业人士。",
    en: "These are traditional balancing practices for entertainment and metaphysics study only; no outcome is guaranteed. For health, financial or legal decisions, consult a qualified professional.",
  },
  tarot: {
    "zh-Hant":
      "以上建議依據所抽塔羅牌的牌義整理，僅供娛樂和玄學學習使用，不保證任何結果；涉及健康、財務或法律的決定，請諮詢相關專業人士。",
    "zh-Hans":
      "以上建议依据所抽塔罗牌的牌义整理，仅供娱乐和玄学学习使用，不保证任何结果；涉及健康、财务或法律的决定，请咨询相关专业人士。",
    en: "These suggestions follow the meanings of the cards drawn, for entertainment and metaphysics study only; no outcome is guaranteed. For health, financial or legal decisions, consult a qualified professional.",
  },
};

/** Methods with a 破除運勢 plan: their own prompt and closing note (astrology has neither). */
export function remedyAvailable(system: ChartSystem): boolean {
  return METHOD_PROMPTS[system].remedy !== undefined && CLOSING[system] !== undefined;
}

export async function generateRemedy(
  chart: ChartFact,
  report: Report,
  topic: Topic,
  opts: { country: string; context?: UserContext },
  deps: PipelineDeps,
): Promise<Remedy> {
  const now = deps.now?.() ?? new Date();
  const locale = report.locale;
  const layers = report.layers;
  if (report.status !== "passed" || !layers) throw new Error("report has no passed layers");
  if (!report.topics.includes(topic)) throw new Error(`topic ${topic} is not in this report`);
  if (NO_PLAN_TOPICS.includes(topic)) throw new Error(`the ${topic} section has no 破除運勢 plan`);
  const prompt = METHOD_PROMPTS[chart.system].remedy;
  const closing = CLOSING[chart.system]?.[locale];
  if (!prompt || !closing) throw new Error(`no 破除運勢 plan for ${chart.system} readings`);

  const { region } = servedRegion(opts.country, chart.system);
  const rules = compileRules(loadRuleSet(), region.rule_groups);
  const regionLine = contentBlockLine(region);
  const routing = deps.routing ?? loadRouting();
  const providerFor = (agent: AgentName) => providerOf(routing, deps.providers, agent, locale);
  // A 八字 plan reads its focused view: the periods where its topic scores lowest (WP2.3).
  const facts =
    chart.system === "bazi"
      ? baziView(modelFacts(chart), planFocus(layers.trend, topic, now.getUTCFullYear()), {
          trend: false,
        })
      : modelFacts(chart);
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
    prompt,
    ...providerFor("remedy"),
    schema: remedySchema,
    payload: { topic, system: chart.system },
    maxRetries: deps.maxRetries ?? 1,
    enforce: deps.review !== false,
    onProgress: deps.onProgress,
    user: (feedback) =>
      remedyUser({
        facts,
        topic,
        interpretation: layers.interpretation.filter((s) => s.topic === topic),
        actions: layers.actions.filter((a) => a.topic === topic),
        trend,
        context: opts.context,
        today: todayLine(now),
        locale,
        glossary,
        feedback,
        regionLine,
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
      if (!value.target.trim()) {
        feedback.push(
          chart.system === "tarot"
            ? "target must name the topic and the cards"
            : "target must name the topic and periods",
        );
      }
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
    ruleViolations.push(...plan.review, ...plan.block);
    const guard =
      deps.review === false
        ? undefined
        : await runAgent<GuardOutput>({
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
                  content_blocks: region.content_blocks,
                },
                draft: { remedy_plan: plan.value },
                context: opts.context,
                trend,
                today: todayLine(now),
              }),
            check: (value) => ({ value, feedback: [], block: [], review: [] }),
          });
    if (guard) {
      const verdict = guardVerdict(guard, traces, reasons);
      if (verdict.held) status = "manual_review";
      if (verdict.review) review = verdict.review;
    }
    if (
      deps.review !== false &&
      status === "passed" &&
      ruleViolations.some((v) => v.action === "review")
    ) {
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
    ...(status === "passed" && plan.ok && { content: { ...plan.value, closing } }),
    ...(status !== "passed" &&
      (plan.ok ? plan.value : plan.held) && {
        held_content: { ...(plan.ok ? plan.value : plan.held)!, closing },
      }),
    compliance: {
      rule_violations: ruleViolations,
      ...(review && { review }),
      term_fixes: [...new Set(termFixes)],
    },
    agents: traces,
  };
}
