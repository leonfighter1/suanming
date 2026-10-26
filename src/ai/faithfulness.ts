/**
 * Automatic faithfulness checks for a generated report: does the AI text only
 * state chart data that is actually in the ChartFact?
 *
 * Checked (deterministically, no model):
 * - every 干支 pair mentioned exists in the chart (pillars, 大運, 流年, 農曆年);
 * - "YYYY年 + 干支" / "YYYY 干支" pairings match the year's real 干支;
 * - every tarot card named is in the spread, and 正位/逆位 claims match;
 * - zh-Hant text contains no simplified forms of protected terms (and vice versa).
 * Not checked: 十神/五行 reasoning, which needs a human reviewer.
 */
import type { ChartFact } from "../chart-fact/index.js";
import { DECK } from "../engines/tarot/deck.js";
import { yearGanZhi } from "../engines/bazi/index.js";
import type { Report } from "./pipeline.js";
import { loadTerms, type Locale } from "./terms.js";

export interface FaithfulnessIssue {
  kind:
    | "unknown_ganzhi"
    | "wrong_year_ganzhi"
    | "card_not_in_spread"
    | "wrong_orientation"
    | "wrong_script";
  detail: string;
  quote: string;
}

const GZ = /[甲乙丙丁戊己庚辛壬癸][子丑寅卯辰巳午未申酉戌亥]/g;
const YEAR_GZ =
  /((?:19|20|21)\d{2})\s*年?\s*的?\s*([甲乙丙丁戊己庚辛壬癸][子丑寅卯辰巳午未申酉戌亥])/g;

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
      Object.values(c.name).map((n) => ({ id: c.id, name: n })),
    ).sort((a, b) => b.name.length - a.name.length);
    for (const t of texts) {
      let rest = t;
      for (const { id, name } of names) {
        const at = rest.indexOf(name);
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
