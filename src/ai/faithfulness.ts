/**
 * Automatic faithfulness checks for a generated report: does the AI text only
 * state chart data that is actually in the ChartFact?
 *
 * Checked (deterministically, no model):
 * - every 干支 pair mentioned exists in the chart (pillars, 大運, 流年, 農曆年);
 * - "YYYY年 + 干支" / "YYYY 干支" pairings match the year's real 干支;
 * - every tarot card named is in the spread, and 正位/逆位 claims match;
 * - a 求籤 reading quotes only its lot's lines, word for word, and keeps the lot's number;
 * - a 算卦 reading names only its own hexagrams and quotes no other hexagram's text;
 * - zh-Hant text contains no simplified forms of protected terms (and vice versa).
 * Not checked: 十神/五行 reasoning, which needs a human reviewer.
 */
import type { ChartFact } from "../chart-fact/index.js";
import { DECK, NAME_ALIASES } from "../engines/tarot/deck.js";
import { yearGanZhi } from "../engines/bazi/index.js";
import { hexOf } from "../engines/liuyao/index.js";
import { zhouyiText } from "../engines/yijing/index.js";
import type { Report } from "./pipeline.js";
import { lotBrief } from "./qiuqian.js";
import { loadTerms, type Locale } from "./terms.js";

export interface FaithfulnessIssue {
  kind:
    | "unknown_ganzhi"
    | "wrong_year_ganzhi"
    | "card_not_in_spread"
    | "wrong_orientation"
    | "wrong_script"
    | "wrong_relative_year"
    | "misquoted_line"
    | "wrong_lot"
    | "wrong_hexagram"
    | "misquoted_text";
  detail: string;
  quote: string;
}

type Script = "zh-Hant" | "zh-Hans";
/** Every hexagram's full name and texts (卦辭, 爻辭), per script: what a 算卦 reading may not borrow. */
let zhouyi:
  { id: string; full: Record<Script, string>; texts: Record<Script, string[]> }[] | undefined;
const allHexagrams = () =>
  (zhouyi ??= Array.from({ length: 64 }, (_, n) => {
    const id = n.toString(2).padStart(6, "0");
    const t = zhouyiText(id);
    const full = hexOf(id).full_name;
    const texts = (s: Script) => [t.gua_ci[s], ...t.yao_ci.map((y) => y[s])];
    return { id, full, texts: { "zh-Hant": texts("zh-Hant"), "zh-Hans": texts("zh-Hans") } };
  }));

const GZ = /[甲乙丙丁戊己庚辛壬癸][子丑寅卯辰巳午未申酉戌亥]/g;
/** 一 starting a word: 「宝剑一样」 is "like a sword", not 宝剑一 (the Ace of Swords). */
const ONE_WORD = /^[样樣般起同致直定些下次点點切种種个個旦边邊面向再时時]/u;

/** Where a card's name is first mentioned in text, or -1. */
function findCard(text: string, name: string): number {
  for (let at = text.indexOf(name); at >= 0; at = text.indexOf(name, at + 1)) {
    if (!name.endsWith("一") || !ONE_WORD.test(text.slice(at + name.length))) return at;
  }
  return -1;
}
/** 今年/明年/去年 … 干支 within one sentence: the 干支 must be that year's (from the report date). */
const RELATIVE_GZ =
  /(今年|明年|去年|this year|next year|last year)[^。！？.!?]{0,20}?([甲乙丙丁戊己庚辛壬癸][子丑寅卯辰巳午未申酉戌亥])/gi;
const RELATIVE_OFFSET: Record<string, number> = {
  今年: 0,
  明年: 1,
  去年: -1,
  "this year": 0,
  "next year": 1,
  "last year": -1,
};
const YEAR_GZ =
  /((?:19|20|21)\d{2})\s*年?\s*的?\s*([甲乙丙丁戊己庚辛壬癸][子丑寅卯辰巳午未申酉戌亥])/g;

/** A quotation: 「…」, “…” or "…". */
const QUOTE = /[「“"]([^」”"]{1,40})[」”"]/g;
/** 第五十二籤, 第52签, Lot 52 */
const LOT_NUMBER = /第([〇零一二三四五六七八九十百\d]{1,4})[籤签]|\blot\s+(\d{1,3})\b/gi;

/** 1–100 in Chinese numerals or digits (一, 十, 十一, 二十, 五十二, 一百), or NaN. */
function lotNumber(s: string): number {
  if (/^\d+$/.test(s)) return Number(s);
  if (s === "一百") return 100;
  const d = (c: string | undefined) => "〇一二三四五六七八九".indexOf(c ?? "〇");
  const m = /^([一二三四五六七八九])?(十)?([一二三四五六七八九])?$/.exec(s);
  if (!m || (!m[2] && m[1] && m[3])) return NaN;
  return m[2] ? (m[1] ? d(m[1]) : 1) * 10 + (m[3] ? d(m[3]) : 0) : d(m[1] ?? m[3]);
}

function reportTexts(r: Report): string[] {
  const l = r.layers;
  if (!l) return [];
  return [
    ...l.interpretation.flatMap((s) => s.paragraphs.map((p) => p.text)),
    ...l.actions.map((a) => a.text),
  ];
}

function knownGanzhi(chart: ChartFact): Set<string> {
  const f = chart.facts as Record<string, unknown>;
  const out = new Set<string>();
  const p = f.pillars as Record<string, { gan: string; zhi: string }> | undefined;
  if (p) for (const x of Object.values(p)) out.add(x.gan + x.zhi);
  for (const c of (f.dayun as { cycles?: { ganzhi: string }[] })?.cycles ?? []) out.add(c.ganzhi);
  for (const y of (f.liunian as { ganzhi: string }[] | undefined) ?? []) out.add(y.ganzhi);
  const lunar = f.lunar as { year_ganzhi?: string } | undefined;
  if (lunar?.year_ganzhi) out.add(lunar.year_ganzhi);
  // Facts since v1.3.0: 胎元 is a 干支, and so is every 流月.
  if (typeof f.taiyuan === "string") out.add(f.taiyuan);
  for (const m of (f.liuyue as { months?: { ganzhi: string }[] } | undefined)?.months ?? [])
    out.add(m.ganzhi);
  // Not dayun_years (v3.3.0): no prompt reads it, and its 80 years hold every 干支, so counting
  // them would let any 干支 through.
  return out;
}

export function checkFaithfulness(chart: ChartFact, report: Report): FaithfulnessIssue[] {
  const issues: FaithfulnessIssue[] = [];
  const texts = reportTexts(report);
  const locale = report.locale as Locale;

  if (chart.system === "bazi") {
    const known = knownGanzhi(chart);
    for (const t of texts) {
      for (const m of t.matchAll(GZ)) {
        // 干支 inside a longer 干支 run like 庚午己卯 are still individually checked.
        if (!known.has(m[0]))
          issues.push({ kind: "unknown_ganzhi", detail: `${m[0]} is not in the chart`, quote: t });
      }
      const thisYear = Number(report.created_at.slice(0, 4));
      for (const m of t.matchAll(RELATIVE_GZ)) {
        const year = thisYear + RELATIVE_OFFSET[m[1]!.toLowerCase()]!;
        const real = yearGanZhi(year);
        if (real !== m[2])
          issues.push({
            kind: "wrong_relative_year",
            detail: `${m[1]} is ${year} ${real}, not ${m[2]}`,
            quote: t,
          });
      }
      for (const m of t.matchAll(YEAR_GZ)) {
        const real = yearGanZhi(Number(m[1]));
        if (real !== m[2])
          issues.push({
            kind: "wrong_year_ganzhi",
            detail: `${m[1]} is ${real}, not ${m[2]}`,
            quote: t,
          });
      }
    }
  }

  if (chart.system === "tarot") {
    const cards = (chart.facts as { cards: { card_id: string; reversed: boolean }[] }).cards;
    const inSpread = new Map(cards.map((c) => [c.card_id, c.reversed]));
    // Longest names first so 「權杖十」 isn't matched as 「權杖一」-like prefixes.
    const names = DECK.flatMap((c) =>
      [...Object.values(c.name), ...(NAME_ALIASES[c.id] ?? [])].map((n) => ({ id: c.id, name: n })),
    ).sort((a, b) => b.name.length - a.name.length);
    for (const t of texts) {
      let rest = t;
      for (const { id, name } of names) {
        const at = findCard(rest, name);
        if (at < 0) continue;
        rest = rest.slice(0, at) + " ".repeat(name.length) + rest.slice(at + name.length);
        if (!inSpread.has(id)) {
          issues.push({
            kind: "card_not_in_spread",
            detail: `${name} is not in this spread`,
            quote: t,
          });
          continue;
        }
        const after = t.slice(at + name.length, at + name.length + 6);
        const saysReversed = /^[（(]?\s*(逆位|reversed)/i.test(after);
        const saysUpright = /^[（(]?\s*(正位|upright)/i.test(after);
        const reversed = inSpread.get(id)!;
        if ((saysReversed && !reversed) || (saysUpright && reversed)) {
          issues.push({
            kind: "wrong_orientation",
            detail: `${name} is ${reversed ? "reversed" : "upright"}`,
            quote: t,
          });
        }
      }
    }
  }

  if (chart.system === "qiuqian") {
    // Every seven-character run in a quotation must be one of the lot's lines, in the reader's script
    // (English readers quote the original). Shorter quotes (a term, part of a line) aren't checked.
    const n = (chart.facts as { lot: { n: number } }).lot.n;
    const lines = new Set(lotBrief(chart, locale).lines.map((l) => l.text));
    for (const t of texts) {
      for (const q of t.matchAll(QUOTE)) {
        for (const run of q[1]!.split(/[，。、；！？,.;!?\s]+/)) {
          if (/^\p{Script=Han}{7}$/u.test(run) && !lines.has(run))
            issues.push({
              kind: "misquoted_line",
              detail: `「${run}」 is not a line of this lot`,
              quote: t,
            });
        }
      }
      for (const m of t.matchAll(LOT_NUMBER)) {
        if (lotNumber(m[1] ?? m[2]!) !== n)
          issues.push({ kind: "wrong_lot", detail: `this is lot ${n}, not ${m[0]}`, quote: t });
      }
    }
  }

  if (chart.system === "liuyao" && locale !== "en") {
    // A 算卦 reading names only its own two hexagrams, and quotes no other hexagram's 卦辭 or 爻辭. A quoted
    // phrase of four or more characters found in no hexagram (the user's own words) isn't checked.
    const f = chart.facts as {
      primary: { id: string };
      changed?: { id: string };
      cast: { ganzhi: Record<string, string> };
    };
    const own = new Set([f.primary.id, ...(f.changed ? [f.changed.id] : [])]);
    const all = allHexagrams();
    const mine = all.filter((h) => own.has(h.id)).flatMap((h) => h.texts[locale]);
    const others = all.filter((h) => !own.has(h.id));
    // The only 干支 a reading may name: the cast time's four (rule 29), and last, this and next year's.
    const year = Number(report.created_at.slice(0, 4));
    const ganzhi = new Set([
      ...Object.values(f.cast.ganzhi),
      yearGanZhi(year - 1),
      yearGanZhi(year),
      yearGanZhi(year + 1),
    ]);
    for (const t of texts) {
      for (const m of t.matchAll(GZ)) {
        if (!ganzhi.has(m[0]))
          issues.push({
            kind: "unknown_ganzhi",
            detail: `${m[0]} is not the cast's 干支`,
            quote: t,
          });
      }
      for (const h of others) {
        if (t.includes(h.full[locale]))
          issues.push({
            kind: "wrong_hexagram",
            detail: `${h.full[locale]} is not this cast's hexagram`,
            quote: t,
          });
      }
      for (const q of t.matchAll(QUOTE)) {
        for (const run of q[1]!.split(/[，。、；：！？,.;:!?\s]+/)) {
          if ([...run].length < 4 || !/^\p{Script=Han}+$/u.test(run)) continue;
          if (mine.some((x) => x.includes(run))) continue;
          if (others.some((h) => h.texts[locale].some((x) => x.includes(run))))
            issues.push({
              kind: "misquoted_text",
              detail: `「${run}」 is from another hexagram's text`,
              quote: t,
            });
        }
      }
    }
  }

  if (locale !== "en") {
    const other: Locale = locale === "zh-Hant" ? "zh-Hans" : "zh-Hant";
    for (const forms of Object.values(loadTerms().terms)) {
      const wrong = forms[other];
      if (wrong.length > 1 && wrong !== forms[locale]) {
        for (const t of texts)
          if (t.includes(wrong))
            issues.push({ kind: "wrong_script", detail: `${wrong} → ${forms[locale]}`, quote: t });
      }
    }
  }
  return issues;
}
