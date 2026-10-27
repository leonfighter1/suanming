/**
 * Builds data/yijing/hexagrams.json: the 64 hexagrams of 周易 with 卦辞, 爻辞 and
 * 大象, in 繁體 and 简体.
 *
 *   npm run build:yijing
 *
 * Source: @freizl/yijing 2.1.0 (MIT, https://github.com/freizl/yijing), zh-TW
 * text. Its zh-CN file mixes in 繁體 characters (e.g. 泰「小往大來」), so 简体 is
 * converted from zh-TW with OpenCC instead. `id` is the six lines bottom (初爻)
 * first, 1 = yang. ERRATA fixes known variants against the 通行本.
 */
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import OpenCC from "opencc-js";

const require = createRequire(import.meta.url);
const toHans = OpenCC.Converter({ from: "tw", to: "cn" });

/** Known variants in the source, corrected to the 通行本 reading. */
const ERRATA: [string, string][] = [["不災畬", "不菑畬"]];
const fix = (s: string) => ERRATA.reduce((t, [a, b]) => t.split(a).join(b), s);

interface SourceGua {
  id: string;
  name: string;
  gua_ci: string;
  yao_ci: string[];
  da_xiang: string;
}
const tw = JSON.parse(
  readFileSync(require.resolve("@freizl/yijing/zh-TW/64gua.json"), "utf8"),
) as SourceGua[];
if (tw.length !== 64 || new Set(tw.map((g) => g.id)).size !== 64)
  throw new Error("expected 64 hexagrams");

/**
 * OpenCC turns 乾 into 干 (乾坤 → 干坤). In 周易 乾 is the hexagram / heaven and
 * Mainland editions keep it, so it is shielded from conversion.
 */
const KEEP = [["乾", "\u{F0000}"]] as const;
const hansOf = (hant: string) => {
  let s = hant;
  for (const [ch, mark] of KEEP) s = s.split(ch).join(mark);
  s = toHans(s);
  for (const [ch, mark] of KEEP) s = s.split(mark).join(ch);
  return s;
};

const both = (s: string) => {
  const hant = fix(s);
  return { "zh-Hant": hant, "zh-Hans": hansOf(hant) };
};
const out = tw.map((g) => ({
  id: g.id,
  name: both(g.name),
  gua_ci: both(g.gua_ci),
  yao_ci: g.yao_ci.map(both),
  da_xiang: both(g.da_xiang),
}));

const dir = new URL("../data/yijing/", import.meta.url);
mkdirSync(dir, { recursive: true });
writeFileSync(
  new URL("hexagrams.json", dir),
  JSON.stringify(
    {
      source:
        "周易 64 卦 text from @freizl/yijing 2.1.0 (MIT, Haisheng Wu); 简体 by OpenCC; built by scripts/build-yijing.ts",
      hexagrams: out,
    },
    null,
    1,
  ) + "\n",
);
console.log(`wrote ${out.length} hexagrams`);
