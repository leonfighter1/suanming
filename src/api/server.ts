/**
 * v1 product API (api/openapi.yaml): auth, account, charts, async reports, health.
 *
 * Identity: `Authorization: Bearer <access token>`; the region is the one stored
 * on the account at sign-up (Geo-Rule checked then), never a client header.
 * devMode additionally accepts `X-Dev-User` / `X-Dev-Country` when no bearer
 * token is sent, for local tools and tests.
 */
import { randomUUID } from "node:crypto";
import { createServer, type IncomingMessage, type ServerResponse, type Server } from "node:http";
import {
  generateLifeReport,
  generateRemedy,
  generateReport,
  remedyAvailable,
  parseUserContext,
  GeoRefusedError,
  LOCALES,
  NO_PLAN_TOPICS,
  ReportInputError,
  TAROT_FOCUS,
  TOPICS,
  TOPICS_BY_SYSTEM,
  type LLMProvider,
  type Locale,
  type Report,
  type RoutingTable,
  type TarotFocus,
  type Topic,
} from "../ai/index.js";
import { SCHEMA_VERSION, type ChartFact, type ChartSystem } from "../chart-fact/index.js";
import { loadGeoMatrix, loadRuleSet, methodsFor, resolveRegion } from "../compliance/index.js";
import { AuthError, AuthService, publicUser } from "../auth/service.js";
import {
  CalendarInputError,
  lunarDate,
  lunarMonths,
  lunarToSolar,
  shichenOptions,
} from "../engines/bazi/index.js";
import { serveStatic } from "../http/static.js";
import { aiHeaders, HttpError, problem, readJson, send } from "../http/util.js";
import { placeCountry, placeIndex } from "../places/index.js";
import {
  computeChart,
  computeNamingChart,
  InputError,
  UUID_RE,
  type EngineSecrets,
} from "../service/charts.js";
import { dailyDate, dailyIds, drawDaily } from "../service/daily.js";
import { upstreamMessage } from "../service/runtime.js";
import { shareFont } from "../share/font.js";
import { renderQiuqianShare } from "../share/qiuqian-image.js";
import { renderTarotShare } from "../share/tarot-image.js";

/** The methods with a share image, each drawn its own way (rule 8). */
const SHARE_RENDERERS: Partial<Record<ChartSystem, typeof renderTarotShare>> = {
  tarot: renderTarotShare,
  qiuqian: renderQiuqianShare,
};
import {
  InMemoryStore,
  type ReviewDecision,
  type LifeReportRecord,
  type RemedyRecord,
  type ReportRecord,
  type Store,
} from "./store.js";

export const API_VERSION = "0.2.0";

export interface ApiOptions {
  secrets: EngineSecrets;
  providers: Record<string, LLMProvider>;
  store?: Store;
  /** Required outside devMode. */
  auth?: AuthService;
  routing?: RoutingTable;
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
  /**
   * Content review (rule-layer holds, guard, 内容审核). Default true; false pauses it
   * (owner decision 2026-10-26, a later legal & obligations item): outputs are
   * scanned and hits recorded, but nothing is held and the console is closed.
   */
  review?: boolean;
  /** Reviewers (内容审核): account logins / emails allowed to read and decide held content. */
  admins?: string[];
  /** Daily caps on AI jobs (reports + 破除運勢 plans), to bound provider spend. */
  aiQuota?: { perUserPerDay: number; totalPerDay: number };
  /**
   * What answers AI calls right now: a provider name, or "mock" (the owner's
   * IS_AI_MOCK switch in .env). Shown on /v1/health; while it is "mock" nothing is
   * spent, so aiQuota is not counted.
   */
  aiServing?: () => string;
  /**
   * Generate every topic's 破除運勢 plan (locked) right after a report passes, so a
   * purchase opens instantly. Default true. Counts against aiQuota.totalPerDay.
   */
  preloadRemedies?: boolean;
  now?: () => Date;
  log?: (msg: string, err?: unknown) => void;
}

interface Caller {
  user: string;
  country: string;
}

/** Short, locale-neutral description of a chart for history lists. */
export function chartSummary(fact: ChartFact) {
  const f = fact.facts as Record<string, unknown>;
  if (fact.system === "bazi") {
    const p = f.pillars as Record<string, { gan: string; zhi: string }>;
    return {
      system: "bazi",
      four_pillars: ["year", "month", "day", "hour"].map((k) => p[k]!.gan + p[k]!.zhi).join(" "),
      civil_local: (f.time_basis as { civil_local: string }).civil_local,
    };
  }
  if (fact.system === "tarot") {
    return {
      system: "tarot",
      spread: f.spread_id as string,
      cards: (f.cards as { card_id: string; reversed: boolean }[]).map((c) => ({
        card_id: c.card_id,
        reversed: c.reversed,
      })),
    };
  }
  if (fact.system === "qiuqian") {
    const lot = f.lot as { n: number; ganzhi: string };
    return { system: "qiuqian", lot_set: f.lot_set as string, lot: lot.n, ganzhi: lot.ganzhi };
  }
  if (fact.system === "fengshui") {
    return {
      system: "fengshui",
      room: f.room as string,
      ...(typeof f.facing === "string" && { facing: f.facing }),
    };
  }
  if (fact.system === "naming") {
    const surname = f.surname as { "zh-Hant": string; "zh-Hans": string };
    const first = (f.candidates as { given: Record<string, string> }[])[0];
    return {
      system: "naming",
      surname,
      ...(first && { first: first.given }),
    };
  }
  return { system: fact.system };
}

/** What the user may see of a report. Drafts, traces and rule details stay internal. */
export function publicReport(r: ReportRecord) {
  const base = {
    report_id: r.id,
    // The reading's chart, so a reading page can show it (a tarot spread, v2.4.0).
    chart_id: r.chart_id,
    status: r.status,
    created_at: r.created_at,
    updated_at: r.updated_at,
    locale: r.locale,
    topics: r.topics,
  };
  if (r.status === "pending") return r.progress ? { ...base, progress: r.progress } : base;
  if (r.status === "failed") return { ...base, message: "generation failed; please retry" };
  const rep = r.report!;
  if (r.status !== "passed") {
    return { ...base, message: "this report is held for review and is not available yet" };
  }
  return { ...base, layers: rep.layers, ai_disclosure: rep.ai_disclosure };
}

/**
 * Price of one 破除運勢 plan. TODO(Phase 4 payments): take this from the store
 * product catalogue and verify the purchase receipt before generating.
 */
export const REMEDY_PRICE = { amount: 18, currency: "HKD" } as const;

export function publicRemedy(r: RemedyRecord) {
  const base = {
    remedy_id: r.id,
    report_id: r.report_id,
    topic: r.topic,
    status: r.status,
    created_at: r.created_at,
    updated_at: r.updated_at,
    /** Preloaded but not bought: ready to unlock, content withheld. */
    locked: !r.unlocked,
    ...(r.payment && { payment: r.payment }),
  };
  if (r.status === "pending") return r.progress ? { ...base, progress: r.progress } : base;
  if (r.status === "failed") return { ...base, message: "generation failed; please retry" };
  if (r.status !== "passed" || !r.remedy?.content) {
    return { ...base, message: "this plan is held for review and is not available yet" };
  }
  return r.unlocked ? { ...base, content: r.remedy.content } : base;
}

/** What the user may see of a 一生运势报告. */
export function publicLifeReport(r: LifeReportRecord) {
  const base = {
    life_report_id: r.id,
    chart_id: r.chart_id,
    status: r.status,
    locale: r.locale,
    created_at: r.created_at,
    updated_at: r.updated_at,
  };
  if (r.status === "pending") return r.progress ? { ...base, progress: r.progress } : base;
  if (r.status === "failed") return { ...base, message: "generation failed; please retry" };
  if (r.status !== "passed" || !r.life?.layers) {
    return { ...base, message: "this report is held for review and is not available yet" };
  }
  return {
    ...base,
    facts: r.life.facts,
    layers: r.life.layers,
    ai_disclosure: r.life.ai_disclosure,
  };
}

/**
 * Why a report or plan was held, for the server log: status reasons, rule ids and
 * guard categories only. Never quotes (they can contain the user's own words).
 */
export function heldWhy(r: {
  reasons: string[];
  compliance: {
    rule_violations: { rule_id: string }[];
    review?: { violations: { category: string }[] };
  };
}): string {
  const rules = [...new Set(r.compliance.rule_violations.map((v) => v.rule_id))];
  const guard = [...new Set((r.compliance.review?.violations ?? []).map((v) => v.category))];
  return [
    r.reasons.join("; "),
    rules.length && `rules ${rules.join(",")}`,
    guard.length && `guard ${guard.join(",")}`,
  ]
    .filter(Boolean)
    .join(" | ");
}

export type HeldKind = "report" | "remedy" | "life_report";

/** What a reviewer sees in the list: why it was held, never the user's identity. */
export function reviewSummary(
  kind: HeldKind,
  r: {
    id: string;
    owner: string;
    status: string;
    created_at: string;
    updated_at: string;
    review?: ReviewDecision;
  },
  out?: {
    reasons: string[];
    compliance: {
      rule_violations: { rule_id: string; match: string; action: string }[];
      review?: { violations: { category: string; quote: string; reason: string }[] };
    };
  },
  extra: Record<string, unknown> = {},
) {
  return {
    kind,
    id: r.id,
    status: r.status,
    created_at: r.created_at,
    updated_at: r.updated_at,
    owner: r.owner.slice(0, 8),
    ...extra,
    reasons: out?.reasons ?? [],
    rule_hits: (out?.compliance.rule_violations ?? []).map((v) => ({
      rule_id: v.rule_id,
      match: v.match,
      action: v.action,
    })),
    guard: out?.compliance.review?.violations ?? [],
    ...(r.review && { decision: r.review }),
  };
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
  /** The reviewer's login when the caller is a reviewer, else undefined. */
  async function reviewer(c: Caller): Promise<string | undefined> {
    const login = auth ? (await auth.users.get(c.user))?.email : undefined;
    const name = (login ?? c.user).toLowerCase();
    return admins.has(name) ? name : undefined;
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

  const auth = opts.auth;
  if (!opts.devMode && !auth) throw new Error("ApiOptions.auth is required outside devMode");

  async function caller(req: IncomingMessage): Promise<Caller> {
    if (req.headers.authorization || !opts.devMode || opts.devHeaders === false) {
      if (!auth) throw new HttpError(401, "authentication not configured");
      const u = await auth.authenticate(req.headers.authorization);
      return { user: u.id, country: u.country };
    }
    const country = String(req.headers["x-dev-country"] ?? "").toUpperCase();
    if (!/^[A-Z]{2}$/.test(country))
      throw new HttpError(400, "X-Dev-Country header required (ISO 3166-1 alpha-2)");
    return { user: String(req.headers["x-dev-user"] ?? "dev-user"), country };
  }

  /** 起名 (v4.5.0): reads the caller's own 八字 chart; anyone else's is as if it weren't there. */
  async function namingChart(body: Record<string, unknown>, c: Caller) {
    const id = body.bazi_chart_id;
    if (typeof id !== "string" || !UUID_RE.test(id)) {
      throw new InputError("bazi_chart_id must be a UUID");
    }
    const bazi = await store.getChart(id);
    if (!bazi || bazi.owner !== c.user) throw new HttpError(404, "chart not found");
    return computeNamingChart(body, bazi.fact, opts.secrets, now);
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

  async function runJob(
    record: ReportRecord,
    fact: Parameters<typeof generateReport>[0],
    c: Caller,
    question?: string,
    focus?: TarotFocus,
  ) {
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
        },
        {
          providers: opts.providers,
          routing: opts.routing,
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
    if (!(await store.getReport(record.id))) return;
    await store.putReport(next);
    if (next.status === "passed" && next.report && opts.preloadRemedies !== false) {
      await preloadRemedies(next, next.report, fact, c);
    }
  }

  /** Every topic's plan, generated now and kept locked until bought (two at a time). */
  async function preloadRemedies(record: ReportRecord, report: Report, fact: ChartFact, c: Caller) {
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
        await runRemedyJob(r, report, fact, c, record.context);
      }
    };
    await Promise.all([worker(), worker()]);
  }

  async function runRemedyJob(
    record: RemedyRecord,
    report: Report,
    fact: ChartFact,
    c: Caller,
    context?: ReportRecord["context"],
  ) {
    let next: RemedyRecord;
    try {
      const remedy = await generateRemedy(
        fact,
        report,
        record.topic,
        { country: c.country, context },
        {
          providers: opts.providers,
          routing: opts.routing,
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
    if (!current) return;
    // Bought while generating: keep the purchase.
    await store.putRemedy({ ...next, unlocked: current.unlocked, payment: current.payment });
  }

  /** The caller's passed report and its chart, or 404 / 409. */
  async function ownedPassedReport(id: string, c: Caller) {
    const r = UUID_RE.test(id) ? await store.getReport(id) : undefined;
    if (!r || r.owner !== c.user) throw new HttpError(404, "report not found");
    if (r.status !== "passed" || !r.report) throw new HttpError(409, "report is not ready");
    const chart = await store.getChart(r.chart_id);
    if (!chart) throw new HttpError(404, "chart not found");
    return { record: r, report: r.report, fact: chart.fact };
  }

  /** One plan per (report, topic): buying again returns the existing plan, never a second charge. */
  async function createRemedy(req: IncomingMessage, reportId: string, c: Caller) {
    const body = (await readJson(req)) as Record<string, unknown>;
    const { record, report, fact } = await ownedPassedReport(reportId, c);
    if (!remedyAvailable(fact.system)) {
      throw new InputError("破除運勢 plans are available for bazi and tarot readings only");
    }
    const topic = body.topic as Topic;
    if (!record.topics.includes(topic)) {
      throw new InputError(
        `topic must be one of this report's topics: ${record.topics.join(", ")}`,
      );
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
    if (existing) {
      // Preloaded: buying only unlocks it. TODO(Phase 4 payments): verify the receipt.
      const bought = existing.unlocked
        ? existing
        : {
            ...existing,
            unlocked: true,
            payment: { status: "placeholder" as const, ...REMEDY_PRICE },
            updated_at: now().toISOString(),
          };
      if (!existing.unlocked) await store.putRemedy(bought);
      return { status: 200, body: publicRemedy(bought), headers: {} as Record<string, string> };
    }
    takeAiQuota(c.user);

    const ts = now().toISOString();
    const remedy: RemedyRecord = {
      id: randomUUID(),
      owner: c.user,
      report_id: record.id,
      topic,
      status: "pending",
      created_at: ts,
      updated_at: ts,
      // TODO(Phase 4 payments): verify the store receipt here; until then every
      // purchase is a placeholder that succeeds without charging.
      unlocked: true,
      payment: { status: "placeholder", ...REMEDY_PRICE },
    };
    await store.putRemedy(remedy);
    track(`plan ${remedy.id}`, runRemedyJob(remedy, report, fact, c, record.context));
    return {
      status: 202,
      body: publicRemedy(remedy),
      headers: { location: `/v1/remedies/${remedy.id}`, "retry-after": "5" },
    };
  }

  async function runLifeJob(
    record: LifeReportRecord,
    fact: ChartFact,
    c: Caller,
    context?: ReportRecord["context"],
  ) {
    let next: LifeReportRecord;
    try {
      const life = await generateLifeReport(
        fact,
        { locale: record.locale, country: c.country, context },
        {
          providers: opts.providers,
          routing: opts.routing,
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
    if (!(await store.getLifeReport(record.id))) return;
    await store.putLifeReport(next);
  }

  async function createLifeReport(req: IncomingMessage, c: Caller) {
    const body = (await readJson(req)) as Record<string, unknown>;
    const chartId = body.chart_id;
    if (typeof chartId !== "string" || !UUID_RE.test(chartId))
      throw new InputError("chart_id must be a UUID");
    const chart = await store.getChart(chartId);
    if (!chart || chart.owner !== c.user) throw new HttpError(404, "chart not found");
    if (chart.fact.system !== "bazi") throw new InputError("a life report needs a bazi chart");
    const locale = body.locale as Locale;
    if (!LOCALES.includes(locale))
      throw new InputError(`locale must be one of ${LOCALES.join(", ")}`);
    assertServed(c.country, "bazi");
    const context = parseUserContext(body.context);
    takeAiQuota(c.user);
    const ts = now().toISOString();
    const record: LifeReportRecord = {
      id: randomUUID(),
      owner: c.user,
      chart_id: chart.id,
      status: "pending",
      locale,
      created_at: ts,
      updated_at: ts,
    };
    await store.putLifeReport(record);
    track(`life report ${record.id}`, runLifeJob(record, chart.fact, c, context));
    return {
      status: 202,
      body: publicLifeReport(record),
      headers: { location: `/v1/life-reports/${record.id}`, "retry-after": "5" },
    };
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
      ].sort((a, b) => (a.created_at < b.created_at ? 1 : -1));
      return send(res, 200, { items });
    }
    const m = /^\/v1\/admin\/reviews\/(report|remedy|life_report)\/([^/]+)$/.exec(path);
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
    const after = await heldItem(item.kind, item.r.id);
    return send(res, 200, after!.summary);
  }

  async function createReport(req: IncomingMessage, c: Caller) {
    const body = (await readJson(req)) as Record<string, unknown>;
    const chartId = body.chart_id;
    if (typeof chartId !== "string" || !UUID_RE.test(chartId))
      throw new InputError("chart_id must be a UUID");
    const chart = await store.getChart(chartId);
    if (!chart || chart.owner !== c.user) throw new HttpError(404, "chart not found");
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
    takeAiQuota(c.user);
    const question = typeof body.question === "string" ? body.question.slice(0, 300) : undefined;
    const focus = body.focus as TarotFocus | undefined;
    if (focus !== undefined && (chart.fact.system !== "tarot" || !TAROT_FOCUS.includes(focus))) {
      throw new InputError(`focus is for tarot readings: one of ${TAROT_FOCUS.join(", ")}`);
    }
    const context = parseUserContext(body.context);

    const ts = now().toISOString();
    const record: ReportRecord = {
      id: randomUUID(),
      owner: c.user,
      chart_id: chart.id,
      status: "pending",
      locale,
      topics: TOPICS.filter((t) => requested.includes(t)),
      created_at: ts,
      updated_at: ts,
      ...(context && { context }),
    };
    await store.putReport(record);
    track(`report ${record.id}`, runJob(record, chart.fact, c, question, focus));
    return {
      status: 202,
      body: publicReport(record),
      headers: { location: `/v1/reports/${record.id}`, "retry-after": "5" },
    };
  }

  async function handle(req: IncomingMessage, res: ServerResponse) {
    const path = new URL(req.url ?? "/", "http://localhost").pathname;
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
        // ...or the mock's demo answers for the real model.
        ...(opts.aiServing && { ai: opts.aiServing() }),
      });
    }

    // ---- calendar lookup: public, stateless (date pickers show the 農曆 equivalent) ----
    if (req.method === "GET" && path === "/v1/calendar/lunar") {
      const date = new URL(req.url ?? "/", "http://localhost").searchParams.get("date") ?? "";
      const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date);
      const [y, mo, d] = m ? [Number(m[1]), Number(m[2]), Number(m[3])] : [0, 0, 0];
      const valid =
        m && y >= 1900 && y <= 2100 && new Date(Date.UTC(y, mo - 1, d)).getUTCDate() === d;
      if (!valid) throw new InputError("date must be a valid YYYY-MM-DD between 1900 and 2100");
      return send(res, 200, {
        date,
        lunar: lunarDate(y, mo, d),
        shichen: shichenOptions(y, mo, d),
      });
    }
    // 農曆 date pickers: the months of a 農曆 year (incl. 閏月), and 農曆 → 公曆.
    if (req.method === "GET" && path === "/v1/calendar/lunar-months") {
      const year = Number(new URL(req.url ?? "/", "http://localhost").searchParams.get("year"));
      if (!Number.isInteger(year) || year < 1900 || year > 2100) {
        throw new InputError("year must be an integer between 1900 and 2100");
      }
      return send(res, 200, { year, months: lunarMonths(year) });
    }
    if (req.method === "GET" && path === "/v1/calendar/solar") {
      const q = new URL(req.url ?? "/", "http://localhost").searchParams;
      const [year, month, day] = ["year", "month", "day"].map((k) => Number(q.get(k)));
      if (![year, month, day].every(Number.isInteger) || year! < 1900 || year! > 2100) {
        throw new InputError("year, month and day must be integers (year 1900–2100)");
      }
      try {
        const solar = lunarToSolar(year!, month!, day!, q.get("leap") === "true");
        const [sy, sm, sd] = solar.split("-").map(Number) as [number, number, number];
        return send(res, 200, { date: solar, lunar: lunarDate(sy, sm, sd) });
      } catch (e) {
        if (e instanceof CalendarInputError) throw new InputError(e.message);
        throw e;
      }
    }

    // ---- birthplaces: public, static (country → region → city with timezone + longitude) ----
    if (req.method === "GET" && path === "/v1/places") {
      return send(res, 200, placeIndex(), { "cache-control": "public, max-age=86400" });
    }
    const pm = /^\/v1\/places\/([^/]+)$/.exec(path);
    if (req.method === "GET" && pm) {
      const data = placeCountry(pm[1]!.toUpperCase());
      if (!data) throw new HttpError(404, "unknown country code");
      return send(res, 200, data, { "cache-control": "public, max-age=86400" });
    }

    // ---- auth (no caller yet) ----
    if (req.method === "POST" && path.startsWith("/v1/auth/")) {
      if (!auth) throw new HttpError(404, "auth not configured");
      const body = (await readJson(req)) as Record<string, unknown>;
      const ip = clientIp(req);
      switch (path) {
        case "/v1/auth/register":
          return send(res, 201, await auth.register(body as never));
        case "/v1/auth/login":
          return send(res, 200, await auth.login(body, ip));
        case "/v1/auth/oauth":
          return send(res, 200, await auth.socialSignIn(body));
        case "/v1/auth/refresh":
          return send(res, 200, await auth.refresh(body.refresh_token));
        case "/v1/auth/logout":
          auth.logout(body.refresh_token);
          res.writeHead(204);
          return res.end();
      }
      throw new HttpError(404, "not found");
    }

    const c = await caller(req);

    // The methods the caller's region offers, in its entry order (v4.3.0, WP6.2): the home page orders
    // its entries by it, so the matrix can put 求籤 first in Taiwan and Hong Kong without a release.
    if (path === "/v1/methods" && req.method === "GET") {
      assertServed(c.country);
      const matrix = loadGeoMatrix();
      return send(res, 200, {
        region: c.country,
        matrix_version: matrix.matrix_version,
        methods: methodsFor(resolveRegion(matrix, c.country)!),
      });
    }

    // ---- account ----
    if (path === "/v1/me" && req.method === "GET") {
      if (!auth) throw new HttpError(404, "auth not configured");
      return send(res, 200, {
        ...publicUser((await auth.users.get(c.user))!),
        role: opts.review !== false && (await reviewer(c)) ? "admin" : "user",
      });
    }
    if (path === "/v1/account" && req.method === "DELETE") {
      if (!auth) throw new HttpError(404, "auth not configured");
      // PIPEDA / Québec Law 25: delete the account and everything it owns, now.
      const deleted = await store.deleteOwnerData(c.user);
      await auth.deleteAccount(c.user);
      for (const k of idempotency.keys()) if (k.startsWith(`${c.user}:`)) idempotency.delete(k);
      return send(res, 200, {
        deleted: { account: true, ...deleted },
        completed_at: now().toISOString(),
      });
    }

    // ---- 内容审核: reviewers only ----
    if (path === "/v1/admin/reviews" || path.startsWith("/v1/admin/reviews/")) {
      const who = await reviewer(c);
      if (opts.review === false) throw new HttpError(404, "content review is paused");
      if (!who) throw new HttpError(403, "reviewers only");
      return reviews(req, res, path, who);
    }

    // ---- 一生运势报告 ----
    if (path === "/v1/life-reports" && req.method === "POST") {
      const out = await createLifeReport(req, c);
      return send(res, out.status, out.body, out.headers);
    }
    if (path === "/v1/life-reports" && req.method === "GET") {
      const rows = await store.listLifeReports(c.user, 50);
      return send(res, 200, {
        items: rows.map((r) => {
          const {
            facts: _f,
            layers: _l,
            ai_disclosure: _a,
            ...view
          } = publicLifeReport(r) as Record<string, unknown>;
          return view;
        }),
      });
    }
    const lm = /^\/v1\/life-reports\/([^/]+)$/.exec(path);
    if (lm && req.method === "GET") {
      const r = UUID_RE.test(lm[1]!) ? await store.getLifeReport(lm[1]!) : undefined;
      if (!r || r.owner !== c.user) throw new HttpError(404, "life report not found");
      const view = publicLifeReport(r);
      return send(
        res,
        200,
        view,
        aiHeaders("ai_disclosure" in view ? view.ai_disclosure : undefined),
      );
    }

    // ---- 破除運勢 plans (paid per topic; payment is a Phase 4 TODO) ----
    const rm = /^\/v1\/reports\/([^/]+)\/remedies$/.exec(path);
    if (rm && req.method === "GET") {
      const r = UUID_RE.test(rm[1]!) ? await store.getReport(rm[1]!) : undefined;
      if (!r || r.owner !== c.user) throw new HttpError(404, "report not found");
      const items = (await store.listRemedies(r.id)).map(publicRemedy);
      return send(res, 200, { price: REMEDY_PRICE, items });
    }
    if (rm && req.method === "POST") {
      const out = await createRemedy(req, rm[1]!, c);
      return send(res, out.status, out.body, out.headers);
    }
    const one = /^\/v1\/remedies\/([^/]+)$/.exec(path);
    if (one && req.method === "GET") {
      const r = UUID_RE.test(one[1]!) ? await store.getRemedy(one[1]!) : undefined;
      if (!r || r.owner !== c.user) throw new HttpError(404, "remedy not found");
      return send(res, 200, publicRemedy(r));
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
      return;
    }

    if (req.method === "GET") {
      const m = /^\/v1\/reports\/([^/]+)$/.exec(path);
      if (m) {
        const r = UUID_RE.test(m[1]!) ? await store.getReport(m[1]!) : undefined;
        if (!r || r.owner !== c.user) throw new HttpError(404, "report not found");
        const view = publicReport(r);
        return send(
          res,
          200,
          view,
          aiHeaders("ai_disclosure" in view ? view.ai_disclosure : undefined),
        );
      }
      // 每日一牌: the account's card of the day, the same all day (src/service/daily.ts).
      if (path === "/v1/tarot/daily") {
        assertServed(c.country, "tarot");
        const date = dailyDate(
          new URL(req.url ?? "/", "http://localhost").searchParams.get("date"),
          now(),
        );
        const { drawId, chartId } = dailyIds(opts.secrets.drawKey, c.user, date);
        let chart = await store.getChart(chartId);
        if (!chart) {
          chart = {
            id: chartId,
            owner: c.user,
            fact: drawDaily(opts.secrets, drawId, now),
            created_at: now().toISOString(),
            daily: date,
          };
          await store.putChart(chart);
        }
        return send(res, 200, { chart_id: chart.id, chart_fact: chart.fact, date });
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
            return { ...view, chart_id: r.chart_id, chart: chart && chartSummary(chart.fact) };
          }),
        );
        return send(res, 200, { items });
      }
      if (path === "/v1/charts") {
        const rows = await store.listCharts(c.user, limit);
        return send(res, 200, {
          items: rows.map((r) => ({
            chart_id: r.id,
            created_at: r.created_at,
            chart: chartSummary(r.fact),
          })),
        });
      }
      const cm = /^\/v1\/charts\/([^/]+)$/.exec(path);
      if (cm) {
        const ch = UUID_RE.test(cm[1]!) ? await store.getChart(cm[1]!) : undefined;
        if (!ch || ch.owner !== c.user) throw new HttpError(404, "chart not found");
        return send(res, 200, { chart_id: ch.id, chart_fact: ch.fact });
      }
    }

    if (req.method === "POST" && (path === "/v1/charts" || path === "/v1/reports")) {
      const key = req.headers["idempotency-key"];
      const idemKey =
        typeof key === "string" && key ? `${c.user}:${path}:${key.slice(0, 128)}` : undefined;
      const cached = idemKey && idempotency.get(idemKey);
      if (cached) return send(res, cached.status, cached.body, cached.headers);

      let out: { status: number; body: unknown; headers: Record<string, string> };
      if (path === "/v1/charts") {
        const body = (await readJson(req)) as { system?: string };
        assertServed(c.country, body.system);
        const fact =
          body.system === "naming"
            ? await namingChart(body as Record<string, unknown>, c)
            : computeChart(body, opts.secrets, now);
        const id = randomUUID();
        await store.putChart({ id, owner: c.user, fact, created_at: now().toISOString() });
        out = {
          status: 201,
          body: { chart_id: id, chart_fact: fact },
          headers: { location: `/v1/charts/${id}` },
        };
      } else {
        out = await createReport(req, c);
      }
      if (idemKey) idempotency.set(idemKey, out);
      return send(res, out.status, out.body, out.headers);
    }

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
      res.setHeader("access-control-allow-methods", "GET, POST, DELETE, OPTIONS");
      res.setHeader(
        "access-control-expose-headers",
        "location, retry-after, x-ai-generated, x-ai-model",
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
      if (e instanceof HttpError) return problem(res, e.status, e.message);
      if (e instanceof AuthError) {
        const title = e.status === 451 ? "Unavailable for legal reasons" : "Authentication failed";
        return problem(res, e.status, title, e.message, e.code ? { code: e.code } : {});
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
