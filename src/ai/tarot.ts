/**
 * Tarot only (nothing here is used by 八字 or any other method): the spread as the
 * reading agent sees it in <spread>. Cards in dealing order, each with its position's
 * name and meaning, where it lies in the classic layout, the card's name, its
 * orientation and the path to cite (position 1 is /cards/0).
 */
import type { ChartFact } from "../chart-fact/index.js";
import { DECK, POSITION_LABELS, POSITION_MEANINGS, type SpreadId } from "../engines/tarot/deck.js";
import type { Locale } from "./terms.js";

/** Where each position lies in the classic layout, in dealing order. */
const PLACES: Record<SpreadId, readonly string[]> = {
  single: ["centre"],
  three_card: ["row, left", "row, middle", "row, right"],
  celtic_cross: [
    "cross: centre",
    "cross: laid across card 1",
    "cross: below card 1",
    "cross: left of card 1 (behind)",
    "cross: above card 1 (the crown)",
    "cross: right of card 1 (ahead)",
    "staff: bottom",
    "staff: second from the bottom",
    "staff: third from the bottom",
    "staff: top",
  ],
};

const ORIENTATION: Record<Locale, readonly [upright: string, reversed: string]> = {
  "zh-Hans": ["正位", "逆位"],
  "zh-Hant": ["正位", "逆位"],
  en: ["upright", "reversed"],
};

export interface SpreadCard {
  n: number;
  path: string;
  position: string;
  meaning: string;
  place: string;
  card: string;
  arcana: "major" | "minor";
  orientation: string;
}

export function spreadBrief(
  chart: ChartFact,
  locale: Locale,
): { spread_id: SpreadId; cards: SpreadCard[] } {
  const f = chart.facts as {
    spread_id: SpreadId;
    cards: { position: number; position_key: string; card_id: string; reversed: boolean }[];
  };
  return {
    spread_id: f.spread_id,
    cards: f.cards.map((c, i) => {
      const card = DECK.find((d) => d.id === c.card_id)!;
      return {
        n: c.position,
        path: `/cards/${i}`,
        position: POSITION_LABELS[c.position_key]?.[locale] ?? c.position_key,
        meaning: POSITION_MEANINGS[c.position_key]?.[locale] ?? "",
        place: PLACES[f.spread_id][i] ?? "",
        card: card.name[locale],
        arcana: card.arcana,
        orientation: ORIENTATION[locale][c.reversed ? 1 : 0],
      };
    }),
  };
}
