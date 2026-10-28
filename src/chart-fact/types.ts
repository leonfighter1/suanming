export const SCHEMA_VERSION = "0.1.0";

/** FROZEN in Phase 0 — see schemas/chart-fact.v0.1.schema.json */
export const SOURCE_LEVELS = [
  "traditional_text",
  "common_consensus",
  "simplified_rule",
  "derived",
] as const;
export type SourceLevel = (typeof SOURCE_LEVELS)[number];

export type ChartSystem =
  "bazi" | "tarot" | "astrology" | "qiuqian" | "fengshui" | "naming" | "liuyao";

export interface Provenance {
  /** JSON Pointer into `facts` */
  path: string;
  source_level: SourceLevel;
  note?: string;
}

export interface ChartFact<F = Record<string, unknown>> {
  schema_version: string;
  engine: { name: ChartSystem; version: string };
  system: ChartSystem;
  input_digest: string;
  rule_versions: Record<string, string>;
  computed_at: string;
  facts: F;
  provenance: Provenance[];
}
