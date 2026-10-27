/**
 * What the user told us about their life, sent with a report request so the
 * reading can relate the chart to their real situation. All fields optional.
 *
 * This is user-declared information, never chart data: the engines' ChartFact
 * still decides every chart claim. It goes to the model inside <user_context>
 * (marked as information, not instructions) and is not written into ChartFact.
 */
import { ReportInputError } from "./pipeline.js";

export const MARITAL = ["single", "dating", "married", "separated", "divorced", "widowed"] as const;
export const CHILDREN = ["none", "has"] as const;

export interface UserContext {
  /** How to address the user (not analysed: no 姓名學 engine yet) */
  name?: string;
  /** Current residence, e.g. "中國 · 廣東 · 深圳" */
  residence?: string;
  marital?: (typeof MARITAL)[number];
  children?: (typeof CHILDREN)[number];
  occupation?: string;
  /** Family situation in the user's words */
  family?: string;
  /** What the user wants to know */
  concern?: string;
}

const LIMITS = { name: 20, residence: 60, occupation: 40, family: 200, concern: 300 } as const;

/** Validates and trims a request's `context`; undefined when empty or absent. */
export function parseUserContext(raw: unknown): UserContext | undefined {
  if (raw === undefined || raw === null) return undefined;
  if (typeof raw !== "object" || Array.isArray(raw))
    throw new ReportInputError("context must be an object");
  const r = raw as Record<string, unknown>;
  const out: UserContext = {};
  for (const [k, max] of Object.entries(LIMITS) as [keyof typeof LIMITS, number][]) {
    const v = r[k];
    if (v === undefined || v === null || v === "") continue;
    if (typeof v !== "string") throw new ReportInputError(`context.${k} must be a string`);
    const t = v.trim().slice(0, max);
    if (t) out[k] = t;
  }
  if (r.marital !== undefined && r.marital !== null && r.marital !== "") {
    if (!MARITAL.includes(r.marital as never)) {
      throw new ReportInputError(`context.marital must be one of ${MARITAL.join(", ")}`);
    }
    out.marital = r.marital as UserContext["marital"];
  }
  if (r.children !== undefined && r.children !== null && r.children !== "") {
    if (!CHILDREN.includes(r.children as never)) {
      throw new ReportInputError(`context.children must be one of ${CHILDREN.join(", ")}`);
    }
    out.children = r.children as UserContext["children"];
  }
  return Object.keys(out).length ? out : undefined;
}
