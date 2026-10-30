/**
 * 破除運勢 plans (paid per topic; payment is a Phase 4 TODO; moved here in S28 WP28.9): buying a topic's plan, its
 * job, and the preload that makes every topic's plan, locked, once a reading passes.
 */
import { randomUUID } from "node:crypto";
import type { IncomingMessage, ServerResponse } from "node:http";
import {
  generateRemedy,
  NO_PLAN_TOPICS,
  remedyAvailable,
  type Report,
  type Topic,
} from "../../ai/index.js";
import type { ChartFact } from "../../chart-fact/index.js";
import { HttpError, readJson, send } from "../../http/util.js";
import { quoteFor, type PointsHold } from "../../points/index.js";
import { InputError, UUID_RE } from "../../service/charts.js";
import { upstreamMessage } from "../../service/runtime.js";
import type { ApiContext, Caller } from "../context.js";
import type { RemedyRecord, ReportRecord } from "../store.js";
import { heldWhy, publicRemedy, REMEDY_PRICE } from "../views.js";

/** Every topic's plan, generated now and kept locked until bought (two at a time). */
export async function preloadRemedies(
  ctx: ApiContext,
  record: ReportRecord,
  report: Report,
  fact: ChartFact,
  c: Caller,
) {
  const { store, now, takeBackgroundQuota } = ctx;
  if (!remedyAvailable(fact.system)) return;
  const queue: RemedyRecord[] = [];
  for (const topic of record.topics.filter((t) => !NO_PLAN_TOPICS.includes(t))) {
    if (!takeBackgroundQuota()) break; // on-demand generation still works later
    const ts = now().toISOString();
    const r: RemedyRecord = {
      id: randomUUID(),
      owner: record.owner,
      report_id: record.id,
      topic,
      status: "pending",
      created_at: ts,
      updated_at: ts,
      unlocked: false,
    };
    await store.putRemedy(r);
    queue.push(r);
  }
  const worker = async () => {
    for (let r = queue.shift(); r; r = queue.shift()) {
      await runRemedyJob(ctx, r, report, fact, c, record.context);
    }
  };
  await Promise.all([worker(), worker()]);
}

async function runRemedyJob(
  ctx: ApiContext,
  record: RemedyRecord,
  report: Report,
  fact: ChartFact,
  c: Caller,
  context?: ReportRecord["context"],
  hold?: PointsHold,
) {
  const { opts, store, now, log, settleHold, recordJob } = ctx;
  let next: RemedyRecord;
  try {
    const remedy = await generateRemedy(
      fact,
      report,
      record.topic,
      { country: c.country, context },
      {
        providers: opts.providers,
        routing: opts.routing?.(),
        review: opts.review !== false,
        now,
        onProgress: async ({ stage, attempt }) => {
          const current = await store.getRemedy(record.id);
          if (current?.status !== "pending") return;
          await store.putRemedy({
            ...current,
            progress: { stage, attempt, updated_at: now().toISOString() },
          });
        },
      },
    );
    next = { ...record, status: remedy.status, remedy, updated_at: now().toISOString() };
    if (remedy.status !== "passed") log(`remedy ${record.id} held: ${heldWhy(remedy)}`);
  } catch (e) {
    const upstream = upstreamMessage(e);
    log(
      `remedy ${record.id} failed: ${upstream ?? (e as Error).message}`,
      upstream ? undefined : e,
    );
    next = {
      ...record,
      status: "failed",
      error: upstream ?? "internal error",
      updated_at: now().toISOString(),
    };
  }
  const current = await store.getRemedy(record.id);
  await recordJob(
    { kind: "remedy", id: record.id, owner: record.owner, system: fact.system },
    next.remedy?.agents,
    !!current && next.status === "passed",
  );
  if (!current) return settleHold(hold, undefined);
  // Bought while generating: keep the purchase.
  await store.putRemedy({ ...next, unlocked: current.unlocked, payment: current.payment });
  await settleHold(hold, next.status === "passed" ? next.remedy?.agents : undefined);
}

/** The caller's passed report and its chart, or 404 / 409. */
export async function ownedPassedReport(ctx: ApiContext, id: string, c: Caller) {
  const { store } = ctx;
  const r = UUID_RE.test(id) ? await store.getReport(id) : undefined;
  if (!r || r.owner !== c.user) throw new HttpError(404, "report not found");
  if (r.status !== "passed" || !r.report) throw new HttpError(409, "report is not ready");
  const chart = await store.getChart(r.chart_id);
  if (!chart) throw new HttpError(404, "chart not found");
  return { record: r, report: r.report, fact: chart.fact };
}

/** One plan per (report, topic): buying again returns the existing plan, never a second charge. */
async function createRemedy(ctx: ApiContext, req: IncomingMessage, reportId: string, c: Caller) {
  const {
    store,
    now,
    pointsConfig,
    priceOf,
    assertAllowed,
    assertServed,
    track,
    holdPoints,
    holdForJob,
    settleHold,
  } = ctx;
  const body = (await readJson(req)) as Record<string, unknown>;
  const { record, report, fact } = await ownedPassedReport(ctx, reportId, c);
  if (!remedyAvailable(fact.system)) {
    throw new InputError("破除運勢 plans are available for bazi and tarot readings only");
  }
  const topic = body.topic as Topic;
  if (!record.topics.includes(topic)) {
    throw new InputError(`topic must be one of this report's topics: ${record.topics.join(", ")}`);
  }
  if (NO_PLAN_TOPICS.includes(topic)) {
    throw new InputError(
      `the ${topic} section has no 破除運勢 plan; a tarot plan is on tarot_advice`,
    );
  }
  assertServed(c.country, fact.system);
  let existing = (await store.listRemedies(record.id)).find(
    (x) => x.topic === topic && x.status !== "failed",
  );
  // A preloaded plan the guard held is never sold: retire it and generate a fresh one.
  if (
    existing &&
    !existing.unlocked &&
    (existing.status === "blocked" || existing.status === "manual_review")
  ) {
    await store.putRemedy({
      ...existing,
      status: "failed",
      error: "superseded: held preload regenerated on purchase",
      updated_at: now().toISOString(),
    });
    existing = undefined;
  }
  const plan = { kind: "remedy" as const, system: fact.system };
  if (existing) {
    // Preloaded: buying only unlocks it. TODO(Phase 4 payments): verify the receipt. With 积分 (a plan preloaded
    // before they were on), buying it pays what it cost to make.
    if (!existing.unlocked) await assertAllowed(c, "ai");
    if (!existing.unlocked && pointsConfig) {
      const hold = await holdPoints(c, priceOf("remedy", quoteFor(fact)), {
        ...plan,
        id: existing.id,
      });
      await settleHold(hold, existing.remedy?.agents ?? []);
    }
    const bought = existing.unlocked
      ? existing
      : {
          ...existing,
          unlocked: true,
          payment: pointsConfig
            ? { status: "points" as const }
            : { status: "placeholder" as const, ...REMEDY_PRICE },
          updated_at: now().toISOString(),
        };
    if (!existing.unlocked) await store.putRemedy(bought);
    return { status: 200, body: publicRemedy(bought), headers: {} as Record<string, string> };
  }
  const id = randomUUID();
  const hold = await holdForJob(c, "remedy", { ...plan, id }, quoteFor(fact));

  const ts = now().toISOString();
  const remedy: RemedyRecord = {
    id,
    owner: c.user,
    report_id: record.id,
    topic,
    status: "pending",
    created_at: ts,
    updated_at: ts,
    // TODO(Phase 4 payments): verify the store receipt here; until then a purchase is
    // paid in 积分 (v11.0.0) or, with them off, a placeholder that succeeds without charging.
    unlocked: true,
    payment: pointsConfig ? { status: "points" } : { status: "placeholder", ...REMEDY_PRICE },
  };
  await store.putRemedy(remedy);
  track(`plan ${remedy.id}`, runRemedyJob(ctx, remedy, report, fact, c, record.context, hold));
  return {
    status: 202,
    body: publicRemedy(remedy),
    headers: { location: `/v1/remedies/${remedy.id}`, "retry-after": "5" },
  };
}

/** A report's plans, buying one, and one plan; false for any other path. */
export async function remediesRoute(
  ctx: ApiContext,
  req: IncomingMessage,
  res: ServerResponse,
  path: string,
  c: Caller,
): Promise<boolean> {
  const { store, pointsConfig, priceOf } = ctx;
  const rm = /^\/v1\/reports\/([^/]+)\/remedies$/.exec(path);
  if (rm && req.method === "GET") {
    const r = UUID_RE.test(rm[1]!) ? await store.getReport(rm[1]!) : undefined;
    if (!r || r.owner !== c.user) throw new HttpError(404, "report not found");
    const items = (await store.listRemedies(r.id)).map(publicRemedy);
    // 积分 (v11.0.0): what a plan costs, in 积分; `price` stays for a server without them.
    const chart = pointsConfig && (await store.getChart(r.chart_id));
    const points = chart && priceOf("remedy", quoteFor(chart.fact));
    send(res, 200, { price: REMEDY_PRICE, items, ...(points && { points }) });
    return true;
  }
  if (rm && req.method === "POST") {
    const out = await createRemedy(ctx, req, rm[1]!, c);
    send(res, out.status, out.body, out.headers);
    return true;
  }
  const one = /^\/v1\/remedies\/([^/]+)$/.exec(path);
  if (one && req.method === "GET") {
    const r = UUID_RE.test(one[1]!) ? await store.getRemedy(one[1]!) : undefined;
    if (!r || r.owner !== c.user) throw new HttpError(404, "remedy not found");
    send(res, 200, publicRemedy(r));
    return true;
  }
  return false;
}
