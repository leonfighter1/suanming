// WP4.2 (docs/tech-plan.md): every term the 命盘 page makes tappable has a plain explanation in the
// three scripts. 简体 and English are written by hand; 繁體 is converted and reviewed (G18).
import { createHash } from "node:crypto";
import { expect, it } from "vitest";
import { loadTerms, TERM_TIPS, termTips } from "../src/ai/index.js";
import { compileRules, loadRuleSet, scan } from "../src/compliance/index.js";
import { diShi, tenGod } from "../src/engines/bazi/index.js";
import type { RelationType } from "../src/engines/bazi/relations.js";
import type { ShenshaName } from "../src/engines/bazi/shensha.js";
import type { Strength } from "../src/engines/bazi/strength.js";

const GANS = [..."甲乙丙丁戊己庚辛壬癸"];
const ZHIS = [..."子丑寅卯辰巳午未申酉戌亥"];

// One entry per member of each engine union: a new relation, 神煞 or verdict fails the typecheck
// until it is listed here, and then this test until it has a tip.
const RELATIONS: Record<RelationType, true> = {
  天干五合: true,
  天干相冲: true,
  六合: true,
  六冲: true,
  三合: true,
  半合: true,
  三会: true,
  相刑: true,
  自刑: true,
  六害: true,
  相破: true,
};
const SHENSHA: Record<ShenshaName, true> = {
  天乙贵人: true,
  文昌: true,
  禄神: true,
  羊刃: true,
  桃花: true,
  驿马: true,
  华盖: true,
};
const STRENGTH: Record<Strength["verdict"] | NonNullable<Strength["special"]>, true> = {
  身强: true,
  身弱: true,
  中和: true,
  专旺候选: true,
  从格候选: true,
};
// The page's row labels, card titles and the other pills (bazi_chart_page.dart). The dialog is
// titled with what the reader tapped, so these need no entry in the term table.
const CONCEPTS = [
  "天干",
  "地支",
  "藏干",
  "十神",
  "十二长生",
  "纳音",
  "日主",
  "五行",
  "大运",
  "流年",
  "神煞",
  "空亡",
  "胎元",
  "得令",
  "喜用",
];

it("every term the 命盘 page can show has a tip", () => {
  // Every 十神 and 十二长生 the engine can write, from every day stem against every stem and branch.
  const tenGods = new Set(GANS.flatMap((d) => GANS.map((o) => tenGod(d, o))));
  const stages = new Set(GANS.flatMap((d) => ZHIS.map((z) => diShi(d, z))));
  expect([tenGods.size, stages.size]).toEqual([10, 12]);
  const shown = [
    ...tenGods,
    ...stages,
    ...Object.keys(RELATIONS),
    ...Object.keys(SHENSHA),
    ...Object.keys(STRENGTH),
    ...CONCEPTS,
  ];
  expect(shown.filter((k) => !TERM_TIPS[k])).toEqual([]);
});

it("tips are keyed by the term as the engine writes it", () => {
  const terms = loadTerms().terms;
  expect(Object.keys(TERM_TIPS).filter((k) => !terms[k] && !CONCEPTS.includes(k))).toEqual([]);
});

it("every tip has all three scripts, each quoted its own way (rule 31)", () => {
  for (const [k, v] of Object.entries(termTips())) {
    for (const s of ["zh-Hans", "zh-Hant", "en"] as const)
      expect(v[s].trim(), `${k} ${s}`).not.toBe("");
    expect(v["zh-Hans"], k).not.toMatch(/[「」]/u);
    expect(v["zh-Hant"], k).not.toMatch(/[“”]/u);
  }
});

it("the 繁體 keeps the characters OpenCC gets wrong in 命理 text (G18)", () => {
  const hant = (k: string) => termTips()[k]!["zh-Hant"];
  expect(hant("地支")).toContain("子丑寅卯"); // the branch 丑, not 醜
  expect(hant("通根")).toContain("藏干"); // 干 the stem, not 幹
  expect(hant("半合")).toContain("三合"); // 合, not 閤
  expect(hant("十神")).toContain("生剋");
  expect(hant("偏财")).toContain("日主所剋");
  expect(hant("七杀")).toContain("剋日主");
  expect(hant("空亡")).toContain("「空」");
  const all = Object.values(termTips())
    .map((v) => v["zh-Hant"])
    .join("\n");
  expect(all).not.toMatch(/[醜閤幹克“”]/u);
});

// Pinned after the G18 review of all 63 tips (v3.2.0): `npx tsx scripts/print-term-tips.ts` prints
// each 简体 beside its 繁體. A new tip, an edited one or an OpenCC upgrade changes this hash: print the
// tips, review the 繁體 again (fix it in TERM_TIP_HANT_FIXES), then update the hash.
it("the reviewed tips are what ships", () => {
  const hash = createHash("sha256").update(JSON.stringify(termTips())).digest("hex").slice(0, 16);
  expect(hash).toBe("2dfbe4d26a426881");
});

it("no tip trips the compliance rule layer in any region", () => {
  const set = loadRuleSet();
  const rules = compileRules(set, Object.keys(set.groups));
  const hits = Object.entries(termTips()).flatMap(([k, v]) =>
    Object.values(v).flatMap((text) =>
      scan(text, rules).map((h) => `${k}: ${h.rule_id} ${h.match}`),
    ),
  );
  expect(hits).toEqual([]);
});
