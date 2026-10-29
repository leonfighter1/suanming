import type { ChartSystem, SourceLevel } from "../chart-fact/index.js";
import type { Locale } from "./terms.js";

/**
 * A 深度分析 as a reading reads it (v10.0.0, S19): the user's goal, every question the master asked with what it said
 * before it and the user's answer, and what the master understood they most want to know.
 */
export interface InquiryContext {
  goal: string;
  turns: { say: string; question: string; answer: string }[];
  understanding?: string;
}

export type AgentName =
  | "narrative"
  | "action"
  | "trend"
  | "remedy"
  | "life_methods"
  | "life_topics"
  // 追问 (v7.0.0, S13): a follow-up question on a passed reading or 一生运势报告.
  | "followup"
  // 深度分析 (v10.0.0, S19): the master's questions before a reading, one turn at a time.
  | "inquiry"
  | "guard";

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
  "naming_candidates",
  "naming_advice",
  "liuyao_hexagram",
  "liuyao_answer",
  "liuyao_advice",
] as const;
export type Topic = (typeof TOPICS)[number];

// Each method lists its own (rule 8): no method takes another's list.
export const TOPICS_BY_SYSTEM: Record<ChartSystem, readonly Topic[]> = {
  bazi: ["wuxing", "personality", "career_wealth", "relationships", "dayun_liunian", "health"],
  tarot: ["tarot_cards", "tarot_synthesis", "tarot_advice"],
  astrology: ["personality", "career_wealth", "relationships", "health"],
  qiuqian: ["qiuqian_poem", "qiuqian_answer", "qiuqian_advice"],
  fengshui: ["fengshui_layout", "fengshui_flow", "fengshui_advice"],
  naming: ["naming_candidates", "naming_advice"],
  liuyao: ["liuyao_hexagram", "liuyao_answer", "liuyao_advice"],
};

/** The area of life a tarot reading may focus on (POST /v1/reports `focus`, tarot only). */
export const TAROT_FOCUS = ["career_wealth", "relationships", "health", "personality"] as const;
export type TarotFocus = (typeof TAROT_FOCUS)[number];

/**
 * Sections that get no 破除運勢 plan: a tarot reading's plan rests on its advice; 求籤 and 算卦 (a cast is
 * read once, for the question asked), 风水 (its principles are the plan) and 起名 (a name is chosen, not
 * worked on) have none at all.
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
  "naming_candidates",
  "naming_advice",
  "liuyao_hexagram",
  "liuyao_answer",
  "liuyao_advice",
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
  naming_candidates: { "zh-Hant": "候選名字", "zh-Hans": "候选名字", en: "The names" },
  naming_advice: { "zh-Hant": "建議", "zh-Hans": "建议", en: "Advice" },
  liuyao_hexagram: { "zh-Hant": "卦象", "zh-Hans": "卦象", en: "The hexagram" },
  liuyao_answer: { "zh-Hant": "所問之事", "zh-Hans": "所问之事", en: "Your question" },
  liuyao_advice: { "zh-Hant": "建議", "zh-Hans": "建议", en: "Advice" },
};

export interface Paragraph {
  /**
   * 术语 (v6.2.0, S13): the facts the paragraph rests on, said the tradition's way, shown first. Absent from
   * readings made before.
   */
  term?: string;
  /** 评论: what it means for the reader, in plain words and in detail. */
  text: string;
  /** 举例 (v6.2.0): one everyday scene that shows the point. Absent from readings made before. */
  example?: string;
  source_level: SourceLevel;
  /** JSON Pointers into ChartFact.facts that this paragraph rests on */
  fact_refs: string[];
}
/**
 * 八字's 总结 (v9.3.0, S18; the owner: 「一定要给出总结」): nine parts in this order, each written to the reader. No
 * other method has one.
 */
export const CONCLUSION_PARTS = [
  "portrait",
  "past",
  "present",
  "challenges",
  "gains",
  "future",
  "caution",
  "momentum",
  "coping",
] as const;
export type ConclusionPart = (typeof CONCLUSION_PARTS)[number];

export const CONCLUSION_LABELS: Record<ConclusionPart, Record<Locale, string>> = {
  portrait: { "zh-Hant": "你是怎樣的人", "zh-Hans": "你是怎样的人", en: "Who you are" },
  past: { "zh-Hant": "過去", "zh-Hans": "过去", en: "The past" },
  present: { "zh-Hant": "現在", "zh-Hans": "现在", en: "Now" },
  challenges: { "zh-Hant": "可能遇到的問題", "zh-Hans": "可能遇到的问题", en: "What may go wrong" },
  gains: { "zh-Hant": "得勢與得失", "zh-Hans": "得势与得失", en: "Gains and losses" },
  future: { "zh-Hant": "未來運勢", "zh-Hans": "未来运势", en: "The years ahead" },
  caution: { "zh-Hant": "何時開始要注意", "zh-Hans": "何时开始要注意", en: "When to take care" },
  momentum: { "zh-Hant": "何時開始要發力", "zh-Hans": "何时开始要发力", en: "When to push" },
  coping: {
    "zh-Hant": "遇到問題時怎麼辦",
    "zh-Hans": "遇到问题时怎么办",
    en: "When trouble comes",
  },
};

/** One part of the 总结 and the chart paths it rests on. */
export interface ConclusionText {
  text: string;
  fact_refs: string[];
}
export type Conclusion = Partial<Record<ConclusionPart, ConclusionText>>;

export interface NarrativeOutput {
  /** summary: the topic's main point in one plain sentence (narrative@4+) */
  sections: { topic: Topic; summary?: string; paragraphs: Paragraph[] }[];
  /** 八字 only (narrative_bazi@8): the 总结, keyed by part in CONCLUSION_PARTS order. */
  conclusion?: Conclusion;
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
  /** Claude's prompt-cache writes (v9.2.0), billed apart from input_tokens. */
  cache_creation_input_tokens?: number;
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
