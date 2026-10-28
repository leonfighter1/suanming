import type { ChartSystem, SourceLevel } from "../chart-fact/index.js";
import type { Locale } from "./terms.js";

export type AgentName =
  "narrative" | "action" | "trend" | "remedy" | "life_methods" | "life_topics" | "guard";

/**
 * The sections a report can have: the six analysis areas (`wuxing` and `dayun_liunian` only for
 * bazi); since v2.3.0, tarot's own three (card by card, the whole spread, the advice); since v4.3.0,
 * 求籤's own three (the poem, the question, the advice).
 */
export const TOPICS = [
  "wuxing",
  "personality",
  "career_wealth",
  "relationships",
  "dayun_liunian",
  "health",
  "tarot_cards",
  "tarot_synthesis",
  "tarot_advice",
  "qiuqian_poem",
  "qiuqian_answer",
  "qiuqian_advice",
  "fengshui_layout",
  "fengshui_flow",
  "fengshui_advice",
] as const;
export type Topic = (typeof TOPICS)[number];

// Each method lists its own (rule 8): no method takes another's list.
export const TOPICS_BY_SYSTEM: Record<ChartSystem, readonly Topic[]> = {
  bazi: ["wuxing", "personality", "career_wealth", "relationships", "dayun_liunian", "health"],
  tarot: ["tarot_cards", "tarot_synthesis", "tarot_advice"],
  astrology: ["personality", "career_wealth", "relationships", "health"],
  qiuqian: ["qiuqian_poem", "qiuqian_answer", "qiuqian_advice"],
  fengshui: ["fengshui_layout", "fengshui_flow", "fengshui_advice"],
};

/** The area of life a tarot reading may focus on (POST /v1/reports `focus`, tarot only). */
export const TAROT_FOCUS = ["career_wealth", "relationships", "health", "personality"] as const;
export type TarotFocus = (typeof TAROT_FOCUS)[number];

/**
 * Sections that get no 破除運勢 plan: a tarot reading's plan rests on its advice; 求籤 (a lot is read
 * once, for the question asked) and 风水 (its principles are the plan) have none at all.
 */
export const NO_PLAN_TOPICS: readonly Topic[] = [
  "tarot_cards",
  "tarot_synthesis",
  "qiuqian_poem",
  "qiuqian_answer",
  "qiuqian_advice",
  "fengshui_layout",
  "fengshui_flow",
  "fengshui_advice",
];

export const TOPIC_LABELS: Record<Topic, Record<Locale, string>> = {
  wuxing: { "zh-Hant": "五行", "zh-Hans": "五行", en: "Five Elements" },
  personality: { "zh-Hant": "性格", "zh-Hans": "性格", en: "Personality" },
  career_wealth: { "zh-Hant": "事業財運", "zh-Hans": "事业财运", en: "Career & wealth" },
  relationships: { "zh-Hant": "婚姻感情", "zh-Hans": "婚姻感情", en: "Relationships" },
  dayun_liunian: { "zh-Hant": "大運流年", "zh-Hans": "大运流年", en: "Luck pillars & years" },
  health: { "zh-Hant": "健康", "zh-Hans": "健康", en: "Wellbeing" },
  tarot_cards: { "zh-Hant": "逐張解讀", "zh-Hans": "逐张解读", en: "Card by card" },
  tarot_synthesis: { "zh-Hant": "綜合解讀", "zh-Hans": "综合解读", en: "The whole spread" },
  tarot_advice: { "zh-Hant": "建議", "zh-Hans": "建议", en: "Advice" },
  qiuqian_poem: { "zh-Hant": "籤詩", "zh-Hans": "签诗", en: "The poem" },
  qiuqian_answer: { "zh-Hant": "所問之事", "zh-Hans": "所问之事", en: "Your question" },
  qiuqian_advice: { "zh-Hant": "建議", "zh-Hans": "建议", en: "Advice" },
  fengshui_layout: { "zh-Hant": "佈局", "zh-Hans": "布局", en: "Layout" },
  fengshui_flow: { "zh-Hant": "光線與動線", "zh-Hans": "光线与动线", en: "Light and movement" },
  fengshui_advice: { "zh-Hant": "建議", "zh-Hans": "建议", en: "Advice" },
};

export interface Paragraph {
  text: string;
  source_level: SourceLevel;
  /** JSON Pointers into ChartFact.facts that this paragraph rests on */
  fact_refs: string[];
}
export interface NarrativeOutput {
  /** summary: the topic's main point in one plain sentence (narrative@4+) */
  sections: { topic: Topic; summary?: string; paragraphs: Paragraph[] }[];
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
