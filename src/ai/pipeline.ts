/**
 * AI Interp pipeline (Phase 1 §2.2): Geo-Rule → Narrative → Action → Compliance Guard.
 *
 * - Facts and expectation layers are deterministic (layers.ts); only interpretation
 *   and actions are model-generated.
 * - Each generating agent gets up to `maxRetries` regenerations with feedback when its
 *   output fails schema, grounding, coverage or the compliance rule layer.
 * - Rule-layer `block` hits that survive retries → status "blocked".
 *   Rule-layer `review` hits, model-review failures and refusals → "manual_review".
 * - Only "passed" reports carry layers for the user.
 */
import { randomUUID } from "node:crypto";
import type { ChartFact, ChartSystem } from "../chart-fact/index.js";
import {
  compileRules,
  loadGeoMatrix,
  loadRuleSet,
  resolveRegion,
  scan,
  type CompiledRule,
  type RegionRule,
  type Violation,
} from "../compliance/index.js";
import { baziView, readingFocus } from "./bazi-view.js";
import type { UserContext } from "./context.js";
import { expectationLayer, factsLayer } from "./layers.js";
import {
  actionUser,
  guardUser,
  METHOD_PROMPTS,
  narrativeUser,
  PROMPTS,
  qiuqianUser,
  fengshuiUser,
  tarotUser,
  todayLine,
  type PromptVersion,
} from "./prompts.js";
import { FENGSHUI_TERMS, fengshuiBrief } from "./fengshui.js";
import { lotBrief, QIUQIAN_TERMS, qiuqianView } from "./qiuqian.js";
import { spreadBrief } from "./tarot.js";
import { loadRouting, routeFor, type RoutingTable } from "./routing.js";
import { actionSchema, checkShape, guardSchema, narrativeSchema } from "./schemas.js";
import { glossaryFor, LOCALES, normalizeTerms, type Locale } from "./terms.js";
import { trendLayer, type TrendLayer } from "./trend.js";
import {
  TAROT_FOCUS,
  TOPICS,
  TOPICS_BY_SYSTEM,
  type ActionOutput,
  type AgentName,
  type GuardOutput,
  type LLMProvider,
  type NarrativeOutput,
  type TarotFocus,
  type Topic,
  type Usage,
} from "./types.js";

export class GeoRefusedError extends Error {
  readonly status = 451;
}
export class ReportInputError extends Error {}

export type ReportStatus = "passed" | "blocked" | "manual_review";

export interface ReportOptions {
  locale: Locale;
  /** ISO 3166-1 alpha-2 of the user (from account, verified server-side) */
  country: string;
  topics?: Topic[];
  /** Optional user question (tarot, 求籤) */
  question?: string;
  /** The area of life a tarot reading looks at (tarot only, v2.3.0) */
  focus?: TarotFocus;
  /** What the user told us about their life (src/ai/context.ts) */
  context?: UserContext;
  /** Return the held draft for blocked/manual_review reports. Internal tools only. */
  includeDraft?: boolean;
}

export interface PipelineDeps {
  providers: Record<string, LLMProvider>;
  routing?: RoutingTable;
  now?: () => Date;
  maxRetries?: number;
  /**
   * Content review: rule-layer holds and rewrites, the guard model and manual
   * review. Default true. false = paused (owner decision 2026-10-26, a later
   * legal & obligations item): rule hits are still scanned and recorded on the
   * output for audit, but nothing is held, rewritten or sent to the guard.
   */
  review?: boolean;
  newId?: () => string;
  /** Called when an agent starts an attempt, so callers can show live progress. */
  onProgress?: (p: Progress) => void | Promise<void>;
}

export interface Progress {
  stage: AgentName;
  /** 1-based; > 1 means a regeneration after a rejected attempt */
  attempt: number;
}

export interface AgentTrace {
  agent: AgentName;
  prompt_version: string;
  model: string;
  attempts: number;
  usage: Usage;
  problems: string[];
}

export interface Report {
  report_id: string;
  status: ReportStatus;
  reasons: string[];
  created_at: string;
  locale: Locale;
  region: string;
  topics: Topic[];
  chart: { system: string; input_digest: string; engine_version: string; schema_version: string };
  layers?: {
    facts: string[];
    interpretation: NarrativeOutput["sections"];
    actions: ActionOutput["actions"];
    expectation: { text: string; ai_label: string; label_required: boolean };
    /** 八字 only; omitted when the trend agent fails (the rest of the report stands). */
    trend?: TrendLayer;
  };
  draft?: { interpretation?: NarrativeOutput["sections"]; actions?: ActionOutput["actions"] };
  /**
   * What the layers would have been, kept when the report is held (manual_review /
   * blocked) so a reviewer can read it and, for manual_review, release it. Never
   * sent to the user unless released.
   */
  held_layers?: Report["layers"];
  ai_disclosure: {
    generated: true;
    model: string;
    prompt_version: string;
    label_required: boolean;
    generated_at: string;
  };
  compliance: {
    geo_matrix_version: string;
    rule_violations: Violation[];
    review?: GuardOutput;
    term_fixes: string[];
    dropped_ungrounded: number;
  };
  agents: AgentTrace[];
}

// ---------- helpers ----------

/** Facts sent to the model: no exact birth time, no audit ids (data minimisation). */
export function modelFacts(chart: ChartFact): Record<string, unknown> {
  const { time_basis: _t, audit: _a, ...rest } = chart.facts as Record<string, unknown>;
  return rest;
}

export function resolvePointer(obj: unknown, ptr: string): boolean {
  if (!ptr.startsWith("/")) return false;
  let cur: unknown = obj;
  for (const raw of ptr.slice(1).split("/")) {
    const key = raw.replace(/~1/g, "/").replace(/~0/g, "~");
    if (cur === null || typeof cur !== "object" || !(key in (cur as object))) return false;
    cur = (cur as Record<string, unknown>)[key];
  }
  return true;
}

const addUsage = (a: Usage, b: Usage): Usage => ({
  input_tokens: a.input_tokens + b.input_tokens,
  output_tokens: a.output_tokens + b.output_tokens,
  cache_read_input_tokens: (a.cache_read_input_tokens ?? 0) + (b.cache_read_input_tokens ?? 0),
});

export interface CheckResult<T> {
  value: T;
  /** Problems worth a retry */
  feedback: string[];
  block: Violation[];
  review: Violation[];
}

type AgentOutcome<T> =
  | { ok: true; value: T; block: Violation[]; review: Violation[]; trace: AgentTrace }
  | { ok: false; reason: string; held?: T; block: Violation[]; trace: AgentTrace };

/** Shared generate → check → retry loop for every agent. */
export async function runAgent<T>(args: {
  agent: AgentName;
  /** A method's own prompt for this agent (tarot's reading); default PROMPTS[agent]. */
  prompt?: PromptVersion;
  provider: LLMProvider;
  route: ReturnType<typeof routeFor>;
  user: (feedback: string[]) => string;
  schema: Record<string, unknown>;
  payload: unknown;
  check: (data: T) => CheckResult<T>;
  maxRetries: number;
  onProgress?: PipelineDeps["onProgress"];
  /** false: rule hits are recorded but cause no rewrite or hold (review paused). */
  enforce?: boolean;
}): Promise<AgentOutcome<T>> {
  const prompt = args.prompt ?? PROMPTS[args.agent];
  const trace: AgentTrace = {
    agent: args.agent,
    prompt_version: prompt.id,
    model: args.route.model,
    attempts: 0,
    usage: { input_tokens: 0, output_tokens: 0, cache_read_input_tokens: 0 },
    problems: [],
  };
  let feedback: string[] = [];
  let last: CheckResult<T> | undefined;

  for (let attempt = 0; attempt <= args.maxRetries; attempt++) {
    trace.attempts++;
    await args.onProgress?.({ stage: args.agent, attempt: attempt + 1 });
    const res = await args.provider.generateJson({
      agent: args.agent,
      model: args.route.model,
      effort: args.route.effort,
      maxTokens: args.route.max_tokens,
      system: prompt.system,
      user: args.user(feedback),
      schema: args.schema,
      payload: args.payload,
    });
    trace.usage = addUsage(trace.usage, res.usage);
    trace.model = res.model;

    if (res.kind === "refusal") {
      trace.problems.push(`refusal (${res.category ?? "uncategorized"})`);
      return { ok: false, reason: `${args.agent}: model refusal`, block: [], trace };
    }
    if (res.kind === "invalid") {
      feedback = [res.error];
      trace.problems.push(res.error);
      continue;
    }
    const shape = checkShape(args.schema, res.data);
    if (shape.length) {
      feedback = shape.map((s) => `schema: ${s}`);
      trace.problems.push(...feedback);
      continue;
    }
    last = args.check(res.data as T);
    feedback = [
      ...last.feedback,
      ...(args.enforce === false ? [] : last.block).map(
        (v) => `The text "${v.match}" breaks content rule ${v.rule_id}. Rephrase without it.`,
      ),
    ];
    if (feedback.length === 0) {
      return {
        ok: true,
        value: last.value,
        block: args.enforce === false ? last.block : [],
        review: last.review,
        trace,
      };
    }
    trace.problems.push(...feedback);
  }

  if (last && (last.block.length === 0 || args.enforce === false)) {
    // Only soft problems (grounding/coverage) remain, or review is paused: accept the cleaned value.
    return {
      ok: true,
      value: last.value,
      block: args.enforce === false ? last.block : [],
      review: last.review,
      trace,
    };
  }
  return {
    ok: false,
    reason: last?.block.length
      ? `${args.agent}: content rules still violated after ${trace.attempts} attempts`
      : `${args.agent}: no valid output after ${trace.attempts} attempts`,
    held: last?.value,
    block: last?.block ?? [],
    trace,
  };
}

export function scanTexts(texts: string[], rules: CompiledRule[]) {
  const hits = texts.flatMap((t) => scan(t, rules));
  return {
    block: hits.filter((h) => h.action === "block"),
    review: hits.filter((h) => h.action === "review"),
  };
}

/**
 * Rule groups that apply to one method's output, on top of the region's (v4.4.0): 风水's own rules
 * against 吉凶 phrasing about a home (the owner's Phase 3 §4).
 */
export const METHOD_RULE_GROUPS: Partial<Record<ChartSystem, string[]>> = {
  fengshui: ["fengshui"],
};

/** Geo-Rule: the region's rules, or GeoRefusedError when the service/system isn't offered. */
export function servedRegion(country: string, system: string) {
  const matrix = loadGeoMatrix();
  const region: RegionRule | null = resolveRegion(matrix, country);
  if (!region || !region.service_available) {
    throw new GeoRefusedError(`service not available in ${country}`);
  }
  if (region.systems[system]?.available === false) {
    throw new GeoRefusedError(`${system} not available in ${country}`);
  }
  return { matrix, region };
}

// ---------- pipeline ----------

export async function generateReport(
  chart: ChartFact,
  opts: ReportOptions,
  deps: PipelineDeps,
): Promise<Report> {
  const now = deps.now?.() ?? new Date();
  const maxRetries = deps.maxRetries ?? 1;
  const enforce = deps.review !== false;
  const routing = deps.routing ?? loadRouting();

  if (!LOCALES.includes(opts.locale))
    throw new ReportInputError(`unsupported locale ${opts.locale}`);

  // 1. Geo-Rule runs before any model call.
  const { matrix, region } = servedRegion(opts.country, chart.system);

  const allowed = TOPICS_BY_SYSTEM[chart.system];
  const requested = opts.topics?.length ? opts.topics : allowed;
  const bad = requested.filter((t) => !allowed.includes(t));
  if (bad.length)
    throw new ReportInputError(`topics not available for ${chart.system}: ${bad.join(", ")}`);
  const topics = TOPICS.filter((t) => requested.includes(t));
  if (opts.focus !== undefined && (chart.system !== "tarot" || !TAROT_FOCUS.includes(opts.focus))) {
    throw new ReportInputError(`focus is for tarot readings: one of ${TAROT_FOCUS.join(", ")}`);
  }

  const rules = compileRules(loadRuleSet(), [
    ...region.rule_groups,
    ...(METHOD_RULE_GROUPS[chart.system] ?? []),
  ]);
  // A 八字 reading reads its focused view (WP2.3), a 求籤 reading the lot without the rounds that
  // confirmed it; the other methods' facts are small already.
  const facts =
    chart.system === "bazi"
      ? baziView(
          modelFacts(chart),
          readingFocus(chart.facts, now.getUTCFullYear(), opts.question),
          { trend: true },
        )
      : chart.system === "qiuqian"
        ? qiuqianView(modelFacts(chart))
        : modelFacts(chart);
  const lot = chart.system === "qiuqian" ? lotBrief(chart, opts.locale) : undefined;
  const room = chart.system === "fengshui" ? fengshuiBrief(chart, opts.locale) : undefined;
  // Glossary keys are the canonical 简体 forms the engines emit; a lot's poem is 繁體 and a room's
  // principles are ids, so 求籤 and 风水 name their own.
  const glossary = glossaryFor(
    lot ? QIUQIAN_TERMS.join(" ") : room ? FENGSHUI_TERMS.join(" ") : JSON.stringify(facts),
    opts.locale,
  );
  const chartSummary = factsLayer(chart, opts.locale, now.getUTCFullYear());
  const providerFor = (agent: AgentName) => {
    const route = routeFor(routing, agent, opts.locale);
    const provider = deps.providers[route.provider];
    if (!provider) throw new Error(`provider "${route.provider}" not configured`);
    return { route, provider };
  };

  const termFixes: string[] = [];
  let dropped = 0;
  const reasons: string[] = [];
  const traces: AgentTrace[] = [];
  const ruleViolations: Violation[] = [];
  let status: ReportStatus = "passed";
  let review: GuardOutput | undefined;

  // 2. The 八字 trend chart is the engine's (since v2.0.0): no model scores it.
  const trend = chart.system === "bazi" ? trendLayer(chart, topics, opts.locale) : undefined;

  // Each method reads and writes its actions with its own prompts (rule 8, METHOD_PROMPTS).
  const prompts = METHOD_PROMPTS[chart.system];
  const tarot = chart.system === "tarot";
  const spread = tarot ? spreadBrief(chart, opts.locale) : undefined;
  const maxParagraphs = (t: Topic) => (t === "tarot_cards" && spread ? spread.cards.length : 4);
  // A tarot, 求籤 or 风水 reading's actions follow its advice (v2.3.0, v4.3.0, v4.4.0); other methods
  // act on every topic.
  const advice: Topic | undefined = tarot
    ? "tarot_advice"
    : lot
      ? "qiuqian_advice"
      : room
        ? "fengshui_advice"
        : undefined;
  const actionTopics: Topic[] = advice && topics.includes(advice) ? [advice] : topics;
  const narrative = await runAgent<NarrativeOutput>({
    agent: "narrative",
    prompt: prompts.narrative,
    ...providerFor("narrative"),
    schema: narrativeSchema(topics),
    payload: {
      topics,
      system: chart.system,
      ...(spread && { cards: spread.cards.length }),
      ...(lot && { lines: lot.lines.length }),
      ...(room && { principles: room.principles.length }),
    },
    maxRetries,
    enforce,
    onProgress: deps.onProgress,
    user: (feedback) =>
      spread
        ? tarotUser({
            facts,
            spread,
            topics,
            locale: opts.locale,
            glossary,
            question: opts.question,
            focus: opts.focus,
            context: opts.context,
            today: todayLine(now),
            feedback,
          })
        : lot
          ? qiuqianUser({
              facts,
              lot,
              topics,
              locale: opts.locale,
              glossary,
              question: opts.question,
              context: opts.context,
              today: todayLine(now),
              feedback,
            })
          : room
            ? fengshuiUser({
                facts,
                room,
                topics,
                locale: opts.locale,
                glossary,
                description: opts.question,
                context: opts.context,
                today: todayLine(now),
                feedback,
              })
            : narrativeUser({
                system: chart.system,
                facts,
                provenance: chart.provenance.filter((p) => resolvePointer(facts, p.path)),
                topics,
                locale: opts.locale,
                glossary,
                question: opts.question,
                context: opts.context,
                today: todayLine(now),
                feedback,
              }),
    check: (data) => {
      const feedback: string[] = [];
      let ungrounded = 0;
      const sections = data.sections.map((s) => ({
        topic: s.topic,
        ...(s.summary && { summary: normalizeTerms(s.summary, opts.locale).text }),
        // 逐张解读 has one paragraph per card (ten for a Celtic Cross); other sections up to four.
        paragraphs: s.paragraphs.slice(0, maxParagraphs(s.topic)).flatMap((p) => {
          const { text, fixes } = normalizeTerms(p.text, opts.locale);
          termFixes.push(...fixes);
          const refs = p.fact_refs.filter((r) => resolvePointer(facts, r));
          if (refs.length === 0) {
            ungrounded++;
            return [];
          }
          // 风水 rests on simplified rules only (the owner's spec): no paragraph claims more.
          const source_level = room ? "simplified_rule" : p.source_level;
          return [{ ...p, text, fact_refs: refs, source_level }];
        }),
      }));
      if (ungrounded) {
        feedback.push(`${ungrounded} paragraph(s) cited no existing chart_facts path in fact_refs`);
      }
      const missing = topics.filter(
        (t) => !sections.some((s) => s.topic === t && s.paragraphs.length),
      );
      if (missing.length) feedback.push(`missing topics: ${missing.join(", ")}`);
      if (spread && topics.includes("tarot_cards")) {
        const read = new Set(
          sections.find((s) => s.topic === "tarot_cards")?.paragraphs.flatMap((p) => p.fact_refs),
        );
        const unread = spread.cards.map((c) => c.path).filter((p) => !read.has(p));
        if (unread.length)
          feedback.push(
            `tarot_cards must read every card in dealing order; not read: ${unread.join(", ")}`,
          );
      }
      if (lot && topics.includes("qiuqian_poem")) {
        const read = new Set(
          sections.find((s) => s.topic === "qiuqian_poem")?.paragraphs.flatMap((p) => p.fact_refs),
        );
        const unread = lot.lines.map((l) => l.path).filter((p) => !read.has(p));
        if (unread.length)
          feedback.push(`qiuqian_poem must read all four lines; not cited: ${unread.join(", ")}`);
      }
      dropped = ungrounded;
      const value = { sections: sections.filter((s) => s.paragraphs.length) };
      return {
        value,
        feedback,
        ...scanTexts(
          value.sections.flatMap((s) => [
            ...(s.summary ? [s.summary] : []),
            ...s.paragraphs.map((p) => p.text),
          ]),
          rules,
        ),
      };
    },
  });
  traces.push(narrative.trace);

  let actions: ActionOutput | undefined;
  if (narrative.ok && narrative.value.sections.length === 0) {
    status = "manual_review";
    reasons.push("narrative: no grounded paragraphs");
  } else if (!narrative.ok) {
    status = narrative.block.length ? "blocked" : "manual_review";
    reasons.push(narrative.reason);
    ruleViolations.push(...narrative.block);
  } else {
    ruleViolations.push(...narrative.review, ...narrative.block);

    // 3. Action
    const action = await runAgent<ActionOutput>({
      agent: "action",
      prompt: prompts.action,
      ...providerFor("action"),
      schema: actionSchema(actionTopics),
      payload: { topics: actionTopics },
      maxRetries,
      enforce,
      onProgress: deps.onProgress,
      user: (feedback) =>
        actionUser({
          interpretation: narrative.value.sections,
          chartSummary,
          locale: opts.locale,
          glossary,
          context: opts.context,
          today: todayLine(now),
          feedback,
        }),
      check: (data) => {
        const list = data.actions.map((a) => {
          const { text, fixes } = normalizeTerms(a.text, opts.locale);
          termFixes.push(...fixes);
          return { ...a, text };
        });
        const value = {
          actions: list
            .filter((a) => actionTopics.includes(a.topic))
            .slice(0, advice ? 5 : topics.length * 3),
        };
        return {
          value,
          feedback: [],
          ...scanTexts(
            value.actions.map((a) => a.text),
            rules,
          ),
        };
      },
    });
    traces.push(action.trace);

    if (!action.ok) {
      status = action.block.length ? "blocked" : "manual_review";
      reasons.push(action.reason);
      ruleViolations.push(...action.block);
    } else {
      actions = action.value;
      ruleViolations.push(...action.review, ...action.block);

      // 4. Model review layer — only for drafts the rule layer already passed,
      //    and only while review is on.
      // The trend chart is the engine's (no model text), so it isn't part of the draft.
      const draft = {
        interpretation: narrative.value.sections,
        actions: actions.actions,
      };
      const guard = !enforce
        ? undefined
        : await runAgent<GuardOutput>({
            agent: "guard",
            ...providerFor("guard"),
            schema: guardSchema,
            payload: draft,
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
                draft,
                context: opts.context,
                today: todayLine(now),
              }),
            check: (value) => ({ value, feedback: [], block: [], review: [] }),
          });
      if (guard) {
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
      }
      if (enforce && status === "passed" && ruleViolations.some((v) => v.action === "review")) {
        status = "manual_review";
        reasons.push("rule layer: review-level patterns present");
      }
    }
  }

  const labelRequired = region.ai_disclosure.visible_label === "required";
  const interpretation = narrative.ok ? narrative.value.sections : narrative.held?.sections;
  if (!(narrative.ok && narrative.value.sections.length)) actions = undefined;
  const report: Report = {
    report_id: deps.newId?.() ?? randomUUID(),
    status,
    reasons,
    created_at: now.toISOString(),
    locale: opts.locale,
    region: opts.country.toUpperCase(),
    topics,
    chart: {
      system: chart.system,
      input_digest: chart.input_digest,
      engine_version: chart.engine.version,
      schema_version: chart.schema_version,
    },
    ai_disclosure: {
      generated: true,
      model: [...new Set(traces.map((t) => t.model))].join(","),
      prompt_version: traces.map((t) => t.prompt_version).join(","),
      label_required: labelRequired,
      generated_at: now.toISOString(),
    },
    compliance: {
      geo_matrix_version: matrix.matrix_version,
      rule_violations: ruleViolations,
      ...(review && { review }),
      term_fixes: [...new Set(termFixes)],
      dropped_ungrounded: dropped,
    },
    agents: traces,
  };
  const candidate = interpretation && {
    facts: chartSummary,
    interpretation,
    actions: actions?.actions ?? [],
    expectation: expectationLayer(opts.locale, labelRequired, chart.system),
    ...(trend && { trend }),
  };
  if (status === "passed" && candidate && actions) {
    report.layers = candidate;
  } else {
    if (candidate) report.held_layers = candidate;
    if (opts.includeDraft) report.draft = { interpretation, actions: actions?.actions };
  }
  return report;
}
