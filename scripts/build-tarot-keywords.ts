/**
 * Builds data/tarot/keywords.json: the three keywords painted on each card (JingyaoPaint
 * local_art/tarot, kept on that computer only), 简体 as painted and 繁體 by OpenCC (cn → tw),
 * reviewed for one-to-many characters (rule G18; reviewed fixes in HANT_FIXES). English is
 * written by hand to the Rider–Waite–Smith meanings (src/engines/tarot/keywords-en.ts).
 *
 *   npm run build:tarot-keywords [-- <JingyaoPaint local_art/tarot folder>]
 */
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import OpenCC from "opencc-js";
import { DECK } from "../src/engines/tarot/deck.js";

const SOURCE = process.argv[2] ?? "C:\\AIProjects\\JingyaoPaint\\local_art\\tarot";
const OUT = new URL("../data/tarot/keywords.json", import.meta.url);
const toHant = OpenCC.Converter({ from: "cn", to: "tw" });

/**
 * Where OpenCC's answer was checked against a reference and is wrong for the card (G18).
 * Reviewed 2026-10-28 (v2.7.0), all 234 keywords against the 教育部 forms: only 疗愈 needed
 * one (OpenCC keeps 愈; healing is 療癒). The rest of the flagged ones are right as converted
 * (專注, 關係, 陰暗面, 復活, 規劃, 衝突, 最後堅持, 衝勁, 夥伴, 恢復, 平復, 困局, 限制, 谷底, 衝鋒, 控制, 困境,
 * and 物質慾望: 慾 for desires).
 */
const HANT_FIXES: Record<string, string> = { 疗愈: "療癒" };

/** 简体 characters with more than one 繁體 form: every keyword holding one is listed for review. */
const ONE_TO_MANY =
  /[后干发钟面里松只台系历复范制准冲尽余斗谷丑云借划才几了占采曲向体伙卜朴困御板扑游征郁注愈欲]/u;

const quoted = (list: string) => [...list.matchAll(/'([^']+)'/g)].map((m) => m[1]!);
const dart = readdirSync(SOURCE).filter((f) => f.endsWith(".dart") && !f.endsWith("_test.dart"));

// The majors: TarotCard(number: N, …, keywords: ['…', '…', '…']).
const majors = new Map<number, string[]>();
for (const f of dart) {
  const src = readFileSync(`${SOURCE}/${f}`, "utf8");
  for (const m of src.matchAll(/TarotCard\(\s*number:\s*(\d+),[\s\S]*?keywords:\s*\[([^\]]*)\]/g)) {
    if (majors.has(Number(m[1]))) throw new Error(`major ${m[1]} defined twice (${f})`);
    majors.set(Number(m[1]), quoted(m[2]!));
  }
}

// The minors: _meanings[suit][rank], rank 0 the ace … 9 the ten, then page, knight, queen, king.
const kit = readFileSync(`${SOURCE}/minors_kit.dart`, "utf8");
const table = /const _meanings = <Suit, List<List<String>>>\{([\s\S]*?)\n\};/.exec(kit)?.[1];
if (!table) throw new Error("minors_kit.dart: _meanings not found");
const minors = new Map<string, string[][]>();
for (const m of table.matchAll(/Suit\.(\w+):\s*\[([\s\S]*?)\n\s*\],/g)) {
  minors.set(
    m[1]!,
    [...m[2]!.matchAll(/\[([^[\]]*)\]/g)].map((x) => quoted(x[1]!)),
  );
}

const cards: Record<string, { "zh-Hans": string[]; "zh-Hant": string[] }> = {};
const review: string[] = [];
for (const card of DECK) {
  const hans =
    card.arcana === "major" ? majors.get(card.rank) : minors.get(card.suit!)?.[card.rank - 1];
  if (hans?.length !== 3) {
    throw new Error(`${card.id}: expected 3 keywords on the card, found ${JSON.stringify(hans)}`);
  }
  const hant = hans.map((w) => HANT_FIXES[w] ?? toHant(w));
  hans.forEach((w, i) => ONE_TO_MANY.test(w) && review.push(`${card.id} ${w} → ${hant[i]}`));
  cards[card.id] = { "zh-Hans": hans, "zh-Hant": hant };
}
if (majors.size !== 22) throw new Error(`expected 22 majors, found ${majors.size}`);

mkdirSync(new URL("./", OUT), { recursive: true });
writeFileSync(
  OUT,
  JSON.stringify({ source: "JingyaoPaint local_art/tarot (painted keywords)", cards }, null, 2) +
    "\n",
);
console.log(`wrote ${Object.keys(cards).length} cards; review these one-to-many characters (G18):`);
for (const line of review) console.log(`  ${line}`);
