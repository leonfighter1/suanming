/**
 * Process-level runtime wiring shared by the v1 API and the demo: engine secrets
 * and LLM providers, both from the environment.
 */
import { randomBytes } from "node:crypto";
import Anthropic from "@anthropic-ai/sdk";
import {
  AnthropicProvider,
  DeepSeekProvider,
  loadRouting,
  MockProvider,
  ProviderHttpError,
  type LLMProvider,
} from "../ai/index.js";
import { noCaptcha, TurnstileVerifier } from "../auth/limits.js";
import { AuthService } from "../auth/service.js";
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

/**
 * Providers keyed by the names config/model_routing.json uses. Each is real when
 * its credentials are present and the mock otherwise. MINGLI_AI_PROVIDER=mock
 * forces the mock everywhere (the test suite sets it).
 */
export function buildProviders(): { live: string[]; map: Record<string, LLMProvider> } {
  const forceMock = process.env.MINGLI_AI_PROVIDER === "mock";
  const mock = new MockProvider();
  const live: string[] = [];
  const map: Record<string, LLMProvider> = { deepseek: mock, anthropic: mock };
  if (!forceMock && process.env.DEEPSEEK_API_KEY) {
    map.deepseek = new DeepSeekProvider();
    live.push("deepseek");
  }
  if (!forceMock && (process.env.ANTHROPIC_API_KEY || process.env.ANTHROPIC_AUTH_TOKEN)) {
    map.anthropic = new AnthropicProvider();
    live.push("anthropic");
  }
  return { live, map };
}

/**
 * Auth from the environment: MINGLI_JWT_SECRET (hex, >= 32 bytes), APPLE_CLIENT_IDS /
 * GOOGLE_CLIENT_IDS (comma-separated audiences), MINGLI_TURNSTILE_SECRET (captcha).
 * Without a captcha secret, captcha is off; that is refused outside dev mode.
 */
export function buildAuth(secrets: EngineSecrets, devMode: boolean): AuthService {
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
  });
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
