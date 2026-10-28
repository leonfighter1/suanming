/**
 * 求籤 only (nothing here is used by 八字, tarot or astrology): the lot as the reading agent sees it in <lot>.
 * The set, the lot's title and label, and its four lines in the reader's script, each with the path to cite
 * (the first line is /lot/poem/0). English readers get the original 繁體 lines: the reading explains them.
 */
import type { ChartFact } from "../chart-fact/index.js";
import { lotSet, type LotSetId } from "../engines/qiuqian/lots.js";
import type { Locale } from "./terms.js";

interface Facts {
  lot_set: LotSetId;
  lot: { n: number; ganzhi: string; poem: string[] };
}

/** The protected terms a 求籤 reading uses (i18n/terms.json keys), for its <glossary>. */
export const QIUQIAN_TERMS = ["求签", "掷筊", "签诗", "签筒", "圣筊", "笑筊", "阴筊", "关圣帝君"];

const DIGITS = "〇一二三四五六七八九";

/** 1–100 in Chinese numerals, as temples number their lots: 一, 十, 十一, 二十, 五十二, 一百. */
export function chineseNumeral(n: number): string {
  if (n === 100) return "一百";
  const tens = Math.floor(n / 10);
  const ones = n % 10;
  return `${tens > 1 ? DIGITS[tens] : ""}${tens > 0 ? "十" : ""}${ones > 0 ? DIGITS[ones] : ""}`;
}

/** 第五十二籤 / 第五十二签 / Lot 52 */
export function lotTitle(n: number, locale: Locale): string {
  if (locale === "en") return `Lot ${n}`;
  return `第${chineseNumeral(n)}${locale === "zh-Hant" ? "籤" : "签"}`;
}

export interface LotBrief {
  set: string;
  title: string;
  ganzhi: string;
  lines: { path: string; text: string }[];
}

export function lotBrief(chart: ChartFact, locale: Locale): LotBrief {
  const f = chart.facts as unknown as Facts;
  const set = lotSet(f.lot_set);
  const lot = set.lots[f.lot.n - 1]!;
  const script = locale === "zh-Hans" ? "zh-Hans" : "zh-Hant";
  return {
    set: locale === "en" ? `${set.name.en} (${set.name["zh-Hant"]})` : set.name[locale],
    title: lotTitle(f.lot.n, locale),
    ganzhi: f.lot.ganzhi,
    lines: lot.poem[script].map((text, i) => ({ path: `/lot/poem/${i}`, text })),
  };
}

/** What the reading agent reads in <chart_facts>: the lot, not the rounds that confirmed it. */
export function qiuqianView(facts: Record<string, unknown>): Record<string, unknown> {
  const { rounds: _r, ...rest } = facts;
  return rest;
}
