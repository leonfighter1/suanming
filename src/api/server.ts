/**
 * v1 product API (api/openapi.yaml): auth, account, charts, async reports, health.
 *
 * Identity: `Authorization: Bearer <access token>`; the region is the one stored
 * on the account at sign-up (Geo-Rule checked then), never a client header.
 * devMode additionally accepts `X-Dev-User` / `X-Dev-Country` when no bearer
 * token is sent, for local tools and tests.
 */
import { createServer, type IncomingMessage, type ServerResponse, type Server } from "node:http";
import {
  loadRouting,
  GeoRefusedError,
  ReportInputError,
  type AgentTrace,
  type LLMProvider,
  type RoutingTable,
} from "../ai/index.js";
import { SCHEMA_VERSION } from "../chart-fact/index.js";
import { loadGeoMatrix, loadRuleSet, resolveRegion } from "../compliance/index.js";
import { AccountError, AccountService } from "../auth/account.js";
import { AuthError, AuthService, permissionsOf, type AccountPermissions } from "../auth/service.js";
import { adminRoute } from "../admin/routes.js";
import { usageRows } from "../admin/usage.js";
import { VerifyError } from "../auth/verify.js";
import { lifeDocument, localTime, readingDocument } from "../export/report-doc.js";
import {
  Dispatcher,
  NoMail,
  NoSms,
  pdfNote,
  type MailTransport,
  type SmsTransport,
} from "../notify/index.js";
import { serveStatic } from "../http/static.js";
import { HttpError, problem, readJson, send } from "../http/util.js";
import {
  chargeFor,
  loadPointsConfig,
  quote,
  type ChargeKind,
  type PointsCharge,
  type PointsConfig,
  type PointsFor,
  type PointsHold,
  type Quote,
  type QuoteFor,
} from "../points/index.js";
import { InputError, UUID_RE, type EngineSecrets } from "../service/charts.js";
import { documentName } from "../export/document.js";
import { renderPdf } from "../export/render-pdf.js";
import { shareFont } from "../share/font.js";
import type { ApiContext, Caller } from "./context.js";
import { authRoute, accountRoute } from "./routes/account.js";
import { archiveRoute } from "./routes/archive.js";
import { chartsRoute } from "./routes/charts.js";
import { dailyRoute } from "./routes/daily.js";
import { followUpRoute } from "./routes/followup.js";
import { inquiryRoute } from "./routes/inquiry.js";
import { lifeRoute } from "./routes/life.js";
import { pointsRoute } from "./routes/points.js";
import { publicRoute } from "./routes/public.js";
import { remediesRoute } from "./routes/remedies.js";
import {
  InMemoryStore,
  type ReviewDecision,
  type LifeReportRecord,
  type ReportMail,
  type ReportRecord,
  type Store,
} from "./store.js";
import { reviewSummary } from "./views.js";

export const API_VERSION = "0.2.0";

/** 发到邮箱 (v9.0.0): messages a day per account (each with at most MAIL_DOCUMENTS records: routes/archive.ts). */
export const MAIL_PER_DAY = 20;

/** 管理后台 (v11.2.0): how often an account's last activity is written. */
export const SEEN_EVERY_MS = 5 * 60_000;

export interface ApiOptions {
  secrets: EngineSecrets;
  providers: Record<string, LLMProvider>;
  store?: Store;
  /** Required outside devMode. */
  auth?: AuthService;
  /**
   * The routing for each AI job, read as the job starts (v9.2.0: ACTIVE_AI_MODEL can change between jobs). Default:
   * config/model_routing.json, which the pipelines read per job.
   */
  routing?: () => RoutingTable;
  devMode?: boolean;
  /**
   * Extra browser origins allowed to call the API, e.g. the GitHub Pages web test
   * ("https://leonfighter1.github.io"). devMode always allows http://localhost.
   */
  corsOrigins?: string[];
  /**
   * LAN testing (phones on the same Wi-Fi): also allow http origins on private
   * addresses (10/8, 172.16/12, 192.168/16) in devMode.
   */
  corsPrivateNetwork?: boolean;
  /**
   * devMode's X-Dev-User / X-Dev-Country shortcut (default: on in devMode). Turn it
   * off whenever the API is reachable from other machines: anyone could act as any user.
   */
  devHeaders?: boolean;
  /**
   * Behind a tunnel or proxy every connection comes from 127.0.0.1: take the client
   * IP from CF-Connecting-IP / X-Forwarded-For instead, so login limits stay per person.
   * Only set this when the server is reachable through that proxy alone.
   */
  trustProxy?: boolean;
  /** Serve this directory (the built web app) for non-/v1 GET requests. */
  staticDir?: string;
  /** Serve this directory (the built 管理后台, admin/build/served) at /admin/ (S22, v12.0.0). */
  adminDir?: string;
  /**
   * Content review (rule-layer holds, guard, 内容审核). Default true; false pauses it
   * (owner decision 2026-10-26, a later legal & obligations item): outputs are
   * scanned and hits recorded, but nothing is held and the console is closed.
   */
  review?: boolean;
  /** Reviewers (内容审核): account usernames / emails allowed to read and decide held content. */
  admins?: string[];
  /**
   * How mail and text messages leave (v8.2.0, tech plan S15): verification codes, and reports their owner asked
   * for. Default off; the API server uses the development outbox (src/notify) until the owner picks providers.
   */
  mail?: MailTransport;
  sms?: SmsTransport;
  /** Daily caps on AI jobs (reports + 破除運勢 plans), to bound provider spend. */
  aiQuota?: { perUserPerDay: number; totalPerDay: number };
  /**
   * What answers AI calls right now: a provider name, or "mock" (the owner's
   * IS_AI_MOCK switch in .env). Shown on /v1/health; while it is "mock" nothing is
   * spent, so aiQuota is not counted.
   */
  aiServing?: () => string;
  /** The model(s) behind aiServing (v9.2.0), shown on /v1/health while a real model answers. */
  aiModel?: () => string;
  /**
   * Generate every topic's 破除運勢 plan (locked) right after a report passes, so a
   * purchase opens instantly. Default true. Counts against aiQuota.totalPerDay. Never with `points`: a preload
   * spends tokens nobody pays for.
   */
  preloadRemedies?: boolean;
  /**
   * 积分 (v11.0.0, tech plan S20): every AI request is paid in points: its price is held while it runs (402
   * points_short when the account can't cover it) and it is charged what it cost (src/points). Absent: everything
   * is free, as before. `simulateTopUp`: 充值 adds a pack's 积分 without payment (development, until Phase 4).
   */
  points?: { config?: PointsConfig; simulateTopUp?: boolean };
  now?: () => Date;
  log?: (msg: string, err?: unknown) => void;
}

export function createApiServer(opts: ApiOptions): Server & { drain(): Promise<void> } {
  const store = opts.store ?? new InMemoryStore();
  const now = opts.now ?? (() => new Date());
  const log = opts.log ?? ((m, e) => console.error(m, e ?? ""));
  const jobs = new Set<Promise<void>>();
  const idempotency = new Map<
    string,
    { status: number; body: unknown; headers: Record<string, string> }
  >();
  // The geo matrix is read on every request, as the pipeline reads it on every reading: a changed matrix
  // (起名 switched on, a region signed off) takes effect without a release or a restart (Phase 3 §2.4).

  /**
   * Runs a background job, tracked for drain(). A failure is logged, never left unhandled: the
   * database store (v4.1.0) can throw where memory never did, e.g. on a write for an account
   * deleted a moment before, and an unhandled rejection would end the process.
   */
  function track(what: string, work: Promise<void>) {
    const job: Promise<void> = work
      .catch((e: unknown) => log(`${what} failed to finish`, e))
      .finally(() => jobs.delete(job));
    jobs.add(job);
  }

  const admins = new Set((opts.admins ?? []).map((a) => a.trim().toLowerCase()).filter(Boolean));
  /** The reviewer's login (its username or its email, v8.2.0) when the caller is a reviewer, else undefined. */
  async function reviewer(c: Caller): Promise<string | undefined> {
    const u = auth ? await auth.users.get(c.user) : undefined;
    const names = u ? [u.username, u.email] : [c.user];
    const named = names
      .filter((n): n is string => n !== undefined)
      .map((n) => n.toLowerCase())
      .find((n) => admins.has(n));
    // An account given the admin role in 管理后台 (v11.2.0) reviews too.
    return named ?? (u?.role === "admin" ? (u.username ?? u.email ?? u.id) : undefined);
  }

  function clientIp(req: IncomingMessage): string {
    if (opts.trustProxy) {
      const cf = req.headers["cf-connecting-ip"];
      const xff = req.headers["x-forwarded-for"];
      const forwarded =
        typeof cf === "string" ? cf : typeof xff === "string" ? xff.split(",")[0] : "";
      if (forwarded?.trim()) return forwarded.trim();
    }
    return req.socket.remoteAddress ?? "unknown";
  }

  /** AI jobs started today, per user and in total (UTC day). */
  const aiUse = new Map<string, number>();
  const aiFree = () => opts.aiServing?.() === "mock";
  function takeAiQuota(user: string) {
    const q = opts.aiQuota;
    if (!q || aiFree()) return;
    const day = now().toISOString().slice(0, 10);
    for (const k of [...aiUse.keys()]) if (!k.startsWith(day)) aiUse.delete(k);
    const mine = aiUse.get(`${day}:u:${user}`) ?? 0;
    const all = aiUse.get(`${day}:all`) ?? 0;
    if (mine >= q.perUserPerDay) {
      throw new HttpError(
        429,
        `daily AI limit reached (${q.perUserPerDay} per account); try again tomorrow`,
      );
    }
    if (all >= q.totalPerDay)
      throw new HttpError(429, "the test service's daily AI limit is reached; try again tomorrow");
    aiUse.set(`${day}:u:${user}`, mine + 1);
    aiUse.set(`${day}:all`, all + 1);
  }
  /** 发到邮箱 messages sent today per account (UTC day): a provider charges for each. */
  const mailUse = new Map<string, number>();
  function takeMailQuota(user: string) {
    const day = now().toISOString().slice(0, 10);
    for (const k of [...mailUse.keys()]) if (!k.startsWith(day)) mailUse.delete(k);
    const used = mailUse.get(`${day}:${user}`) ?? 0;
    if (used >= MAIL_PER_DAY) {
      throw new HttpError(
        429,
        `at most ${MAIL_PER_DAY} mails a day; try again tomorrow`,
        "too_many",
      );
    }
    mailUse.set(`${day}:${user}`, used + 1);
  }
  /** Background jobs (preloads) take only from the daily total; false = skip. */
  function takeBackgroundQuota(): boolean {
    const q = opts.aiQuota;
    if (!q || aiFree()) return true;
    const day = now().toISOString().slice(0, 10);
    const all = aiUse.get(`${day}:all`) ?? 0;
    if (all >= q.totalPerDay) return false;
    aiUse.set(`${day}:all`, all + 1);
    return true;
  }

  // ---- 积分 (v11.0.0, tech plan S20): every AI request held, then charged what it cost ----

  const pointsConfig = opts.points && (opts.points.config ?? loadPointsConfig());
  const simulatedTopUp = !!opts.points?.simulateTopUp;
  /** The routing a job started now would get: prices follow the model it names (ACTIVE_AI_MODEL too). */
  const routingNow = () => opts.routing?.() ?? loadRouting();
  /** What an AI request costs now; undefined while 积分 are off. */
  const priceOf = (kind: ChargeKind, about?: QuoteFor): Quote | undefined =>
    pointsConfig && quote(pointsConfig, routingNow(), kind, about);

  /** Holds a request's price; 402 points_short, with what it needs and what is available, when that doesn't cover it. */
  async function holdPoints(c: Caller, price: Quote | undefined, what: PointsFor) {
    if (!price) return undefined;
    const hold = await store.holdPoints(
      c.user,
      price.points,
      price.hold,
      what,
      now().toISOString(),
    );
    if (hold) return hold;
    const { balance, held } = await store.pointsOf(c.user);
    const available = Math.max(0, balance - held);
    throw new HttpError(
      402,
      `not enough 积分: this costs about ${price.points}, and ${available} are available`,
      "points_short",
      { need: price.points, available },
    );
  }

  /** 管理后台 (v11.2.0): what an admin allows this account; 403 `ai_not_allowed` / `top_up_not_allowed` when not. */
  async function assertAllowed(c: Caller, what: keyof AccountPermissions) {
    const u = auth && (await auth.users.get(c.user));
    if (u && !permissionsOf(u)[what]) {
      throw new HttpError(
        403,
        what === "ai"
          ? "AI readings are turned off for this account"
          : "充值 is turned off for this account",
        `${what}_not_allowed`,
      );
    }
  }

  /** Prices a step on a model without a list price (the usage rows' cost), whether or not 积分 are on. */
  const referenceModel = (pointsConfig ?? loadPointsConfig()).pricing.reference_model;

  /** 管理后台 (v11.2.0): an AI job's steps as it ends, delivered or not: its tokens were spent either way. */
  async function recordJob(
    job: { kind: ChargeKind; id: string; owner: string; system?: string },
    agents: readonly AgentTrace[] | undefined,
    delivered: boolean,
  ) {
    if (!agents?.length) return;
    await store.recordUsage(usageRows(job, agents, delivered, now().toISOString(), referenceModel));
  }

  /**
   * Before an AI job: the account allowed AI, its price held, then the daily AI caps, so a refusal takes nothing.
   * The hold is undefined while 积分 are off.
   */
  async function holdForJob(c: Caller, kind: ChargeKind, what: PointsFor, about?: QuoteFor) {
    await assertAllowed(c, "ai");
    const hold = await holdPoints(c, priceOf(kind, about), what);
    try {
      takeAiQuota(c.user);
    } catch (e) {
      await settleHold(hold, undefined);
      throw e;
    }
    return hold;
  }

  /**
   * Ends a job's hold. What it delivered is charged: its measured cost (its quote when no tokens were reported: the
   * mock), or with `flat` its quote, the 深度分析's 统一收费; never more than was held. A job that delivered nothing
   * (failed, held for review, deleted meanwhile) is charged nothing.
   */
  async function settleHold(
    hold: PointsHold | undefined,
    delivered: readonly AgentTrace[] | undefined,
    flat = false,
  ) {
    if (!hold || !pointsConfig) return;
    const charge: PointsCharge | undefined = !delivered
      ? undefined
      : flat
        ? { points: hold.quote, basis: "flat" }
        : chargeFor(pointsConfig, hold, delivered);
    await store.settlePoints(hold, charge, now().toISOString());
  }

  const auth = opts.auth;
  if (!opts.devMode && !auth) throw new Error("ApiOptions.auth is required outside devMode");
  const mail = opts.mail ?? new NoMail();
  const sms = opts.sms ?? new NoSms();
  /** Every message's way out (S25): its template (an admin's wording, else the default), its channel, its note. */
  const messages = new Dispatcher({ mail, sms, templates: store, now });
  /** The account's own logins and settings (v8.2.0). */
  const account = auth && new AccountService({ auth, mail, sms, messages, now });
  const delivery = () => ({ mail: mail.name, sms: sms.name });

  async function caller(req: IncomingMessage): Promise<Caller> {
    if (req.headers.authorization || !opts.devMode || opts.devHeaders === false) {
      if (!auth) throw new HttpError(401, "authentication not configured");
      // A suspended account is refused here (403 account_suspended, v11.2.0).
      const u = await auth.authenticate(req.headers.authorization);
      // 管理后台 (v11.2.0): when it was last active, to the minute, at most every five minutes.
      const t = now();
      if (!u.last_seen_at || t.getTime() - Date.parse(u.last_seen_at) >= SEEN_EVERY_MS) {
        const minute = new Date(Math.floor(t.getTime() / 60_000) * 60_000).toISOString();
        track("last seen", auth.users.touch(u.id, minute));
      }
      return { user: u.id, country: u.country };
    }
    const country = String(req.headers["x-dev-country"] ?? "").toUpperCase();
    if (!/^[A-Z]{2}$/.test(country))
      throw new HttpError(400, "X-Dev-Country header required (ISO 3166-1 alpha-2)");
    return { user: String(req.headers["x-dev-user"] ?? "dev-user"), country };
  }

  /** Geo-Rule: refuse before computing anything for unserved regions. */
  function assertServed(country: string, system?: string) {
    const region = resolveRegion(loadGeoMatrix(), country);
    if (!region || !region.service_available)
      throw new GeoRefusedError(`service not available in ${country}`);
    if (system && region.systems[system]?.available === false) {
      throw new GeoRefusedError(`${system} not available in ${country}`);
    }
  }

  /**
   * 测算完成后发到邮箱 (v9.0.0, tech plan WP15.4): a reading or a 一生运势报告 that passed goes to its owner's verified
   * email, when the owner turned the setting on (否 by default). Never a held, blocked or failed one: a released one
   * goes when the reviewer releases it. The report is in the message and attached as a PDF. How it went is noted on
   * the record; a failure is logged, without the address, and never retried on its own.
   */
  async function mailWhenDone(kind: "report" | "life_report", id: string) {
    if (!auth || mail.name === "off") return;
    const record = kind === "report" ? await store.getReport(id) : await store.getLifeReport(id);
    if (!record || record.status !== "passed") return;
    const owner = await auth.users.get(record.owner);
    if (!owner?.settings?.email_reports || !owner.email || !owner.email_verified_at) return;
    const chart = await store.getChart(record.chart_id);
    const context = {
      locale: record.locale,
      region: owner.country,
      created_at: record.created_at,
      ...(chart?.person && { person: chart.person }),
    };
    let status: ReportMail["status"] = "sent";
    try {
      const doc =
        kind === "report"
          ? readingDocument((record as ReportRecord).report!, {
              ...context,
              system: chart?.fact.system ?? "bazi",
              ...((record as ReportRecord).question && {
                question: (record as ReportRecord).question,
              }),
            })
          : lifeDocument((record as LifeReportRecord).life!, context);
      // Without a Chinese font on the server the report still goes, in the message alone.
      const font = shareFont(record.locale);
      const day = localTime(record.created_at, owner.country).slice(0, 10);
      const pdf = font && {
        // As the app names a downloaded file (docFileName): spaces become dashes.
        filename: documentName(`命理大师-${doc.title.replace(/\s+/g, "-")}-${day}`, "pdf"),
        contentType: "application/pdf",
        content: await renderPdf(doc, font),
      };
      await messages.send("report_mail", {
        to: owner.email,
        locale: record.locale,
        vars: {
          title: doc.title,
          subtitle: doc.subtitle ?? "",
          pdf_note: pdf ? pdfNote(record.locale) : "",
        },
        parts: { report: doc.blocks },
        ...(pdf && { attachments: [pdf] }),
      });
    } catch (e) {
      status = "failed";
      const why = ((e as Error).message ?? String(e)).replace(/[^\s@]+@[^\s@]+/g, "<address>");
      log(`mailing ${kind} ${id} failed: ${why}`);
    }
    const at = now().toISOString();
    // Read again: the record may have changed, or gone, meanwhile.
    if (kind === "report") {
      const current = await store.getReport(id);
      if (current) await store.putReport({ ...current, mail: { status, at } });
    } else {
      const current = await store.getLifeReport(id);
      if (current) await store.putLifeReport({ ...current, mail: { status, at } });
    }
  }

  /** A request on one of the caller's charts: its body, and the chart its chart_id names (400 or 404 otherwise; S28). */
  async function chartRequest(req: IncomingMessage, c: Caller) {
    const body = (await readJson(req)) as Record<string, unknown>;
    const chartId = body.chart_id;
    if (typeof chartId !== "string" || !UUID_RE.test(chartId))
      throw new InputError("chart_id must be a UUID");
    const chart = await store.getChart(chartId);
    if (!chart || chart.owner !== c.user) throw new HttpError(404, "chart not found");
    return { body, chart };
  }

  async function heldItem(kind: string, id: string) {
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
  async function reviews(req: IncomingMessage, res: ServerResponse, path: string, who: string) {
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
    const item = m ? await heldItem(m[1]!, m[2]!) : undefined;
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
    if (body.decision === "approve" && !item.content)
      throw new HttpError(409, "nothing to release");
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
    const after = await heldItem(item.kind, item.r.id);
    return send(res, 200, after!.summary);
  }

  /** What the route groups share (context.ts): these same objects, never copies. */
  const api: ApiContext = {
    opts,
    store,
    now,
    log,
    auth,
    account,
    admins,
    idempotency,
    delivery,
    mail,
    messages,
    takeMailQuota,
    reviewer,
    clientIp,
    pointsConfig,
    simulatedTopUp,
    priceOf,
    assertAllowed,
    assertServed,
    track,
    takeBackgroundQuota,
    holdPoints,
    holdForJob,
    settleHold,
    recordJob,
    chartRequest,
    mailWhenDone,
    routingNow,
  };

  async function handle(req: IncomingMessage, res: ServerResponse) {
    const path = new URL(req.url ?? "/", "http://localhost").pathname;
    // The 管理后台, once built: its page at /admin/, on the API's own origin, so it needs no
    // settings. Before the public mode's app, which would take every path.
    if (
      opts.adminDir &&
      req.method === "GET" &&
      (path === "/admin" || path.startsWith("/admin/"))
    ) {
      if (path === "/admin") {
        // The page's files are relative to /admin/.
        res.writeHead(301, {
          location: "/admin/" + new URL(req.url ?? "/", "http://localhost").search,
        });
        return res.end();
      }
      if (serveStatic(res, opts.adminDir, path.slice("/admin".length))) return;
      throw new HttpError(404, "not found");
    }
    // Public test mode: the built web app on the same origin as the API.
    if (opts.staticDir && req.method === "GET" && !path.startsWith("/v1/")) {
      if (serveStatic(res, opts.staticDir, path)) return;
      throw new HttpError(404, "not found");
    }
    if (req.method === "GET" && path === "/v1/health") {
      return send(res, 200, {
        status: "ok",
        versions: {
          api: API_VERSION,
          chart_fact_schema: SCHEMA_VERSION,
          geo_rule_matrix: loadGeoMatrix().matrix_version,
          prohibited_patterns: loadRuleSet().version,
          tzdb: process.versions.tz ?? "unknown",
        },
        // Visible so nobody mistakes a paused review for a working one.
        content_review: opts.review === false ? "paused" : "on",
        // 积分 (v11.0.0): whether AI requests are paid, and how 充值 works here.
        points: !pointsConfig ? "off" : simulatedTopUp ? "simulated" : "on",
        // ...or the mock's demo answers for the real model.
        ...(opts.aiServing && { ai: opts.aiServing() }),
        ...(opts.aiModel && opts.aiServing?.() !== "mock" && { ai_model: opts.aiModel() }),
      });
    }

    // ---- the calendar and birthplaces: public, stateless (routes/public.ts) ----
    if (publicRoute(req, res, path)) return;

    // ---- auth (no caller yet; routes/account.ts) ----
    if (await authRoute(api, req, res, path)) return;

    const c = await caller(req);

    // ---- account (routes/account.ts) ----
    if (await accountRoute(api, req, res, path, c)) return;

    // ---- 积分 (v11.0.0, tech plan S20; routes/points.ts) ----
    if (await pointsRoute(api, req, res, path, c)) return;

    // ---- 内容审核: reviewers only ----
    if (path === "/v1/admin/reviews" || path.startsWith("/v1/admin/reviews/")) {
      const who = await reviewer(c);
      if (opts.review === false) throw new HttpError(404, "content review is paused");
      if (!who) throw new HttpError(403, "reviewers only");
      return reviews(req, res, path, who);
    }

    // ---- 管理后台 (v11.2.0, tech plan S22): admins only (src/admin/routes.ts) ----
    if (path.startsWith("/v1/admin/")) {
      if (!auth) throw new HttpError(404, "auth not configured");
      const ctx = {
        store,
        auth,
        config: pointsConfig ?? loadPointsConfig(),
        admins,
        messages,
        now,
        log: (m: string) => log(m),
      };
      if (await adminRoute(ctx, req, res, path, c.user)) return;
    }

    // ---- 一生运势报告 (routes/life.ts) ----
    if (await lifeRoute(api, req, res, path, c)) return;

    // ---- 以往记录 (v8.0.0, S14) and the documents (routes/archive.ts) ----
    if (await archiveRoute(api, req, res, path, c)) return;

    // ---- 深度分析 (v10.0.0, S19): the master's questions before a reading (routes/inquiry.ts) ----
    if (await inquiryRoute(api, req, res, path, c)) return;

    // ---- 追问 (v7.0.0, S13): follow-up questions on a passed reading or 一生运势报告 (routes/followup.ts) ----
    if (await followUpRoute(api, req, res, path, c)) return;

    // ---- 破除運勢 plans (paid per topic; payment is a Phase 4 TODO; routes/remedies.ts) ----
    if (await remediesRoute(api, req, res, path, c)) return;

    // ---- the cards of the day: 每日一牌, 今日一卦 / 今日一签 (routes/daily.ts) ----
    if (await dailyRoute(api, req, res, path, c)) return;

    // ---- charts and readings: making them, a reading, its share image, the history (routes/charts.ts) ----
    if (await chartsRoute(api, req, res, path, c)) return;

    throw new HttpError(404, "not found");
  }

  const server = createServer(async (req, res) => {
    // Let Flutter web builds call the API: localhost in devMode, plus configured origins.
    const origin = req.headers.origin;
    const corsOk =
      !!origin &&
      ((opts.devMode && /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) ||
        (opts.devMode &&
          opts.corsPrivateNetwork &&
          /^http:\/\/(10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+)(:\d+)?$/.test(
            origin,
          )) ||
        !!opts.corsOrigins?.includes(origin));
    if (origin && corsOk) {
      res.setHeader("access-control-allow-origin", origin);
      res.setHeader("vary", "origin");
      res.setHeader(
        "access-control-allow-headers",
        "authorization, content-type, idempotency-key, x-dev-user, x-dev-country",
      );
      res.setHeader("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS");
      // content-disposition: an export's file name, for the 管理后台 run from its own origin (v11.4.0).
      res.setHeader(
        "access-control-expose-headers",
        "location, retry-after, x-ai-generated, x-ai-model, content-disposition",
      );
      // Chrome Private Network Access: an https page (GitHub Pages) calling a local API.
      if (req.headers["access-control-request-private-network"] === "true") {
        res.setHeader("access-control-allow-private-network", "true");
      }
      if (req.method === "OPTIONS") {
        res.writeHead(204);
        return res.end();
      }
    }
    try {
      await handle(req, res);
    } catch (e) {
      if (e instanceof HttpError) {
        return problem(res, e.status, e.message, undefined, {
          ...(e.code && { code: e.code }),
          ...e.extra,
        });
      }
      if (e instanceof AuthError) {
        const title = e.status === 451 ? "Unavailable for legal reasons" : "Authentication failed";
        return problem(res, e.status, title, e.message, e.code ? { code: e.code } : {});
      }
      if (e instanceof AccountError || e instanceof VerifyError) {
        return problem(res, e.status, e.message, undefined, { code: e.code });
      }
      if (e instanceof GeoRefusedError)
        return problem(res, 451, "Unavailable for legal reasons", e.message);
      if (e instanceof InputError || e instanceof ReportInputError) {
        return problem(res, /DST gap/.test(e.message) ? 422 : 400, "Invalid request", e.message);
      }
      log("unhandled error", e);
      return problem(res, 500, "Internal error");
    }
  });

  return Object.assign(server, {
    async drain() {
      while (jobs.size) await Promise.all([...jobs]);
    },
  });
}
