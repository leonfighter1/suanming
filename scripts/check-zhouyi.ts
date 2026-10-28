/**
 * Checks data/yijing/hexagrams.json (A, ours) against two other transcriptions of the 周易:
 * B 維基文庫《周易》 and C 維基文庫《周易正義》 (王弼注本, with 孔穎達's 疏). Every 卦辭, 爻辭 and 大象 is compared
 * character by character, punctuation and wiki markup aside, with variant forms (无/無, 于/於 …) mapped together.
 *
 *   npm run check:zhouyi
 *
 * Each text falls in one class: all agree; A = C (B differs); A = B (C differs); B = C (ours differs: a
 * correction for scripts/build-yijing.ts); or none agree. Then each text is looked up in D, 維基文庫's page
 * transcription of the print P (四部叢刊 周易, a 宋 print): a miss names the scan page to read in P. The result
 * of 2026-10-28 and each decision are in docs/verification/zhouyi.md. Not a harness gate: it fetches the pages
 * (raw wikitext, cached in .cache/zhouyi/), so it needs the network on its first run.
 */
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";

const CACHE = new URL("../.cache/zhouyi/", import.meta.url);
const TITLES = (
  "乾 坤 屯 蒙 需 訟 師 比 小畜 履 泰 否 同人 大有 謙 豫 隨 蠱 臨 觀 噬嗑 賁 剝 復 无妄 大畜 頤 大過 坎 離 " +
  "咸 恒 遯 大壯 晉 明夷 家人 睽 蹇 解 損 益 夬 姤 萃 升 困 井 革 鼎 震 艮 漸 歸妹 豐 旅 巽 兌 渙 節 中孚 小過 既濟 未濟"
).split(" ");

/** A page's raw wikitext, from the cache or 維基文庫 (a generic agent, rule 40; raw wikitext, rule 41). */
async function page(title: string, file: string): Promise<string> {
  const path = new URL(file, CACHE);
  if (existsSync(path)) return readFileSync(path, "utf8");
  const url = `https://zh.wikisource.org/w/index.php?title=${encodeURIComponent(title)}&action=raw`;
  const res = await fetch(url, { headers: { "user-agent": "mingli-research/1.0" } });
  if (!res.ok) throw new Error(`${title}: HTTP ${res.status}`);
  const text = await res.text();
  mkdirSync(new URL(".", path), { recursive: true });
  writeFileSync(path, text);
  await new Promise((r) => setTimeout(r, 300));
  return text;
}

const VARIANTS = [
  ["无", "無"],
  ["于", "於"],
  ["恒", "恆"],
  ["彊", "強"],
  ["强", "強"],
  ["説", "說"],
  ["敘", "敍"],
  ["艸", "草"],
  ["禦", "御"],
];
const norm = (s: string) => {
  let t = s.replace(/[，。；：、！？「」『』“”‘’（）()\s·．,.;:!?]/g, "");
  for (const [a, b] of VARIANTS) t = t.split(a!).join(b!);
  return t;
};
const YAO = /^(初[六九]|[六九][二三四五]|上[六九]|用[六九])[：，]/;

/** -{A|zh:乾;zh-hant:乾}- and -{云}- → the text. */
const conv = (s: string) =>
  s.replace(/-\{(?:A\|)?([^}]*)\}-/g, (_, x: string) =>
    x.includes(":") ? x.split(";").pop()!.split(":").pop()! : x,
  );

/** Every reading a {{另|X|Y}} allows (X or Y at each place). */
function readings(s: string): string[] {
  const m = /\{\{另\|([^|}]*)\|([^}]*)\}\}/.exec(s);
  if (!m) return [s];
  const head = s.slice(0, m.index);
  const tail = s.slice(m.index + m[0].length);
  return [m[1]!, m[2]!].flatMap((x) => readings(head + x + tail));
}

const strip = (s: string) =>
  conv(s)
    .replace(/<[^>]+>/g, "")
    .replace(/'''/g, "")
    .trim();

/** B: the 易經 block, one line per bullet (坤's 卦辭 runs over several); the 大象 opens 象曰. */
function parseB(text: string) {
  const lines = text.split("\n");
  const block: string[] = [];
  for (const l of lines.slice(lines.findIndex((x) => x.includes("易經：")) + 1)) {
    if (!/^\*[*#]/.test(l)) break;
    block.push(strip(l.replace(/^\*[*#]+/, "")));
  }
  const first = block.findIndex((l) => YAO.test(l));
  const at = lines.findIndex((x) => x.includes("'''象曰：'''"));
  const xiang = at < 0 ? "" : (lines.slice(at + 1).find((x) => x.startsWith("**")) ?? "");
  return {
    xiang: strip(xiang.replace(/^\*+/, "")),
    gua: block
      .slice(0, first)
      .join("")
      .replace(/^[^：]+：/, ""),
    yao: block.slice(first),
  };
}

/** Removes each {{*|…}} (王弼's 注), braces balanced, but keeps one that opens with the name (乾's 卦辭). */
function dropNotes(s: string, name: string) {
  let out = "";
  for (let i = 0; i < s.length;) {
    if (!s.startsWith("{{*|", i)) {
      out += s[i++];
      continue;
    }
    let depth = 0;
    let j = i;
    for (; j < s.length; j++) {
      if (s.startsWith("{{", j)) (depth++, j++);
      else if (s.startsWith("}}", j)) {
        depth--;
        j++;
        if (depth === 0) break;
      }
    }
    const inner = s.slice(i + 4, j - 1);
    if (inner.startsWith(`${name}：`)) out += inner;
    i = j + 1;
  }
  return out;
}

/**
 * C: the 經 between the 注 and 疏; a 《彖》 / 《象》 paragraph closes the text before it. The first 《象》 is the
 * 大象, which runs on (坤: 「地勢坤。」「君子以厚德載物。」) until it has its 「君子以 / 先王以 / 后以 …」.
 */
function parseC(text: string, name: string, count: number) {
  const lines = text.split("\n");
  let gua = "";
  let xiang = "";
  const yao: string[] = [];
  let open: "gua" | "xiang" | number | null = null;
  for (const raw of lines.slice(lines.findIndex((l) => /^==[^=]/.test(l)) + 1)) {
    if (/^\s*$|^\[疏\]|^:?\{\{批\|/.test(raw)) continue;
    const l = conv(dropNotes(raw, name))
      .replace(/\{\{\+\|([^}]*)\}\}/g, "$1")
      .replace(/<[^>]+>/g, "")
      .trim();
    if (!l) continue;
    if (/^.下.上。/.test(l)) {
      gua = l.replace(/^.下.上。/, "").replace(/^[^：]+：/, "");
      open = "gua";
    } else if (YAO.test(l) && yao.length < count) {
      yao.push(l);
      open = yao.length - 1;
    } else if (!xiang && /^《象》曰：?/.test(l)) {
      xiang = l.replace(/^《象》曰：?/, "");
      open = "xiang";
    } else if (l.startsWith("《")) open = null;
    else if (open === "gua") gua += l;
    else if (open === "xiang") {
      if (!xiang.includes("以")) xiang += l;
    } else if (open !== null) yao[open] += l;
  }
  return { gua, yao, xiang };
}

interface Text {
  id: string;
  name: Record<string, string>;
  gua_ci: Record<string, string>;
  yao_ci: Record<string, string>[];
  da_xiang: Record<string, string>;
}
const ours = (
  JSON.parse(readFileSync(new URL("../data/yijing/hexagrams.json", import.meta.url), "utf8")) as {
    hexagrams: Text[];
  }
).hexagrams;

const index = await page("周易正義", "zhengyi.txt");
const subpages = [...index.matchAll(/\[\[\/(\d\d[^|\]]+)\|/g)].map((m) => m[1]!).slice(0, 64);
const counts = { all: 0, "A=C": 0, "A=B": 0, "B=C": 0, none: 0 };
const differ: string[] = [];
for (const [i, a] of ours.entries()) {
  const n = String(i + 1).padStart(2, "0");
  const name = a.name["zh-Hant"]!;
  const b = parseB(await page(`周易/${TITLES[i]}`, `zhouyi/${n}.txt`));
  const c = parseC(
    await page(`周易正義/${subpages[i]}`, `zhengyi/${n}.txt`),
    name,
    a.yao_ci.length,
  );
  if (b.yao.length !== a.yao_ci.length || c.yao.length !== a.yao_ci.length)
    differ.push(`${i + 1} ${name}: ${a.yao_ci.length} lines, B ${b.yao.length}, C ${c.yao.length}`);
  const units: [string, string, string, string][] = [
    ["卦辭", a.gua_ci["zh-Hant"]!.replace(/^[^：]+：/, ""), b.gua, c.gua],
    ...a.yao_ci.map((y, j): [string, string, string, string] => [
      `爻${j + 1}`,
      y["zh-Hant"]!,
      b.yao[j] ?? "",
      c.yao[j] ?? "",
    ]),
    ["大象", a.da_xiang["zh-Hant"]!, b.xiang, c.xiang],
  ];
  for (const [what, at, bt, ct] of units) {
    const A = norm(at);
    const Bs = readings(bt).map(norm);
    const C = norm(ct);
    const ab = Bs.includes(A);
    const ac = A === C;
    const cls = ab && ac ? "all" : ac ? "A=C" : ab ? "A=B" : Bs.includes(C) ? "B=C" : "none";
    counts[cls]++;
    if (cls !== "all")
      differ.push(`${i + 1} ${name} ${what} [${cls}]\n  A ${at}\n  B ${bt}\n  C ${ct}`);
  }
}
console.log(JSON.stringify(counts));
for (const d of differ) console.log(d);

// ---- D: 維基文庫's page transcription of the print P (四部叢刊 周易, 王弼注, photo-reprint of a 宋 print) ----
// D has no punctuation and keeps the print's glyph forms. Each text of ours must occur in its hexagram's run of
// 經 text; a miss prints the closest run and the scan page(s) to read in P.

const SCANS = ["Sibu Congkan0001-王弼-周易-2-1.djvu", "Sibu Congkan0002-王弼-周易-2-2.djvu"];
/** D's pages for one scan, by number, from the cache or the API (50 at a time). */
async function transcription(file: string, cache: string): Promise<Record<number, string>> {
  const path = new URL(cache, CACHE);
  if (existsSync(path)) return JSON.parse(readFileSync(path, "utf8")) as Record<number, string>;
  const pages: Record<number, string> = {};
  let cont: Record<string, string> = {};
  for (;;) {
    const params = new URLSearchParams({
      action: "query",
      format: "json",
      generator: "allpages",
      gapnamespace: "104",
      gapprefix: `${file}/`,
      gaplimit: "50",
      prop: "revisions",
      rvprop: "content",
      rvslots: "main",
      ...cont,
    });
    const res = await fetch(`https://zh.wikisource.org/w/api.php?${params}`, {
      headers: { "user-agent": "mingli-research/1.0" },
    });
    const j = (await res.json()) as {
      continue?: Record<string, string>;
      query?: {
        pages: Record<
          string,
          { title: string; revisions?: { slots: { main: { "*": string } } }[] }
        >;
      };
    };
    for (const p of Object.values(j.query?.pages ?? {}))
      pages[Number(p.title.split("/").pop())] = p.revisions?.[0]?.slots.main["*"] ?? "";
    if (!j.continue) break;
    cont = j.continue;
    await new Promise((r) => setTimeout(r, 1000));
  }
  mkdirSync(CACHE, { recursive: true });
  writeFileSync(path, JSON.stringify(pages));
  return pages;
}

/** D's glyph codes ({{SKchar|N}}) that occur in the 經, read from their contexts; 1231–1294 are hexagram symbols. */
const SK: Record<string, string> = {
  2780: "吉",
  2965: "彖",
  2989: "恒",
  3892: "類",
  3932: "鬼",
  2854: "孤",
  3129: "桓",
  3664: "說",
  2973: "衍",
  3771: "邦",
  3424: "初",
  3470: "笑",
  3951: "揚",
  2679: "肉",
  1841: "龜",
  3140: "棘",
  2902: "歲",
  1699: "雨",
  3787: "鉉",
  1507: "虩",
  2517: "昃",
};
/** The print's glyph forms (爲, 徃, 顚 …) and the usual variants, mapped together: forms, not readings. */
const PRINT_FORMS = (
  "無无 於于 為爲 舍舎 遠逺 潛濳 既旣 兌兊 剝剥 頤頥 朵朶 歲歳 即卽 恆恒 強彊 强彊 說説 敍敘 草艸 御禦 群羣 " +
  "床牀 眾衆 告吿 教敎 真眞 奇竒 宜冝 乘乗 高髙 盜盗 器噐 寇宼 㓂宼 靜静 敘叙 𢘆恒 久乆 喪䘮 婚㛰 涉渉 𠮷吉 " +
  "陷䧟 戶户 戸户 內内 往徃 彙彚 祿禄 𩔖類 遲遟 賓賔 宮宫 顛顚 慎愼 世丗 虛虚 茲兹 䑕鼠 岀出 蒞莅 曳曵 脩修 " +
  "慍愠 葘菑 𥙿裕 㝠冥 蔾藜 薫薰 閴闃 隂陰 鼔鼓 勑敕 𤣥玄 𣅳昃 耊耋 𣏌杞 𤓰瓜"
)
  .split(" ")
  .map((p) => [...p] as [string, string]);
const normP = (s: string) => {
  let t = s.replace(/[，。；：、！？「」『』“”‘’（）()\s·．,.;:!?]/g, "");
  for (const [a, b] of PRINT_FORMS) t = t.split(a).join(b);
  return t;
};
/** Removes each {{雙行註文|…}} (王弼's 注, in double small columns), braces balanced. */
function dropSmall(s: string) {
  let out = "";
  for (let i = 0; i < s.length;) {
    if (!s.startsWith("{{雙行註文|", i)) {
      out += s[i++];
      continue;
    }
    let depth = 0;
    let j = i;
    for (; j < s.length; j++) {
      if (s.startsWith("{{", j)) (depth++, j++);
      else if (s.startsWith("}}", j)) {
        depth--;
        j++;
        if (depth === 0) break;
      }
    }
    i = j + 1;
  }
  return out;
}

// One stream of 經 text, each character with its scan page.
let stream = "";
const pageOf: string[] = [];
for (const [v, file] of SCANS.entries()) {
  const pages = await transcription(file, `sibu-${v + 1}.json`);
  for (const n of Object.keys(pages)
    .map(Number)
    .sort((a, b) => a - b)) {
    const t = dropSmall(pages[n]!.replace(/<noinclude>[\s\S]*?<\/noinclude>/g, ""))
      .replace(/\{\{SKchar\|(\d+)\}\}/g, (_, k: string) =>
        Number(k) >= 1231 && Number(k) <= 1294 ? "§" : (SK[k] ?? "□"),
      )
      .replace(/\{\{[^}]*\}\}/g, "")
      .replace(/<[^>]+>/g, "");
    for (const ch of normP(t)) {
      stream += ch;
      pageOf.push(`${v + 1}/${n}`);
    }
  }
}
// Each hexagram starts at its name and first words (履 opens 「履虎尾」, 坎 「習坎」), else at its symbol.
const starts: number[] = [];
for (const h of ours) {
  const name = normP(h.name["zh-Hant"]!);
  const gua = normP(h.gua_ci["zh-Hant"]!.replace(/^[^：]+：/, ""));
  const key = name === "坎" ? "習坎有孚" : (gua.startsWith(name) ? gua : name + gua).slice(0, 4);
  const from = (starts.at(-1) ?? -1) + 1;
  let at = stream.indexOf(key, from);
  if (at < 0) at = stream.indexOf("§", from) + 1;
  starts.push(at);
}
let found = 0;
const missed: string[] = [];
for (const [i, h] of ours.entries()) {
  const seg = stream.slice(starts[i], starts[i + 1] ?? starts[i]! + 3000);
  const name = normP(h.name["zh-Hant"]!);
  const gua = normP(h.gua_ci["zh-Hant"]!.replace(/^[^：]+：/, ""));
  const units: [string, string, string[]][] = [
    ["卦辭", gua, [name + gua, gua]],
    ...h.yao_ci.map((y, j): [string, string, string[]] => [
      `爻${j + 1}`,
      normP(y["zh-Hant"]!),
      [normP(y["zh-Hant"]!)],
    ]),
    ["大象", normP(h.da_xiang["zh-Hant"]!), [normP(h.da_xiang["zh-Hant"]!)]],
  ];
  for (const [what, text, forms] of units) {
    if (forms.some((f) => seg.includes(f))) {
      found++;
      continue;
    }
    let best = 0;
    let at = 0;
    for (let k = 0; k < seg.length; k++) {
      let m = 0;
      for (let c = 0; c < text.length; c++) if (seg[k + c] === text[c]) m++;
      if (m > best) ((best = m), (at = k));
    }
    const pages = new Set(pageOf.slice(starts[i]! + at, starts[i]! + at + text.length));
    missed.push(
      `${i + 1} ${h.name["zh-Hant"]} ${what} (scan ${[...pages].join(", ")})\n  ours ${text}\n  D    ${seg.slice(at, at + text.length + 2)}`,
    );
  }
}
console.log(JSON.stringify({ print: { found, missed: missed.length } }));
for (const m of missed) console.log(m);
