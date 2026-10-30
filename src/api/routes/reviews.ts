/**
 * 内容审核 (moved here in S28 WP28.9): reviewers only. The held readings, plans, 追问 and 一生运势报告, one with its
 * held content, and a reviewer's decision: released, it goes out as any passed one does. Paused by the owner
 * (ApiOptions.review false, 2026-10-26): then these routes answer 404.
 */
import type { IncomingMessage, ServerResponse } from "node:http";
import { HttpError, readJson, send } from "../../http/util.js";
import { InputError, UUID_RE } from "../../service/charts.js";
import type { ApiContext, Caller } from "../context.js";
import type { ReviewDecision } from "../store.js";
import { reviewSummary } from "../views.js";

async function heldItem(ctx: ApiContext, kind: string, id: string) {
  const { store } = ctx;
  if (!UUID_RE.test(id)) return undefined;
  if (kind === "report") {
    const r = await store.getReport(id);
    return (
      r && {
        kind: "report" as const,
        r,
        summary: reviewSummary("report", r, r.report, { locale: r.locale, topics: r.topics }),
        content: r.report?.held_layers,
      }
    );
  }
  if (kind === "remedy") {
    const r = await store.getRemedy(id);
    return (
      r && {
        kind: "remedy" as const,
        r,
        summary: reviewSummary("remedy", r, r.remedy, { topic: r.topic, locked: !r.unlocked }),
        content: r.remedy?.held_content,
      }
    );
  }
  if (kind === "followup") {
    const r = await store.getFollowUp(id);
    return (
      r && {
        kind: "followup" as const,
        r,
        summary: reviewSummary("followup", r, r.followup, { parent: r.parent }),
        content: r.followup?.held_answer,
      }
    );
  }
  if (kind === "life_report") {
    const r = await store.getLifeReport(id);
    return (
      r && {
        kind: "life_report" as const,
        r,
        summary: reviewSummary("life_report", r, r.life, { locale: r.locale }),
        content: r.life && { facts: r.life.facts, layers: r.life.held_layers },
      }
    );
  }
  return undefined;
}

/**
 * GET  /v1/admin/reviews                      everything held, newest first
 * GET  /v1/admin/reviews/{kind}/{id}          one item with its held content
 * POST /v1/admin/reviews/{kind}/{id}          { decision: approve | reject, note? }
 * Approve releases manual_review items only: rule-layer blocks are hard violations.
 */
async function reviews(
  ctx: ApiContext,
  req: IncomingMessage,
  res: ServerResponse,
  path: string,
  who: string,
) {
  const { store, now, log, track, mailWhenDone } = ctx;
  if (path === "/v1/admin/reviews" && req.method === "GET") {
    const h = await store.listHeld();
    const items = [
      ...h.reports.map((r) =>
        reviewSummary("report", r, r.report, { locale: r.locale, topics: r.topics }),
      ),
      ...h.remedies.map((r) =>
        reviewSummary("remedy", r, r.remedy, { topic: r.topic, locked: !r.unlocked }),
      ),
      ...h.life.map((r) => reviewSummary("life_report", r, r.life, { locale: r.locale })),
      ...h.followups.map((r) => reviewSummary("followup", r, r.followup, { parent: r.parent })),
    ].sort((a, b) => (a.created_at < b.created_at ? 1 : -1));
    return send(res, 200, { items });
  }
  const m = /^\/v1\/admin\/reviews\/(report|remedy|life_report|followup)\/([^/]+)$/.exec(path);
  const item = m ? await heldItem(ctx, m[1]!, m[2]!) : undefined;
  if (!item || !["manual_review", "blocked"].includes(item.r.status)) {
    throw new HttpError(404, "no held item with that id");
  }
  if (req.method === "GET")
    return send(res, 200, { ...item.summary, content: item.content ?? null });
  if (req.method !== "POST") throw new HttpError(405, "method not allowed");

  const body = (await readJson(req)) as { decision?: unknown; note?: unknown };
  if (body.decision !== "approve" && body.decision !== "reject") {
    throw new InputError("decision must be approve or reject");
  }
  if (body.decision === "approve" && item.r.status !== "manual_review") {
    throw new HttpError(
      409,
      "only manual_review items can be released; rule-layer blocks can only be rejected",
    );
  }
  if (body.decision === "approve" && !item.content) throw new HttpError(409, "nothing to release");
  const review: ReviewDecision = {
    decision: body.decision,
    by: who,
    at: now().toISOString(),
    ...(typeof body.note === "string" &&
      body.note.trim() && { note: body.note.trim().slice(0, 500) }),
  };
  const status = body.decision === "approve" ? ("passed" as const) : ("blocked" as const);
  const ts = now().toISOString();
  if (item.kind === "report") {
    const rep = item.r.report!;
    await store.putReport({
      ...item.r,
      status,
      review,
      updated_at: ts,
      report:
        status === "passed"
          ? { ...rep, status, layers: rep.held_layers, held_layers: undefined }
          : rep,
    });
  } else if (item.kind === "remedy") {
    const rem = item.r.remedy!;
    await store.putRemedy({
      ...item.r,
      status,
      review,
      updated_at: ts,
      remedy:
        status === "passed"
          ? { ...rem, status, content: rem.held_content, held_content: undefined }
          : rem,
    });
  } else if (item.kind === "followup") {
    const fu = item.r.followup!;
    await store.putFollowUp({
      ...item.r,
      status,
      review,
      updated_at: ts,
      followup:
        status === "passed"
          ? { ...fu, status, answer: fu.held_answer, held_answer: undefined }
          : fu,
    });
  } else {
    const life = item.r.life!;
    await store.putLifeReport({
      ...item.r,
      status,
      review,
      updated_at: ts,
      life:
        status === "passed"
          ? { ...life, status, layers: life.held_layers, held_layers: undefined }
          : life,
    });
  }
  log(`review ${item.kind} ${item.r.id}: ${review.decision} by ${who}`);
  // Released: now it is done, and goes out as any passed report does.
  if (status === "passed" && (item.kind === "report" || item.kind === "life_report")) {
    track("report mail", mailWhenDone(item.kind, item.r.id));
  }
  const after = await heldItem(ctx, item.kind, item.r.id);
  return send(res, 200, after!.summary);
}

/** 内容审核's list, one held item, and a decision; false for any other path. */
export async function reviewsRoute(
  ctx: ApiContext,
  req: IncomingMessage,
  res: ServerResponse,
  path: string,
  c: Caller,
): Promise<boolean> {
  const { opts, reviewer } = ctx;
  if (path === "/v1/admin/reviews" || path.startsWith("/v1/admin/reviews/")) {
    const who = await reviewer(c);
    if (opts.review === false) throw new HttpError(404, "content review is paused");
    if (!who) throw new HttpError(403, "reviewers only");
    await reviews(ctx, req, res, path, who);
    return true;
  }
  return false;
}
