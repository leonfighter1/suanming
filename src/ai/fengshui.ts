/**
 * 风水 only (nothing here is used by any other method): the room as the reading agent sees it in <room>.
 * The room's name, the facing with its traditional association when given, and each principle in the
 * reader's language with its everyday reason and the path to cite (the first principle is /principles/0).
 */
import type { ChartFact } from "../chart-fact/index.js";
import type { FengshuiFacts } from "../engines/fengshui/index.js";
import { DIRECTIONS, ROOMS } from "../engines/fengshui/principles.js";
import type { Locale } from "./terms.js";

/** The protected terms a 风水 reading uses (i18n/terms.json keys), for its <glossary>. */
export const FENGSHUI_TERMS = ["风水", "后天八卦"];

export interface RoomBrief {
  room: string;
  facing?: { direction: string; trigram: string; element: string; path: string };
  principles: { path: string; area: string; principle: string; why: string }[];
}

export function fengshuiBrief(chart: ChartFact, locale: Locale): RoomBrief {
  const f = chart.facts as unknown as FengshuiFacts;
  const room = ROOMS[f.room];
  const byId = new Map(room.principles.map((p) => [p.id, p]));
  const d = f.facing ? DIRECTIONS[f.facing] : undefined;
  return {
    room: room.name[locale],
    ...(d && {
      facing: {
        direction: d.name[locale],
        trigram: d.trigram[locale],
        element: d.element[locale],
        path: "/direction",
      },
    }),
    principles: f.principles.map((p, i) => ({
      path: `/principles/${i}`,
      area: p.area,
      principle: byId.get(p.id)?.text[locale] ?? p.id,
      why: byId.get(p.id)?.why[locale] ?? "",
    })),
  };
}
