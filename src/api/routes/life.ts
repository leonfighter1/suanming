/**
 * 一生运势报告 (moved here in S28 WP28.9): asking for one on a 八字 chart, its job, the list, and one report.
 */
import { randomUUID } from "node:crypto";
import type { IncomingMessage, ServerResponse } from "node:http";
import { generateLifeReport, LOCALES, parseUserContext, type Locale } from "../../ai/index.js";
import type { ChartFact } from "../../chart-fact/index.js";
import { aiHeaders, HttpError, send } from "../../http/util.js";
import type { PointsHold } from "../../points/index.js";
import { InputError, UUID_RE } from "../../service/charts.js";
import { upstreamMessage } from "../../service/runtime.js";
import type { ApiContext, Caller } from "../context.js";
import type { LifeReportRecord, ReportRecord } from "../store.js";
import { heldWhy, publicLifeReport } from "../views.js";

/** The caller's passed 一生运势报告 and its chart, or 404 / 409. */
export async function ownedPassedLifeReport(ctx: ApiContext, id: string, c: Caller) {
  const { store } = ctx;
  const r = UUID_RE.test(id) ? await store.getLifeReport(id) : undefined;
  if (!r || r.owner !== c.user) throw new HttpError(404, "life report not found");
  if (r.status !== "passed" || !r.life) throw new HttpError(409, "the report is not ready");
  const chart = await store.getChart(r.chart_id);
  if (!chart) throw new HttpError(404, "chart not found");
  return { record: r, life: r.life, fact: chart.fact };
}

async function runLifeJob(
  ctx: ApiContext,
  record: LifeReportRecord,
  fact: ChartFact,
  c: Caller,
  context?: ReportRecord["context"],
  hold?: PointsHold,
) {
  const { opts, store, now, log, settleHold, recordJob, mailWhenDone } = ctx;
  let next: LifeReportRecord;
  try {
    const life = await generateLifeReport(
      fact,
      { locale: record.locale, country: c.country, context },
      {
        providers: opts.providers,
        routing: opts.routing?.(),
        review: opts.review !== false,
        now,
        onProgress: async ({ stage, attempt }) => {
          const current = await store.getLifeReport(record.id);
          if (current?.status !== "pending") return;
          await store.putLifeReport({
            ...current,
            progress: { stage, attempt, updated_at: now().toISOString() },
          });
        },
      },
    );
    next = { ...record, status: life.status, life, updated_at: now().toISOString() };
    if (life.status !== "passed") log(`life report ${record.id} held: ${heldWhy(life)}`);
  } catch (e) {
    const upstream = upstreamMessage(e);
    log(
      `life report ${record.id} failed: ${upstream ?? (e as Error).message}`,
      upstream ? undefined : e,
    );
    next = {
      ...record,
      status: "failed",
      error: upstream ?? "internal error",
      updated_at: now().toISOString(),
    };
  }
  const gone = !(await store.getLifeReport(record.id));
  await recordJob(
    { kind: "life_report", id: record.id, owner: record.owner, system: fact.system },
    next.life?.agents,
    !gone && next.status === "passed",
  );
  if (gone) return settleHold(hold, undefined);
  await store.putLifeReport(next);
  await settleHold(hold, next.status === "passed" ? next.life?.agents : undefined);
  if (next.status === "passed") await mailWhenDone("life_report", record.id);
}

async function createLifeReport(ctx: ApiContext, req: IncomingMessage, c: Caller) {
  const { store, now, assertServed, track, holdForJob, chartRequest } = ctx;
  const { body, chart } = await chartRequest(req, c);
  if (chart.fact.system !== "bazi") throw new InputError("a life report needs a bazi chart");
  const locale = body.locale as Locale;
  if (!LOCALES.includes(locale))
    throw new InputError(`locale must be one of ${LOCALES.join(", ")}`);
  assertServed(c.country, "bazi");
  const context = parseUserContext(body.context);
  const lifeId = randomUUID();
  const hold = await holdForJob(c, "life_report", {
    kind: "life_report",
    id: lifeId,
    system: "bazi",
  });
  const ts = now().toISOString();
  const record: LifeReportRecord = {
    id: lifeId,
    owner: c.user,
    chart_id: chart.id,
    status: "pending",
    locale,
    created_at: ts,
    updated_at: ts,
    // Kept for the report's 追问 (v7.0.0), sealed with it.
    ...(context && { context }),
  };
  await store.putLifeReport(record);
  track(`life report ${record.id}`, runLifeJob(ctx, record, chart.fact, c, context, hold));
  return {
    status: 202,
    body: publicLifeReport(record),
    headers: { location: `/v1/life-reports/${record.id}`, "retry-after": "5" },
  };
}

/** Asking for a 一生运势报告, the list, and one; false for any other path. */
export async function lifeRoute(
  ctx: ApiContext,
  req: IncomingMessage,
  res: ServerResponse,
  path: string,
  c: Caller,
): Promise<boolean> {
  const { store } = ctx;
  if (path === "/v1/life-reports" && req.method === "POST") {
    const out = await createLifeReport(ctx, req, c);
    send(res, out.status, out.body, out.headers);
    return true;
  }
  if (path === "/v1/life-reports" && req.method === "GET") {
    const rows = await store.listLifeReports(c.user, 50);
    send(res, 200, {
      items: await Promise.all(
        rows.map(async (r) => {
          const {
            facts: _f,
            layers: _l,
            ai_disclosure: _a,
            ...view
          } = publicLifeReport(r) as Record<string, unknown>;
          // Whose report it is (v6.2.0), from its chart: 「xxx 的一生运势报告」 on every device.
          const person = (await store.getChart(r.chart_id))?.person;
          return { ...view, ...(person && { person }) };
        }),
      ),
    });
    return true;
  }
  const lm = /^\/v1\/life-reports\/([^/]+)$/.exec(path);
  if (lm && req.method === "GET") {
    const r = UUID_RE.test(lm[1]!) ? await store.getLifeReport(lm[1]!) : undefined;
    if (!r || r.owner !== c.user) throw new HttpError(404, "life report not found");
    const view = publicLifeReport(r);
    const person = (await store.getChart(r.chart_id))?.person;
    send(
      res,
      200,
      { ...view, ...(person && { person }) },
      aiHeaders("ai_disclosure" in view ? view.ai_disclosure : undefined),
    );
    return true;
  }
  return false;
}
