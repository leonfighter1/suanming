import { describe, expect, it } from "vitest";
import { canonicalJson, inputDigest, SOURCE_LEVELS } from "../src/chart-fact/index.js";
import { PEPPER } from "./helpers.js";

describe("canonicalJson", () => {
  it("sorts keys recursively and drops undefined", () => {
    expect(canonicalJson({ b: 1, a: { d: [2, { z: 1, y: 2 }], c: undefined } })).toBe(
      '{"a":{"d":[2,{"y":2,"z":1}]},"b":1}',
    );
  });
  it("rejects non-finite numbers", () => {
    expect(() => canonicalJson({ x: NaN })).toThrow();
  });
});

describe("inputDigest", () => {
  const parts = {
    input: { b: 1, a: 2 },
    engine_version: "1.0.0",
    rule_versions: { tzdb: "2025b" },
  };
  it("is stable under key order", () => {
    const reordered = {
      rule_versions: { tzdb: "2025b" },
      engine_version: "1.0.0",
      input: { a: 2, b: 1 },
    };
    expect(inputDigest(parts, PEPPER)).toBe(inputDigest(reordered, PEPPER));
    expect(inputDigest(parts, PEPPER)).toMatch(/^hmac-sha256:[0-9a-f]{64}$/);
  });
  it("changes with engine version, rule version and pepper", () => {
    const d = inputDigest(parts, PEPPER);
    expect(inputDigest({ ...parts, engine_version: "1.0.1" }, PEPPER)).not.toBe(d);
    expect(inputDigest({ ...parts, rule_versions: { tzdb: "2026a" } }, PEPPER)).not.toBe(d);
    expect(inputDigest(parts, Buffer.alloc(32, 8))).not.toBe(d);
  });
  it("refuses short peppers", () => {
    expect(() => inputDigest(parts, Buffer.alloc(16))).toThrow();
  });
});

it("source_level enum is frozen at four levels", () => {
  expect(SOURCE_LEVELS).toEqual([
    "traditional_text",
    "common_consensus",
    "simplified_rule",
    "derived",
  ]);
});
