/**
 * 起名 only (nothing here is used by any other method): the candidates as the reading agent sees them in
 * <names>. The surname, the elements the names serve and why, and each candidate in the reader's script with
 * its pinyin, each character's 五行 and meaning, the notes behind its score, and the path to cite (the first
 * is /candidates/0).
 */
import type { ChartFact } from "../chart-fact/index.js";
import { NAME_CHARS, type Element } from "../engines/naming/characters.js";
import type { Candidate } from "../engines/naming/index.js";
import type { Locale } from "./terms.js";

/** The protected terms a 起名 reading uses (i18n/terms.json keys), for its <glossary>. */
export const NAMING_TERMS = ["五行", "喜用", "平仄", "双声", "叠韵"];

const ELEMENT_EN: Record<Element, string> = {
  木: "Wood",
  火: "Fire",
  土: "Earth",
  金: "Metal",
  水: "Water",
};

const NOTES: Record<string, Record<Locale, string>> = {
  elements: { "zh-Hant": "五行合所需", "zh-Hans": "五行合所需", en: "serves the elements" },
  pingze: { "zh-Hant": "平仄相間", "zh-Hans": "平仄相间", en: "tones rise and fall" },
  ends_level: { "zh-Hant": "平聲收尾", "zh-Hans": "平声收尾", en: "ends on a level tone" },
  same_tone: {
    "zh-Hant": "相鄰同聲調",
    "zh-Hans": "相邻同声调",
    en: "two like tones side by side",
  },
  shuangsheng: { "zh-Hant": "雙聲", "zh-Hans": "双声", en: "alliteration (双声)" },
  dieyun: { "zh-Hant": "疊韻", "zh-Hans": "叠韵", en: "rhyme (叠韵)" },
};

interface Facts {
  surname: { "zh-Hant": string; "zh-Hans": string; pinyin?: string };
  elements: Element[];
  basis: "favorable" | "balance";
  candidates: Candidate[];
}

export function namingBrief(chart: ChartFact, locale: Locale) {
  const f = chart.facts as unknown as Facts;
  const script = locale === "zh-Hans" ? "zh-Hans" : "zh-Hant";
  const element = (e: Element) => (locale === "en" ? ELEMENT_EN[e] : e);
  const byChar = new Map(NAME_CHARS.flatMap((c) => [[c.hant, c] as const, [c.hans, c] as const]));
  return {
    surname: f.surname[script],
    ...(f.surname.pinyin && { surname_pinyin: f.surname.pinyin }),
    elements: f.elements.map(element),
    basis: f.basis,
    candidates: f.candidates.map((c, i) => ({
      path: `/candidates/${i}`,
      name: `${f.surname[script]}${c.given[script]}`,
      pinyin: c.pinyin,
      chars: [...c.given[script]].map((ch) => {
        const entry = byChar.get(ch);
        return {
          char: ch,
          element: entry ? element(entry.element) : "",
          meaning: entry?.meaning[locale] ?? "",
        };
      }),
      notes: c.notes.map((n) => NOTES[n]?.[locale] ?? n),
    })),
  };
}
