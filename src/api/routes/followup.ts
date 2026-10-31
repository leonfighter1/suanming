/**
 * 追问 (v7.0.0, S13; moved here in S28 WP28.9): follow-up questions on a passed reading or 一生运势报告, each answered
 * in the background from that reading alone; the questions asked, and one answer.
 */
import { randomUUID } from "node:crypto";
import type { IncomingMessage, ServerResponse } from "node:http";
import {
  FOLLOWUP_QUESTION_MAX,
  followUpAvailable,
  generateFollowUp,
  type FollowUpParent,
  type FollowUpTurn,
} from "../../ai/index.js";
import type { ChartFact } from "../../chart-fact/index.js";
import { aiHeaders, HttpError, readJson, send } from "../../http/util.js";
import type { PointsHold } from "../../points/index.js";
import { InputError, UUID_RE } from "../../service/charts.js";
import { upstreamMessage } from "../../service/runtime.js";
import type { ApiContext, Caller } from "../context.js";
import type { FollowUpRecord } from "../store.js";
import { heldWhy, publicFollowUp } from "../views.js";
import { ownedPassedLifeReport } from "./life.js";
import { ownedPassedReport } from "./remedies.js";

/** What a 追问 asks about: the caller's passed reading with what it was asked for and told, or 404 / 409. */
async function followUpParent(
  ctx: ApiContext,
  kind: FollowUpRecord["parent"]["kind"],
  id: string,
  c: Caller,
): Promise<{ parent: FollowUpParent; fact: ChartFact }> {
  if (kind === "life_report") {
    const { record, life, fact } = await ownedPassedLifeReport(ctx, id, c);
    return { parent: { kind, life, ...(record.context && { context: record.context }) }, fact };
  }
  const { record, report, fact } = await ownedPassedReport(ctx, id, c);
  return {
    parent: {
      kind,
      report,
      ...(record.question && { question: record.question }),
      ...(record.focus && { focus: record.focus }),
      ...(record.context && { context: record.context }),
    },
    fact,
  };
}

async function runFollowUpJob(
  ctx: ApiContext,
  record: FollowUpRecord,
  parent: FollowUpParent,
  fact: ChartFact,
  thread: FollowUpTurn[],
  c: Caller,
  hold?: PointsHold,
) {
  const { opts, store, now, log, settleHold, recordJob } = ctx;
  let next: FollowUpRecord;
  try {
    const followup = await generateFollowUp(
      fact,
      parent,
      record.question,
      thread,
      { country: c.country },
      {
        providers: opts.providers,
        routing: opts.routing?.(),
        review: opts.review !== false,
        now,
        onProgress: async ({ stage, attempt }) => {
          const current = await store.getFollowUp(record.id);
          if (current?.status !== "pending") return;
          await store.putFollowUp({
            ...current,
            progress: { stage, attempt, updated_at: now().toISOString() },
          });
        },
      },
    );
    next = { ...record, status: followup.status, followup, updated_at: now().toISOString() };
    if (followup.status !== "passed") log(`follow-up ${record.id} held: ${heldWhy(followup)}`);
  } catch (e) {
    const upstream = upstreamMessage(e);
    log(
      `follow-up ${record.id} failed: ${upstream ?? (e as Error).message}`,
      upstream ? undefined : e,
    );
    next = {
      ...record,
      status: "failed",
      error: upstream ?? "internal error",
      updated_at: now().toISOString(),
    };
  }
  // The account may have been deleted while this ran; never resurrect its data.
  const gone = !(await store.getFollowUp(record.id));
  await recordJob(
    { kind: "followup", id: record.id, owner: record.owner, system: fact.system },
    next.followup?.agents,
    !gone && next.status === "passed",
  );
  if (gone) return settleHold(hold, undefined);
  await store.putFollowUp(next);
  await settleHold(hold, next.status === "passed" ? next.followup?.agents : undefined);
}

/**
 * 追问 (v7.0.0, S13): one question on a passed reading or 一生运势报告, answered in the background from that reading
 * alone. One at a time, up to 设置's limits.followups_per_reading per reading (S32); each takes one from the daily AI
 * caps.
 */
async function createFollowUp(
  ctx: ApiContext,
  req: IncomingMessage,
  kind: FollowUpRecord["parent"]["kind"],
  id: string,
  c: Caller,
) {
  const { store, now, assertServed, track, holdForJob } = ctx;
  const body = (await readJson(req)) as Record<string, unknown>;
  const question = typeof body.question === "string" ? body.question.trim() : "";
  if (!question) throw new InputError("question is required");
  if ([...question].length > FOLLOWUP_QUESTION_MAX) {
    throw new InputError(`question must be at most ${FOLLOWUP_QUESTION_MAX} characters`);
  }
  const { parent, fact } = await followUpParent(ctx, kind, id, c);
  if (!followUpAvailable(kind, fact)) {
    throw new InputError(`follow-up questions are not offered for ${fact.system} readings`);
  }
  assertServed(c.country, fact.system);
  const earlier = await store.listFollowUps(id);
  if (earlier.some((f) => f.status === "pending")) {
    throw new HttpError(409, "the previous follow-up is still being answered", "followup_pending");
  }
  const limit = ctx.settings.number("limits.followups_per_reading");
  if (earlier.filter((f) => f.status !== "failed").length >= limit) {
    throw new HttpError(
      409,
      `this reading has had its ${limit} follow-up questions`,
      "followup_limit",
    );
  }
  const followUpId = randomUUID();
  const hold = await holdForJob(
    c,
    "followup",
    { kind: "followup", id: followUpId, system: fact.system },
    { system: fact.system, parent: kind },
  );
  const ts = now().toISOString();
  const record: FollowUpRecord = {
    id: followUpId,
    owner: c.user,
    parent: { kind, id },
    question,
    status: "pending",
    created_at: ts,
    updated_at: ts,
  };
  await store.putFollowUp(record);
  const thread = earlier.flatMap((f) =>
    f.status === "passed" && f.followup?.answer
      ? [{ question: f.question, answer: f.followup.answer }]
      : [],
  );
  track(`follow-up ${record.id}`, runFollowUpJob(ctx, record, parent, fact, thread, c, hold));
  return {
    status: 202,
    body: publicFollowUp(record),
    headers: { location: `/v1/followups/${record.id}`, "retry-after": "5" },
  };
}

/** Asking a 追问, a reading's 追问, and one; false for any other path. */
export async function followUpRoute(
  ctx: ApiContext,
  req: IncomingMessage,
  res: ServerResponse,
  path: string,
  c: Caller,
): Promise<boolean> {
  const { store, pointsConfig, priceOf } = ctx;
  const fq = /^\/v1\/(reports|life-reports)\/([^/]+)\/followups$/.exec(path);
  if (fq && req.method === "POST") {
    const kind = fq[1] === "reports" ? "report" : "life_report";
    const out = await createFollowUp(ctx, req, kind, fq[2]!, c);
    send(res, out.status, out.body, out.headers);
    return true;
  }
  if (fq && req.method === "GET") {
    const id = fq[2]!;
    const parent = !UUID_RE.test(id)
      ? undefined
      : fq[1] === "reports"
        ? await store.getReport(id)
        : await store.getLifeReport(id);
    if (!parent || parent.owner !== c.user) throw new HttpError(404, "reading not found");
    const items = (await store.listFollowUps(parent.id)).map(publicFollowUp);
    // 积分 (v11.0.0): what one more costs.
    const system = pointsConfig && (await store.getChart(parent.chart_id))?.fact.system;
    const price =
      system &&
      priceOf("followup", {
        system,
        parent: fq[1] === "reports" ? "report" : "life_report",
      });
    const limit = ctx.settings.number("limits.followups_per_reading");
    send(res, 200, { limit, items, ...(price && { price }) });
    return true;
  }
  const fo = /^\/v1\/followups\/([^/]+)$/.exec(path);
  if (fo && req.method === "GET") {
    const r = UUID_RE.test(fo[1]!) ? await store.getFollowUp(fo[1]!) : undefined;
    if (!r || r.owner !== c.user) throw new HttpError(404, "follow-up not found");
    const view = publicFollowUp(r);
    send(res, 200, view, aiHeaders("ai_disclosure" in view ? view.ai_disclosure : undefined));
    return true;
  }
  return false;
}
