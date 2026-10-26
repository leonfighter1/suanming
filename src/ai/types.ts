import type { ChartSystem, SourceLevel } from "../chart-fact/index.js";
import type { Locale } from "./terms.js";

export type AgentName = "narrative" | "action" | "trend" | "remedy" | "guard";

/** The six analysis areas. `wuxing` and `dayun_liunian` exist only for bazi. */
export const TOPICS = [
  "wuxing",
  "personality",
  "career_wealth",
  "relationships",
  "dayun_liunian",
  "health",
] as const;
export type Topic = (typeof TOPICS)[number];

export const TOPICS_BY_SYSTEM: Record<ChartSystem, readonly Topic[]> = {
  bazi: TOPICS,
  tarot: ["personality", "career_wealth", "relationships", "health"],
  astrology: ["personality", "career_wealth", "relationships", "health"],
};

export const TOPIC_LABELS: Record<Topic, Record<Locale, string>> = {
  wuxing: { "zh-Hant": "五行", "zh-Hans": "五行", en: "Five Elements" },
  personality: { "zh-Hant": "性格", "zh-Hans": "性格", en: "Personality" },
  career_wealth: { "zh-Hant": "事業財運", "zh-Hans": "事业财运", en: "Career & wealth" },
  relationships: { "zh-Hant": "婚姻感情", "zh-Hans": "婚姻感情", en: "Relationships" },
  dayun_liunian: { "zh-Hant": "大運流年", "zh-Hans": "大运流年", en: "Luck pillars & years" },
  health: { "zh-Hant": "健康", "zh-Hans": "健康", en: "Wellbeing" },
};

export interface Paragraph {
  text: string;
  source_level: SourceLevel;
  /** JSON Pointers into ChartFact.facts that this paragraph rests on */
  fact_refs: string[];
}
export interface NarrativeOutput {
  sections: { topic: Topic; paragraphs: Paragraph[] }[];
}

export const HORIZONS = ["this_week", "this_month", "this_year", "ongoing"] as const;
export interface ActionOutput {
  actions: { topic: Topic; text: string; horizon: (typeof HORIZONS)[number] }[];
}

export const GUARD_CATEGORIES = [
  "fatalism",
  "fear_or_paywall",
  "medical",
  "financial",
  "legal",
  "discrimination",
  "fabricated_fact",
  "other",
] as const;
export interface GuardOutput {
  pass: boolean;
  violations: { quote: string; category: (typeof GUARD_CATEGORIES)[number]; reason: string }[];
}

export interface Usage {
  input_tokens: number;
  output_tokens: number;
  cache_read_input_tokens?: number;
}

export interface LLMJsonRequest {
  agent: AgentName;
  model: string;
  effort: "low" | "medium" | "high" | "xhigh" | "max";
  maxTokens: number;
  system: string;
  user: string;
  /** JSON Schema for structured output (API-supported subset) */
  schema: Record<string, unknown>;
  /** Structured form of the user message. Real providers ignore it; MockProvider reads it. */
  payload: unknown;
}

export type LLMJsonResult =
  | { kind: "ok"; data: unknown; model: string; usage: Usage }
  | { kind: "refusal"; model: string; category: string | null; usage: Usage }
  | { kind: "invalid"; model: string; error: string; usage: Usage };

export interface LLMProvider {
  readonly name: string;
  generateJson(req: LLMJsonRequest): Promise<LLMJsonResult>;
}
