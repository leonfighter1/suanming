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
  generateRemedy,
  generateReport,
  GeoRefusedError,
  LOCALES,
  ReportInputError,
  TOPICS,
  TOPICS_BY_SYSTEM,
  type LLMProvider,
  type Locale,
  type Report,
  type RoutingTable,
  type Topic,
} from "../ai/index.js";
import { SCHEMA_VERSION, type ChartFact } from "../chart-fact/index.js";
import { loadGeoMatrix, loadRuleSet, resolveRegion } from "../compliance/index.js";
import { AuthError, AuthService, publicUser } from "../auth/service.js";
import {
  CalendarInputError,
  lunarDate,
  lunarMonths,
  lunarToSolar,
  shichenOptions,
} from "../engines/bazi/index.js";
import { aiHeaders, HttpError, problem, readJson, send } from "../http/util.js";
import { placeCountry, placeIndex } from "../places/index.js";
import { computeChart, InputError, UUID_RE, type EngineSecrets } from "../service/charts.js";
import { upstreamMessage } from "../service/runtime.js";
import { InMemoryStore, type RemedyRecord, type ReportRecord, type Store } from "./store.js";

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
  return { system: fact.system };
}

/** What the user may see of a report. Drafts, traces and rule details stay internal. */
export function publicReport(r: ReportRecord) {
  const base = {
    report_id: r.id,
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
    payment: r.payment,
  };
  if (r.status === "pending") return r.progress ? { ...base, progress: r.progress } : base;
  if (r.status === "failed") return { ...base, message: "generation failed; please retry" };
  if (r.status !== "passed" || !r.remedy?.content) {
    return { ...base, message: "this plan is held for review and is not available yet" };
  }
  return { ...base, content: r.remedy.content };
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
  const matrix = loadGeoMatrix();

  const auth = opts.auth;
  if (!opts.devMode && !auth) throw new Error("ApiOptions.auth is required outside devMode");

  async function caller(req: IncomingMessage): Promise<Caller> {
    if (req.headers.authorization || !opts.devMode) {
      if (!auth) throw new HttpError(401, "authentication not configured");
      const u = await auth.authenticate(req.headers.authorization);
      return { user: u.id, country: u.country };
    }
    const country = String(req.headers["x-dev-country"] ?? "").toUpperCase();
    if (!/^[A-Z]{2}$/.test(country))
      throw new HttpError(400, "X-Dev-Country header required (ISO 3166-1 alpha-2)");
    return { user: String(req.headers["x-dev-user"] ?? "dev-user"), country };
  }

  /** Geo-Rule: refuse before computing anything for unserved regions. */
  function assertServed(country: string, system?: string) {
    const region = resolveRegion(matrix, country);
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
  ) {
    let next: ReportRecord;
    try {
      const report: Report = await generateReport(
        fact,
        { locale: record.locale, country: c.country, topics: record.topics, question },
        {
          providers: opts.providers,
          routing: opts.routing,
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
  }

  async function runRemedyJob(record: RemedyRecord, report: Report, fact: ChartFact, c: Caller) {
    let next: RemedyRecord;
    try {
      const remedy = await generateRemedy(
        fact,
        report,
        record.topic,
        { country: c.country },
        {
          providers: opts.providers,
          routing: opts.routing,
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
    if (!(await store.getRemedy(record.id))) return;
    await store.putRemedy(next);
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
    const topic = body.topic as Topic;
    if (!record.topics.includes(topic)) {
      throw new InputError(
        `topic must be one of this report's topics: ${record.topics.join(", ")}`,
      );
    }
    assertServed(c.country, fact.system);
    const existing = (await store.listRemedies(record.id)).find(
      (x) => x.topic === topic && x.status !== "failed",
    );
    if (existing) {
      return { status: 200, body: publicRemedy(existing), headers: {} as Record<string, string> };
    }

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
      payment: { status: "placeholder", ...REMEDY_PRICE },
    };
    await store.putRemedy(remedy);
    const job = runRemedyJob(remedy, report, fact, c).finally(() => jobs.delete(job));
    jobs.add(job);
    return {
      status: 202,
      body: publicRemedy(remedy),
      headers: { location: `/v1/remedies/${remedy.id}`, "retry-after": "5" },
    };
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
    const question = typeof body.question === "string" ? body.question.slice(0, 300) : undefined;

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
    };
    await store.putReport(record);
    const job = runJob(record, chart.fact, c, question).finally(() => jobs.delete(job));
    jobs.add(job);
    return {
      status: 202,
      body: publicReport(record),
      headers: { location: `/v1/reports/${record.id}`, "retry-after": "5" },
    };
  }

  async function handle(req: IncomingMessage, res: ServerResponse) {
    const path = new URL(req.url ?? "/", "http://localhost").pathname;
    if (req.method === "GET" && path === "/v1/health") {
      return send(res, 200, {
        status: "ok",
        versions: {
          api: API_VERSION,
          chart_fact_schema: SCHEMA_VERSION,
          geo_rule_matrix: matrix.matrix_version,
          prohibited_patterns: loadRuleSet().version,
          tzdb: process.versions.tz ?? "unknown",
        },
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
      const ip = req.socket.remoteAddress ?? "unknown";
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

    // ---- account ----
    if (path === "/v1/me" && req.method === "GET") {
      if (!auth) throw new HttpError(404, "auth not configured");
      return send(res, 200, publicUser((await auth.users.get(c.user))!));
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
        const fact = computeChart(body, opts.secrets, now);
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
