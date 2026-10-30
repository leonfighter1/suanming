/**
 * Process-level runtime wiring shared by the v1 API and the demo: engine secrets
 * and LLM providers, both from the environment.
 */
import { randomBytes } from "node:crypto";
import { readFileSync, statSync } from "node:fs";
import { parseEnv } from "node:util";
import Anthropic from "@anthropic-ai/sdk";
import {
  AnthropicProvider,
  DeepSeekProvider,
  loadRouting,
  MockProvider,
  modelInfo,
  MODELS,
  ProviderHttpError,
  withModel,
  type LLMJsonRequest,
  type LLMJsonResult,
  type LLMProvider,
  type ModelInfo,
  type RoutingTable,
} from "../ai/index.js";
import type { Store } from "../api/store.js";
import { loginKind } from "../auth/identifiers.js";
import { noCaptcha, TurnstileVerifier } from "../auth/limits.js";
import type { PointsLedger } from "../points/index.js";
import { AuthService, type AccountRole, type UserStore } from "../auth/service.js";
import { parseKek } from "../db/envelope.js";
import { PgStore } from "../db/pg-store.js";
import { SocialVerifier } from "../auth/social.js";
import { TokenService } from "../auth/tokens.js";
import type { EngineSecrets } from "./charts.js";

function hexSecret(name: string): Buffer | undefined {
  const v = process.env[name];
  if (!v) return undefined;
  const b = Buffer.from(v, "hex");
  if (b.length < 32) throw new Error(`${name} must be at least 32 bytes of hex`);
  return b;
}

/**
 * MINGLI_DIGEST_PEPPER / MINGLI_TAROT_DRAW_KEY (hex, >= 32 bytes). Missing values
 * get a random per-process key: fine for dev, but digests and tarot replays then
 * don't survive a restart, so production must set both.
 */
export function loadSecrets(): EngineSecrets & { ephemeral: boolean } {
  const pepper = hexSecret("MINGLI_DIGEST_PEPPER");
  const draw = hexSecret("MINGLI_TAROT_DRAW_KEY");
  return {
    digestPepper: pepper ?? randomBytes(32),
    drawKey: draw ?? randomBytes(32),
    ephemeral: !pepper || !draw,
  };
}

/** A TRUE/FALSE switch from .env (also 1/0, yes/no, on/off); undefined if unset or unclear. */
export function envFlag(v: string | undefined): boolean | undefined {
  const s = v?.trim().toLowerCase();
  if (s === "true" || s === "1" || s === "yes" || s === "on") return true;
  if (s === "false" || s === "0" || s === "no" || s === "off") return false;
  return undefined;
}

export interface AiMode {
  /** Every AI step answers with the mock: the（示范）demo text, no tokens spent. */
  mock: boolean;
  /** The setting that chose the mock. */
  reason?: string;
}

/**
 * The owner's AI switch. The real models run only when nothing asks for the mock;
 * each of these does: MINGLI_AI_PROVIDER=mock (the test suite), and in .env
 * IS_AI_MOCK=TRUE or IS_AI_MODEL=FALSE (to save tokens).
 */
export function aiMode(env: Record<string, string | undefined>): AiMode {
  if (env.MINGLI_AI_PROVIDER === "mock") return { mock: true, reason: "MINGLI_AI_PROVIDER=mock" };
  if (envFlag(env.IS_AI_MOCK) === true) return { mock: true, reason: "IS_AI_MOCK=TRUE" };
  if (envFlag(env.IS_AI_MODEL) === false) return { mock: true, reason: "IS_AI_MODEL=FALSE" };
  return { mock: false };
}

export interface ModelChoice {
  /** The model ACTIVE_AI_MODEL picks for every AI step; absent: config/model_routing.json as it is. */
  model?: ModelInfo;
  /** ACTIVE_AI_MODEL names no usable model: the table answers, and the console says why. */
  error?: string;
}

/**
 * The owner's model choice (S17): ACTIVE_AI_MODEL=<id> in .env (the owner's name for it), one of MODELS
 * (npm run ai:models lists them).
 */
export function modelChoice(env: Record<string, string | undefined>): ModelChoice {
  const id = env.ACTIVE_AI_MODEL?.trim();
  if (!id) return {};
  const model = modelInfo(id);
  if (model) return { model };
  const usable = MODELS.map((m) => m.id).join(", ");
  return {
    error: `ACTIVE_AI_MODEL=${id} is not a usable model, so config/model_routing.json answers (usable: ${usable})`,
  };
}

interface AiSettings {
  mode: AiMode;
  choice: ModelChoice;
}

const sameSettings = (a: AiSettings, b: AiSettings) =>
  a.mode.mock === b.mode.mock &&
  a.mode.reason === b.mode.reason &&
  a.choice.model?.id === b.choice.model?.id &&
  a.choice.error === b.choice.error;

/**
 * The AI settings in an .env file, kept current: the switch (aiMode) and the model choice (modelChoice), re-read
 * whenever the file changes. Flip IS_AI_MOCK or change ACTIVE_AI_MODEL and the next AI call follows, with no restart
 * (so a tunnel's URL survives). `shell` is the environment from before .env was loaded; like process.loadEnvFile, it
 * wins over the file. onChange hears every change, once per change of the file.
 */
export function watchAi(
  file: string,
  shell: Record<string, string | undefined>,
  onChange?: () => void,
): { mode: () => AiMode; choice: () => ModelChoice } {
  let stamp: number | undefined;
  let now: AiSettings | undefined;
  const current = (): AiSettings => {
    let mtime = -1;
    try {
      mtime = statSync(file).mtimeMs;
    } catch {
      // no .env: the shell alone
    }
    if (mtime !== stamp || !now) {
      stamp = mtime;
      let fromFile: Record<string, string | undefined> = {};
      try {
        fromFile = parseEnv(readFileSync(file, "utf8"));
      } catch {
        // missing or unreadable: the shell alone
      }
      const env = { ...fromFile, ...shell };
      const prev = now;
      now = { mode: aiMode(env), choice: modelChoice(env) };
      // After storing them: a listener that reads the settings back sees the new ones.
      if (prev && !sameSettings(prev, now)) onChange?.();
    }
    return now;
  };
  return { mode: () => current().mode, choice: () => current().choice };
}

/** A real provider that hands each call to the mock while the AI switch says so. */
export class SwitchedProvider implements LLMProvider {
  constructor(
    private readonly real: LLMProvider,
    private readonly mock: LLMProvider,
    private readonly useMock: () => boolean,
  ) {}

  get name() {
    return this.useMock() ? this.mock.name : this.real.name;
  }

  generateJson(req: LLMJsonRequest): Promise<LLMJsonResult> {
    return (this.useMock() ? this.mock : this.real).generateJson(req);
  }
}

const defaultRoutes = (routing: RoutingTable) =>
  Object.values(routing.routes).map((r) => r.default);

export interface Providers {
  /** Providers with credentials (the ones the switch can turn on). */
  live: string[];
  map: Record<string, LLMProvider>;
  mode: () => AiMode;
  choice: () => ModelChoice;
  /** The routing for the next AI job: config/model_routing.json, every route on the chosen model if there is one. */
  routing: () => RoutingTable;
  /** What answers AI calls right now: the routed provider name(s), or "mock". */
  serving: () => string;
  /** The model(s) the routes name: they answer once serving() is not "mock". */
  models: () => string;
}

/**
 * Providers keyed by the names config/model_routing.json uses. Each is real when
 * its credentials are present and the AI switch (`mode`, default: aiMode of the
 * environment) allows it, and the mock otherwise. Under MINGLI_AI_PROVIDER=mock
 * (the test suite) no real provider is even built. `choice` (default: modelChoice
 * of the environment) puts every route on one model.
 */
export function buildProviders(
  mode: () => AiMode = () => aiMode(process.env),
  choice: () => ModelChoice = () => modelChoice(process.env),
): Providers {
  const testing = process.env.MINGLI_AI_PROVIDER === "mock";
  const mock = new MockProvider();
  const live: string[] = [];
  const map: Record<string, LLMProvider> = { deepseek: mock, anthropic: mock };
  const useMock = () => mode().mock;
  if (!testing && process.env.DEEPSEEK_API_KEY) {
    map.deepseek = new SwitchedProvider(new DeepSeekProvider(), mock, useMock);
    live.push("deepseek");
  }
  // CLAUDE_API_KEY is the owner's name for the key (2026-10-29), used before the SDK's own variables.
  const claudeKey = process.env.CLAUDE_API_KEY?.trim();
  if (
    !testing &&
    (claudeKey || process.env.ANTHROPIC_API_KEY || process.env.ANTHROPIC_AUTH_TOKEN)
  ) {
    const client = claudeKey ? new Anthropic({ apiKey: claudeKey, authToken: null }) : undefined;
    map.anthropic = new SwitchedProvider(new AnthropicProvider(client), mock, useMock);
    live.push("anthropic");
  }
  const routing = () => {
    const { model } = choice();
    return model ? withModel(loadRouting(), model) : loadRouting();
  };
  return {
    live,
    map,
    mode,
    choice,
    routing,
    serving: () => (useMock() ? "mock" : servingProvider(live, routing())),
    models: () => [...new Set(defaultRoutes(routing()).map((r) => r.model))].join(","),
  };
}

/** The .env change that turns the real model back on, per reason for the mock. */
const UNMOCK: Record<string, string> = {
  "IS_AI_MOCK=TRUE": "IS_AI_MOCK=FALSE",
  "IS_AI_MODEL=FALSE": "IS_AI_MODEL=TRUE",
};

/** The .env key each provider needs (Claude's also answers to ANTHROPIC_API_KEY). */
const KEYS: Record<string, string> = {
  anthropic: "CLAUDE_API_KEY",
  deepseek: "DEEPSEEK_API_KEY",
};

/** One console line: what answers AI calls now, and how to flip it. */
export function describeAi(p: Providers): string {
  const serving = p.serving();
  const models = p.models();
  const wrong = p.choice().error;
  const choice = wrong ? `; ${wrong}` : "";
  if (serving !== "mock")
    return `${serving} ${models} (real model; IS_AI_MOCK=TRUE in .env switches to the mock)${choice}`;
  // The keys the routed providers still lack: without them the mock answers whatever the switch says.
  const missing = [...new Set(defaultRoutes(p.routing()).map((r) => r.provider))]
    .filter((name) => !p.live.includes(name))
    .map((name) => KEYS[name] ?? `a ${name} key`)
    .join(" or ");
  const { reason } = p.mode();
  if (!reason) return `mock (no ${missing || "API key"} in .env for ${models})${choice}`;
  const unmock = UNMOCK[reason];
  const flip = !unmock
    ? ""
    : missing
      ? `; for the real model (${models}): ${unmock} and ${missing} in .env`
      : `; ${unmock} in .env for the real model (${models})`;
  return `mock (${reason}): demo answers marked （示范）, no tokens spent${flip}${choice}`;
}

/**
 * Auth from the environment: MINGLI_JWT_SECRET (hex, >= 32 bytes), APPLE_CLIENT_IDS /
 * GOOGLE_CLIENT_IDS (comma-separated audiences), MINGLI_TURNSTILE_SECRET (captcha).
 * Without a captcha secret, captcha is off; that is refused outside dev mode.
 */
export function buildAuth(
  secrets: EngineSecrets,
  devMode: boolean,
  users?: UserStore,
): AuthService {
  const jwt = hexSecret("MINGLI_JWT_SECRET");
  if (!jwt && !devMode) throw new Error("MINGLI_JWT_SECRET is required outside dev mode");
  const turnstile = process.env.MINGLI_TURNSTILE_SECRET;
  if (!turnstile && !devMode)
    throw new Error("MINGLI_TURNSTILE_SECRET is required outside dev mode");
  return new AuthService({
    pepper: secrets.digestPepper,
    tokens: new TokenService(jwt ?? randomBytes(32)),
    social: SocialVerifier.fromEnv(),
    captcha: turnstile ? new TurnstileVerifier(turnstile) : noCaptcha,
    ...(users && { users }),
  });
}

/** Where readings and accounts are kept: in memory (the default), or the encrypted database. */
export interface Persistence {
  /** Undefined: the API's in-memory store. */
  store?: Store;
  users?: UserStore;
  /** The folder of the database, when there is one. */
  dataDir?: string;
  close(): Promise<void>;
}

/**
 * MINGLI_STORE=pglite keeps readings and accounts across restarts (tech plan S5), in the folder
 * MINGLI_DATA_DIR (default .data, git-ignored), every body sealed under its owner's data key, which
 * MINGLI_DATA_KEY wraps. Without it, everything stays in memory, as before. It refuses to start
 * without a valid key, or with per-process secrets: a random pepper would lose every email lookup
 * at the next start.
 */
export async function openStore(
  secrets: EngineSecrets & { ephemeral: boolean },
): Promise<Persistence> {
  const kind = process.env.MINGLI_STORE?.trim().toLowerCase() || "memory";
  if (kind === "memory") return { close: async () => {} };
  if (kind !== "pglite") throw new Error(`MINGLI_STORE must be memory or pglite, not ${kind}`);
  if (secrets.ephemeral) {
    throw new Error(
      "MINGLI_STORE=pglite needs MINGLI_DIGEST_PEPPER and MINGLI_TAROT_DRAW_KEY in .env (npm run keygen prints them)",
    );
  }
  const dataDir = process.env.MINGLI_DATA_DIR?.trim() || ".data";
  const pg = await PgStore.open({
    dataDir,
    kek: parseKek(process.env.MINGLI_DATA_KEY),
    pepper: secrets.digestPepper,
  });
  return { store: pg, users: pg, dataDir, close: () => pg.close() };
}

/**
 * Test accounts seeded on every dev-mode start (the store is in-memory). A login without an @ is the account's
 * username since v8.2.0; one with an @ its email.
 */
export const DEV_ACCOUNTS = [
  { login: "admin", password: "admin", country: "HK", locale: "zh-Hans" as const },
  { login: "xumei", password: "xumei", country: "HK", locale: "zh-Hans" as const },
  // Owner request (2026-10-28): three more, each with its login as its password, as admin and xumei have.
  { login: "qianli", password: "qianli", country: "HK", locale: "zh-Hans" as const },
  { login: "wuyong", password: "wuyong", country: "HK", locale: "zh-Hans" as const },
  { login: "leonfighter", password: "leonfighter", country: "HK", locale: "zh-Hans" as const },
  {
    login: "test@mingli.local",
    password: "Test-12345678",
    country: "HK",
    locale: "zh-Hant" as const,
  },
  // 后台角色 (S25, v13.1.0): one of each staff role besides admin, to try the 管理后台 as each.
  {
    login: "manager",
    password: "manager",
    country: "HK",
    locale: "zh-Hans" as const,
    role: "manager" as const,
  },
  {
    login: "integrator",
    password: "integrator",
    country: "HK",
    locale: "zh-Hans" as const,
    role: "integrator" as const,
  },
];

export async function seedDevAccounts(auth: AuthService, devMode: boolean) {
  if (!devMode) throw new Error("dev accounts may only be seeded in dev mode");
  for (const { role, ...a } of DEV_ACCOUNTS as ((typeof DEV_ACCOUNTS)[number] & {
    role?: AccountRole;
  })[]) {
    await auth.seedDevUser(a);
    // Given once: a role an admin changed later in the dashboard stays.
    const u = role && (await auth.findLogin(loginKind(a.login), a.login));
    if (u && u.role === undefined) await auth.users.put({ ...u, role });
  }
}

/**
 * 积分 (v11.0.0, the owner: 「给所有dev给个相应的分数去进行计算」): every dev account starts with `points`, given once, so a
 * database that keeps the accounts doesn't give them again at the next start. Returns how many got them now.
 */
export async function grantDevPoints(
  auth: AuthService,
  ledger: PointsLedger,
  points: number,
  now = new Date(),
): Promise<number> {
  let granted = 0;
  for (const a of DEV_ACCOUNTS) {
    const u = await auth.findLogin(loginKind(a.login), a.login);
    if (!u) continue;
    const entry = await ledger.creditPoints(
      u.id,
      points,
      { kind: "grant", reason: "dev" },
      now.toISOString(),
    );
    if (entry) granted++;
  }
  return granted;
}

/**
 * The owner's 积分 switch (v11.0.0): on unless MINGLI_POINTS=off. Off, every AI request is free, as before v11.0.0.
 */
export function pointsOn(env: Record<string, string | undefined>): boolean {
  return envFlag(env.MINGLI_POINTS) !== false;
}

/** A model-provider failure (outage, auth, rate limit): message if so, else undefined. */
export function upstreamMessage(e: unknown): string | undefined {
  if (e instanceof Anthropic.APIError) return `Claude API ${e.status ?? ""}: ${e.message}`;
  if (e instanceof ProviderHttpError) return `${e.provider} API ${e.message}`;
  return undefined;
}

/** Which provider actually serves the routes: its name(s), or "mock" while one of them has no key. */
export function servingProvider(live: string[], routing: RoutingTable = loadRouting()): string {
  const used = new Set(defaultRoutes(routing).map((r) => r.provider));
  return [...used].every((p) => live.includes(p)) ? [...used].join(",") : "mock";
}
