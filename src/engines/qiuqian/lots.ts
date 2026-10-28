/**
 * 求籤's lot sets (tech plan WP6.1). One so far: the 關聖帝君一百籤 (雷雨師一百籤), built by
 * scripts/build-qiuqian.ts into data/qiuqian/guandi-100.json, with the evidence for its text in
 * docs/verification/qiuqian-guandi-100.md. Only 求籤 reads this.
 */
import { readFileSync } from "node:fs";

type Names = { "zh-Hant": string; "zh-Hans": string; en: string };

export interface Lot {
  n: number;
  /** The lot's label in the set, 甲甲 … 癸癸 */
  ganzhi: string;
  /** Four lines of seven characters */
  poem: { "zh-Hant": string[]; "zh-Hans": string[] };
}

export interface LotSet {
  id: string;
  version: string;
  name: Names;
  source: string;
  lots: Lot[];
}

export const LOT_SET_IDS = ["guandi_100"] as const;
export type LotSetId = (typeof LOT_SET_IDS)[number];

const FILES: Record<LotSetId, string> = { guandi_100: "guandi-100.json" };
const cache = new Map<LotSetId, LotSet>();

export function lotSet(id: LotSetId): LotSet {
  let set = cache.get(id);
  if (!set) {
    set = JSON.parse(
      readFileSync(new URL(`../../../data/qiuqian/${FILES[id]}`, import.meta.url), "utf8"),
    ) as LotSet;
    cache.set(id, set);
  }
  return set;
}
