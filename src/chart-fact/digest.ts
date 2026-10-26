import { createHash, createHmac } from "node:crypto";

/**
 * Canonical JSON: object keys sorted, no whitespace, numbers in JS shortest form.
 * Equivalent to RFC 8785 for the value types we use (no floats beyond what
 * normalizeInput produces, no -0, no NaN).
 */
export function canonicalJson(value: unknown): string {
  if (value === null || typeof value !== "object") {
    if (typeof value === "number" && !Number.isFinite(value)) {
      throw new Error("non-finite number in canonical JSON");
    }
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  const entries = Object.entries(value as Record<string, unknown>)
    .filter(([, v]) => v !== undefined)
    .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
  return `{${entries.map(([k, v]) => `${JSON.stringify(k)}:${canonicalJson(v)}`).join(",")}}`;
}

export interface DigestParts {
  /** Normalized engine input (see each engine's normalizeInput) */
  input: unknown;
  engine_version: string;
  rule_versions: Record<string, string>;
}

/**
 * input_digest = HMAC-SHA256(pepper, canonical(input, engine_version, rule_versions)).
 *
 * Keyed rather than plain SHA-256: birth data has low entropy (~10^8 combinations
 * of date/time/city), so a plain hash stored in the DB could be reversed by
 * enumeration. The pepper lives in the secrets manager, never in the DB.
 * Same pepper ⇒ same digest across time, which is what reproducibility and the
 * Phase 4 cache need.
 */
export function inputDigest(parts: DigestParts, pepper: Buffer): string {
  if (pepper.length < 32) throw new Error("digest pepper must be >= 32 bytes");
  const mac = createHmac("sha256", pepper).update(canonicalJson(parts), "utf8").digest("hex");
  return `hmac-sha256:${mac}`;
}

export function sha256Hex(data: string | Buffer): string {
  return createHash("sha256").update(data).digest("hex");
}
