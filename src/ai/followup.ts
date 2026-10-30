/**
 * 追问 (S13 WP13.2, the owner's request 2026-10-28): a follow-up question on a passed reading or 一生运势报告, answered
 * from what that reading rests on and what it already said. Its own pipeline (hard rule 2): Geo-Rule → the follow-up
 * agent → the rule layer → the guard, with the same retry loop as every agent.
 *
 * Not making things up (the owner: 「不能胡编乱造，一定要基于之前的回答和各个卦象所表达的东西」):
 * - every answer paragraph cites the facts it rests on (JSON pointers that must exist), or it is dropped and the answer
 *   sent back;
 * - the deterministic faithfulness checks (faithfulness.ts) read every answer: a paragraph naming a card, a line, a
 *   hexagram or a 干支 the reading doesn't have is dropped and the answer sent back;
 * - a question the reading can't answer gets `in_scope: false` and a reply that makes no claim about it.
 */
import type { ChartFact, SourceLevel } from "../chart-fact/index.js";
import {
  compileRules,
  contentBlockLine,
  loadRuleSet,
  type Violation,
} from "../compliance/index.js";
import type { UserContext } from "./context.js";
import { disclosureOf, guardVerdict, providerOf } from "./envelope.js";
import { checkTexts } from "./faithfulness.js";
import { lifeModelInput, type LifeReport } from "./life.js";
import {
  METHOD_RULE_GROUPS,
  paragraphTexts,
  readingInputs,
  ReportInputError,
  resolvePointer,
  runAgent,
  scanTexts,
  servedRegion,
  type AgentTrace,
  type PipelineDeps,
  type Report,
  type ReportStatus,
} from "./pipeline.js";
import { followupUser, guardUser, METHOD_PROMPTS, PROMPTS, todayLine } from "./prompts.js";
import { loadRouting } from "./routing.js";
import { followUpSchema, guardSchema } from "./schemas.js";
import { glossaryFor, normalizeTerms, type Locale } from "./terms.js";
import {
  CONCLUSION_LABELS,
  CONCLUSION_PARTS,
  TOPIC_LABELS,
  type AgentName,
  type GuardOutput,
  type Paragraph,
  type TarotFocus,
} from "./types.js";

/** Follow-ups per reading (each takes one from the daily AI caps). */
export const FOLLOWUP_LIMIT = 20;
/** A question's length, in characters. */
export const FOLLOWUP_QUESTION_MAX = 200;
/** How many earlier 追问 the model reads with a new one: the last six. */
export const FOLLOWUP_THREAD = 6;

export interface FollowUpAnswer {
  /** false: the reading can't answer this; the one paragraph says so and makes no claim. */
  in_scope: boolean;
  /** 1–3, each 术语 → 评论 → 例子 as a reading's paragraph (v6.2.0). */
  paragraphs: Paragraph[];
  /** 2–3 next questions this reading can answer (the owner: 持续给出后续问题). */
  suggestions: string[];
}

export interface FollowUp {
  status: ReportStatus;
  reasons: string[];
  locale: Locale;
  question: string;
  created_at: string;
  /** Only for "passed". */
  answer?: FollowUpAnswer;
  /** Kept when held, for the review console; never shown unless released. */
  held_answer?: FollowUpAnswer;
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
    /** What the faithfulness checks found in dropped paragraphs (kinds and details, never the user's words). */
    unfaithful: string[];
  };
  agents: AgentTrace[];
}

/** What a 追问 is about: a passed reading, or a passed 一生运势报告, with what the user told us for it. */
export type FollowUpParent =
  | {
      kind: "report";
      report: Report;
      /** The reading's own question (a tarot, 求籤 or 算卦 question; 风水's room description). */
      question?: string;
      focus?: TarotFocus;
      context?: UserContext;
    }
  | { kind: "life_report"; life: LifeReport; context?: UserContext };

/** One earlier 追问 on the same reading, passed. */
export interface FollowUpTurn {
  question: string;
  answer: FollowUpAnswer;
}

/** A 追问 that can't be asked (the API answers 400 before it gets here). */
export class FollowUpInputError extends ReportInputError {}

/** Methods that can be asked about: each has its own follow-up prompt (rule 8), and the 一生运势报告 has one. */
export function followUpAvailable(parent: FollowUpParent["kind"], chart: ChartFact): boolean {
  return parent === "life_report"
    ? chart.system === "bazi"
    : METHOD_PROMPTS[chart.system].followup !== undefined;
}

const words = (p: Pick<Paragraph, "term" | "text" | "example">) => ({
  ...(p.term && { term: p.term }),
  text: p.text,
  ...(p.example && { example: p.example }),
});

export async function generateFollowUp(
  chart: ChartFact,
  parent: FollowUpParent,
  question: string,
  thread: FollowUpTurn[],
  opts: { country: string },
  deps: PipelineDeps,
): Promise<FollowUp> {
  const now = deps.now?.() ?? new Date();
  const enforce = deps.review !== false;
  const routing = deps.routing ?? loadRouting();
  const asked = question.trim();
  if (!asked) throw new FollowUpInputError("question is required");
  if ([...asked].length > FOLLOWUP_QUESTION_MAX) {
    throw new FollowUpInputError(`question must be at most ${FOLLOWUP_QUESTION_MAX} characters`);
  }
  const life = parent.kind === "life_report";
  const done = life ? parent.life.layers : parent.report.layers;
  const passed = life ? parent.life.status : parent.report.status;
  if (passed !== "passed" || !done) throw new FollowUpInputError("the reading has not passed");
  if (!followUpAvailable(parent.kind, chart)) {
    throw new FollowUpInputError(`no follow-up questions for ${chart.system} readings`);
  }
  const locale = life ? parent.life.locale : parent.report.locale;
  const prompt = life ? PROMPTS.followup_life : METHOD_PROMPTS[chart.system].followup!;

  // 1. Geo-Rule runs before any model call: the reading's method in the account's region.
  const { matrix, region } = servedRegion(opts.country, chart.system);
  const rules = compileRules(loadRuleSet(), [
    ...region.rule_groups,
    ...(METHOD_RULE_GROUPS[chart.system] ?? []),
  ]);
  const regionLine = contentBlockLine(region);
  const providerFor = (agent: AgentName) => providerOf(routing, deps.providers, agent, locale);

  // 2. What the reading read, and what it said. A 八字 reading's view gains any year the 追问 names.
  const inputs = life
    ? undefined
    : readingInputs(chart, locale, now, [parent.question, asked].filter(Boolean).join(" "));
  const facts = life ? lifeModelInput(chart, locale) : inputs!.facts;
  const glossary = life ? glossaryFor(JSON.stringify(facts), locale) : inputs!.glossary;
  const reading = life
    ? (({ expectation: _e, ...rest }) => rest)(parent.life.layers!)
    : {
        sections: parent.report.layers!.interpretation.map((s) => ({
          topic: s.topic,
          label: TOPIC_LABELS[s.topic][locale],
          ...(s.summary && { summary: s.summary }),
          paragraphs: s.paragraphs.map(words),
        })),
        // 八字's 总结 (v9.3.0), by its parts' labels, in order.
        ...(parent.report.layers!.conclusion && {
          conclusion: CONCLUSION_PARTS.flatMap((p) => {
            const c = parent.report.layers!.conclusion![p];
            return c ? [{ part: CONCLUSION_LABELS[p][locale], text: c.text }] : [];
          }),
        }),
        actions: parent.report.layers!.actions.map((a) => a.text),
      };
  const earlier = thread.slice(-FOLLOWUP_THREAD).map((t) => ({
    question: t.question,
    in_scope: t.answer.in_scope,
    answer: t.answer.paragraphs.map(words),
  }));
  const before = new Set(thread.map((t) => t.question.trim()));
  before.add(asked);
  // The mock answers with a path the reading itself cited (real providers ignore the payload).
  const refs = life
    ? parent.life.layers!.methods.fact_refs.slice(0, 1)
    : (parent.report.layers!.interpretation[0]?.paragraphs[0]?.fact_refs.slice(0, 1) ?? []);

  const termFixes: string[] = [];
  const norm = (t: string) => {
    const { text, fixes } = normalizeTerms(t, locale);
    termFixes.push(...fixes);
    return text;
  };
  let dropped = 0;
  const unfaithful: string[] = [];
  const traces: AgentTrace[] = [];
  const reasons: string[] = [];
  const ruleViolations: Violation[] = [];
  let status: ReportStatus = "passed";
  let review: GuardOutput | undefined;
  const today = todayLine(now);

  // 3. The follow-up agent.
  const out = await runAgent<FollowUpAnswer>({
    agent: "followup",
    prompt,
    ...providerFor("followup"),
    schema: followUpSchema,
    payload: { system: life ? "life" : chart.system, refs },
    maxRetries: deps.maxRetries ?? 1,
    enforce,
    onProgress: deps.onProgress,
    user: (feedback) =>
      followupUser({
        factsTag: life ? "life_facts" : "chart_facts",
        facts,
        ...(inputs?.brief && { brief: inputs.brief }),
        glossary,
        ...(!life &&
          parent.question && {
            readingQuestion: {
              tag: chart.system === "fengshui" ? "user_description" : "user_question",
              text: parent.question,
            },
          }),
        ...(!life && parent.focus && { focus: parent.focus }),
        context: parent.context,
        reading,
        thread: earlier,
        question: asked,
        locale,
        today,
        feedback,
        regionLine,
      }),
    check: (data) => {
      const feedback: string[] = [];
      let ungrounded = 0;
      const found: string[] = [];
      const paragraphs = data.paragraphs.slice(0, 3).flatMap((p) => {
        const cited = p.fact_refs.filter((r) => resolvePointer(facts, r));
        if (data.in_scope && cited.length === 0) {
          ungrounded++;
          return [];
        }
        const para: Paragraph = {
          ...(p.term?.trim() && { term: norm(p.term.trim()) }),
          text: norm(p.text),
          ...(p.example?.trim() && { example: norm(p.example.trim()) }),
          // 风水 rests on simplified rules only (the owner's spec), as its reading does.
          source_level: (chart.system === "fengshui" && !life
            ? "simplified_rule"
            : p.source_level) as SourceLevel,
          fact_refs: cited,
        };
        const issues = checkTexts(chart, paragraphTexts(para), locale, now.toISOString());
        if (issues.length) {
          found.push(...issues.map((i) => `${i.kind}: ${i.detail}`));
          return [];
        }
        return [para];
      });
      const suggestions = [...new Set(data.suggestions.map((s) => norm(s.trim())).filter(Boolean))]
        .filter((s) => [...s].length <= 40 && !before.has(s))
        .filter((s) => checkTexts(chart, [s], locale, now.toISOString()).length === 0)
        .slice(0, 3);
      if (ungrounded) {
        feedback.push(`${ungrounded} paragraph(s) cited no existing chart_facts path in fact_refs`);
      }
      if (found.length) {
        feedback.push(
          ...found.map((f) => `not in this reading's facts (${f}): answer only from them`),
        );
      }
      if (paragraphs.length === 0)
        feedback.push("no paragraph answered the question from the facts");
      dropped = ungrounded;
      unfaithful.splice(0, unfaithful.length, ...found);
      const value: FollowUpAnswer = { in_scope: data.in_scope, paragraphs, suggestions };
      return {
        value,
        feedback,
        ...scanTexts([...paragraphs.flatMap(paragraphTexts), ...suggestions], rules),
      };
    },
  });
  traces.push(out.trace);

  if (!out.ok) {
    status = out.block.length ? "blocked" : "manual_review";
    reasons.push(out.reason);
    ruleViolations.push(...out.block);
  } else if (out.value.paragraphs.length === 0) {
    status = "manual_review";
    reasons.push("followup: no grounded paragraphs");
  } else {
    ruleViolations.push(...out.review, ...out.block);
    // 4. The guard, only while review is on.
    const guard = !enforce
      ? undefined
      : await runAgent<GuardOutput>({
          agent: "guard",
          ...providerFor("guard"),
          schema: guardSchema,
          payload: out.value,
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
              draft: { follow_up_question: asked, answer: out.value },
              context: parent.context,
              today,
            }),
          check: (value) => ({ value, feedback: [], block: [], review: [] }),
        });
    if (guard) {
      const verdict = guardVerdict(guard, traces, reasons);
      if (verdict.held) status = "manual_review";
      if (verdict.review) review = verdict.review;
    }
    if (enforce && status === "passed" && ruleViolations.some((v) => v.action === "review")) {
      status = "manual_review";
      reasons.push("rule layer: review-level patterns present");
    }
  }

  const answer = out.ok ? out.value : out.held;
  return {
    status,
    reasons,
    locale,
    question: asked,
    created_at: now.toISOString(),
    ...(status === "passed" && answer && { answer }),
    ...(status !== "passed" && answer && { held_answer: answer }),
    ai_disclosure: disclosureOf(traces, region.ai_disclosure.visible_label === "required", now),
    compliance: {
      geo_matrix_version: matrix.matrix_version,
      rule_violations: ruleViolations,
      ...(review && { review }),
      term_fixes: [...new Set(termFixes)],
      dropped_ungrounded: dropped,
      unfaithful,
    },
    agents: traces,
  };
}
