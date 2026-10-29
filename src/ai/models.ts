/**
 * The models the AI steps can use (S17, owner 2026-10-29: 「再添加可以用的model」). One entry per model: the provider
 * that serves it, its output limit, its list price and what it is for. config/model_routing.json names models from
 * this list (checkRouting), and ACTIVE_AI_MODEL in .env picks one of them for every AI step (withModel).
 *
 * Claude: Anthropic's model catalog as of 2026-10-29 (the claude-api skill: shared/models.md, model-migration.md).
 * Every entry has a 1M context, 128K output, adaptive thinking (always on for Claude Opus 5.5) and effort low…max.
 * Cache writes are the 5-minute kind, 1.25 × input; Claude Haiku 5.5's cache reads are 0.1 × input (the rate the
 * catalog gives every model without its own).
 * DeepSeek: deepseek-v4-pro, every route's model until v9.2.0; its output limit is the largest the routes have used
 * live. Its price is not checked here, so it has none.
 */
import type { Route, RoutingTable } from "./routing.js";
import type { LLMJsonRequest, Usage } from "./types.js";

/** US dollars per million tokens. */
export interface Price {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
}

export interface ModelInfo {
  id: string;
  /** Its key in the providers map. */
  provider: "anthropic" | "deepseek";
  label: string;
  /** What it is for, in a few words (npm run ai:models). */
  use: string;
  /** The largest max_tokens a route may ask of it. */
  maxOutput: number;
  /** The effort every AI step gets when ACTIVE_AI_MODEL picks it. */
  effort: LLMJsonRequest["effort"];
  /** Claude's server-side refusal fallback (`fallbacks: "default"`), for the models that have one. */
  fallback?: boolean;
  price?: Price;
  /** Anything to know before choosing it. */
  note?: string;
}

export const MODELS: readonly ModelInfo[] = [
  {
    id: "claude-opus-5-5",
    provider: "anthropic",
    label: "Claude Opus 5.5",
    use: "the default (owner, 2026-10-29)",
    maxOutput: 128_000,
    effort: "medium",
    fallback: true,
    price: { input: 4, output: 20, cacheRead: 0.2, cacheWrite: 5 },
  },
  {
    id: "claude-fable-5-1",
    provider: "anthropic",
    label: "Claude Fable 5.1",
    use: "the most capable, at 2.5 times Opus 5.5's price",
    maxOutput: 128_000,
    effort: "medium",
    fallback: true,
    price: { input: 10, output: 50, cacheRead: 0.25, cacheWrite: 12.5 },
    note: "Anthropic keeps its requests for 30 days; an organisation with zero data retention is refused",
  },
  {
    id: "claude-sonnet-5-5",
    provider: "anthropic",
    label: "Claude Sonnet 5.5",
    use: "balanced, at half Opus 5.5's price",
    maxOutput: 128_000,
    effort: "medium",
    fallback: true,
    price: { input: 2, output: 10, cacheRead: 0.2, cacheWrite: 2.5 },
  },
  {
    id: "claude-haiku-5-5",
    provider: "anthropic",
    label: "Claude Haiku 5.5",
    use: "the fastest and cheapest",
    maxOutput: 128_000,
    effort: "medium",
    // It has no server-side fallback: the parameter is left out of its requests.
    fallback: false,
    price: { input: 0.1, output: 0.5, cacheRead: 0.01, cacheWrite: 0.125 },
    note: "a prompt over 100K tokens costs $0.50 / $2.50 per MTok; readings stay far below",
  },
  {
    id: "deepseek-v4-pro",
    provider: "deepseek",
    label: "DeepSeek V4 Pro",
    use: "every step's model until v9.2.0",
    maxOutput: 32_000,
    effort: "high",
  },
];

export function modelInfo(id: string): ModelInfo | undefined {
  return MODELS.find((m) => m.id === id);
}

/** What is wrong with a routing table against MODELS: an unknown model, the wrong provider, too many tokens. */
export function checkRouting(table: RoutingTable): string[] {
  const problems: string[] = [];
  for (const [agent, routes] of Object.entries(table.routes)) {
    for (const [locale, r] of Object.entries(routes) as [string, Route][]) {
      const where = locale === "default" ? agent : `${agent} (${locale})`;
      const m = modelInfo(r.model);
      if (!m) {
        problems.push(`${where}: ${r.model} is not a usable model`);
        continue;
      }
      if (r.provider !== m.provider) {
        problems.push(`${where}: ${r.model} is served by ${m.provider}, not ${r.provider}`);
      }
      if (r.max_tokens > m.maxOutput) {
        problems.push(`${where}: max_tokens ${r.max_tokens} is over ${m.label}'s ${m.maxOutput}`);
      }
    }
  }
  return problems;
}

/**
 * The table with every route answered by one model, at its effort, each max_tokens kept within its limit. A route the
 * table already gives that model keeps its own settings (v10.0.0): choosing the table's own model changes nothing, so
 * the 深度分析's questions stay at their low effort.
 */
export function withModel(table: RoutingTable, model: ModelInfo): RoutingTable {
  const answer = (r: Route): Route =>
    r.provider === model.provider && r.model === model.id
      ? r
      : {
          provider: model.provider,
          model: model.id,
          effort: model.effort,
          max_tokens: Math.min(r.max_tokens, model.maxOutput),
        };
  const routes = Object.fromEntries(
    Object.entries(table.routes).map(([agent, byLocale]) => [
      agent,
      Object.fromEntries(
        Object.entries(byLocale).map(([locale, r]) => [locale, answer(r as Route)]),
      ),
    ]),
  );
  return { ...table, routes: routes as RoutingTable["routes"] };
}

/**
 * What a usage costs at the model's list price, in US dollars; undefined for a model without one. Claude counts
 * cache reads and writes apart from input_tokens.
 */
export function costUsd(id: string, usage: Usage): number | undefined {
  const p = modelInfo(id)?.price;
  if (!p) return undefined;
  const tokens =
    usage.input_tokens * p.input +
    usage.output_tokens * p.output +
    (usage.cache_read_input_tokens ?? 0) * p.cacheRead +
    (usage.cache_creation_input_tokens ?? 0) * p.cacheWrite;
  return tokens / 1_000_000;
}
