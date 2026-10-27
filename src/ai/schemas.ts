/**
 * Output schemas for the three agents. The `api` schemas are sent as
 * output_config.format (keep to the structured-outputs subset: type, enum,
 * required, additionalProperties, items). Limits the API subset can't express
 * (counts, lengths, grounding) are checked in pipeline.ts after parsing.
 */
import { Ajv2020 } from "ajv/dist/2020.js";
import { SOURCE_LEVELS } from "../chart-fact/index.js";
import { GUARD_CATEGORIES, HORIZONS, type Topic } from "./types.js";

const str = { type: "string" } as const;

export function narrativeSchema(topics: readonly Topic[]) {
  return {
    type: "object",
    additionalProperties: false,
    required: ["sections"],
    properties: {
      sections: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          // summary is asked for in the prompt but optional: a missing one never costs a regeneration.
          required: ["topic", "paragraphs"],
          properties: {
            topic: { type: "string", enum: [...topics] },
            summary: str,
            paragraphs: {
              type: "array",
              items: {
                type: "object",
                additionalProperties: false,
                required: ["text", "source_level", "fact_refs"],
                properties: {
                  text: str,
                  source_level: { type: "string", enum: [...SOURCE_LEVELS] },
                  fact_refs: { type: "array", items: str },
                },
              },
            },
          },
        },
      },
    },
  };
}

export function actionSchema(topics: readonly Topic[]) {
  return {
    type: "object",
    additionalProperties: false,
    required: ["actions"],
    properties: {
      actions: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["topic", "text", "horizon"],
          properties: {
            topic: { type: "string", enum: [...topics] },
            text: str,
            horizon: { type: "string", enum: [...HORIZONS] },
          },
        },
      },
    },
  };
}

export const guardSchema = {
  type: "object",
  additionalProperties: false,
  required: ["pass", "violations"],
  properties: {
    pass: { type: "boolean" },
    violations: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["quote", "category", "reason"],
        properties: {
          quote: str,
          category: { type: "string", enum: [...GUARD_CATEGORIES] },
          reason: str,
        },
      },
    },
  },
};

const ajv = new Ajv2020({ allErrors: true, strict: false });

/** Validate a parsed model output against the schema it was asked for. */
export function checkShape(schema: Record<string, unknown>, data: unknown): string[] {
  const v = ajv.compile(schema);
  return v(data) ? [] : (v.errors ?? []).map((e) => `${e.instancePath || "/"} ${e.message}`);
}
