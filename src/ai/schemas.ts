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
                // term and example (v6.2.0) are asked for in the prompts but optional, as summary is.
                required: ["text", "source_level", "fact_refs"],
                properties: {
                  term: str,
                  text: str,
                  example: str,
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

/**
 * 追问 (v7.0.0, S13 WP13.2): whether the reading can answer it, 1–3 paragraphs in the reading's three parts, and
 * the next questions. Counts and grounding are checked in followup.ts.
 */
export const followUpSchema = {
  type: "object",
  additionalProperties: false,
  required: ["in_scope", "paragraphs", "suggestions"],
  properties: {
    in_scope: { type: "boolean" },
    paragraphs: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["term", "text", "source_level", "fact_refs"],
        properties: {
          term: str,
          text: str,
          example: str,
          source_level: { type: "string", enum: [...SOURCE_LEVELS] },
          fact_refs: { type: "array", items: str },
        },
      },
    },
    suggestions: { type: "array", items: str },
  },
};

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
