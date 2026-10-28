/**
 * Each card's three keywords (tech plan WP3.4): 简体 and 繁體 as painted on the card art
 * (data/tarot/keywords.json, built by `npm run build:tarot-keywords`), English to the
 * Rider–Waite–Smith meanings (keywords-en.ts). The one source the app's 牌义图鉴 gets
 * through `npm run sync:app`.
 */
import { readFileSync } from "node:fs";
import { DECK } from "./deck.js";
import { KEYWORDS_EN } from "./keywords-en.js";

type Locale = "en" | "zh-Hans" | "zh-Hant";

const painted = (
  JSON.parse(
    readFileSync(new URL("../../../data/tarot/keywords.json", import.meta.url), "utf8"),
  ) as { cards: Record<string, Record<"zh-Hans" | "zh-Hant", string[]>> }
).cards;

export const KEYWORDS: Readonly<Record<string, Readonly<Record<Locale, readonly string[]>>>> =
  Object.freeze(
    Object.fromEntries(DECK.map((c) => [c.id, { ...painted[c.id]!, en: KEYWORDS_EN[c.id] ?? [] }])),
  );
