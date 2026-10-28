/**
 * Builds data/liuyao/plain.json: 算卦's 直說 for the 64 hexagrams, in 繁體 (scripts/liuyao-plain, by hand) and
 * 简体 (OpenCC, here, so the server never loads it: rule 36).
 *
 *   npm run build:liuyao
 *
 * Checks the source against data/yijing: the same hexagram at each place in the King Wen order, and one 直說
 * for each 爻辭 (seven for 乾 and 坤, with 用九 / 用六). 乾 is kept from OpenCC's 乾 → 干 (G18), as for the
 * 周易 text itself.
 */
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import OpenCC from "opencc-js";
import { PLAIN } from "./liuyao-plain/index.js";

const toHans = OpenCC.Converter({ from: "tw", to: "cn" });
const KEEP = [["乾", "\u{F0000}"]] as const;
const hansOf = (hant: string) => {
  let s = hant;
  for (const [ch, mark] of KEEP) s = s.split(ch).join(mark);
  s = toHans(s);
  for (const [ch, mark] of KEEP) s = s.split(mark).join(ch);
  return s;
};
const both = (hant: string) => ({ "zh-Hant": hant, "zh-Hans": hansOf(hant) });

export const PLAIN_VERSION = "1.0.0";

/** The table the server reads, from the source; throws if the source and the 周易 text disagree. */
export function buildPlain() {
  const zhouyi = (
    JSON.parse(readFileSync("data/yijing/hexagrams.json", "utf8")) as {
      hexagrams: { id: string; yao_ci: unknown[] }[];
    }
  ).hexagrams;
  if (PLAIN.length !== zhouyi.length) throw new Error(`expected ${zhouyi.length} hexagrams`);
  const hexagrams = PLAIN.map((h, i) => {
    const z = zhouyi[i]!;
    if (h.id !== z.id) throw new Error(`hexagram ${i + 1}: source ${h.id}, 周易 ${z.id}`);
    if (h.lines.length !== z.yao_ci.length)
      throw new Error(`hexagram ${i + 1}: ${h.lines.length} lines, 周易 has ${z.yao_ci.length}`);
    return { id: h.id, number: i + 1, gua: both(h.gua), lines: h.lines.map(both) };
  });
  return {
    version: PLAIN_VERSION,
    source:
      "算卦 直說, written by hand in 繁體 after the common readings (程頤, 朱熹); 简体 by OpenCC; built by scripts/build-liuyao.ts",
    hexagrams,
  };
}

if (process.argv[1]?.endsWith("build-liuyao.ts")) {
  mkdirSync("data/liuyao", { recursive: true });
  const table = buildPlain();
  writeFileSync("data/liuyao/plain.json", JSON.stringify(table, null, 1) + "\n");
  console.log(`wrote ${table.hexagrams.length} hexagrams`);
}
