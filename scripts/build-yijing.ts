/**
 * Builds data/yijing/hexagrams.json: the 64 hexagrams of 周易 with 卦辞, 爻辞 and
 * 大象, in 繁體 and 简体.
 *
 *   npm run build:yijing
 *
 * Source: @freizl/yijing 2.1.0 (MIT, https://github.com/freizl/yijing), zh-TW
 * text. Its zh-CN file mixes in 繁體 characters (e.g. 泰「小往大來」), so 简体 is
 * converted from zh-TW with OpenCC instead. `id` is the six lines bottom (初爻)
 * first, 1 = yang. ERRATA and LINES correct the source where 維基文庫《周易》 and
 * 《周易正義》 agree against it (docs/verification/zhouyi.md).
 */
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import OpenCC from "opencc-js";

const require = createRequire(import.meta.url);
const toHans = OpenCC.Converter({ from: "tw", to: "cn" });

/**
 * Corrections: [source, correct, matches]. Most are characters mis-converted to
 * 繁體 (兇 for 凶, 鹹 for 咸, 鬥 for 斗 …); the rest are missing or misplaced
 * words. Each must match the source exactly `matches` times, so a correction
 * that no longer fits (or fits more than it should) stops the build.
 */
const ERRATA: [string, string, number][] = [
  ["不災畬", "不菑畬", 1],
  ["兇", "凶", 58],
  ["鹹", "咸", 10],
  ["輿屍", "輿尸", 2],
  ["終來有他", "終來有它", 1],
  ["訴訴", "愬愬", 1],
  ["以其匯", "以其彙", 1],
  ["系於苞桑", "繫於苞桑", 1],
  ["系小子", "係小子", 1],
  ["系丈夫", "係丈夫", 1],
  ["拘系之", "拘係之", 1],
  ["不復遠", "不遠復", 1],
  ["不耕獲", "不耕穫", 1],
  ["或系之牛", "或繫之牛", 1],
  ["系用徽纆", "係用徽纆", 1],
  ["系遯", "係遯", 1],
  ["出於門庭", "於出門庭", 1],
  ["巳事遄往", "已事遄往", 1],
  ["巳日", "已日", 2],
  ["踟躅", "蹢躅", 1],
  ["賫咨", "齎咨", 1],
  ["百裏", "百里", 1],
  ["見鬥", "見斗", 2],
  ["見沫", "見沬", 1],
  ["童仆", "童僕", 2],
  ["號啕", "號咷", 2],
  ["渙奔其機", "渙奔其机", 1],
  ["鴻漸於幹", "鴻漸於干", 1],
  ["勿用娶女", "勿用取女", 1],
  ["晉如碩鼠", "晉如鼫鼠", 1],
  ["老婦得士夫", "老婦得其士夫", 1],
  ["王假有家，勿恤，往吉", "王假有家，勿恤，吉", 1],
  ["無咎，貞吉，有攸往", "無咎，貞吉，利有攸往", 1],
  ["小亨，利攸往", "小亨，利有攸往", 1],
  [
    "九五：以杞包瓜，含章，有隕自天。九五：以杞包瓜，含章，有隕自天。",
    "九五：以杞包瓜，含章，有隕自天。",
    1,
  ],
  // 大象: 后 (the sovereign) mis-converted to 後, 志 to 誌, 嚮 written 向; 履, 大壯, 震 and 既濟 misworded.
  ["天地交泰，後以", "天地交，泰；后以", 1],
  ["後不省方", "后不省方", 1],
  ["後以施命", "后以施命", 1],
  ["遂誌", "遂志", 1],
  ["向晦", "嚮晦", 1],
  ["安民誌", "定民志", 1],
  ["非禮勿履", "非禮弗履", 1],
  ["虩雷，震；君子以恐懼修身", "洊雷，震；君子以恐懼修省", 1],
  ["預防", "豫防", 1],
  // Read in the print (四部叢刊 宋本) where the copies disagree, or agree on a slip (噬腊, 繫, 祇).
  ["以辨上下", "以辯上下", 1],
  ["自天佑之", "自天祐之", 1],
  ["窺觀", "闚觀", 1],
  ["噬臘肉", "噬腊肉", 1],
  ["山附地上", "山附於地", 1],
  ["置於叢棘", "寘於叢棘", 1],
  ["系於金柅", "繫於金柅", 1],
  ["無祗悔", "無祇悔", 1],
  ["祗既平", "祇既平", 1],
];
const matched = new Map<string, number>();
const fix = (s: string) =>
  ERRATA.reduce((t, [a, b]) => {
    const parts = t.split(a);
    matched.set(a, (matched.get(a) ?? 0) + parts.length - 1);
    return parts.join(b);
  }, s);

/** Whole lines the source has wrong: [hexagram id, line index, source text, correct text]. */
const LINES: [string, number, string, string][] = [
  // 大有 九二 holds 同人 六二's text.
  ["111101", 1, "六二：同人於宗，吝。", "九二：大車以載，有攸往，無咎。"],
];

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
/** After OpenCC: 闚 is a 繁體 variant of 窺, and 简体 writes 窥. */
const HANS_FIXES = [["闚", "窥"]] as const;
const hansOf = (hant: string) => {
  let s = hant;
  for (const [ch, mark] of KEEP) s = s.split(ch).join(mark);
  s = toHans(s);
  for (const [ch, mark] of KEEP) s = s.split(mark).join(ch);
  for (const [a, b] of HANS_FIXES) s = s.split(a).join(b);
  return s;
};

const both = (hant: string) => ({ "zh-Hant": hant, "zh-Hans": hansOf(hant) });

/**
 * The source's layout slips: trailing spaces; 咸's lines open 「初六，」 where
 * the rest open 「初九：」; 屯, 師, 比, 履, 否, 同人 and 咸 lack the 「名：」 the
 * other 卦辭 open with. 履, 否 and 同人 open with their name as a word, as 艮
 * does (「艮：艮其背」), so they take the label before it: 「履：履虎尾」.
 */
const LINE_NAME = /^(初[六九]|[六九][二三四五]|上[六九]|用[六九])，/;
let lineNames = 0;
const yaoText = (s: string) => {
  if (LINE_NAME.test(s)) lineNames++;
  return s.replace(LINE_NAME, "$1：");
};
let guaNames = 0;
const guaText = (name: string, s: string) => {
  if (s.startsWith(`${name}：`)) return s;
  guaNames++;
  return `${name}：${s.startsWith(`${name}，`) ? s.slice(name.length + 1) : s}`;
};

const out = tw.map((g) => {
  const name = fix(g.name.trim());
  const yao = g.yao_ci.map((y) => yaoText(fix(y.trim())));
  for (const [id, i, was, is] of LINES) {
    if (id !== g.id) continue;
    if (yao[i] !== was) throw new Error(`${id} line ${i + 1}: expected the source's 「${was}」`);
    yao[i] = is;
  }
  return {
    id: g.id,
    name: both(name),
    gua_ci: both(guaText(name, fix(g.gua_ci.trim()))),
    yao_ci: yao.map(both),
    da_xiang: both(fix(g.da_xiang.trim())),
  };
});
for (const [a, , n] of ERRATA)
  if (matched.get(a) !== n)
    throw new Error(`erratum 「${a}」: ${matched.get(a) ?? 0} matches, expected ${n}`);
if (lineNames !== 6 || guaNames !== 7)
  throw new Error(
    `layout: ${lineNames} line names (expected 6), ${guaNames} 卦辭 names (expected 7)`,
  );

const dir = new URL("../data/yijing/", import.meta.url);
mkdirSync(dir, { recursive: true });
writeFileSync(
  new URL("hexagrams.json", dir),
  JSON.stringify(
    {
      source:
        "周易 64 卦 text from @freizl/yijing 2.1.0 (MIT, Haisheng Wu), corrected against 維基文庫《周易》 and 《周易正義》 (docs/verification/zhouyi.md); 简体 by OpenCC; built by scripts/build-yijing.ts",
      hexagrams: out,
    },
    null,
    1,
  ) + "\n",
);
console.log(`wrote ${out.length} hexagrams`);
