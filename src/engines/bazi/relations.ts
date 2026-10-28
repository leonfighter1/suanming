/**
 * 合冲刑害破 between the characters of a chart (WP1.3, docs/tech-plan.md): the natal
 * pillars among themselves, and a 大运 or 流年 with the natal chart (and its 大运).
 *
 * Tables (子平 tradition):
 * - 天干五合: 甲己 土, 乙庚 金, 丙辛 水, 丁壬 木, 戊癸 火. 天干相冲: 甲庚, 乙辛, 丙壬, 丁癸.
 * - 六合: 子丑 土, 寅亥 木, 卯戌 火, 辰酉 金, 巳申 水, 午未 土. 六冲: 子午 丑未 寅申 卯酉 辰戌 巳亥.
 * - 三合: 申子辰 水, 亥卯未 木, 寅午戌 火, 巳酉丑 金; 半合 = two of them including the middle one.
 * - 三会: 寅卯辰 木, 巳午未 火, 申酉戌 金, 亥子丑 水.
 * - 相刑: 寅巳申 and 丑戌未 (all three, or any two), 子卯; 自刑: 辰辰 午午 酉酉 亥亥.
 * - 六害: 子未 丑午 寅巳 卯辰 申亥 酉戌. 相破: 子酉 卯午 巳申 寅亥 辰丑 戌未.
 * A full 三合 / 三刑 is listed once, without the pairs inside it.
 */
export type Element = "木" | "火" | "土" | "金" | "水";
export type Place = "year" | "month" | "day" | "hour" | "dayun" | "liunian";
export type RelationType =
  | "天干五合"
  | "天干相冲"
  | "六合"
  | "六冲"
  | "三合"
  | "半合"
  | "三会"
  | "相刑"
  | "自刑"
  | "六害"
  | "相破";

export interface Member {
  pillar: Place;
  char: string;
}
export interface Relation {
  type: RelationType;
  element?: Element;
  members: Member[];
}

const GAN_HE: [string, Element][] = [
  ["甲己", "土"],
  ["乙庚", "金"],
  ["丙辛", "水"],
  ["丁壬", "木"],
  ["戊癸", "火"],
];
const GAN_CHONG = ["甲庚", "乙辛", "丙壬", "丁癸"];
const LIU_HE: [string, Element][] = [
  ["子丑", "土"],
  ["寅亥", "木"],
  ["卯戌", "火"],
  ["辰酉", "金"],
  ["巳申", "水"],
  ["午未", "土"],
];
const LIU_CHONG = ["子午", "丑未", "寅申", "卯酉", "辰戌", "巳亥"];
/** The middle branch (index 1) is the one a 半合 must include. */
const SAN_HE: [string, Element][] = [
  ["申子辰", "水"],
  ["亥卯未", "木"],
  ["寅午戌", "火"],
  ["巳酉丑", "金"],
];
const SAN_HUI: [string, Element][] = [
  ["寅卯辰", "木"],
  ["巳午未", "火"],
  ["申酉戌", "金"],
  ["亥子丑", "水"],
];
const SAN_XING = ["寅巳申", "丑戌未"];
const XING_PAIRS = ["子卯"];
const ZI_XING = "辰午酉亥";
const LIU_HAI = ["子未", "丑午", "寅巳", "卯辰", "申亥", "酉戌"];
const PO = ["子酉", "卯午", "巳申", "寅亥", "辰丑", "戌未"];

/** Whether two characters are the pair `p` (either order). */
const isPair = (p: string, a: string, b: string) => (a + b === p || b + a === p) && a !== b;
/** Whether three characters are exactly the set `s` (any order). */
const isSet = (s: string, chars: string[]) =>
  chars.length === 3 && new Set(chars).size === 3 && chars.every((c) => s.includes(c));

function pairs<T>(xs: T[]): [T, T][] {
  const out: [T, T][] = [];
  for (let i = 0; i < xs.length; i++)
    for (let j = i + 1; j < xs.length; j++) out.push([xs[i]!, xs[j]!]);
  return out;
}
function triples<T>(xs: T[]): [T, T, T][] {
  const out: [T, T, T][] = [];
  for (let i = 0; i < xs.length; i++)
    for (let j = i + 1; j < xs.length; j++)
      for (let k = j + 1; k < xs.length; k++) out.push([xs[i]!, xs[j]!, xs[k]!]);
  return out;
}

/** Every relation among the given stems and branches. */
export function relationsAmong(stems: Member[], branches: Member[]): Relation[] {
  const out: Relation[] = [];
  for (const [a, b] of pairs(stems)) {
    const he = GAN_HE.find(([p]) => isPair(p, a.char, b.char));
    if (he) out.push({ type: "天干五合", element: he[1], members: [a, b] });
    if (GAN_CHONG.some((p) => isPair(p, a.char, b.char)))
      out.push({ type: "天干相冲", members: [a, b] });
  }

  // Triples first: a full 三合 or 三刑 stands for the pairs inside it.
  const covered = new Set<string>();
  const key = (...ms: Member[]) =>
    ms
      .map((m) => m.pillar)
      .sort()
      .join("+");
  for (const trio of triples(branches)) {
    const chars = trio.map((m) => m.char);
    const he = SAN_HE.find(([s]) => isSet(s, chars));
    if (he) {
      out.push({ type: "三合", element: he[1], members: trio });
      for (const [x, y] of pairs(trio)) covered.add(`半合:${key(x, y)}`);
    }
    const hui = SAN_HUI.find(([s]) => isSet(s, chars));
    if (hui) out.push({ type: "三会", element: hui[1], members: trio });
    if (SAN_XING.some((s) => isSet(s, chars))) {
      out.push({ type: "相刑", members: trio });
      for (const [x, y] of pairs(trio)) covered.add(`相刑:${key(x, y)}`);
    }
  }

  for (const [a, b] of pairs(branches)) {
    const [x, y] = [a.char, b.char];
    const he = LIU_HE.find(([p]) => isPair(p, x, y));
    if (he) out.push({ type: "六合", element: he[1], members: [a, b] });
    if (LIU_CHONG.some((p) => isPair(p, x, y))) out.push({ type: "六冲", members: [a, b] });
    const half = SAN_HE.find(
      ([s]) => s.includes(x) && s.includes(y) && x !== y && [x, y].includes(s[1]!),
    );
    if (half && !covered.has(`半合:${key(a, b)}`))
      out.push({ type: "半合", element: half[1], members: [a, b] });
    const xing =
      SAN_XING.some((s) => s.includes(x) && s.includes(y) && x !== y) ||
      XING_PAIRS.some((p) => isPair(p, x, y));
    if (xing && !covered.has(`相刑:${key(a, b)}`)) out.push({ type: "相刑", members: [a, b] });
    if (x === y && ZI_XING.includes(x)) out.push({ type: "自刑", members: [a, b] });
    if (LIU_HAI.some((p) => isPair(p, x, y))) out.push({ type: "六害", members: [a, b] });
    if (PO.some((p) => isPair(p, x, y))) out.push({ type: "相破", members: [a, b] });
  }
  return out;
}

type Pillars = Record<"year" | "month" | "day" | "hour", { gan: string; zhi: string }>;
const NATAL = ["year", "month", "day", "hour"] as const;
const stemsOf = (p: Pillars): Member[] => NATAL.map((k) => ({ pillar: k, char: p[k].gan }));
const branchesOf = (p: Pillars): Member[] => NATAL.map((k) => ({ pillar: k, char: p[k].zhi }));

/** Relations among the four natal pillars. */
export function natalRelations(p: Pillars): Relation[] {
  return relationsAmong(stemsOf(p), branchesOf(p));
}

/**
 * Relations a period brings: its 干支 with the natal chart, and for a 流年 also with its
 * 大运. Only relations that include the period itself are kept.
 */
export function periodRelations(
  p: Pillars,
  period: { place: "dayun" | "liunian"; ganzhi: string },
  dayun?: string,
): Relation[] {
  const extra = (place: Place, gz: string) => ({
    stem: { pillar: place, char: gz[0]! },
    branch: { pillar: place, char: gz[1]! },
  });
  const own = extra(period.place, period.ganzhi);
  const luck = dayun ? extra("dayun", dayun) : undefined;
  const stems = [...stemsOf(p), ...(luck ? [luck.stem] : []), own.stem];
  const branches = [...branchesOf(p), ...(luck ? [luck.branch] : []), own.branch];
  return relationsAmong(stems, branches).filter((r) =>
    r.members.some((m) => m.pillar === period.place),
  );
}
