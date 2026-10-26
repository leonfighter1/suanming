import { readFileSync } from "node:fs";
import { Ajv2020 } from "ajv/dist/2020.js";
import { describe, expect, it } from "vitest";
import { parse } from "yaml";
import {
  compileRules,
  loadGeoMatrix,
  loadRuleSet,
  resolveRegion,
  scan,
} from "../src/compliance/index.js";

interface Case {
  text: string;
  groups: string[];
  rule?: string;
}
const cases = parse(
  readFileSync(new URL("./fixtures/compliance-cases.yaml", import.meta.url), "utf8"),
) as { block: Case[]; allow: Case[] };
const rules = loadRuleSet();

describe("prohibited patterns — block cases", () => {
  it.each(cases.block)("$rule: $text", ({ text, groups, rule }) => {
    const hits = scan(text, compileRules(rules, groups));
    expect(hits.map((h) => h.rule_id)).toContain(rule);
  });
});

describe("prohibited patterns — allow (whitelist) cases", () => {
  it.each(cases.allow)("$text", ({ text, groups }) => {
    expect(scan(text, compileRules(rules, groups))).toEqual([]);
  });
});

it("every rule has at least one block case", () => {
  const covered = new Set(cases.block.map((c) => c.rule));
  const all = Object.values(rules.groups).flatMap((g) => g.map((r) => r.id));
  expect(all.filter((id) => !covered.has(id))).toEqual([]);
});

it("rule ids are unique", () => {
  const all = Object.values(rules.groups).flatMap((g) => g.map((r) => r.id));
  expect(new Set(all).size).toBe(all.length);
});

describe("geo rule matrix", () => {
  const matrix = loadGeoMatrix();

  it("validates against its JSON Schema", () => {
    const schema = JSON.parse(
      readFileSync(new URL("../schemas/geo-rule-matrix.schema.json", import.meta.url), "utf8"),
    );
    const validate = new Ajv2020({ allErrors: true }).compile(schema);
    expect(validate(matrix) ? [] : validate.errors).toEqual([]);
  });

  it("references only rule groups that exist", () => {
    for (const r of Object.values(matrix.regions)) {
      for (const g of r.rule_groups ?? []) expect(Object.keys(rules.groups)).toContain(g);
    }
  });

  it("resolves EU members through the EU group with mandatory AI label", () => {
    const de = resolveRegion(matrix, "de")!;
    expect(de.name).toBe("European Union");
    expect(de.ai_disclosure.visible_label).toBe("required");
    expect(de.rule_groups).toContain("eu");
  });

  it("merges region overrides onto defaults", () => {
    const hk = resolveRegion(matrix, "HK")!;
    expect(hk.systems.bazi!.entry_weight).toBe(1.2);
    expect(hk.systems.tarot!.available).toBe(true);
    expect(hk.age_gate.min_age).toBe(18);
  });

  it("refuses unknown countries and mainland China", () => {
    expect(resolveRegion(matrix, "ZZ")).toBeNull();
    expect(resolveRegion(matrix, "CN")!.service_available).toBe(false);
  });
});
