import { readFileSync } from "node:fs";

export interface RegionRule {
  name: string;
  phase: number;
  service_available: boolean;
  /** provisional = product-owner sign-off (2026-10-26); formal legal review still to come. */
  legal_review: "pending" | "provisional" | "approved";
  locales: string[];
  rule_groups: string[];
  systems: Record<string, { available: boolean; entry_weight: number }>;
  /** Topics the region's readings never touch (Phase 3 §2.4, v5.1.0): Indonesia's 前世, 通灵 and 降头. */
  content_blocks?: ContentBlock[];
  paywall: { copy_rules: string[] };
  age_gate: { min_age: number; enforcement: "self_declare" | "store_rating" | "verified" };
  ai_disclosure: { visible_label: "required" | "recommended"; machine_readable: boolean };
}

export interface GeoRuleMatrix {
  matrix_version: string;
  defaults: Omit<RegionRule, "name" | "phase" | "legal_review" | "locales" | "rule_groups">;
  region_groups: Record<string, string[]>;
  regions: Record<
    string,
    Partial<RegionRule> & Pick<RegionRule, "name" | "phase" | "legal_review">
  >;
}

export type ContentBlock = "past_lives" | "mediumship" | "black_magic";

/** What the model is told for each content block, with the words it covers in both scripts. */
export const CONTENT_BLOCK_TEXT: Record<ContentBlock, string> = {
  past_lives: "past lives or reincarnation (前世, 轮回 / 輪迴, 转世 / 轉世)",
  mediumship:
    "spirit mediums, séances or contacting the dead (通灵 / 通靈, 灵媒 / 靈媒, 问米 / 問米)",
  black_magic: "降头 / 降頭, 蛊 / 蠱 or any black magic (santet, guna-guna)",
};

/**
 * The line that ends every model call's user message in a region with content blocks (v5.1.0). Review
 * is paused, so a rule hit is recorded but still reaches the reader: the model has to know. Empty without
 * blocks, so other regions' messages are unchanged.
 */
export function contentBlockLine(region: Pick<RegionRule, "content_blocks">): string {
  const blocks = region.content_blocks ?? [];
  if (!blocks.length) return "";
  return `This reader's region rules out these topics. Never write about them, not even to deny them: ${blocks.map((b) => CONTENT_BLOCK_TEXT[b]).join("; ")}.`;
}

/** Ties in entry weight keep this order. */
const DEFAULT_ORDER = ["bazi", "tarot", "qiuqian", "liuyao", "fengshui", "naming", "astrology"];

/**
 * The methods a region offers, heaviest entry weight first (Phase 3 §2.4: 擲筊 / 求签 first in Taiwan and
 * Hong Kong). The matrix decides, so the order changes without an app release.
 */
export function methodsFor(region: RegionRule): { system: string; entry_weight: number }[] {
  const rank = (s: string) => {
    const i = DEFAULT_ORDER.indexOf(s);
    return i < 0 ? DEFAULT_ORDER.length : i;
  };
  return Object.entries(region.systems)
    .filter(([, s]) => s.available)
    .map(([system, s]) => ({ system, entry_weight: s.entry_weight }))
    .sort((a, b) => b.entry_weight - a.entry_weight || rank(a.system) - rank(b.system));
}

/**
 * The matrix: compliance/geo_rule_matrix.json, or the file `MINGLI_GEO_MATRIX` names (ops: a hot-updated
 * matrix without a release; tests: a matrix with a method switched on, such as 起名 before its review).
 */
export function loadGeoMatrix(
  path: URL | string = process.env.MINGLI_GEO_MATRIX ??
    new URL("../../compliance/geo_rule_matrix.json", import.meta.url),
): GeoRuleMatrix {
  return JSON.parse(readFileSync(path, "utf8")) as GeoRuleMatrix;
}

/**
 * Resolve the effective rule for an ISO 3166-1 alpha-2 country code.
 * Lookup order: exact country → region group containing it (e.g. EU) → null.
 * Unknown countries return null: callers must refuse service rather than guess,
 * per the "Geo-Rule before model call" hard constraint.
 */
export function resolveRegion(m: GeoRuleMatrix, country: string): RegionRule | null {
  const cc = country.toUpperCase();
  const key =
    cc in m.regions ? cc : Object.entries(m.region_groups).find(([, cs]) => cs.includes(cc))?.[0];
  if (!key) return null;
  const r = m.regions[key]!;
  return {
    locales: [],
    rule_groups: [],
    ...m.defaults,
    ...r,
    systems: { ...m.defaults.systems, ...r.systems },
  } as RegionRule;
}
