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

export function loadGeoMatrix(
  path = new URL("../../compliance/geo_rule_matrix.json", import.meta.url),
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
