/**
 * 起名 (tech plan WP6.4, the owner's Phase 3 spec): candidate given names for a surname, from a person's 八字
 * chart (五行补益), a 字义库 (characters.ts, a draft awaiting the owner's review) and 音律 rules. Its own method
 * (rule 8): it reads a 八字 chart's facts and changes nothing of 八字.
 *
 * - The elements: the 八字 engine's 喜用 (strength.favorable). Without one (中和, or a chart flagged for a
 *   closer look) the names keep a balance: the two weakest elements by wuxing_weighted.
 * - The sound (each rule its own function, unit-tested):
 *   - never a character of the surname, and never two like syllables side by side;
 *   - three or more syllables never all in one tone;
 *   - +1 for each change between 平 (tones 1–2) and 仄 (3–4), −1 for each pair in one tone;
 *   - +0.5 when the name ends on a 平 tone;
 *   - −0.5 for each 双声 (same initial) or 叠韵 (same final) side by side.
 * - The candidates: every combination whose elements serve the targets, scored, the top 12, no character in more
 *   than two of them. Ties fall in a fixed order from the surname, so the list is reproducible.
 *
 * The chart copies only the elements and the 八字 chart's digest, never birth data.
 */
import { createHash } from "node:crypto";
import { inputDigest, SCHEMA_VERSION, type ChartFact } from "../../chart-fact/index.js";
import { NAME_CHARS, SURNAMES, type Element, type NameChar } from "./characters.js";

export const NAMING_ENGINE_VERSION = "0.1.0";
/** The 字义库's version and review state: the owner's 人工校订 turns `reviewed` to true. */
export const LIBRARY = { version: "0.1.0-draft", reviewed: false } as const;
export const MAX_CANDIDATES = 12;

const ELEMENTS: Element[] = ["木", "火", "土", "金", "水"];
const MARKS: Record<string, [string, number]> = {
  ā: ["a", 1],
  á: ["a", 2],
  ǎ: ["a", 3],
  à: ["a", 4],
  ē: ["e", 1],
  é: ["e", 2],
  ě: ["e", 3],
  è: ["e", 4],
  ī: ["i", 1],
  í: ["i", 2],
  ǐ: ["i", 3],
  ì: ["i", 4],
  ō: ["o", 1],
  ó: ["o", 2],
  ǒ: ["o", 3],
  ò: ["o", 4],
  ū: ["u", 1],
  ú: ["u", 2],
  ǔ: ["u", 3],
  ù: ["u", 4],
  ǖ: ["ü", 1],
  ǘ: ["ü", 2],
  ǚ: ["ü", 3],
  ǜ: ["ü", 4],
};
const INITIALS = [
  "zh",
  "ch",
  "sh",
  "b",
  "p",
  "m",
  "f",
  "d",
  "t",
  "n",
  "l",
  "g",
  "k",
  "h",
  "j",
  "q",
  "x",
  "r",
  "z",
  "c",
  "s",
  "y",
  "w",
];

export interface Syllable {
  base: string;
  tone: number;
  initial: string;
  final: string;
}

/** One pinyin syllable with its tone mark: the toneless base, the tone (5 = neutral), initial and final. */
export function syllable(pinyin: string): Syllable {
  let tone = 5;
  const base = [...pinyin]
    .map((c) => {
      const m = MARKS[c];
      if (!m) return c;
      tone = m[1];
      return m[0];
    })
    .join("");
  const initial = INITIALS.find((i) => base.startsWith(i)) ?? "";
  return { base, tone, initial, final: base.slice(initial.length) };
}

const level = (tone: number) => tone === 1 || tone === 2;

export type SoundNote = "pingze" | "same_tone" | "ends_level" | "shuangsheng" | "dieyun";

/** Rejected outright: two like syllables side by side, or three or more in one tone. */
export function soundRejects(s: Syllable[]): boolean {
  for (let i = 1; i < s.length; i++) if (s[i]!.base === s[i - 1]!.base) return true;
  return s.length >= 3 && s.every((x) => x.tone === s[0]!.tone);
}

/** The sound's score and the notes behind it (see the module comment). */
export function soundScore(s: Syllable[]): { score: number; notes: SoundNote[] } {
  let score = 0;
  const notes = new Set<SoundNote>();
  for (let i = 1; i < s.length; i++) {
    const [a, b] = [s[i - 1]!, s[i]!];
    if (a.tone === b.tone) {
      score -= 1;
      notes.add("same_tone");
    } else if (level(a.tone) !== level(b.tone)) {
      score += 1;
      notes.add("pingze");
    }
    if (a.initial && a.initial === b.initial) {
      score -= 0.5;
      notes.add("shuangsheng");
    }
    if (a.final === b.final) {
      score -= 0.5;
      notes.add("dieyun");
    }
  }
  if (s.length && level(s.at(-1)!.tone)) {
    score += 0.5;
    notes.add("ends_level");
  }
  return { score, notes: [...notes] };
}

interface BaziFacts {
  strength?: { favorable?: Element[]; special?: string };
  wuxing_weighted?: { scores?: Record<Element, number> };
}

/** The elements the names serve: the 喜用, or else the two weakest (a balance). */
export function targetElements(bazi: BaziFacts): {
  elements: Element[];
  basis: "favorable" | "balance";
} {
  const favorable = (bazi.strength?.favorable ?? []).filter((e) => ELEMENTS.includes(e));
  if (favorable.length && !bazi.strength?.special) {
    return { elements: favorable.slice(0, 2), basis: "favorable" };
  }
  const scores = bazi.wuxing_weighted?.scores ?? ({} as Record<Element, number>);
  const weakest = [...ELEMENTS].sort((a, b) => (scores[a] ?? 0) - (scores[b] ?? 0)).slice(0, 2);
  return { elements: weakest, basis: "balance" };
}

export interface NamingInput {
  /** One or two characters, 繁 or 简 */
  surname: string;
  length: 1 | 2;
}

export interface Candidate {
  given: { "zh-Hant": string; "zh-Hans": string };
  pinyin: string;
  elements: Element[];
  tones: number[];
  score: number;
  notes: (SoundNote | "elements")[];
  source_level: "simplified_rule";
}

export function computeNaming(
  bazi: ChartFact,
  input: NamingInput,
  ctx: { digestPepper: Buffer; now?: () => Date },
): ChartFact {
  if (bazi.system !== "bazi") throw new Error("起名 reads a 八字 chart");
  const surname = input.surname.trim();
  if (!/^\p{Script=Han}{1,2}$/u.test(surname))
    throw new Error("surname must be one or two Chinese characters");
  if (input.length !== 1 && input.length !== 2) throw new Error("length must be 1 or 2");
  const known = SURNAMES.find(([hant, hans]) => hant === surname || hans === surname);
  const surnameSyllables = known ? known[2].split(" ").map(syllable) : [];
  const { elements, basis } = targetElements(bazi.facts as BaziFacts);

  const pool = NAME_CHARS.filter(
    (c) => elements.includes(c.element) && !surname.includes(c.hant) && !surname.includes(c.hans),
  );
  const combos: NameChar[][] =
    input.length === 1
      ? pool.map((c) => [c])
      : pool.flatMap((a) => pool.filter((b) => b !== a).map((b) => [a, b]));

  const scored = combos.flatMap((chars) => {
    const s = [...surnameSyllables, ...chars.map((c) => syllable(c.pinyin))];
    if (soundRejects(s)) return [];
    const sound = soundScore(s);
    const covered = new Set(chars.map((c) => c.element));
    const score =
      2 * chars.length + (elements.length === 2 && covered.size === 2 ? 1 : 0) + sound.score;
    const given = chars.map((c) => c.hant).join("");
    return [
      {
        given: { "zh-Hant": given, "zh-Hans": chars.map((c) => c.hans).join("") },
        pinyin: chars.map((c) => c.pinyin).join(" "),
        elements: chars.map((c) => c.element),
        tones: chars.map((c) => syllable(c.pinyin).tone),
        score,
        notes: ["elements" as const, ...sound.notes],
        source_level: "simplified_rule" as const,
        // From the surname's 繁 form when known, so 張 and 张 give the same list.
        tie: createHash("sha256")
          .update(`${known?.[0] ?? surname}:${given}`)
          .digest("hex"),
      },
    ];
  });
  scored.sort((a, b) => b.score - a.score || a.tie.localeCompare(b.tie));

  // The top candidates, no character in more than two of them.
  const used = new Map<string, number>();
  const candidates: Candidate[] = [];
  for (const { tie: _t, ...c } of scored) {
    const chars = [...c.given["zh-Hant"]];
    if (chars.some((ch) => (used.get(ch) ?? 0) >= 2)) continue;
    for (const ch of chars) used.set(ch, (used.get(ch) ?? 0) + 1);
    candidates.push(c);
    if (candidates.length === MAX_CANDIDATES) break;
  }

  const rule_versions = { library: `naming-chars@${LIBRARY.version}` };
  const normalized = { surname, length: input.length, bazi: bazi.input_digest };
  return {
    schema_version: SCHEMA_VERSION,
    engine: { name: "naming", version: NAMING_ENGINE_VERSION },
    system: "naming",
    input_digest: inputDigest(
      { input: normalized, engine_version: NAMING_ENGINE_VERSION, rule_versions },
      ctx.digestPepper,
    ),
    rule_versions,
    computed_at: (ctx.now?.() ?? new Date()).toISOString(),
    facts: {
      surname: {
        "zh-Hant": known?.[0] ?? surname,
        "zh-Hans": known?.[1] ?? surname,
        ...(known && { pinyin: known[2] }),
      },
      length: input.length,
      elements,
      basis,
      bazi_digest: bazi.input_digest,
      library: { ...LIBRARY },
      candidates,
    },
    provenance: [
      {
        path: "/elements",
        source_level: "simplified_rule",
        note:
          basis === "favorable"
            ? "八字扶抑法的喜用（簡化判斷）"
            : "五行加權分數中最弱的兩行，取其平衡",
      },
      {
        path: "/candidates",
        source_level: "simplified_rule",
        note: "字形五行（依部首）與聲調、平仄規則，簡化",
      },
    ],
  };
}
