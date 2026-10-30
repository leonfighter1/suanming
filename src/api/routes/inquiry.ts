/**
 * 深度分析 (v10.0.0, S19; moved here in S28 WP28.9): the master's questions on a chart before its reading. Starting
 * one, answering a question, each turn in the background, and the guard that keeps the turns within the one fee.
 */
import { randomUUID } from "node:crypto";
import type { IncomingMessage, ServerResponse } from "node:http";
import {
  generateInquiryTurn,
  INQUIRY_ANSWER_MAX,
  INQUIRY_GOAL_MAX,
  INQUIRY_GOAL_MIN,
  inquiryAvailable,
  inquiryGoal,
  LOCALES,
  parseUserContext,
  TAROT_FOCUS,
  type InquiryStep,
  type Locale,
  type TarotFocus,
} from "../../ai/index.js";
import type { ChartFact } from "../../chart-fact/index.js";
import { aiHeaders, HttpError, readJson, send } from "../../http/util.js";
import { inquiryFee, measuredCost, pointsPerUsd, type PointsHold } from "../../points/index.js";
import { asksQuestion, InputError, parseQuestion, UUID_RE } from "../../service/charts.js";
import { upstreamMessage } from "../../service/runtime.js";
import type { ApiContext, Caller } from "../context.js";
import type { InquiryRecord } from "../store.js";
import { heldWhy, publicInquiry, questionRequired } from "../views.js";

/**
 * The 深度分析's guard (the owner's 统一收费): its fee is paid once, so a turn that would take what its turns spent
 * past what the fee allows at the margin is not asked for; the conversation closes and the reading goes on.
 */
function inquiryOverBudget(ctx: ApiContext, record: InquiryRecord): boolean {
  const { pointsConfig, routingNow } = ctx;
  if (!pointsConfig || record.fee === undefined || record.turns.length === 0) return false;
  const agents = record.agents ?? [];
  const spent = measuredCost(pointsConfig, agents).usd;
  const largest = Math.max(0, ...agents.map((a) => measuredCost(pointsConfig, [a]).usd));
  const { turnUsd } = inquiryFee(pointsConfig, routingNow());
  return spent + Math.max(turnUsd, largest) > record.fee / pointsPerUsd(pointsConfig);
}

/**
 * 深度分析 (v10.0.0, S19): the master's next turn, in the background. A question goes on the record and waits for its
 * answer (asking); when the master asks nothing more it is ready, with its last words. A turn that fails or is held
 * ends the questions there (ready: the reading goes on with what was said), or, on the first turn, fails the 深度分析.
 */
async function runInquiryTurn(
  ctx: ApiContext,
  record: InquiryRecord,
  fact: ChartFact,
  c: Caller,
  /** The first turn's: the 统一收费, charged once the master has asked. */
  hold?: PointsHold,
) {
  const { opts, store, now, log, settleHold, recordJob } = ctx;
  let step: InquiryStep | undefined;
  let error: string | undefined;
  if (inquiryOverBudget(ctx, record)) {
    error = "its fee covers no further turn";
    log(`inquiry ${record.id}: closed, its fee covers no further turn`);
  } else {
    try {
      step = await generateInquiryTurn(
        fact,
        {
          goal: record.goal,
          ...(record.question && { question: record.question }),
          ...(record.focus && { focus: record.focus }),
          ...(record.context && { context: record.context }),
          turns: record.turns,
          ...(record.planned !== undefined && { planned: record.planned }),
        },
        { locale: record.locale, country: c.country },
        {
          providers: opts.providers,
          routing: opts.routing?.(),
          review: opts.review !== false,
          now,
          onProgress: async ({ stage, attempt }) => {
            const current = await store.getInquiry(record.id);
            if (current?.status !== "thinking") return;
            await store.putInquiry({
              ...current,
              progress: { stage, attempt, updated_at: now().toISOString() },
            });
          },
        },
      );
      if (step.status !== "passed") {
        error = step.reasons.join("; ");
        log(`inquiry ${record.id} turn held: ${heldWhy(step)}`);
      }
    } catch (e) {
      const upstream = upstreamMessage(e);
      error = upstream ?? "internal error";
      log(
        `inquiry ${record.id} turn failed: ${upstream ?? (e as Error).message}`,
        upstream ? undefined : e,
      );
    }
  }
  // The account or the reading may have gone, or the user moved on, meanwhile: never resurrect or overwrite.
  const current = await store.getInquiry(record.id);
  // Each turn's steps, under the conversation's id.
  await recordJob(
    { kind: "inquiry", id: record.id, owner: record.owner, system: fact.system },
    step?.agents,
    step?.status === "passed",
  );
  if (!current || current.status !== "thinking") return settleHold(hold, undefined);
  const { progress: _p, error: _e, ...rest } = current;
  const base: InquiryRecord = {
    ...rest,
    updated_at: now().toISOString(),
    agents: [...(current.agents ?? []), ...(step?.agents ?? [])],
    ...(step && { ai_disclosure: step.ai_disclosure }),
  };
  const turn = step?.status === "passed" ? step.turn : undefined;
  let next: InquiryRecord;
  if (step && turn && !step.done && turn.question) {
    next = {
      ...base,
      status: "asking",
      turns: [...current.turns, turn],
      planned: step.planned,
      ...(step.focus && { understanding: step.focus }),
    };
  } else if (step && turn) {
    next = {
      ...base,
      status: "ready",
      planned: step.planned,
      ...(turn.say && { closing: turn.say }),
      ...(step.focus && { understanding: step.focus }),
    };
  } else {
    next = {
      ...base,
      status: current.turns.length === 0 ? "failed" : "ready",
      ...(error && { error }),
    };
  }
  await store.putInquiry(next);
  // The fee is paid once the conversation has begun; a 深度分析 whose first question never came costs nothing.
  await settleHold(hold, next.status === "failed" ? undefined : (step?.agents ?? []), true);
}

/** The caller's 深度分析, or 404. */
export async function ownedInquiry(ctx: ApiContext, id: string, c: Caller) {
  const { store } = ctx;
  const r = UUID_RE.test(id) ? await store.getInquiry(id) : undefined;
  if (!r || r.owner !== c.user) throw new HttpError(404, "inquiry not found");
  return r;
}

/**
 * 深度分析 (v10.0.0): the master's questions on a chart before its reading. It needs a goal (the owner:
 * 「使用这一功能一定要给出个明确的目标才行」): 400 goal_required without one. The first question comes in the background.
 * One from the daily AI caps, as a reading takes.
 */
async function createInquiry(ctx: ApiContext, req: IncomingMessage, c: Caller) {
  const { store, now, assertServed, track, holdForJob, chartRequest } = ctx;
  const { body, chart } = await chartRequest(req, c);
  if (!inquiryAvailable(chart.fact)) {
    throw new InputError(`深度分析 is not offered for ${chart.fact.system} readings`);
  }
  const locale = body.locale as Locale;
  if (!LOCALES.includes(locale))
    throw new InputError(`locale must be one of ${LOCALES.join(", ")}`);
  const goal = inquiryGoal(body.goal);
  if (!goal) {
    throw new HttpError(
      400,
      `a 深度分析 needs a clear goal: what you want to know, ${INQUIRY_GOAL_MIN}–${INQUIRY_GOAL_MAX} characters`,
      "goal_required",
    );
  }
  const focus = body.focus as TarotFocus | undefined;
  if (focus !== undefined && (chart.fact.system !== "tarot" || !TAROT_FOCUS.includes(focus))) {
    throw new InputError(`focus is for tarot readings: one of ${TAROT_FOCUS.join(", ")}`);
  }
  assertServed(c.country, chart.fact.system);
  const context = parseUserContext(body.context);
  // The question the chart was drawn for (v11.1.0), which the reading after the conversation answers.
  const asks = asksQuestion(chart.fact.system) && !chart.daily;
  const question = (asks && chart.question) || parseQuestion(body.question);
  if (asks && !question) throw questionRequired();
  const inquiryId = randomUUID();
  // The owner's 统一收费: one fee for the conversation however many questions it takes (1–6), held now.
  const hold = await holdForJob(c, "inquiry", {
    kind: "inquiry",
    id: inquiryId,
    system: chart.fact.system,
  });
  const ts = now().toISOString();
  const record: InquiryRecord = {
    id: inquiryId,
    owner: c.user,
    chart_id: chart.id,
    locale,
    status: "thinking",
    goal,
    ...(question && { question }),
    ...(focus && { focus }),
    ...(context && { context }),
    turns: [],
    ...(hold && { fee: hold.quote }),
    created_at: ts,
    updated_at: ts,
  };
  await store.putInquiry(record);
  track(`inquiry ${record.id}`, runInquiryTurn(ctx, record, chart.fact, c, hold));
  return {
    status: 202,
    body: publicInquiry(record),
    headers: { location: `/v1/inquiries/${record.id}`, "retry-after": "3" },
  };
}

/** The user's answer to the master's question; the master's next turn comes in the background. */
async function answerInquiry(ctx: ApiContext, req: IncomingMessage, id: string, c: Caller) {
  const { store, now, assertAllowed, assertServed, track } = ctx;
  const body = (await readJson(req)) as Record<string, unknown>;
  const answer = typeof body.answer === "string" ? body.answer.trim() : "";
  if (!answer) throw new InputError("answer is required");
  if ([...answer].length > INQUIRY_ANSWER_MAX) {
    throw new InputError(`answer must be at most ${INQUIRY_ANSWER_MAX} characters`);
  }
  const record = await ownedInquiry(ctx, id, c);
  // Each answer asks the model for the next turn (v11.2.0).
  await assertAllowed(c, "ai");
  if (record.status === "thinking") {
    throw new HttpError(409, "the master is still thinking", "inquiry_thinking");
  }
  if (record.status !== "asking") {
    throw new HttpError(409, "the master has no question waiting", "inquiry_not_asking");
  }
  const chart = await store.getChart(record.chart_id);
  if (!chart) throw new HttpError(404, "chart not found");
  assertServed(c.country, chart.fact.system);
  const turns = record.turns.map((t, i) => (i === record.turns.length - 1 ? { ...t, answer } : t));
  const next: InquiryRecord = {
    ...record,
    status: "thinking",
    turns,
    updated_at: now().toISOString(),
  };
  await store.putInquiry(next);
  track(`inquiry ${record.id}`, runInquiryTurn(ctx, next, chart.fact, c));
  return {
    status: 202,
    body: publicInquiry(next),
    headers: { location: `/v1/inquiries/${record.id}`, "retry-after": "3" },
  };
}

/** Starting a 深度分析, one, and answering it; false for any other path. */
export async function inquiryRoute(
  ctx: ApiContext,
  req: IncomingMessage,
  res: ServerResponse,
  path: string,
  c: Caller,
): Promise<boolean> {
  if (path === "/v1/inquiries" && req.method === "POST") {
    const out = await createInquiry(ctx, req, c);
    send(res, out.status, out.body, out.headers);
    return true;
  }
  const iq = /^\/v1\/inquiries\/([^/]+)(\/answers)?$/.exec(path);
  if (iq && !iq[2] && req.method === "GET") {
    const r = await ownedInquiry(ctx, iq[1]!, c);
    send(res, 200, publicInquiry(r), aiHeaders(r.ai_disclosure));
    return true;
  }
  if (iq && iq[2] && req.method === "POST") {
    const out = await answerInquiry(ctx, req, iq[1]!, c);
    send(res, out.status, out.body, out.headers);
    return true;
  }
  return false;
}
