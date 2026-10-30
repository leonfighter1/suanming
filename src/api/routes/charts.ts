/**
 * Charts and readings (moved here in S28 WP28.9): the methods the caller's region offers, 算卦's coins laid out,
 * making a chart (a 起名 chart from the caller's 八字 one) or a reading with its job, a reading and its share image,
 * the history, and a chart.
 */
import { randomUUID } from "node:crypto";
import type { IncomingMessage, ServerResponse } from "node:http";
import {
  generateReport,
  LOCALES,
  parseUserContext,
  TAROT_FOCUS,
  TOPICS,
  TOPICS_BY_SYSTEM,
  type InquiryContext,
  type Locale,
  type Report,
  type TarotFocus,
  type Topic,
} from "../../ai/index.js";
import type { ChartSystem } from "../../chart-fact/index.js";
import { loadGeoMatrix, methodsFor, resolveRegion } from "../../compliance/index.js";
import { newLayout } from "../../engines/liuyao/index.js";
import { aiHeaders, HttpError, readJson, send } from "../../http/util.js";
import { quoteFor, type PointsHold } from "../../points/index.js";
import {
  asksQuestion,
  computeChart,
  computeNamingChart,
  InputError,
  parsePerson,
  parseQuestion,
  UUID_RE,
} from "../../service/charts.js";
import { upstreamMessage } from "../../service/runtime.js";
import { shareFont } from "../../share/font.js";
import { renderQiuqianShare } from "../../share/qiuqian-image.js";
import { renderTarotShare } from "../../share/tarot-image.js";
import type { ApiContext, Caller } from "../context.js";
import type { InquiryRecord, ReportRecord } from "../store.js";
import { chartSummary, heldWhy, publicReport, questionRequired } from "../views.js";
import { ownedInquiry } from "./inquiry.js";
import { preloadRemedies } from "./remedies.js";

/** The methods with a share image, each drawn its own way (rule 8). */
const SHARE_RENDERERS: Partial<Record<ChartSystem, typeof renderTarotShare>> = {
  tarot: renderTarotShare,
  qiuqian: renderQiuqianShare,
};

/**
 * 起名 (v4.5.0): reads the caller's own 八字 chart; anyone else's is as if it weren't there. The names are for that
 * chart's person (v8.0.0), so the 起名 record is filed under them too.
 */
async function namingChart(ctx: ApiContext, body: Record<string, unknown>, c: Caller) {
  const { opts, store, now } = ctx;
  const id = body.bazi_chart_id;
  if (typeof id !== "string" || !UUID_RE.test(id)) {
    throw new InputError("bazi_chart_id must be a UUID");
  }
  const bazi = await store.getChart(id);
  if (!bazi || bazi.owner !== c.user) throw new HttpError(404, "chart not found");
  return {
    fact: computeNamingChart(body, bazi.fact, opts.secrets, now),
    ...(bazi.person?.name && { person: { name: bazi.person.name } }),
  };
}

async function runJob(
  ctx: ApiContext,
  record: ReportRecord,
  fact: Parameters<typeof generateReport>[0],
  c: Caller,
  question?: string,
  focus?: TarotFocus,
  inquiry?: InquiryContext,
  hold?: PointsHold,
) {
  const { opts, store, now, log, pointsConfig, settleHold, recordJob, mailWhenDone } = ctx;
  let next: ReportRecord;
  try {
    const report: Report = await generateReport(
      fact,
      {
        locale: record.locale,
        country: c.country,
        topics: record.topics,
        question,
        ...(focus && { focus }),
        context: record.context,
        ...(inquiry && { inquiry }),
      },
      {
        providers: opts.providers,
        routing: opts.routing?.(),
        review: opts.review !== false,
        now,
        // Live stage for clients polling the pending report.
        onProgress: async ({ stage, attempt }) => {
          const current = await store.getReport(record.id);
          if (current?.status !== "pending") return;
          await store.putReport({
            ...current,
            progress: { stage, attempt, updated_at: now().toISOString() },
          });
        },
      },
    );
    next = { ...record, status: report.status, report, updated_at: now().toISOString() };
    if (report.status !== "passed") log(`report ${record.id} held: ${heldWhy(report)}`);
  } catch (e) {
    const upstream = upstreamMessage(e);
    log(
      `report ${record.id} failed: ${upstream ?? (e as Error).message}`,
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
  const gone = !(await store.getReport(record.id));
  await recordJob(
    { kind: "report", id: record.id, owner: record.owner, system: fact.system },
    next.report?.agents,
    !gone && next.status === "passed",
  );
  if (gone) return settleHold(hold, undefined);
  await store.putReport(next);
  await settleHold(hold, next.status === "passed" ? next.report?.agents : undefined);
  if (next.status === "passed") await mailWhenDone("report", record.id);
  // With 积分 a plan is made when bought: a preload spends tokens nobody pays for.
  if (next.status === "passed" && next.report && opts.preloadRemedies !== false && !pointsConfig) {
    await preloadRemedies(ctx, next, next.report, fact, c);
  }
}

async function createReport(ctx: ApiContext, req: IncomingMessage, c: Caller) {
  const { store, now, assertServed, track, holdForJob, chartRequest } = ctx;
  const { body, chart } = await chartRequest(req, c);
  const locale = body.locale as Locale;
  if (!LOCALES.includes(locale))
    throw new InputError(`locale must be one of ${LOCALES.join(", ")}`);
  const allowed = TOPICS_BY_SYSTEM[chart.fact.system];
  const requested =
    Array.isArray(body.topics) && body.topics.length ? (body.topics as Topic[]) : [...allowed];
  const bad = requested.filter((t) => !allowed.includes(t));
  if (bad.length)
    throw new InputError(`topics not available for ${chart.fact.system}: ${bad.join(", ")}`);
  assertServed(c.country, chart.fact.system);
  // 深度分析 (v10.0.0): the conversation held on this chart, read by the reading. The last question may go unanswered
  // (the user skipped the rest); a conversation is read by one reading only.
  let inquiry: InquiryRecord | undefined;
  if (body.inquiry_id !== undefined) {
    const id = body.inquiry_id;
    if (typeof id !== "string" || !UUID_RE.test(id))
      throw new InputError("inquiry_id must be a UUID");
    inquiry = await ownedInquiry(ctx, id, c);
    if (inquiry.chart_id !== chart.id) throw new InputError("the 深度分析 is for another chart");
    if (inquiry.status === "thinking") {
      throw new HttpError(409, "the master is still thinking", "inquiry_thinking");
    }
    if (inquiry.status === "closed" || inquiry.report_id) {
      throw new HttpError(409, "this 深度分析 already has its reading", "inquiry_used");
    }
    if (inquiry.status === "failed") {
      throw new HttpError(409, "this 深度分析 failed: read without it", "inquiry_failed");
    }
  }
  // Every check before anything is held or counted (v11.0.0). 塔罗, 求签 and 算卦 answer the question they were
  // drawn for (v11.1.0); a chart drawn before then, the one the request asks. 每日一牌 is drawn for none.
  const asks = asksQuestion(chart.fact.system) && !chart.daily;
  const question = asks
    ? (chart.question ?? parseQuestion(body.question) ?? inquiry?.question)
    : typeof body.question === "string"
      ? body.question.slice(0, 300)
      : inquiry?.question;
  if (asks && !question) throw questionRequired();
  const focus = (body.focus ?? inquiry?.focus) as TarotFocus | undefined;
  if (focus !== undefined && (chart.fact.system !== "tarot" || !TAROT_FOCUS.includes(focus))) {
    throw new InputError(`focus is for tarot readings: one of ${TAROT_FOCUS.join(", ")}`);
  }
  const context = parseUserContext(body.context) ?? inquiry?.context;
  const conversation: InquiryContext | undefined = inquiry && {
    goal: inquiry.goal,
    turns: inquiry.turns.flatMap((t) =>
      t.answer ? [{ say: t.say, question: t.question, answer: t.answer }] : [],
    ),
    ...(inquiry.understanding && { understanding: inquiry.understanding }),
  };
  const topics = TOPICS.filter((t) => requested.includes(t));
  const reportId = randomUUID();
  const hold = await holdForJob(
    c,
    "report",
    { kind: "report", id: reportId, system: chart.fact.system },
    quoteFor(chart.fact, topics.length),
  );

  const ts = now().toISOString();
  const record: ReportRecord = {
    id: reportId,
    owner: c.user,
    chart_id: chart.id,
    status: "pending",
    locale,
    topics,
    created_at: ts,
    updated_at: ts,
    ...(context && { context }),
    // What the reading was asked for, kept for its 追问 (v7.0.0), sealed with it.
    ...(question && { question }),
    ...(focus && { focus }),
    ...(inquiry && { inquiry_id: inquiry.id }),
  };
  await store.putReport(record);
  if (inquiry) {
    await store.putInquiry({
      ...inquiry,
      status: "closed",
      report_id: record.id,
      updated_at: ts,
    });
  }
  track(
    `report ${record.id}`,
    runJob(ctx, record, chart.fact, c, question, focus, conversation, hold),
  );
  return {
    status: 202,
    body: publicReport(record),
    headers: { location: `/v1/reports/${record.id}`, "retry-after": "5" },
  };
}

/** The methods, 算卦's layout, a share image, a reading, the history, a chart, making one; false otherwise. */
export async function chartsRoute(
  ctx: ApiContext,
  req: IncomingMessage,
  res: ServerResponse,
  path: string,
  c: Caller,
): Promise<boolean> {
  const { opts, store, now, idempotency, assertServed } = ctx;
  // The methods the caller's region offers, in its entry order (v4.3.0, WP6.2): the home page orders
  // its entries by it, so the matrix can put 求籤 first in Taiwan and Hong Kong without a release.
  if (path === "/v1/methods" && req.method === "GET") {
    assertServed(c.country);
    const matrix = loadGeoMatrix();
    send(res, 200, {
      region: c.country,
      matrix_version: matrix.matrix_version,
      methods: methodsFor(resolveRegion(matrix, c.country)!),
    });
    return true;
  }

  // 算卦 (v5.3.0): coins laid out face down for a pick cast. The coins stay on the server (they follow
  // from the draw key and the id); the reader gets the id and the commitment, then posts the 18 coins
  // picked, in order, as a liuyao chart.
  if (path === "/v1/liuyao/layouts" && req.method === "POST") {
    assertServed(c.country, "liuyao");
    send(res, 201, newLayout(opts.secrets.drawKey));
    return true;
  }

  // 分享图 (S7, v4.2.0): a passed tarot or (v4.3.0) 求籤 reading as an image, made here, as the
  // owner's spec asks. Each method draws its own.
  const sm = /^\/v1\/reports\/([^/]+)\/share\.jpg$/.exec(path);
  if (sm && req.method === "GET") {
    const r = UUID_RE.test(sm[1]!) ? await store.getReport(sm[1]!) : undefined;
    if (!r || r.owner !== c.user) throw new HttpError(404, "report not found");
    const chart = await store.getChart(r.chart_id);
    const render = chart && SHARE_RENDERERS[chart.fact.system];
    if (r.status !== "passed" || !r.report?.layers || !render) {
      throw new HttpError(409, "only a finished tarot or 求籤 reading can be shared as an image");
    }
    const font = shareFont(r.locale);
    if (!font) {
      throw new HttpError(
        503,
        "share images need a CJK font on the server: install fonts-noto-cjk or set MINGLI_SHARE_FONT",
      );
    }
    const jpg = await render(r.report, chart.fact, { font, locale: r.locale });
    res.writeHead(200, {
      "content-type": "image/jpeg",
      "content-length": String(jpg.length),
      "cache-control": "private, max-age=86400",
      ...aiHeaders(r.report.ai_disclosure),
    });
    res.end(jpg);
    return true;
  }

  if (req.method === "GET") {
    const m = /^\/v1\/reports\/([^/]+)$/.exec(path);
    if (m) {
      const r = UUID_RE.test(m[1]!) ? await store.getReport(m[1]!) : undefined;
      if (!r || r.owner !== c.user) throw new HttpError(404, "report not found");
      const view = publicReport(r);
      send(res, 200, view, aiHeaders("ai_disclosure" in view ? view.ai_disclosure : undefined));
      return true;
    }
    const limit = Math.min(
      Math.max(
        Number(new URL(req.url ?? "/", "http://localhost").searchParams.get("limit") ?? 20) || 20,
        1,
      ),
      100,
    );
    // History: the user's earlier readings (newest first) with a chart summary each.
    if (path === "/v1/reports") {
      const rows = await store.listReports(c.user, limit);
      const items = await Promise.all(
        rows.map(async (r) => {
          const chart = await store.getChart(r.chart_id);
          const {
            layers: _l,
            ai_disclosure: _a,
            ...view
          } = publicReport(r) as Record<string, unknown>;
          return {
            ...view,
            chart_id: r.chart_id,
            chart: chart && chartSummary(chart.fact),
            ...(chart?.person && { person: chart.person }),
            // 同名重算 (v10.0.0): what the reading was asked, so the app can tell the same question asked again.
            ...(r.question && { question: r.question }),
          };
        }),
      );
      send(res, 200, { items });
      return true;
    }
    if (path === "/v1/charts") {
      const rows = await store.listCharts(c.user, limit);
      send(res, 200, {
        items: rows.map((r) => ({
          chart_id: r.id,
          created_at: r.created_at,
          chart: chartSummary(r.fact),
          ...(r.person && { person: r.person }),
        })),
      });
      return true;
    }
    const cm = /^\/v1\/charts\/([^/]+)$/.exec(path);
    if (cm) {
      const ch = UUID_RE.test(cm[1]!) ? await store.getChart(cm[1]!) : undefined;
      if (!ch || ch.owner !== c.user) throw new HttpError(404, "chart not found");
      send(res, 200, {
        chart_id: ch.id,
        chart_fact: ch.fact,
        ...(ch.person && { person: ch.person }),
        ...(ch.question && { question: ch.question }),
      });
      return true;
    }
  }

  if (req.method === "POST" && (path === "/v1/charts" || path === "/v1/reports")) {
    const key = req.headers["idempotency-key"];
    const idemKey =
      typeof key === "string" && key ? `${c.user}:${path}:${key.slice(0, 128)}` : undefined;
    const cached = idemKey && idempotency.get(idemKey);
    if (cached) {
      send(res, cached.status, cached.body, cached.headers);
      return true;
    }

    let out: { status: number; body: unknown; headers: Record<string, string> };
    if (path === "/v1/charts") {
      const body = (await readJson(req)) as {
        system?: string;
        person?: unknown;
        question?: unknown;
      };
      assertServed(c.country, body.system);
      // 塔罗, 求签 and 算卦 are drawn for a question (v11.1.0): nothing is drawn before something is asked.
      const question = asksQuestion(body.system) ? parseQuestion(body.question) : undefined;
      if (asksQuestion(body.system) && !question) throw questionRequired();
      // Whose chart it is (v6.2.0): kept on the record for history on any device, never in the facts. A 起名
      // chart takes its 八字 chart's person unless the request names one (v8.0.0).
      const asked = parsePerson(body.person, body.system);
      const made =
        body.system === "naming"
          ? await namingChart(ctx, body as Record<string, unknown>, c)
          : { fact: computeChart(body, opts.secrets, now) };
      const fact = made.fact;
      const person = asked ?? ("person" in made ? made.person : undefined);
      const id = randomUUID();
      await store.putChart({
        id,
        owner: c.user,
        fact,
        created_at: now().toISOString(),
        ...(person && { person }),
        ...(question && { question }),
      });
      out = {
        status: 201,
        body: {
          chart_id: id,
          chart_fact: fact,
          ...(person && { person }),
          ...(question && { question }),
        },
        headers: { location: `/v1/charts/${id}` },
      };
    } else {
      out = await createReport(ctx, req, c);
    }
    if (idemKey) idempotency.set(idemKey, out);
    send(res, out.status, out.body, out.headers);
    return true;
  }
  return false;
}
