/**
 * Demo handlers shared by the CLI (scripts/demo.ts) and the local web UI
 * (src/demo/server.ts). Thin wrappers over the chart service and the AI pipeline;
 * they only add display helpers (schema verdicts, card names, guard previews).
 */
import {
  generateReport,
  GeoRefusedError,
  loadRouting,
  ReportInputError,
  TOPICS_BY_SYSTEM,
  type Locale,
  type Topic,
} from "../ai/index.js";
import { validateChartFact, type ChartFact } from "../chart-fact/index.js";
import {
  compileRules,
  loadGeoMatrix,
  loadRuleSet,
  resolveRegion,
  scan,
} from "../compliance/index.js";
import { DECK } from "../engines/tarot/deck.js";
import { verifyDraw } from "../engines/tarot/index.js";
import { computeChart, InputError, str } from "../service/charts.js";
import { buildProviders, loadSecrets, upstreamMessage } from "../service/runtime.js";

/** Demo input errors are the service's input errors. */
export { InputError as DemoInputError };
export class DemoUpstreamError extends Error {}

const secrets = loadSecrets();
let providers: ReturnType<typeof buildProviders> | undefined;
const aiProviders = () => (providers ??= buildProviders());

function withSchema(fact: ChartFact) {
  const v = validateChartFact(fact);
  return { fact, schema: v.ok ? { ok: true as const } : { ok: false as const, errors: v.errors } };
}

export interface BaziRequest {
  local: string;
  timezone: string;
  longitude: number;
  gender: "male" | "female";
  trueSolarTime?: boolean;
  ziHourSect?: 1 | 2;
}

export function runBazi(req: BaziRequest) {
  return withSchema(
    computeChart(
      {
        system: "bazi",
        local: req.local,
        timezone: req.timezone,
        longitude: req.longitude,
        gender: req.gender,
        options: { trueSolarTime: req.trueSolarTime ?? true, ziHourSect: req.ziHourSect },
      },
      secrets,
    ),
  );
}

/** With `draw_id`, re-derives that earlier draw from the server draw key (ADR-0003). */
export function runTarot(req: { spread?: string; draw_id?: string }) {
  const fact = computeChart({ system: "tarot", ...req }, secrets);
  const cards = (
    fact.facts as { cards: { position_key: string; card_id: string; reversed: boolean }[] }
  ).cards.map((c) => ({ ...c, card: DECK.find((d) => d.id === c.card_id)! }));
  return { ...withSchema(fact), cards, audit_verified: verifyDraw(fact, secrets.drawKey) };
}

export interface AstroRequest {
  local: string;
  timezone: string;
  latitude: number;
  longitude: number;
}

export function runAstro(req: AstroRequest) {
  return withSchema(computeChart({ system: "astrology", ...req }, secrets));
}

export function runGuard(req: { country: string; text: string }) {
  const country = str(req.country, "country").toUpperCase();
  const text = typeof req.text === "string" ? req.text : "";
  const region = resolveRegion(loadGeoMatrix(), country);
  if (!region || !region.service_available) {
    return { country, refused: true as const, status: 451 };
  }
  const violations = scan(text, compileRules(loadRuleSet(), region.rule_groups));
  return { country, refused: false as const, region, violations, pass: violations.length === 0 };
}

/** Country codes the Geo-Rule matrix knows, for UI pickers. */
export function listRegions() {
  const m = loadGeoMatrix();
  return {
    regions: Object.entries(m.regions).map(([code, r]) => ({ code, name: r.name })),
    groups: m.region_groups,
  };
}

// ---------- AI report (Phase 1) ----------

export function aiStatus() {
  const routing = loadRouting();
  return {
    provider: aiProviders().serving(),
    routes: Object.fromEntries(
      Object.entries(routing.routes).map(([agent, r]) => [
        agent,
        `${r.default.model} (effort ${r.default.effort})`,
      ]),
    ),
    topics_by_system: TOPICS_BY_SYSTEM,
  };
}

export interface ReportRequest {
  system: "bazi" | "tarot" | "astrology";
  input: Record<string, unknown>;
  locale: Locale;
  country: string;
  topics?: Topic[];
  question?: string;
}

export async function runReport(req: ReportRequest) {
  const chart =
    req.system === "bazi"
      ? runBazi(req.input as unknown as BaziRequest).fact
      : req.system === "tarot"
        ? runTarot(req.input as { spread?: string; draw_id?: string }).fact
        : req.system === "astrology"
          ? runAstro(req.input as unknown as AstroRequest).fact
          : undefined;
  if (!chart) throw new InputError("system must be bazi | tarot | astrology");
  try {
    const report = await generateReport(
      chart,
      {
        locale: req.locale,
        country: str(req.country, "country"),
        topics: req.topics,
        question: typeof req.question === "string" ? req.question.slice(0, 300) : undefined,
        includeDraft: true, // demo is an internal tool
      },
      { providers: aiProviders().map },
    );
    return { report, chart, provider: aiProviders().serving() };
  } catch (e) {
    if (e instanceof GeoRefusedError) {
      return { refused: true as const, status: 451, error: e.message };
    }
    if (e instanceof ReportInputError) throw new InputError(e.message);
    const upstream = upstreamMessage(e);
    if (upstream) throw new DemoUpstreamError(upstream);
    throw e;
  }
}
