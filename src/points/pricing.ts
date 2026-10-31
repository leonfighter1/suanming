/**
 * 积分 (v11.0.0, tech plan S20): what an AI request costs, in points. The owner's terms (2026-10-29): 10元 = 1000 积分
 * and more per 元 in the larger packs; a gross margin of at least 50% (「保证利润在50%基础以上」); every request paid by
 * what it really cost (「看看有没有办法知道当前的提交问题给花费了多少，以此反馈到积分上去」).
 *
 * A request is priced before it runs from its estimate in config/points.json, at the list price of the model its
 * main step is routed to now (so ACTIVE_AI_MODEL moves every price), and that price is held. When it has run it is
 * charged its measured tokens, never more than was held; while the mock answers (no tokens reported) it is charged
 * its estimate, so the flow can be tried without spending (the owner's 模拟策略).
 */
import { readFileSync } from "node:fs";
import {
  costUsd,
  modelInfo,
  type AgentName,
  type AgentTrace,
  type Price,
  type RoutingTable,
} from "../ai/index.js";
import type { ChartFact, ChartSystem } from "../chart-fact/index.js";

export interface Tokens {
  input: number;
  output: number;
}

/** A request's tokens, all its steps; `per_topic` and `per_card` add for each topic asked (八字) or card drawn (塔罗). */
export interface Estimate extends Tokens {
  per_topic?: Partial<Tokens>;
  per_card?: Partial<Tokens>;
}

/** A 充值 pack: what is paid, in 元, and the 积分 it brings. */
export interface Pack {
  yuan: number;
  points: number;
}

export interface PointsConfig {
  version: number;
  packs: Pack[];
  pricing: {
    /** CNY per US dollar, cautious. */
    usd_cny: number;
    /** The gross margin every price keeps on the cheapest 积分. */
    margin: number;
    /** What the payment service takes of a payment (微信 / 支付宝). */
    payment_fee: number;
    vat: number;
    /** Prices a model without a list price (DeepSeek). */
    reference_model: string;
  };
  /** What is held while a request runs: its quote times this. */
  hold_factor: number;
  /** What each dev account starts with, given once. */
  dev_grant: number;
  estimates: {
    report: Record<ChartSystem, Estimate>;
    life_report: Estimate;
    /** By the reading's method, `life_report` for a 一生运势报告's, else `default`. */
    followup: Record<string, Estimate> & { default: Estimate };
    /** By the reading's method, else `default`. */
    remedy: Record<string, Estimate> & { default: Estimate };
    /** The 深度分析's 统一收费 covers `typical_turns` turns and one `largest_turn`. */
    inquiry: { turn: Tokens; largest_turn: Tokens; typical_turns: number };
  };
}

export function loadPointsConfig(
  path = new URL("../../config/points.json", import.meta.url),
): PointsConfig {
  return JSON.parse(readFileSync(path, "utf8")) as PointsConfig;
}

/** What an AI request is, as the ledger says what a charge paid for. */
export type ChargeKind = "report" | "life_report" | "followup" | "inquiry" | "remedy";

/** Each request's main step: the model its route names prices the request. */
const MAIN_STEP: Record<ChargeKind, AgentName> = {
  report: "narrative",
  life_report: "life_methods",
  followup: "followup",
  inquiry: "inquiry",
  remedy: "remedy",
};

/** A pack the owner's terms allow: a price above 0, whole 积分, at least 100 of them per 元 (10元 = 1000 积分). */
export const packFits = (p: Pack) =>
  p.yuan > 0 && Number.isInteger(p.points) && p.points >= p.yuan * 100;

/** What is wrong with a config: a pack, the pricing terms, a method without an estimate. */
export function checkPointsConfig(c: PointsConfig, systems: readonly ChartSystem[]): string[] {
  const problems: string[] = [];
  if (!c.packs.length) problems.push("no packs");
  for (const p of c.packs) {
    if (!packFits(p)) problems.push(`pack ${p.yuan} 元: ${p.points} 积分 is less than 100 per 元`);
  }
  const { margin, payment_fee, vat, usd_cny, reference_model } = c.pricing;
  if (!(margin > 0 && margin < 1)) problems.push(`margin ${margin} must be between 0 and 1`);
  if (!(usd_cny > 0)) problems.push("usd_cny must be positive");
  if (!(payment_fee >= 0 && vat >= 0 && payment_fee + vat < 1))
    problems.push("payment_fee + vat must be below 1");
  if (!modelInfo(reference_model)?.price)
    problems.push(`reference_model ${reference_model} has no list price`);
  if (!(c.hold_factor >= 1)) problems.push("hold_factor must be at least 1");
  for (const s of systems) if (!c.estimates.report[s]) problems.push(`no report estimate for ${s}`);
  return problems;
}

/** The cheapest 积分 in 元, after the payment fee and VAT: the best pack's. */
export function pointValueCny(c: PointsConfig): number {
  const most = Math.max(...c.packs.map((p) => p.points / p.yuan));
  return (1 - c.pricing.payment_fee - c.pricing.vat) / most;
}

/** 积分 per US dollar of tokens: the price at which the cheapest 积分 still keeps the margin. */
export function pointsPerUsd(c: PointsConfig): number {
  return c.pricing.usd_cny / ((1 - c.pricing.margin) * pointValueCny(c));
}

/** A cost in US dollars as 积分, rounded up (the tolerance keeps a whole number whole). */
export function pointsFor(c: PointsConfig, usd: number): number {
  return Math.ceil(usd * pointsPerUsd(c) - 1e-9);
}

/** A model's list price; the reference model's for one without a price. */
export function priceOf(c: PointsConfig, model: string | undefined): Price {
  return (model && modelInfo(model)?.price) || modelInfo(c.pricing.reference_model)!.price!;
}

export function tokensUsd(price: Price, t: Tokens): number {
  return (t.input * price.input + t.output * price.output) / 1_000_000;
}

/** What a request is about, for its estimate. */
export interface QuoteFor {
  /** The chart's method: a reading's, or the reading's that a plan or a 追问 is on. */
  system?: ChartSystem;
  /** Topics asked (八字's sections). */
  topics?: number;
  /** Cards drawn (塔罗). */
  cards?: number;
  /** What a 追问 is on. */
  parent?: "report" | "life_report";
}

/** What a request on [fact] is about: its method and, for 塔罗, its cards. */
export function quoteFor(fact: ChartFact, topics?: number): QuoteFor {
  const cards = (fact.facts as { cards?: unknown[] }).cards;
  return {
    system: fact.system,
    ...(topics !== undefined && { topics }),
    ...(fact.system === "tarot" && Array.isArray(cards) && { cards: cards.length }),
  };
}

/** The tokens a request should send and write. */
export function estimateTokens(c: PointsConfig, kind: ChargeKind, what: QuoteFor = {}): Tokens {
  const e = c.estimates;
  const s = what.system ?? "bazi";
  const base: Estimate =
    kind === "report"
      ? (e.report[s] ?? e.report.bazi)
      : kind === "life_report"
        ? e.life_report
        : kind === "followup"
          ? what.parent === "life_report"
            ? e.followup.life_report!
            : (e.followup[s] ?? e.followup.default)
          : kind === "remedy"
            ? (e.remedy[s] ?? e.remedy.default)
            : e.inquiry.turn;
  const topics = what.topics ?? 0;
  const cards = what.cards ?? 0;
  return {
    input: base.input + topics * (base.per_topic?.input ?? 0) + cards * (base.per_card?.input ?? 0),
    output:
      base.output + topics * (base.per_topic?.output ?? 0) + cards * (base.per_card?.output ?? 0),
  };
}

/** What a request costs before it runs: its estimate in 积分, and what is held while it runs. */
export interface Quote {
  points: number;
  hold: number;
}

export function quote(
  c: PointsConfig,
  routing: RoutingTable,
  kind: ChargeKind,
  what: QuoteFor = {},
): Quote {
  if (kind === "inquiry") {
    const fee = inquiryFee(c, routing).points;
    return { points: fee, hold: fee };
  }
  const model = routing.routes[MAIN_STEP[kind]]?.default.model;
  const points = pointsFor(c, tokensUsd(priceOf(c, model), estimateTokens(c, kind, what)));
  return { points, hold: Math.ceil(points * c.hold_factor) };
}

/**
 * The 深度分析's 统一收费 (the owner: 「对话了解阶段给一个统一的收费」): typical turns and one at its largest, at the
 * inquiry route's price; what its conversation may spend before the fee no longer keeps the margin (budgetUsd); and a
 * typical turn, which the conversation must still have room for before the master asks again.
 */
export function inquiryFee(c: PointsConfig, routing: RoutingTable) {
  const price = priceOf(c, routing.routes.inquiry?.default.model);
  const { turn, largest_turn, typical_turns } = c.estimates.inquiry;
  const turnUsd = tokensUsd(price, turn);
  const points = pointsFor(c, typical_turns * turnUsd + tokensUsd(price, largest_turn));
  return { points, turnUsd, budgetUsd: points / pointsPerUsd(c) };
}

/**
 * What a job's steps cost at list price (a model without one at the reference model's), and the tokens they
 * reported: none means the mock answered.
 */
export function measuredCost(c: PointsConfig, agents: readonly AgentTrace[]) {
  let usd = 0;
  let tokens = 0;
  for (const a of agents) {
    const u = a.usage;
    tokens +=
      u.input_tokens +
      u.output_tokens +
      (u.cache_read_input_tokens ?? 0) +
      (u.cache_creation_input_tokens ?? 0);
    usd += costUsd(a.model, u) ?? costUsd(c.pricing.reference_model, u)!;
  }
  return { usd, tokens };
}

export type PointsBasis = "measured" | "estimate" | "flat";

/** What a settled request is charged. */
export interface PointsCharge {
  points: number;
  basis: PointsBasis;
  /** The measured cost, in US dollars at list price. */
  usd?: number;
}

/**
 * What a request that delivered is charged: its measured cost, or its quote when no tokens were reported (the mock),
 * and never more than was held.
 */
export function chargeFor(
  c: PointsConfig,
  held: { points: number; quote: number },
  agents: readonly AgentTrace[],
): PointsCharge {
  const m = measuredCost(c, agents);
  if (m.tokens === 0) return { points: Math.min(held.quote, held.points), basis: "estimate" };
  return {
    points: Math.min(pointsFor(c, m.usd), held.points),
    basis: "measured",
    usd: Math.round(m.usd * 1e6) / 1e6,
  };
}
