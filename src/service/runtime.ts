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
  ProviderHttpError,
  type LLMJsonRequest,
  type LLMJsonResult,
  type LLMProvider,
} from "../ai/index.js";
import type { Store } from "../api/store.js";
import { noCaptcha, TurnstileVerifier } from "../auth/limits.js";
import { AuthService, type UserStore } from "../auth/service.js";
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

/**
 * aiMode() kept current with an .env file, re-read whenever the file changes: flip
 * IS_AI_MOCK and the next AI call follows, with no restart (so a tunnel's URL
 * survives). `shell` is the environment from before .env was loaded; like
 * process.loadEnvFile, it wins over the file. onChange hears every flip.
 */
export function watchAiMode(
  file: string,
  shell: Record<string, string | undefined>,
  onChange?: (mode: AiMode) => void,
): () => AiMode {
  let stamp: number | undefined;
  let mode: AiMode | undefined;
  return () => {
    let mtime = -1;
    try {
      mtime = statSync(file).mtimeMs;
    } catch {
      // no .env: the shell alone
    }
    if (mtime !== stamp || !mode) {
      stamp = mtime;
      let fromFile: Record<string, string | undefined> = {};
      try {
        fromFile = parseEnv(readFileSync(file, "utf8"));
      } catch {
        // missing or unreadable: the shell alone
      }
      const prev = mode;
      mode = aiMode({ ...fromFile, ...shell });
      // After storing it: a listener that reads the switch sees the new mode.
      if (prev && (mode.mock !== prev.mock || mode.reason !== prev.reason)) onChange?.(mode);
    }
    return mode;
  };
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

export interface Providers {
  /** Providers with credentials (the ones the switch can turn on). */
  live: string[];
  map: Record<string, LLMProvider>;
  mode: () => AiMode;
  /** What answers AI calls right now: the routed provider name(s), or "mock". */
  serving: () => string;
}

/**
 * Providers keyed by the names config/model_routing.json uses. Each is real when
 * its credentials are present and the AI switch (`mode`, default: aiMode of the
 * environment) allows it, and the mock otherwise. Under MINGLI_AI_PROVIDER=mock
 * (the test suite) no real provider is even built.
 */
export function buildProviders(mode: () => AiMode = () => aiMode(process.env)): Providers {
  const testing = process.env.MINGLI_AI_PROVIDER === "mock";
  const mock = new MockProvider();
  const live: string[] = [];
  const map: Record<string, LLMProvider> = { deepseek: mock, anthropic: mock };
  const useMock = () => mode().mock;
  if (!testing && process.env.DEEPSEEK_API_KEY) {
    map.deepseek = new SwitchedProvider(new DeepSeekProvider(), mock, useMock);
    live.push("deepseek");
  }
  if (!testing && (process.env.ANTHROPIC_API_KEY || process.env.ANTHROPIC_AUTH_TOKEN)) {
    map.anthropic = new SwitchedProvider(new AnthropicProvider(), mock, useMock);
    live.push("anthropic");
  }
  return { live, map, mode, serving: () => (useMock() ? "mock" : servingProvider(live)) };
}

/** The .env change that turns the real model back on, per reason for the mock. */
const UNMOCK: Record<string, string> = {
  "IS_AI_MOCK=TRUE": "IS_AI_MOCK=FALSE",
  "IS_AI_MODEL=FALSE": "IS_AI_MODEL=TRUE",
};

/** One console line: what answers AI calls now, and how to flip it. */
export function describeAi(p: Providers): string {
  const serving = p.serving();
  if (serving !== "mock")
    return `${serving} (real model; IS_AI_MOCK=TRUE in .env switches to the mock)`;
  const { reason } = p.mode();
  if (!reason) return "mock (no API key in .env)";
  const flip = UNMOCK[reason] ? `; ${UNMOCK[reason]} in .env for the real model` : "";
  return `mock (${reason}): demo answers marked （示范）, no tokens spent${flip}`;
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

/** Test accounts seeded on every dev-mode start (the store is in-memory). */
export const DEV_ACCOUNTS = [
  { login: "admin", password: "admin", country: "HK", locale: "zh-Hans" as const },
  { login: "xumei", password: "xumei", country: "HK", locale: "zh-Hans" as const },
  {
    login: "test@mingli.local",
    password: "Test-12345678",
    country: "HK",
    locale: "zh-Hant" as const,
  },
];

export async function seedDevAccounts(auth: AuthService, devMode: boolean) {
  if (!devMode) throw new Error("dev accounts may only be seeded in dev mode");
  for (const a of DEV_ACCOUNTS) await auth.seedDevUser(a);
}

/** A model-provider failure (outage, auth, rate limit): message if so, else undefined. */
export function upstreamMessage(e: unknown): string | undefined {
  if (e instanceof Anthropic.APIError) return `Claude API ${e.status ?? ""}: ${e.message}`;
  if (e instanceof ProviderHttpError) return `${e.provider} API ${e.message}`;
  return undefined;
}

/** Which provider actually serves the configured routes: its name(s), or "mock". */
export function servingProvider(live: string[]): string {
  const used = new Set(Object.values(loadRouting().routes).map((r) => r.default.provider));
  return [...used].every((p) => live.includes(p)) ? [...used].join(",") : "mock";
}
