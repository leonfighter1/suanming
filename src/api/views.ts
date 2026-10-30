/**
 * What the API shows of its records (S28 Phase D): each response's view, without the drafts, traces and rule details
 * that stay internal, and what a reviewer sees in 内容审核's list. One home for the server, its route modules
 * (routes/*.ts) and the app's fixtures (scripts/app-assets.ts).
 */
import { INQUIRY_MAX_QUESTIONS } from "../ai/index.js";
import type { ChartFact } from "../chart-fact/index.js";
import { HttpError } from "../http/util.js";
import type { PointsEntry } from "../points/index.js";
import type {
  FollowUpRecord,
  InquiryRecord,
  LifeReportRecord,
  RemedyRecord,
  ReportRecord,
  ReviewDecision,
} from "./store.js";

/** Short, locale-neutral description of a chart for history lists. */
export function chartSummary(fact: ChartFact) {
  const f = fact.facts as Record<string, unknown>;
  if (fact.system === "bazi") {
    const p = f.pillars as Record<string, { gan: string; zhi: string }>;
    return {
      system: "bazi",
      four_pillars: ["year", "month", "day", "hour"].map((k) => p[k]!.gan + p[k]!.zhi).join(" "),
      civil_local: (f.time_basis as { civil_local: string }).civil_local,
    };
  }
  if (fact.system === "tarot") {
    return {
      system: "tarot",
      spread: f.spread_id as string,
      cards: (f.cards as { card_id: string; reversed: boolean }[]).map((c) => ({
        card_id: c.card_id,
        reversed: c.reversed,
      })),
    };
  }
  if (fact.system === "qiuqian") {
    const lot = f.lot as { n: number; ganzhi: string };
    return { system: "qiuqian", lot_set: f.lot_set as string, lot: lot.n, ganzhi: lot.ganzhi };
  }
  if (fact.system === "fengshui") {
    return {
      system: "fengshui",
      room: f.room as string,
      ...(typeof f.facing === "string" && { facing: f.facing }),
    };
  }
  if (fact.system === "naming") {
    const surname = f.surname as { "zh-Hant": string; "zh-Hans": string };
    const first = (f.candidates as { given: Record<string, string> }[])[0];
    return {
      system: "naming",
      surname,
      ...(first && { first: first.given }),
    };
  }
  if (fact.system === "liuyao") {
    type Hex = { id: string; full_name: { "zh-Hant": string; "zh-Hans": string } };
    const changed = f.changed as Hex | undefined;
    return {
      system: "liuyao",
      mode: f.mode as string,
      primary: (f.primary as Hex).full_name,
      ...(changed && { changed: changed.full_name }),
    };
  }
  return { system: fact.system };
}

/** What the user may see of a report. Drafts, traces and rule details stay internal. */
export function publicReport(r: ReportRecord) {
  const base = {
    report_id: r.id,
    // The reading's chart, so a reading page can show it (a tarot spread, v2.4.0).
    chart_id: r.chart_id,
    status: r.status,
    created_at: r.created_at,
    updated_at: r.updated_at,
    locale: r.locale,
    topics: r.topics,
  };
  if (r.status === "pending") return r.progress ? { ...base, progress: r.progress } : base;
  if (r.status === "failed") return { ...base, message: "generation failed; please retry" };
  const rep = r.report!;
  if (r.status !== "passed") {
    return { ...base, message: "this report is held for review and is not available yet" };
  }
  return {
    ...base,
    layers: rep.layers,
    ai_disclosure: rep.ai_disclosure,
    ...(r.mail && { mail: r.mail }),
    // 深度分析 (v10.0.0): the conversation this reading read, at /v1/inquiries/{id}.
    ...(r.inquiry_id && { inquiry_id: r.inquiry_id }),
  };
}

/**
 * What the user may see of a 深度分析 (v10.0.0): their goal, the master's turns with their answers, how many questions
 * it plans, and once it is done its last words and what it understood they most want to know.
 */
export function publicInquiry(r: InquiryRecord) {
  const done = r.status === "ready" || r.status === "closed";
  return {
    inquiry_id: r.id,
    chart_id: r.chart_id,
    status: r.status,
    created_at: r.created_at,
    updated_at: r.updated_at,
    goal: r.goal,
    max_questions: INQUIRY_MAX_QUESTIONS,
    ...(r.planned !== undefined && { planned: r.planned }),
    turns: r.turns.map((t) => ({
      say: t.say,
      question: t.question,
      ...(t.answer !== undefined && { answer: t.answer }),
    })),
    ...(done && r.closing && { closing: r.closing }),
    ...(done && r.understanding && { understanding: r.understanding }),
    ...(r.report_id && { report_id: r.report_id }),
    ...(r.status === "thinking" && r.progress && { progress: r.progress }),
    ...(r.status === "failed" && {
      message: "the master could not ask its first question; try again, or read without 深度分析",
    }),
    ...(r.ai_disclosure && { ai_disclosure: r.ai_disclosure }),
  };
}

/**
 * Price of one 破除運勢 plan. TODO(Phase 4 payments): take this from the store
 * product catalogue and verify the purchase receipt before generating.
 */
export const REMEDY_PRICE = { amount: 18, currency: "HKD" } as const;

export function publicRemedy(r: RemedyRecord) {
  const base = {
    remedy_id: r.id,
    report_id: r.report_id,
    topic: r.topic,
    status: r.status,
    created_at: r.created_at,
    updated_at: r.updated_at,
    /** Preloaded but not bought: ready to unlock, content withheld. */
    locked: !r.unlocked,
    ...(r.payment && { payment: r.payment }),
  };
  if (r.status === "pending") return r.progress ? { ...base, progress: r.progress } : base;
  if (r.status === "failed") return { ...base, message: "generation failed; please retry" };
  if (r.status !== "passed" || !r.remedy?.content) {
    return { ...base, message: "this plan is held for review and is not available yet" };
  }
  return r.unlocked ? { ...base, content: r.remedy.content } : base;
}

/**
 * What the user sees of a 积分 change (v11.0.0): what it was and what it left. A charge's measured cost in dollars is
 * shown while 充值 is simulated (development), for the owner's 「提交问题给花费了多少」; never once real money pays.
 */
export function publicPointsEntry(e: PointsEntry, showCost: boolean) {
  return {
    id: e.id,
    kind: e.kind,
    points: e.points,
    balance: e.balance,
    created_at: e.created_at,
    ...(e.for && { for: e.for }),
    ...(e.basis && { basis: e.basis }),
    ...(showCost && e.usd !== undefined && { usd: e.usd }),
    ...(e.pack && { pack: e.pack }),
    ...(e.reason && { reason: e.reason }),
    ...(e.note && { note: e.note }),
  };
}

/**
 * 400 question_required (v11.1.0, the owner: 「必须要有所求才能去求」): a 塔罗, 求签 or 算卦 draw, or its reading, with
 * nothing asked.
 */
export const questionRequired = () =>
  new HttpError(
    400,
    "ask your question first: 塔罗, 求签 and 算卦 are drawn for a question",
    "question_required",
  );

/** A 充值 pack as the app offers it: its bonus over 100 积分 a 元, in percent (20元 = 2200: 10). */
export function publicPack(p: { yuan: number; points: number }) {
  return { ...p, bonus_percent: Math.round((p.points / (p.yuan * 100) - 1) * 100) };
}

/** What the user may see of a 一生运势报告. */
export function publicLifeReport(r: LifeReportRecord) {
  const base = {
    life_report_id: r.id,
    chart_id: r.chart_id,
    status: r.status,
    locale: r.locale,
    created_at: r.created_at,
    updated_at: r.updated_at,
  };
  if (r.status === "pending") return r.progress ? { ...base, progress: r.progress } : base;
  if (r.status === "failed") return { ...base, message: "generation failed; please retry" };
  if (r.status !== "passed" || !r.life?.layers) {
    return { ...base, message: "this report is held for review and is not available yet" };
  }
  return {
    ...base,
    facts: r.life.facts,
    layers: r.life.layers,
    ai_disclosure: r.life.ai_disclosure,
    ...(r.mail && { mail: r.mail }),
  };
}

/** What the user may see of a 追问 (v7.0.0): the question, where it stands, and the answer once it has passed. */
export function publicFollowUp(r: FollowUpRecord) {
  const base = {
    followup_id: r.id,
    parent: r.parent,
    question: r.question,
    status: r.status,
    created_at: r.created_at,
    updated_at: r.updated_at,
  };
  if (r.status === "pending") return r.progress ? { ...base, progress: r.progress } : base;
  if (r.status === "failed") return { ...base, message: "generation failed; please ask again" };
  if (r.status !== "passed" || !r.followup?.answer) {
    return { ...base, message: "this answer is held for review and is not available yet" };
  }
  return { ...base, answer: r.followup.answer, ai_disclosure: r.followup.ai_disclosure };
}

/**
 * Why a report or plan was held, for the server log: status reasons, rule ids and
 * guard categories only. Never quotes (they can contain the user's own words).
 */
export function heldWhy(r: {
  reasons: string[];
  compliance: {
    rule_violations: { rule_id: string }[];
    review?: { violations: { category: string }[] };
  };
}): string {
  const rules = [...new Set(r.compliance.rule_violations.map((v) => v.rule_id))];
  const guard = [...new Set((r.compliance.review?.violations ?? []).map((v) => v.category))];
  return [
    r.reasons.join("; "),
    rules.length && `rules ${rules.join(",")}`,
    guard.length && `guard ${guard.join(",")}`,
  ]
    .filter(Boolean)
    .join(" | ");
}

export type HeldKind = "report" | "remedy" | "life_report" | "followup";

/** What a reviewer sees in the list: why it was held, never the user's identity. */
export function reviewSummary(
  kind: HeldKind,
  r: {
    id: string;
    owner: string;
    status: string;
    created_at: string;
    updated_at: string;
    review?: ReviewDecision;
  },
  out?: {
    reasons: string[];
    compliance: {
      rule_violations: { rule_id: string; match: string; action: string }[];
      review?: { violations: { category: string; quote: string; reason: string }[] };
    };
  },
  extra: Record<string, unknown> = {},
) {
  return {
    kind,
    id: r.id,
    status: r.status,
    created_at: r.created_at,
    updated_at: r.updated_at,
    owner: r.owner.slice(0, 8),
    ...extra,
    reasons: out?.reasons ?? [],
    rule_hits: (out?.compliance.rule_violations ?? []).map((v) => ({
      rule_id: v.rule_id,
      match: v.match,
      action: v.action,
    })),
    guard: out?.compliance.review?.violations ?? [],
    ...(r.review && { decision: r.review }),
  };
}
