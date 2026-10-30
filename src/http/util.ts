/** Minimal JSON-over-HTTP helpers shared by the v1 API and the demo server. */
import type { IncomingMessage, ServerResponse } from "node:http";

export class HttpError extends Error {
  constructor(
    readonly status: number,
    message: string,
    /** A machine-readable reason in the problem body (`code`), e.g. followup_pending (v7.0.0). */
    readonly code?: string,
    /** More fields for the problem body, e.g. a 402's `need` and `available` 积分 (v11.0.0). */
    readonly extra?: Record<string, unknown>,
  ) {
    super(message);
  }
}

export async function readJson(req: IncomingMessage, maxBytes = 64 * 1024): Promise<unknown> {
  let size = 0;
  const chunks: Buffer[] = [];
  for await (const c of req) {
    size += (c as Buffer).length;
    if (size > maxBytes) throw new HttpError(413, "request body too large");
    chunks.push(c as Buffer);
  }
  if (!chunks.length) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8"));
  } catch {
    throw new HttpError(400, "body must be JSON");
  }
}

export function send(
  res: ServerResponse,
  status: number,
  body: unknown,
  headers: Record<string, string> = {},
  type = "application/json; charset=utf-8",
) {
  res.writeHead(status, { "content-type": type, "cache-control": "no-store", ...headers });
  res.end(typeof body === "string" ? body : JSON.stringify(body));
}

/** AI disclosure headers (compliance/ai_disclosure_spec.md §1) — only on model-generated content. */
export function aiHeaders(ai?: { model: string; prompt_version: string }): Record<string, string> {
  return ai
    ? { "x-ai-generated": "true", "x-ai-model": `${ai.model};prompt=${ai.prompt_version}` }
    : {};
}

/** RFC 9457 problem details. */
export function problem(
  res: ServerResponse,
  status: number,
  title: string,
  detail?: string,
  extra: Record<string, unknown> = {},
) {
  send(
    res,
    status,
    { type: "about:blank", title, status, ...(detail && { detail }), ...extra },
    {},
    "application/problem+json; charset=utf-8",
  );
}
