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
import { SCHEMA_VERSION } from "../chart-fact/index.js";
import { loadGeoMatrix, loadRuleSet, resolveRegion } from "../compliance/index.js";
import { AuthError, AuthService, publicUser } from "../auth/service.js";
import { aiHeaders, HttpError, problem, readJson, send } from "../http/util.js";
import { computeChart, InputError, UUID_RE, type EngineSecrets } from "../service/charts.js";
import { upstreamMessage } from "../service/runtime.js";
import { InMemoryStore, type ReportRecord, type Store } from "./store.js";

export const API_VERSION = "0.2.0";

export interface ApiOptions {
  secrets: EngineSecrets;
  providers: Record<string, LLMProvider>;
  store?: Store;
  /** Required outside devMode. */
  auth?: AuthService;
  routing?: RoutingTable;
  devMode?: boolean;
  now?: () => Date;
  log?: (msg: string, err?: unknown) => void;
}

interface Caller {
  user: string;
  country: string;
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
  if (r.status === "pending") return base;
  if (r.status === "failed") return { ...base, message: "generation failed; please retry" };
  const rep = r.report!;
  if (r.status !== "passed") {
    return { ...base, message: "this report is held for review and is not available yet" };
  }
  return { ...base, layers: rep.layers, ai_disclosure: rep.ai_disclosure };
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
        { providers: opts.providers, routing: opts.routing, now },
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
    // Dev only: let Flutter web/desktop builds served from localhost call the API.
    const origin = req.headers.origin;
    if (opts.devMode && origin && /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) {
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
