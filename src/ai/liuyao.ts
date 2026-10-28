/**
 * 算卦 only (nothing here is used by any other method): the cast as the reading agent sees it in <cast>. The
 * time and its 干支, the 本卦 and 變卦 with their trigrams and 卦辭, the six lines by name, and the texts the
 * reading rests on (朱熹), each with its 直說 and the path to cite (/focus/texts/0 is the main one). Chinese
 * only: the owner removed English support (2026-10-28).
 */
import type { ChartFact } from "../chart-fact/index.js";
import type { Hex, LiuyaoFacts } from "../engines/liuyao/index.js";
import { plainOf } from "../engines/liuyao/plain.js";
import { TRIGRAMS } from "../engines/yijing/index.js";
import type { Locale } from "./terms.js";

/** The protected terms a 算卦 reading uses (i18n/terms.json keys), for its <glossary>. */
export const LIUYAO_TERMS = [
  "本卦",
  "变卦",
  "动爻",
  "卦辞",
  "爻辞",
  "老阳",
  "老阴",
  "少阳",
  "少阴",
];

type Script = "zh-Hant" | "zh-Hans";
const NUMBERS = ["初", "二", "三", "四", "五", "上"];

/** 初九, 六二 … 上六: a line's name from its place and whether it is yang; 7 is 用九 / 用六. */
export function lineName(position: number, yang: boolean): string {
  const n = yang ? "九" : "六";
  if (position === 7) return `用${n}`;
  return position === 1 || position === 6
    ? `${NUMBERS[position - 1]}${n}`
    : `${n}${NUMBERS[position - 1]}`;
}

export function liuyaoBrief(chart: ChartFact, locale: Locale) {
  const f = chart.facts as unknown as LiuyaoFacts;
  const s: Script = locale === "zh-Hans" ? "zh-Hans" : "zh-Hant";
  const trigram = (id: string) => {
    const t = TRIGRAMS.find((x) => x.id === id)!;
    return `${t.name[s]}（${t.image[s]}）`;
  };
  const hex = (h: Hex) => ({
    name: h.full_name[s],
    number: h.number,
    upper: trigram(h.upper),
    lower: trigram(h.lower),
    gua_ci: h.gua_ci[s],
  });
  const g = f.cast.ganzhi;
  const yang = (hexId: string, position: number) => hexId[position - 1] === "1";
  return {
    time: f.cast.local.replace("T", " "),
    ganzhi: `${g.year}年 ${g.month}月 ${g.day}日 ${g.hour}${s === "zh-Hant" ? "時" : "时"}`,
    primary: hex(f.primary),
    ...(f.changed && { changed: hex(f.changed) }),
    lines: f.lines.map((l) => ({
      name: lineName(l.position, l.yang),
      moving: l.moving,
    })),
    focus: f.focus.texts.map((t, i) => {
      const h = t.hexagram === "primary" ? f.primary : f.changed!;
      return {
        path: `/focus/texts/${i}`,
        role: t.role,
        of: t.hexagram,
        name:
          t.line === undefined
            ? s === "zh-Hant"
              ? "卦辭"
              : "卦辞"
            : // 用九 / 用六 take the hexagram's own lines, all yang (乾) or all yin (坤).
              lineName(t.line, t.line === 7 ? h.id === "111111" : yang(h.id, t.line)),
        text: t.text[s],
        plain: plainOf(h.id, t.line)[s],
      };
    }),
  };
}

/** What the reading agent reads in <chart_facts>: the cast, without the coins, the layout and the audit. */
export function liuyaoView(facts: Record<string, unknown>): Record<string, unknown> {
  const { tosses: _t, pick: _p, audit: _a, ...rest } = facts;
  return rest;
}
