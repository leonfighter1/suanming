/**
 * 深度分析 (S19, v10.0.0; the owner 2026-10-29): before a reading, the master asks the user about their situation, one
 * question at a time, from what the result shows and what they want to know, and infers from every answer:
 * 「在进行ai分析结果的时候会根据卦象或者推算结果再去问对方问题，越多了解越好 … 要根据用户的输入做出合理推断」. Fewer questions for a smooth
 * result, more for a hard one, never more than six (「对于比较不顺的命盘可以多问几个问题，顺的命盘少问一些，最多不超过6个问题」). The
 * reading then reads the whole conversation (ReportOptions.inquiry).
 *
 * Its own pipeline (hard rule 2): Geo-Rule → the method's inquiry agent → grounding, the faithfulness checks and the
 * rule layer → the guard while review is on, with the retry loop every agent has. What the master says about the result
 * cites the facts it rests on; a path that doesn't exist is dropped, and a text naming a card, a line or a 干支 the
 * result doesn't have is sent back, then left out.
 */
import type { ChartFact } from "../chart-fact/index.js";
import {
  compileRules,
  contentBlockLine,
  loadRuleSet,
  type Violation,
} from "../compliance/index.js";
import type { UserContext } from "./context.js";
import { disclosureOf, guardVerdict, providerOf } from "./envelope.js";
import { checkTexts } from "./faithfulness.js";
import {
  METHOD_RULE_GROUPS,
  readingInputs,
  ReportInputError,
  resolvePointer,
  runAgent,
  scanTexts,
  servedRegion,
  type AgentTrace,
  type PipelineDeps,
  type ReportStatus,
} from "./pipeline.js";
import { guardUser, inquiryUser, METHOD_PROMPTS, todayLine } from "./prompts.js";
import { loadRouting } from "./routing.js";
import { guardSchema, inquirySchema } from "./schemas.js";
import { LOCALES, normalizeTerms, type Locale } from "./terms.js";
import type { AgentName, GuardOutput, TarotFocus } from "./types.js";

/** The most questions a 深度分析 asks (the owner: 最多不超过6个问题). */
export const INQUIRY_MAX_QUESTIONS = 6;
/** A goal's length, in characters: shorter is no goal (the owner: 一定要给出个明确的目标). */
export const INQUIRY_GOAL_MIN = 4;
export const INQUIRY_GOAL_MAX = 300;
/** An answer's length, in characters. */
export const INQUIRY_ANSWER_MAX = 300;

/** One turn: what the master said, its question, and the user's answer once given. */
export interface InquiryTurn {
  say: string;
  question: string;
  fact_refs: string[];
  answer?: string;
}

/** What a turn is asked from: the goal, what the reading was asked for, and every earlier turn, each answered. */
export interface InquiryState {
  goal: string;
  /** The reading's own question when it isn't the goal (a tarot, 求籤 or 算卦 question; 风水's room description). */
  question?: string;
  focus?: TarotFocus;
  context?: UserContext;
  turns: InquiryTurn[];
  /** How many questions the master planned on its first turn (1–6). */
  planned?: number;
}

/** The master's turn as the model writes it. */
interface InquiryOutput {
  say: string;
  question: string;
  done: boolean;
  planned: number;
  focus: string;
  fact_refs: string[];
}

export interface InquiryStep {
  status: ReportStatus;
  reasons: string[];
  locale: Locale;
  created_at: string;
  /** The master's turn; only for "passed". */
  turn?: { say: string; question: string; fact_refs: string[] };
  /** Kept when held, for the review console; never shown unless released. */
  held_turn?: { say: string; question: string; fact_refs: string[] };
  /** True when the master asks nothing more. */
  done: boolean;
  /** How many questions the master plans, 1–6. */
  planned: number;
  /** What the user most wants to know, as the master understands it now. */
  focus: string;
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
    /** fact_refs that named no existing path, dropped. */
    dropped_refs: number;
    /** What the faithfulness checks found in dropped texts (kinds and details, never the user's words). */
    unfaithful: string[];
  };
  agents: AgentTrace[];
}

/** A 深度分析 that can't be held (the API answers 400 before it gets here). */
export class InquiryInputError extends ReportInputError {}

/** The methods whose readings take a 深度分析: each asks with its own prompt (rule 8). */
export function inquiryAvailable(chart: ChartFact): boolean {
  return METHOD_PROMPTS[chart.system].inquiry !== undefined;
}

/** A goal fit to read for: trimmed, at least INQUIRY_GOAL_MIN characters, at most INQUIRY_GOAL_MAX. */
export function inquiryGoal(goal: unknown): string | undefined {
  const g = typeof goal === "string" ? goal.trim() : "";
  const n = [...g].length;
  return n >= INQUIRY_GOAL_MIN && n <= INQUIRY_GOAL_MAX ? g : undefined;
}

/** The same question twice, whatever its spacing and punctuation. */
const same = (a: string) => a.replace(/[\s\p{P}]/gu, "");

export async function generateInquiryTurn(
  chart: ChartFact,
  state: InquiryState,
  opts: { locale: Locale; country: string },
  deps: PipelineDeps,
): Promise<InquiryStep> {
  const now = deps.now?.() ?? new Date();
  const enforce = deps.review !== false;
  const routing = deps.routing ?? loadRouting();
  const { locale } = opts;
  if (!LOCALES.includes(locale)) throw new InquiryInputError(`unsupported locale ${locale}`);
  if (chart.system === "liuyao" && locale === "en") {
    throw new InquiryInputError("算卦 readings are in Chinese: zh-Hans or zh-Hant");
  }
  const prompt = METHOD_PROMPTS[chart.system].inquiry;
  if (!prompt) throw new InquiryInputError(`${chart.system} readings have no 深度分析`);
  const goal = inquiryGoal(state.goal);
  if (!goal) {
    throw new InquiryInputError(
      `goal must be ${INQUIRY_GOAL_MIN}–${INQUIRY_GOAL_MAX} characters: what the user wants to know`,
    );
  }
  // After the sixth answer the master still has its last word (what the user wants to know may have shifted with it),
  // but asks nothing more.
  const asked = state.turns.length;
  if (asked > INQUIRY_MAX_QUESTIONS) {
    throw new InquiryInputError(`a 深度分析 asks at most ${INQUIRY_MAX_QUESTIONS} questions`);
  }
  if (state.turns.some((t) => !t.answer?.trim())) {
    throw new InquiryInputError("every earlier question needs its answer first");
  }

  // 1. Geo-Rule runs before any model call: the reading's method in the account's region.
  const { matrix, region } = servedRegion(opts.country, chart.system);
  const rules = compileRules(loadRuleSet(), [
    ...region.rule_groups,
    ...(METHOD_RULE_GROUPS[chart.system] ?? []),
  ]);
  const regionLine = contentBlockLine(region);
  const providerFor = (agent: AgentName) => providerOf(routing, deps.providers, agent, locale);

  // 2. What the reading will read: its own view of the chart and its brief.
  const { facts, brief, glossary } = readingInputs(
    chart,
    locale,
    now,
    [state.question, goal].filter(Boolean).join(" "),
  );
  const readingQuestion =
    state.question && same(state.question) !== same(goal)
      ? {
          tag:
            chart.system === "fengshui"
              ? ("user_description" as const)
              : ("user_question" as const),
          text: state.question,
        }
      : undefined;
  const conversation = state.turns.map((t) => ({
    say: t.say,
    question: t.question,
    answer: t.answer!.trim(),
  }));
  const before = new Set(state.turns.map((t) => same(t.question)));
  // The mock cites a path the result has, so its demo turn is grounded (real providers ignore the payload).
  const refs = [
    ...((
      {
        bazi: ["/pillars/day"],
        tarot: ["/cards/0"],
        qiuqian: ["/lot/poem/0"],
        liuyao: ["/primary"],
        fengshui: ["/principles/0"],
      } as Partial<Record<string, string[]>>
    )[chart.system] ?? []),
  ].filter((r) => resolvePointer(facts, r));

  const termFixes: string[] = [];
  const norm = (t: string) => {
    const { text, fixes } = normalizeTerms(t, locale);
    termFixes.push(...fixes);
    return text;
  };
  let droppedRefs = 0;
  const unfaithful: string[] = [];
  const traces: AgentTrace[] = [];
  const reasons: string[] = [];
  const ruleViolations: Violation[] = [];
  let status: ReportStatus = "passed";
  let review: GuardOutput | undefined;
  const today = todayLine(now);

  // 3. The inquiry agent.
  const out = await runAgent<InquiryOutput>({
    agent: "inquiry",
    prompt,
    ...providerFor("inquiry"),
    schema: inquirySchema,
    payload: { system: chart.system, refs, asked },
    maxRetries: deps.maxRetries ?? 1,
    enforce,
    onProgress: deps.onProgress,
    user: (feedback) =>
      inquiryUser({
        facts,
        ...(brief && { brief }),
        glossary,
        goal,
        ...(readingQuestion && { readingQuestion }),
        ...(state.focus && { focus: state.focus }),
        context: state.context,
        conversation,
        progress: {
          asked,
          ...(state.planned !== undefined && { planned: state.planned }),
          max: INQUIRY_MAX_QUESTIONS,
        },
        locale,
        today,
        feedback,
        regionLine,
      }),
    check: (data) => {
      const feedback: string[] = [];
      const found: string[] = [];
      const cited = data.fact_refs.filter((r) => resolvePointer(facts, r));
      droppedRefs = data.fact_refs.length - cited.length;
      const unfaithfulIn = (text: string) => {
        const issues = checkTexts(chart, [text], locale, now.toISOString());
        found.push(...issues.map((i) => `${i.kind}: ${i.detail}`));
        return issues.length > 0;
      };
      // What the master says about the result must be the result's: else it goes, and the turn is sent back.
      let say = norm(data.say.trim());
      if (say && unfaithfulIn(say)) say = "";
      let question = norm(data.question.trim());
      if (question && unfaithfulIn(question)) {
        question = "";
        feedback.push("the question named something the result doesn't have: ask from it alone");
      }
      if (question && before.has(same(question))) {
        question = "";
        feedback.push("that question was already asked: ask something new, or set done");
      }
      if ([...question].length > 80)
        feedback.push("question: one short question, at most about 40 characters");
      if ([...say].length > 200)
        feedback.push("say: one or two short sentences, at most about 80 characters");
      // The first turn asks: the user chose the 深度分析 to be asked.
      if (asked === 0 && (data.done || !question)) {
        feedback.push("this is the first turn: ask your first question, and set done false");
      }
      if (found.length) {
        feedback.push(
          ...found.map((f) => `not in this result's facts (${f}): say only what it shows`),
        );
      }
      unfaithful.splice(0, unfaithful.length, ...found);
      const done = data.done || !question || asked >= INQUIRY_MAX_QUESTIONS;
      const floor = Math.max(1, asked + (done ? 0 : 1));
      const planned = Math.min(
        INQUIRY_MAX_QUESTIONS,
        Math.max(floor, Number.isFinite(data.planned) ? Math.round(data.planned) : floor),
      );
      const focus = norm(data.focus.trim()).slice(0, 100);
      const value: InquiryOutput = {
        say,
        question: done ? "" : question,
        done,
        planned,
        focus,
        fact_refs: cited,
      };
      return {
        value,
        feedback,
        ...scanTexts([say, value.question, focus].filter(Boolean), rules),
      };
    },
  });
  traces.push(out.trace);

  if (!out.ok) {
    status = out.block.length ? "blocked" : "manual_review";
    reasons.push(out.reason);
    ruleViolations.push(...out.block);
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
              draft: { inquiry_goal: goal, inquiry_turn: out.value },
              context: state.context,
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

  const value = out.ok ? out.value : out.held;
  const turn = value && { say: value.say, question: value.question, fact_refs: value.fact_refs };
  return {
    status,
    reasons,
    locale,
    created_at: now.toISOString(),
    ...(status === "passed" && turn && { turn }),
    ...(status !== "passed" && turn && { held_turn: turn }),
    done: value?.done ?? true,
    planned: value?.planned ?? Math.max(1, asked),
    focus: value?.focus ?? "",
    ai_disclosure: disclosureOf(traces, region.ai_disclosure.visible_label === "required", now),
    compliance: {
      geo_matrix_version: matrix.matrix_version,
      rule_violations: ruleViolations,
      ...(review && { review }),
      term_fixes: [...new Set(termFixes)],
      dropped_refs: droppedRefs,
      unfaithful,
    },
    agents: traces,
  };
}
