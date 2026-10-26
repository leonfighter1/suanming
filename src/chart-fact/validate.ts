import { readFileSync } from "node:fs";
import { Ajv2020, type ErrorObject } from "ajv/dist/2020.js";
import addFormatsModule from "ajv-formats";
import type { ChartFact } from "./types.js";

const addFormats = addFormatsModule as unknown as (ajv: Ajv2020) => Ajv2020;

const schema = JSON.parse(
  readFileSync(new URL("../../schemas/chart-fact.v0.1.schema.json", import.meta.url), "utf8"),
);

const ajv = addFormats(new Ajv2020({ allErrors: true, strict: true }));
const validateFn = ajv.compile(schema);

export function validateChartFact(
  value: unknown,
): { ok: true } | { ok: false; errors: ErrorObject[] } {
  return validateFn(value) ? { ok: true } : { ok: false, errors: validateFn.errors ?? [] };
}

export function assertChartFact(value: unknown): asserts value is ChartFact {
  const r = validateChartFact(value);
  if (!r.ok) throw new Error(`ChartFact schema violation: ${JSON.stringify(r.errors, null, 2)}`);
}
