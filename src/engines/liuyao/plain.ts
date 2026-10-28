/**
 * 算卦's 直說 (tech plan WP10.2): each hexagram's 卦辭 and each 爻辭 said straight out, as the owner asks
 * (「卦辞都是直抒胸臆，不用绕」). Built by `npm run build:liuyao` into data/liuyao/plain.json, in 繁體 and 简体; this
 * module only reads it (no OpenCC on the server, rule 36). The app gets the same table through `npm run sync:app`.
 */
import { readFileSync } from "node:fs";

export type PlainText = { "zh-Hant": string; "zh-Hans": string };

interface PlainHexagram {
  id: string;
  number: number;
  gua: PlainText;
  /** 初 to 上, then 用九 / 用六 for 乾 and 坤 */
  lines: PlainText[];
}

let table: { version: string; hexagrams: PlainHexagram[] } | undefined;
const load = () =>
  (table ??= JSON.parse(
    readFileSync(new URL("../../../data/liuyao/plain.json", import.meta.url), "utf8"),
  ) as { version: string; hexagrams: PlainHexagram[] });

export const plainVersion = () => load().version;

/** The 直說 of a hexagram's 卦辭 (no line), or of one of its lines (1–6, 7 for 用九 / 用六). */
export function plainOf(id: string, line?: number): PlainText {
  const h = load().hexagrams.find((x) => x.id === id);
  if (!h) throw new Error(`no hexagram ${id}`);
  const text = line === undefined ? h.gua : h.lines[line - 1];
  if (!text) throw new Error(`hexagram ${id} has no line ${line}`);
  return text;
}
