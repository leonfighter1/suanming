import { readFileSync } from "node:fs";
import type { Locale } from "./terms.js";
import type { AgentName, LLMJsonRequest } from "./types.js";

export interface Route {
  provider: string;
  model: string;
  effort: LLMJsonRequest["effort"];
  max_tokens: number;
}

export interface RoutingTable {
  version: string;
  routes: Record<AgentName, { default: Route } & Partial<Record<Locale, Route>>>;
}

export function loadRouting(
  path = new URL("../../config/model_routing.json", import.meta.url),
): RoutingTable {
  return JSON.parse(readFileSync(path, "utf8")) as RoutingTable;
}

export function routeFor(table: RoutingTable, agent: AgentName, locale: Locale): Route {
  const r = table.routes[agent];
  if (!r) throw new Error(`no route for agent ${agent}`);
  return r[locale] ?? r.default;
}
