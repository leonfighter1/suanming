/**
 * The mechanics every AI pipeline shares (S28 WP28.6; docs/refactor-plan.md F2): which provider an agent's step runs
 * on, the guard's verdict on a draft, and the AI disclosure a result carries. Each entry point keeps its own prompts,
 * steps and checks (rule 8); nothing here decides what a model is told.
 */
import type { AgentOutcome, AgentTrace } from "./pipeline.js";
import { routeFor, type RoutingTable } from "./routing.js";
import type { Locale } from "./terms.js";
import type { AgentName, GuardOutput, LLMProvider } from "./types.js";

/** The route and the provider [agent]'s step runs on, for [locale]; a provider not configured is an error. */
export function providerOf(
  routing: RoutingTable,
  providers: Record<string, LLMProvider>,
  agent: AgentName,
  locale: Locale,
) {
  const route = routeFor(routing, agent, locale);
  const provider = providers[route.provider];
  if (!provider) throw new Error(`provider "${route.provider}" not configured`);
  return { route, provider };
}

/**
 * The guard's verdict on a draft: its trace kept in [traces]; a failed guard, or a draft it flags, held for review with
 * the reason in [reasons]. [review] is the guard's output when it gave one.
 */
export function guardVerdict(
  guard: AgentOutcome<GuardOutput>,
  traces: AgentTrace[],
  reasons: string[],
) {
  traces.push(guard.trace);
  if (!guard.ok) {
    reasons.push(guard.reason);
    return { held: true, review: undefined };
  }
  if (!guard.value.pass) reasons.push(`guard: ${guard.value.violations.length} issue(s) flagged`);
  return { held: !guard.value.pass, review: guard.value };
}

/** The AI disclosure a result carries: the models and prompts its steps used, and whether the label is required. */
export function disclosureOf(traces: readonly AgentTrace[], labelRequired: boolean, now: Date) {
  return {
    generated: true as const,
    model: [...new Set(traces.map((t) => t.model))].join(","),
    prompt_version: traces.map((t) => t.prompt_version).join(","),
    label_required: labelRequired,
    generated_at: now.toISOString(),
  };
}
