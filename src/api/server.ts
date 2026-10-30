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
  FOLLOWUP_LIMIT,
  FOLLOWUP_QUESTION_MAX,
  followUpAvailable,
  generateFollowUp,
  generateInquiryTurn,
  generateLifeReport,
  generateRemedy,
  generateReport,
  INQUIRY_ANSWER_MAX,
  INQUIRY_GOAL_MAX,
  INQUIRY_GOAL_MIN,
  INQUIRY_MAX_QUESTIONS,
  inquiryAvailable,
  inquiryGoal,
  loadRouting,
  remedyAvailable,
  parseUserContext,
  GeoRefusedError,
  LOCALES,
  NO_PLAN_TOPICS,
  ReportInputError,
  TAROT_FOCUS,
  TOPICS,
  TOPICS_BY_SYSTEM,
  type AgentTrace,
  type FollowUpParent,
  type FollowUpTurn,
  type InquiryContext,
  type InquiryStep,
  type LLMProvider,
  type Locale,
  type Report,
  type RoutingTable,
  type TarotFocus,
  type Topic,
} from "../ai/index.js";
import { SCHEMA_VERSION, type ChartFact, type ChartSystem } from "../chart-fact/index.js";
import { loadGeoMatrix, loadRuleSet, methodsFor, resolveRegion } from "../compliance/index.js";
import { AccountError, AccountService } from "../auth/account.js";
import { maskEmail } from "../auth/identifiers.js";
import {
  AuthError,
  AuthService,
  permissionsOf,
  publicUser,
  type AccountPermissions,
} from "../auth/service.js";
import { adminRoute } from "../admin/routes.js";
import { staffRoleOf } from "../admin/roles.js";
import { usageRows } from "../admin/usage.js";
import { VerifyError, type ContactKind } from "../auth/verify.js";
import { lifeDocument, localTime, readingDocument } from "../export/report-doc.js";
import {
  Dispatcher,
  NoMail,
  NoSms,
  pdfNote,
  recordsTitle,
  type MailAttachment,
  type MailTransport,
  type SmsTransport,
} from "../notify/index.js";
import {
  CalendarInputError,
  lunarDate,
  lunarMonths,
  lunarToSolar,
  shichenOptions,
} from "../engines/bazi/index.js";
import { newLayout } from "../engines/liuyao/index.js";
import { serveStatic } from "../http/static.js";
import { aiHeaders, HttpError, problem, readJson, send } from "../http/util.js";
import { placeCountry, placeIndex } from "../places/index.js";
import {
  chargeFor,
  inquiryFee,
  loadPointsConfig,
  measuredCost,
  pointsPerUsd,
  quote,
  quoteFor,
  type ChargeKind,
  type PointsCharge,
  type PointsConfig,
  type PointsEntry,
  type PointsFor,
  type PointsHold,
  type Quote,
  type QuoteFor,
} from "../points/index.js";
import {
  asksQuestion,
  changePerson,
  computeChart,
  computeNamingChart,
  InputError,
  parsePerson,
  parseQuestion,
  UUID_RE,
  type EngineSecrets,
} from "../service/charts.js";
import {
  contentDisposition,
  documentName,
  DocumentInputError,
  parseDocument,
  type Doc,
} from "../export/document.js";
import { renderDocx } from "../export/render-docx.js";
import { renderPdf } from "../export/render-pdf.js";
import {
  dailyDate,
  dailyIds,
  dailyZone,
  drawDaily,
  drawEastDaily,
  EAST_DAILY,
  eastDaily,
} from "../service/daily.js";
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
  type FollowUpRecord,
  type InquiryRecord,
  type ReviewDecision,
  type LifeReportRecord,
  type ReportMail,
  type RemedyRecord,
  type ReportRecord,
  type Store,
} from "./store.js";

export const API_VERSION = "0.2.0";

/** 发到邮箱 (v9.0.0): records in one message, and messages a day per account. */
export const MAIL_DOCUMENTS = 10;
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
  if (fact.system === "liuyao") {
    type Hex = { id: string; full_name: { "zh-Hant": string; "zh-Hans": string } };
    const changed = f.changed as Hex | undefined;
    return {
      system: "liuyao",
      mode: f.mode as string,
      primary: (f.primary as Hex).full_name,
      ...(changed && { changed: changed.full_name }),
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
  return {
    ...base,
    layers: rep.layers,
    ai_disclosure: rep.ai_disclosure,
    ...(r.mail && { mail: r.mail }),
    // 深度分析 (v10.0.0): the conversation this reading read, at /v1/inquiries/{id}.
    ...(r.inquiry_id && { inquiry_id: r.inquiry_id }),
  };
}

/**
 * What the user may see of a 深度分析 (v10.0.0): their goal, the master's turns with their answers, how many questions
 * it plans, and once it is done its last words and what it understood they most want to know.
 */
export function publicInquiry(r: InquiryRecord) {
  const done = r.status === "ready" || r.status === "closed";
  return {
    inquiry_id: r.id,
    chart_id: r.chart_id,
    status: r.status,
    created_at: r.created_at,
    updated_at: r.updated_at,
    goal: r.goal,
    max_questions: INQUIRY_MAX_QUESTIONS,
    ...(r.planned !== undefined && { planned: r.planned }),
    turns: r.turns.map((t) => ({
      say: t.say,
      question: t.question,
      ...(t.answer !== undefined && { answer: t.answer }),
    })),
    ...(done && r.closing && { closing: r.closing }),
    ...(done && r.understanding && { understanding: r.understanding }),
    ...(r.report_id && { report_id: r.report_id }),
    ...(r.status === "thinking" && r.progress && { progress: r.progress }),
    ...(r.status === "failed" && {
      message: "the master could not ask its first question; try again, or read without 深度分析",
    }),
    ...(r.ai_disclosure && { ai_disclosure: r.ai_disclosure }),
  };
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

/**
 * What the user sees of a 积分 change (v11.0.0): what it was and what it left. A charge's measured cost in dollars is
 * shown while 充值 is simulated (development), for the owner's 「提交问题给花费了多少」; never once real money pays.
 */
export function publicPointsEntry(e: PointsEntry, showCost: boolean) {
  return {
    id: e.id,
    kind: e.kind,
    points: e.points,
    balance: e.balance,
    created_at: e.created_at,
    ...(e.for && { for: e.for }),
    ...(e.basis && { basis: e.basis }),
    ...(showCost && e.usd !== undefined && { usd: e.usd }),
    ...(e.pack && { pack: e.pack }),
    ...(e.reason && { reason: e.reason }),
    ...(e.note && { note: e.note }),
  };
}

/**
 * 400 question_required (v11.1.0, the owner: 「必须要有所求才能去求」): a 塔罗, 求签 or 算卦 draw, or its reading, with
 * nothing asked.
 */
export const questionRequired = () =>
  new HttpError(
    400,
    "ask your question first: 塔罗, 求签 and 算卦 are drawn for a question",
    "question_required",
  );

/** A 充值 pack as the app offers it: its bonus over 100 积分 a 元, in percent (20元 = 2200: 10). */
export function publicPack(p: { yuan: number; points: number }) {
  return { ...p, bonus_percent: Math.round((p.points / (p.yuan * 100) - 1) * 100) };
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
    ...(r.mail && { mail: r.mail }),
  };
}

/** What the user may see of a 追问 (v7.0.0): the question, where it stands, and the answer once it has passed. */
export function publicFollowUp(r: FollowUpRecord) {
  const base = {
    followup_id: r.id,
    parent: r.parent,
    question: r.question,
    status: r.status,
    created_at: r.created_at,
    updated_at: r.updated_at,
  };
  if (r.status === "pending") return r.progress ? { ...base, progress: r.progress } : base;
  if (r.status === "failed") return { ...base, message: "generation failed; please ask again" };
  if (r.status !== "passed" || !r.followup?.answer) {
    return { ...base, message: "this answer is held for review and is not available yet" };
  }
  return { ...base, answer: r.followup.answer, ai_disclosure: r.followup.ai_disclosure };
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

export type HeldKind = "report" | "remedy" | "life_report" | "followup";

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

  /**
   * The 深度分析's guard (the owner's 统一收费): its fee is paid once, so a turn that would take what its turns spent
   * past what the fee allows at the margin is not asked for; the conversation closes and the reading goes on.
   */
  function inquiryOverBudget(record: InquiryRecord): boolean {
    if (!pointsConfig || record.fee === undefined || record.turns.length === 0) return false;
    const agents = record.agents ?? [];
    const spent = measuredCost(pointsConfig, agents).usd;
    const largest = Math.max(0, ...agents.map((a) => measuredCost(pointsConfig, [a]).usd));
    const { turnUsd } = inquiryFee(pointsConfig, routingNow());
    return spent + Math.max(turnUsd, largest) > record.fee / pointsPerUsd(pointsConfig);
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

  /**
   * 起名 (v4.5.0): reads the caller's own 八字 chart; anyone else's is as if it weren't there. The names are for that
   * chart's person (v8.0.0), so the 起名 record is filed under them too.
   */
  async function namingChart(body: Record<string, unknown>, c: Caller) {
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

  async function runJob(
    record: ReportRecord,
    fact: Parameters<typeof generateReport>[0],
    c: Caller,
    question?: string,
    focus?: TarotFocus,
    inquiry?: InquiryContext,
    hold?: PointsHold,
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
    if (
      next.status === "passed" &&
      next.report &&
      opts.preloadRemedies !== false &&
      !pointsConfig
    ) {
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
    hold?: PointsHold,
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
    track(`plan ${remedy.id}`, runRemedyJob(remedy, report, fact, c, record.context, hold));
    return {
      status: 202,
      body: publicRemedy(remedy),
      headers: { location: `/v1/remedies/${remedy.id}`, "retry-after": "5" },
    };
  }

  /** The caller's passed 一生运势报告 and its chart, or 404 / 409. */
  async function ownedPassedLifeReport(id: string, c: Caller) {
    const r = UUID_RE.test(id) ? await store.getLifeReport(id) : undefined;
    if (!r || r.owner !== c.user) throw new HttpError(404, "life report not found");
    if (r.status !== "passed" || !r.life) throw new HttpError(409, "the report is not ready");
    const chart = await store.getChart(r.chart_id);
    if (!chart) throw new HttpError(404, "chart not found");
    return { record: r, life: r.life, fact: chart.fact };
  }

  /** What a 追问 asks about: the caller's passed reading with what it was asked for and told, or 404 / 409. */
  async function followUpParent(
    kind: FollowUpRecord["parent"]["kind"],
    id: string,
    c: Caller,
  ): Promise<{ parent: FollowUpParent; fact: ChartFact }> {
    if (kind === "life_report") {
      const { record, life, fact } = await ownedPassedLifeReport(id, c);
      return { parent: { kind, life, ...(record.context && { context: record.context }) }, fact };
    }
    const { record, report, fact } = await ownedPassedReport(id, c);
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
    record: FollowUpRecord,
    parent: FollowUpParent,
    fact: ChartFact,
    thread: FollowUpTurn[],
    c: Caller,
    hold?: PointsHold,
  ) {
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
   * alone. One at a time, up to FOLLOWUP_LIMIT per reading; each takes one from the daily AI caps.
   */
  async function createFollowUp(
    req: IncomingMessage,
    kind: FollowUpRecord["parent"]["kind"],
    id: string,
    c: Caller,
  ) {
    const body = (await readJson(req)) as Record<string, unknown>;
    const question = typeof body.question === "string" ? body.question.trim() : "";
    if (!question) throw new InputError("question is required");
    if ([...question].length > FOLLOWUP_QUESTION_MAX) {
      throw new InputError(`question must be at most ${FOLLOWUP_QUESTION_MAX} characters`);
    }
    const { parent, fact } = await followUpParent(kind, id, c);
    if (!followUpAvailable(kind, fact)) {
      throw new InputError(`follow-up questions are not offered for ${fact.system} readings`);
    }
    assertServed(c.country, fact.system);
    const earlier = await store.listFollowUps(id);
    if (earlier.some((f) => f.status === "pending")) {
      throw new HttpError(
        409,
        "the previous follow-up is still being answered",
        "followup_pending",
      );
    }
    if (earlier.filter((f) => f.status !== "failed").length >= FOLLOWUP_LIMIT) {
      throw new HttpError(
        409,
        `this reading has had its ${FOLLOWUP_LIMIT} follow-up questions`,
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
    track(`follow-up ${record.id}`, runFollowUpJob(record, parent, fact, thread, c, hold));
    return {
      status: 202,
      body: publicFollowUp(record),
      headers: { location: `/v1/followups/${record.id}`, "retry-after": "5" },
    };
  }

  /**
   * 深度分析 (v10.0.0, S19): the master's next turn, in the background. A question goes on the record and waits for its
   * answer (asking); when the master asks nothing more it is ready, with its last words. A turn that fails or is held
   * ends the questions there (ready: the reading goes on with what was said), or, on the first turn, fails the 深度分析.
   */
  async function runInquiryTurn(
    record: InquiryRecord,
    fact: ChartFact,
    c: Caller,
    /** The first turn's: the 统一收费, charged once the master has asked. */
    hold?: PointsHold,
  ) {
    let step: InquiryStep | undefined;
    let error: string | undefined;
    if (inquiryOverBudget(record)) {
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
  async function ownedInquiry(id: string, c: Caller) {
    const r = UUID_RE.test(id) ? await store.getInquiry(id) : undefined;
    if (!r || r.owner !== c.user) throw new HttpError(404, "inquiry not found");
    return r;
  }

  /**
   * The account's draw of the day (每日一牌, 今日一卦 / 今日一签; S28): the chart kept under [chartId], else [draw] kept
   * now as that day's chart. Each route keeps its own draw (rule 8).
   */
  async function dailyChart(c: Caller, chartId: string, date: string, draw: () => ChartFact) {
    let chart = await store.getChart(chartId);
    if (!chart) {
      chart = {
        id: chartId,
        owner: c.user,
        fact: draw(),
        created_at: now().toISOString(),
        daily: date,
      };
      await store.putChart(chart);
    }
    return { chart_id: chart.id, chart_fact: chart.fact, date };
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

  /**
   * 深度分析 (v10.0.0): the master's questions on a chart before its reading. It needs a goal (the owner:
   * 「使用这一功能一定要给出个明确的目标才行」): 400 goal_required without one. The first question comes in the background.
   * One from the daily AI caps, as a reading takes.
   */
  async function createInquiry(req: IncomingMessage, c: Caller) {
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
    track(`inquiry ${record.id}`, runInquiryTurn(record, chart.fact, c, hold));
    return {
      status: 202,
      body: publicInquiry(record),
      headers: { location: `/v1/inquiries/${record.id}`, "retry-after": "3" },
    };
  }

  /** The user's answer to the master's question; the master's next turn comes in the background. */
  async function answerInquiry(req: IncomingMessage, id: string, c: Caller) {
    const body = (await readJson(req)) as Record<string, unknown>;
    const answer = typeof body.answer === "string" ? body.answer.trim() : "";
    if (!answer) throw new InputError("answer is required");
    if ([...answer].length > INQUIRY_ANSWER_MAX) {
      throw new InputError(`answer must be at most ${INQUIRY_ANSWER_MAX} characters`);
    }
    const record = await ownedInquiry(id, c);
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
    const turns = record.turns.map((t, i) =>
      i === record.turns.length - 1 ? { ...t, answer } : t,
    );
    const next: InquiryRecord = {
      ...record,
      status: "thinking",
      turns,
      updated_at: now().toISOString(),
    };
    await store.putInquiry(next);
    track(`inquiry ${record.id}`, runInquiryTurn(next, chart.fact, c));
    return {
      status: 202,
      body: publicInquiry(next),
      headers: { location: `/v1/inquiries/${record.id}`, "retry-after": "3" },
    };
  }

  async function runLifeJob(
    record: LifeReportRecord,
    fact: ChartFact,
    c: Caller,
    context?: ReportRecord["context"],
    hold?: PointsHold,
  ) {
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

  async function createLifeReport(req: IncomingMessage, c: Caller) {
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
    track(`life report ${record.id}`, runLifeJob(record, chart.fact, c, context, hold));
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

  async function createReport(req: IncomingMessage, c: Caller) {
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
      inquiry = await ownedInquiry(id, c);
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
      runJob(record, chart.fact, c, question, focus, conversation, hold),
    );
    return {
      status: 202,
      body: publicReport(record),
      headers: { location: `/v1/reports/${record.id}`, "retry-after": "5" },
    };
  }

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

    // 算卦 (v5.3.0): coins laid out face down for a pick cast. The coins stay on the server (they follow
    // from the draw key and the id); the reader gets the id and the commitment, then posts the 18 coins
    // picked, in order, as a liuyao chart.
    if (path === "/v1/liuyao/layouts" && req.method === "POST") {
      assertServed(c.country, "liuyao");
      return send(res, 201, newLayout(opts.secrets.drawKey));
    }

    // ---- account ----
    /** The caller's account as /v1/me shows it. */
    const me = async () => {
      const u = (await auth!.users.get(c.user))!;
      // 后台角色 (S25): the app's ☰ shows 管理后台 to staff; `role` stays what it was, 内容审核's reviewer.
      const staff = staffRoleOf(
        u,
        [u.username, u.email].some((n) => !!n && admins.has(n.toLowerCase())),
      );
      return {
        ...publicUser(u),
        role: opts.review !== false && (await reviewer(c)) ? "admin" : "user",
        ...(staff && { staff }),
      };
    };
    if (path === "/v1/me" && req.method === "GET") {
      if (!auth) throw new HttpError(404, "auth not configured");
      return send(res, 200, await me());
    }
    // The logins and settings (v8.2.0, tech plan WP15.3–15.4): a username; an email or a phone, each proved by a
    // code (POST sends it, POST …/verify brings it back, DELETE removes it); 测算完成后发到邮箱.
    if (path.startsWith("/v1/account/")) {
      if (!auth || !account) throw new HttpError(404, "auth not configured");
      if (path === "/v1/account/username" && req.method === "PUT") {
        const body = (await readJson(req)) as Record<string, unknown>;
        await account.setUsername(c.user, body.username);
        return send(res, 200, await me());
      }
      const contact = /^\/v1\/account\/(email|phone)(\/verify)?$/.exec(path);
      if (contact) {
        const kind = contact[1] as ContactKind;
        if (req.method === "POST" && !contact[2]) {
          const body = (await readJson(req)) as Record<string, unknown>;
          return send(res, 202, await account.startContact(c.user, kind, body[kind]));
        }
        if (req.method === "POST") {
          const body = (await readJson(req)) as Record<string, unknown>;
          await account.confirmContact(c.user, kind, body[kind], body.code);
          return send(res, 200, await me());
        }
        if (req.method === "DELETE" && !contact[2]) {
          await account.removeContact(c.user, kind);
          return send(res, 200, await me());
        }
      }
      if (path === "/v1/account/settings" && req.method === "GET") {
        return send(res, 200, { settings: await account.settings(c.user), delivery: delivery() });
      }
      if (path === "/v1/account/settings" && req.method === "PATCH") {
        const settings = await account.updateSettings(c.user, await readJson(req));
        return send(res, 200, { settings, delivery: delivery() });
      }
      throw new HttpError(404, "not found");
    }
    if (path === "/v1/account" && req.method === "DELETE") {
      if (!auth) throw new HttpError(404, "auth not configured");
      // PIPEDA / Québec Law 25: delete the account and everything it owns, now.
      const deleted = await store.deleteOwnerData(c.user);
      account?.forget(c.user);
      await auth.deleteAccount(c.user);
      for (const k of idempotency.keys()) if (k.startsWith(`${c.user}:`)) idempotency.delete(k);
      return send(res, 200, {
        deleted: { account: true, ...deleted },
        completed_at: now().toISOString(),
      });
    }

    // ---- 积分 (v11.0.0, tech plan S20): the balance, 充值, and what each AI request on a chart costs ----
    if (path === "/v1/points" && req.method === "GET") {
      if (!pointsConfig) return send(res, 200, { enabled: false });
      const { balance, held } = await store.pointsOf(c.user);
      const [entries, holds] = await Promise.all([
        store.listPoints(c.user, 50),
        store.listHolds(c.user),
      ]);
      return send(res, 200, {
        enabled: true,
        balance,
        held,
        available: Math.max(0, balance - held),
        top_up: simulatedTopUp ? "simulated" : "unavailable",
        packs: pointsConfig.packs.map(publicPack),
        entries: entries.map((e) => publicPointsEntry(e, simulatedTopUp)),
        holds: holds.map((h) => ({ points: h.points, for: h.for, created_at: h.created_at })),
      });
    }
    if (path === "/v1/points/top-ups" && req.method === "POST") {
      if (!pointsConfig) throw new HttpError(404, "积分 are off on this server", "points_off");
      await assertAllowed(c, "top_up");
      if (!simulatedTopUp) {
        throw new HttpError(
          501,
          "充值 needs real payments, which come with Phase 4",
          "payments_unavailable",
        );
      }
      const body = (await readJson(req)) as Record<string, unknown>;
      const pack = pointsConfig.packs.find((p) => p.yuan === body.yuan);
      if (!pack) {
        throw new InputError(
          `yuan must be one of the packs: ${pointsConfig.packs.map((p) => p.yuan).join(", ")}`,
        );
      }
      // Simulated (development): the pack's 积分 arrive without payment. TODO(Phase 4): a verified payment.
      const entry = await store.creditPoints(
        c.user,
        pack.points,
        { kind: "topup", pack },
        now().toISOString(),
      );
      const { balance, held } = await store.pointsOf(c.user);
      return send(res, 201, {
        entry: publicPointsEntry(entry!, simulatedTopUp),
        balance,
        held,
        available: Math.max(0, balance - held),
      });
    }
    const qm = /^\/v1\/charts\/([^/]+)\/quote$/.exec(path);
    if (qm && req.method === "GET") {
      if (!pointsConfig) throw new HttpError(404, "积分 are off on this server", "points_off");
      const ch = UUID_RE.test(qm[1]!) ? await store.getChart(qm[1]!) : undefined;
      if (!ch || ch.owner !== c.user) throw new HttpError(404, "chart not found");
      const allowed = TOPICS_BY_SYSTEM[ch.fact.system];
      const asked = new URL(req.url ?? "/", "http://localhost").searchParams.get("topics");
      const topics = asked
        ? asked.split(",").filter((t) => allowed.includes(t as Topic)).length
        : allowed.length;
      return send(res, 200, {
        report: priceOf("report", quoteFor(ch.fact, topics)),
        ...(inquiryAvailable(ch.fact) && {
          inquiry: { ...priceOf("inquiry"), max_questions: INQUIRY_MAX_QUESTIONS },
        }),
        ...(ch.fact.system === "bazi" && { life_report: priceOf("life_report") }),
      });
    }

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

    // ---- 一生运势报告 ----
    if (path === "/v1/life-reports" && req.method === "POST") {
      const out = await createLifeReport(req, c);
      return send(res, out.status, out.body, out.headers);
    }
    if (path === "/v1/life-reports" && req.method === "GET") {
      const rows = await store.listLifeReports(c.user, 50);
      return send(res, 200, {
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
    }
    const lm = /^\/v1\/life-reports\/([^/]+)$/.exec(path);
    if (lm && req.method === "GET") {
      const r = UUID_RE.test(lm[1]!) ? await store.getLifeReport(lm[1]!) : undefined;
      if (!r || r.owner !== c.user) throw new HttpError(404, "life report not found");
      const view = publicLifeReport(r);
      const person = (await store.getChart(r.chart_id))?.person;
      return send(
        res,
        200,
        { ...view, ...(person && { person }) },
        aiHeaders("ai_disclosure" in view ? view.ai_disclosure : undefined),
      );
    }

    // ---- 以往记录 (v8.0.0, S14): delete one record; file a chart under a person; a record as Word or PDF ----
    const dr = /^\/v1\/(reports|life-reports)\/([^/]+)$/.exec(path);
    if (dr && req.method === "DELETE") {
      const id = dr[2]!;
      const reading = dr[1] === "reports";
      const r = !UUID_RE.test(id)
        ? undefined
        : reading
          ? await store.getReport(id)
          : await store.getLifeReport(id);
      if (!r || r.owner !== c.user) throw new HttpError(404, "record not found");
      // The record with what hangs off it; its chart too when nothing else reads it. A job still running for it
      // finds the record gone and writes nothing back.
      const removed = reading ? await store.deleteReport(id) : await store.deleteLifeReport(id);
      const charts = (await store.deleteChartIfUnused(r.chart_id)) ? 1 : 0;
      return send(res, 200, { deleted: { ...removed, charts }, completed_at: now().toISOString() });
    }
    const pm2 = /^\/v1\/charts\/([^/]+)\/person$/.exec(path);
    if (pm2 && req.method === "POST") {
      const ch = UUID_RE.test(pm2[1]!) ? await store.getChart(pm2[1]!) : undefined;
      if (!ch || ch.owner !== c.user) throw new HttpError(404, "chart not found");
      const person = changePerson(ch.person, await readJson(req), ch.fact.system);
      const { person: _old, ...rest } = ch;
      await store.putChart(person ? { ...rest, person } : rest);
      return send(res, 200, { chart_id: ch.id, ...(person && { person }) });
    }
    if (path === "/v1/documents" && req.method === "POST") {
      // A long 一生运势报告 with its 追问 runs to tens of kilobytes of text.
      const body = (await readJson(req, 1024 * 1024)) as Record<string, unknown>;
      const format = body.format === "pdf" || body.format === "docx" ? body.format : undefined;
      if (!format) throw new InputError("format must be pdf or docx");
      let doc: Doc;
      try {
        doc = parseDocument(body.document);
      } catch (e) {
        if (e instanceof DocumentInputError) throw new InputError(e.message);
        throw e;
      }
      const locale = LOCALES.includes(body.locale as Locale) ? (body.locale as Locale) : "zh-Hans";
      let bytes: Buffer;
      if (format === "pdf") {
        const font = shareFont(locale);
        if (!font) {
          throw new HttpError(
            503,
            "PDF documents need a CJK font on the server: install fonts-noto-cjk or set MINGLI_SHARE_FONT",
          );
        }
        bytes = await renderPdf(doc, font);
      } else {
        bytes = await renderDocx(doc, locale);
      }
      res.writeHead(200, {
        "content-type":
          format === "pdf"
            ? "application/pdf"
            : "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "content-length": String(bytes.length),
        "content-disposition": contentDisposition(documentName(body.filename, format)),
        "cache-control": "no-store",
      });
      res.end(bytes);
      return;
    }

    // 发到邮箱 (v9.0.0, tech plan WP15.4): the chosen records, as the app builds them for 下载, rendered to Word or PDF
    // and mailed in one message to the account's verified email. Nothing is kept.
    if (path === "/v1/documents/email" && req.method === "POST") {
      if (!auth) throw new HttpError(404, "auth not configured");
      const body = (await readJson(req, 4 * 1024 * 1024)) as Record<string, unknown>;
      const format = body.format === "pdf" || body.format === "docx" ? body.format : undefined;
      if (!format) throw new InputError("format must be pdf or docx");
      const list = body.documents;
      if (!Array.isArray(list) || list.length < 1 || list.length > MAIL_DOCUMENTS) {
        throw new InputError(`documents must hold 1 to ${MAIL_DOCUMENTS} documents`);
      }
      const owner = (await auth.users.get(c.user))!;
      if (!owner.email || !owner.email_verified_at) {
        throw new HttpError(
          409,
          "verify an email first: documents go only to a verified email",
          "email_unverified",
        );
      }
      if (mail.name === "off") {
        throw new HttpError(503, "mail is not set up on this server yet", "delivery_unavailable");
      }
      const locale = LOCALES.includes(body.locale as Locale) ? (body.locale as Locale) : "zh-Hans";
      const font = format === "pdf" ? shareFont(locale) : undefined;
      if (format === "pdf" && !font) {
        throw new HttpError(
          503,
          "PDF documents need a CJK font on the server: install fonts-noto-cjk or set MINGLI_SHARE_FONT",
        );
      }
      const docs = list.map((item, i) => {
        const { document, filename } = (item ?? {}) as Record<string, unknown>;
        try {
          return { doc: parseDocument(document), filename };
        } catch (e) {
          if (e instanceof DocumentInputError)
            throw new InputError(`documents[${i}]: ${e.message}`);
          throw e;
        }
      });
      takeMailQuota(c.user);
      const files: MailAttachment[] = [];
      for (const { doc, filename } of docs) {
        files.push({
          filename: documentName(filename, format),
          contentType:
            format === "pdf"
              ? "application/pdf"
              : "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
          content: format === "pdf" ? await renderPdf(doc, font!) : await renderDocx(doc, locale),
        });
      }
      try {
        const titles = docs.map((d) => d.doc.title);
        await messages.send("records_mail", {
          to: owner.email,
          locale,
          vars: { title: recordsTitle(titles, locale), count: String(titles.length) },
          parts: { records: titles },
          attachments: files,
        });
      } catch (e) {
        log(
          `mailing documents failed: ${(e as Error).message?.replace(/[^\s@]+@[^\s@]+/g, "<address>")}`,
        );
        throw new HttpError(502, "the mail could not be sent; try again later", "delivery_failed");
      }
      return send(res, 202, {
        sent_to: maskEmail(owner.email),
        count: files.length,
        delivery: mail.name,
      });
    }

    // ---- 深度分析 (v10.0.0, S19): the master's questions before a reading ----
    if (path === "/v1/inquiries" && req.method === "POST") {
      const out = await createInquiry(req, c);
      return send(res, out.status, out.body, out.headers);
    }
    const iq = /^\/v1\/inquiries\/([^/]+)(\/answers)?$/.exec(path);
    if (iq && !iq[2] && req.method === "GET") {
      const r = await ownedInquiry(iq[1]!, c);
      return send(res, 200, publicInquiry(r), aiHeaders(r.ai_disclosure));
    }
    if (iq && iq[2] && req.method === "POST") {
      const out = await answerInquiry(req, iq[1]!, c);
      return send(res, out.status, out.body, out.headers);
    }

    // ---- 追问 (v7.0.0, S13): follow-up questions on a passed reading or 一生运势报告 ----
    const fq = /^\/v1\/(reports|life-reports)\/([^/]+)\/followups$/.exec(path);
    if (fq && req.method === "POST") {
      const kind = fq[1] === "reports" ? "report" : "life_report";
      const out = await createFollowUp(req, kind, fq[2]!, c);
      return send(res, out.status, out.body, out.headers);
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
      return send(res, 200, { limit: FOLLOWUP_LIMIT, items, ...(price && { price }) });
    }
    const fo = /^\/v1\/followups\/([^/]+)$/.exec(path);
    if (fo && req.method === "GET") {
      const r = UUID_RE.test(fo[1]!) ? await store.getFollowUp(fo[1]!) : undefined;
      if (!r || r.owner !== c.user) throw new HttpError(404, "follow-up not found");
      const view = publicFollowUp(r);
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
      // 积分 (v11.0.0): what a plan costs, in 积分; `price` stays for a server without them.
      const chart = pointsConfig && (await store.getChart(r.chart_id));
      const points = chart && priceOf("remedy", quoteFor(chart.fact));
      return send(res, 200, { price: REMEDY_PRICE, items, ...(points && { points }) });
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
        return send(
          res,
          200,
          await dailyChart(c, chartId, date, () => drawDaily(opts.secrets, drawId, now)),
        );
      }
      // 今日一卦 / 今日一签 (S26): the account's 东方 draw of the day, a 签 or a 卦 at random, the same all day
      // (src/service/daily.ts). Only the 东方 methods served in the region take part; none, and it isn't served.
      if (path === "/v1/east/daily") {
        assertServed(c.country);
        const served = methodsFor(resolveRegion(loadGeoMatrix(), c.country)!).map((m) => m.system);
        const systems = EAST_DAILY.filter((s) => served.includes(s));
        if (systems.length === 0) {
          throw new GeoRefusedError(`neither 求签 nor 算卦 is available in ${c.country}`);
        }
        const query = new URL(req.url ?? "/", "http://localhost").searchParams;
        const date = dailyDate(query.get("date"), now());
        const timezone = dailyZone(query.get("timezone"));
        const { system, drawId, chartId } = eastDaily(opts.secrets.drawKey, c.user, date, systems);
        return send(
          res,
          200,
          await dailyChart(c, chartId, date, () =>
            drawEastDaily(system, opts.secrets, drawId, timezone, now),
          ),
        );
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
        return send(res, 200, { items });
      }
      if (path === "/v1/charts") {
        const rows = await store.listCharts(c.user, limit);
        return send(res, 200, {
          items: rows.map((r) => ({
            chart_id: r.id,
            created_at: r.created_at,
            chart: chartSummary(r.fact),
            ...(r.person && { person: r.person }),
          })),
        });
      }
      const cm = /^\/v1\/charts\/([^/]+)$/.exec(path);
      if (cm) {
        const ch = UUID_RE.test(cm[1]!) ? await store.getChart(cm[1]!) : undefined;
        if (!ch || ch.owner !== c.user) throw new HttpError(404, "chart not found");
        return send(res, 200, {
          chart_id: ch.id,
          chart_fact: ch.fact,
          ...(ch.person && { person: ch.person }),
          ...(ch.question && { question: ch.question }),
        });
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
            ? await namingChart(body as Record<string, unknown>, c)
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
