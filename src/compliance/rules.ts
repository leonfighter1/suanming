import { readFileSync } from "node:fs";
import { parse } from "yaml";

export interface RuleDef {
  id: string;
  description: string;
  pattern: string;
  flags?: string;
  unless?: string;
  action: "block" | "review";
}

export interface RuleSet {
  version: string;
  groups: Record<string, RuleDef[]>;
}

export interface CompiledRule extends RuleDef {
  group: string;
  re: RegExp;
  unlessRe?: RegExp;
}

export interface Violation {
  rule_id: string;
  group: string;
  action: RuleDef["action"];
  match: string;
  index: number;
}

export function loadRuleSet(
  path = new URL("../../compliance/prohibited_patterns.yaml", import.meta.url),
): RuleSet {
  return parse(readFileSync(path, "utf8")) as RuleSet;
}

export function compileRules(set: RuleSet, groups: string[]): CompiledRule[] {
  const wanted = new Set(["global", ...groups]);
  const out: CompiledRule[] = [];
  for (const g of wanted) {
    const defs = set.groups[g];
    if (!defs) throw new Error(`unknown rule group "${g}"`);
    for (const d of defs) {
      const flags = `gu${d.flags ?? ""}`;
      out.push({
        ...d,
        group: g,
        re: new RegExp(d.pattern, flags),
        unlessRe: d.unless ? new RegExp(d.unless, `u${d.flags ?? ""}`) : undefined,
      });
    }
  }
  return out;
}

const SENTENCE_END = /[。！？!?\n]|\.(?=\s|$)/gu;

function sentenceAround(text: string, index: number): string {
  let start = 0;
  let end = text.length;
  for (const m of text.matchAll(SENTENCE_END)) {
    const i = m.index!;
    if (i < index) start = i + 1;
    else {
      end = i;
      break;
    }
  }
  return text.slice(start, end);
}

/** Rule layer of Compliance Guard. Pure; no I/O. */
export function scan(text: string, rules: CompiledRule[]): Violation[] {
  const hits: Violation[] = [];
  for (const r of rules) {
    for (const m of text.matchAll(r.re)) {
      if (r.unlessRe?.test(sentenceAround(text, m.index!))) continue;
      hits.push({ rule_id: r.id, group: r.group, action: r.action, match: m[0], index: m.index! });
    }
  }
  return hits.sort((a, b) => a.index - b.index);
}
