/**
 * Account lifecycle: register, login, social sign-in, refresh, logout, delete.
 * Region and age gate come from the Geo-Rule matrix at sign-up, before any
 * account exists. The email is looked up by keyed hash; the plain address is
 * kept only for account mail (encrypted in the PostgreSQL store).
 */
import { createHmac, randomUUID } from "node:crypto";
import { LOCALES, type Locale } from "../ai/terms.js";
import { loadGeoMatrix, resolveRegion } from "../compliance/index.js";
import {
  CAPTCHA_AFTER,
  FailureLimiter,
  LOCK_AFTER,
  noCaptcha,
  type CaptchaVerifier,
} from "./limits.js";
import { dummyHash, hashPassword, passwordProblem, verifyPassword } from "./passwords.js";
import { SocialVerifier, type SocialProvider } from "./social.js";
import { TokenService, type TokenPair } from "./tokens.js";

export interface UserRecord {
  id: string;
  email?: string;
  email_lookup?: string;
  password_hash?: string;
  social: Partial<Record<SocialProvider, string>>;
  country: string;
  locale: Locale;
  age_confirmed_at: string;
  created_at: string;
}

export interface UserStore {
  get(id: string): Promise<UserRecord | undefined>;
  byEmailLookup(lookup: string): Promise<UserRecord | undefined>;
  bySocial(provider: SocialProvider, sub: string): Promise<UserRecord | undefined>;
  put(u: UserRecord): Promise<void>;
  delete(id: string): Promise<void>;
}

export class InMemoryUserStore implements UserStore {
  private users = new Map<string, UserRecord>();
  async get(id: string) {
    const u = this.users.get(id);
    return u && structuredClone(u);
  }
  async byEmailLookup(l: string) {
    return [...this.users.values()].find((u) => u.email_lookup === l);
  }
  async bySocial(p: SocialProvider, sub: string) {
    return [...this.users.values()].find((u) => u.social[p] === sub);
  }
  async put(u: UserRecord) {
    this.users.set(u.id, structuredClone(u));
  }
  async delete(id: string) {
    this.users.delete(id);
  }
}

/** Auth failures carry an HTTP status. */
export class AuthError extends Error {
  constructor(
    readonly status: number,
    message: string,
    readonly code?: "captcha_required" | "locked" | "region" | "age",
  ) {
    super(message);
  }
}

export interface AuthDeps {
  pepper: Buffer;
  tokens: TokenService;
  users?: UserStore;
  social?: SocialVerifier;
  captcha?: CaptchaVerifier;
  limiter?: FailureLimiter;
  now?: () => Date;
}

export interface SignupProfile {
  country: unknown;
  locale: unknown;
  /** User confirmed they meet the region's minimum age (self-declared). */
  age_confirmed: unknown;
}

const EMAIL_RE = /^[^\s@]{1,64}@[^\s@]{1,253}\.[^\s@]{2,}$/;

export class AuthService {
  readonly users: UserStore;
  private readonly social: SocialVerifier;
  private readonly captcha: CaptchaVerifier;
  private readonly limiter: FailureLimiter;
  private readonly now: () => Date;
  private readonly matrix = loadGeoMatrix();

  constructor(private readonly deps: AuthDeps) {
    this.users = deps.users ?? new InMemoryUserStore();
    this.social = deps.social ?? new SocialVerifier({ audiences: {} });
    this.captcha = deps.captcha ?? noCaptcha;
    this.limiter = deps.limiter ?? new FailureLimiter();
    this.now = deps.now ?? (() => new Date());
  }

  emailLookup(email: string) {
    return createHmac("sha256", this.deps.pepper)
      .update(`email:${email.trim().toLowerCase()}`)
      .digest("hex");
  }

  /** Geo-Rule + age gate + locale, checked before an account is created. */
  private profile(p: SignupProfile) {
    const country = String(p.country ?? "").toUpperCase();
    if (!/^[A-Z]{2}$/.test(country)) throw new AuthError(400, "country must be ISO 3166-1 alpha-2");
    const region = resolveRegion(this.matrix, country);
    if (!region || !region.service_available) {
      throw new AuthError(451, `service not available in ${country}`, "region");
    }
    if (p.age_confirmed !== true) {
      throw new AuthError(
        400,
        `you must confirm you are at least ${region.age_gate.min_age}`,
        "age",
      );
    }
    const locale = (p.locale ?? "zh-Hant") as Locale;
    if (!LOCALES.includes(locale))
      throw new AuthError(400, `locale must be one of ${LOCALES.join(", ")}`);
    return { country, locale };
  }

  async register(
    body: { email?: unknown; password?: unknown } & SignupProfile,
  ): Promise<TokenPair> {
    const email = typeof body.email === "string" ? body.email.trim() : "";
    if (!EMAIL_RE.test(email)) throw new AuthError(400, "a valid email is required");
    const pwProblem = passwordProblem(body.password);
    if (pwProblem) throw new AuthError(400, pwProblem);
    const { country, locale } = this.profile(body);
    const lookup = this.emailLookup(email);
    // Same response time and shape either way would be ideal; a 409 is the usual
    // trade-off for a consumer app with an explicit "log in instead" path.
    if (await this.users.byEmailLookup(lookup))
      throw new AuthError(409, "an account with this email already exists");
    const ts = this.now().toISOString();
    const user: UserRecord = {
      id: randomUUID(),
      email,
      email_lookup: lookup,
      password_hash: await hashPassword(body.password as string),
      social: {},
      country,
      locale,
      age_confirmed_at: ts,
      created_at: ts,
    };
    await this.users.put(user);
    return this.deps.tokens.issue(user.id);
  }

  async login(
    body: { email?: unknown; password?: unknown; captcha_token?: unknown },
    ip: string,
  ): Promise<TokenPair> {
    const email = typeof body.email === "string" ? body.email.trim() : "";
    const lookup = this.emailLookup(email);
    const keys = [`email:${lookup}`, `ip:${ip}`];
    const failures = Math.max(...keys.map((k) => this.limiter.count(k)));
    if (failures >= LOCK_AFTER)
      throw new AuthError(429, "too many attempts; try again later", "locked");
    if (failures >= CAPTCHA_AFTER) {
      const ok = await this.captcha.verify(
        typeof body.captcha_token === "string" ? body.captcha_token : undefined,
        ip,
      );
      if (!ok) throw new AuthError(400, "captcha required", "captcha_required");
    }
    const user = email ? await this.users.byEmailLookup(lookup) : undefined;
    const ok = user?.password_hash
      ? await verifyPassword(user.password_hash, String(body.password ?? ""))
      : (await verifyPassword(await dummyHash(), String(body.password ?? "")), false);
    if (!user || !ok) {
      keys.forEach((k) => this.limiter.fail(k));
      throw new AuthError(401, "email or password is incorrect");
    }
    keys.forEach((k) => this.limiter.clear(k));
    return this.deps.tokens.issue(user.id);
  }

  /** Sign in with Apple/Google. Creates the account on first sign-in (needs the sign-up profile). */
  async socialSignIn(
    body: { provider?: unknown; id_token?: unknown } & Partial<SignupProfile>,
  ): Promise<TokenPair> {
    const provider = body.provider as SocialProvider;
    if (provider !== "apple" && provider !== "google")
      throw new AuthError(400, "provider must be apple | google");
    if (typeof body.id_token !== "string") throw new AuthError(400, "id_token is required");
    let identity;
    try {
      identity = await this.social.verify(provider, body.id_token);
    } catch (e) {
      throw new AuthError(401, (e as Error).message);
    }
    const existing = await this.users.bySocial(provider, identity.sub);
    if (existing) return this.deps.tokens.issue(existing.id);

    const { country, locale } = this.profile({
      country: body.country,
      locale: body.locale,
      age_confirmed: body.age_confirmed,
    });
    const ts = this.now().toISOString();
    const user: UserRecord = {
      id: randomUUID(),
      // Only keep an email the provider verified; don't merge into existing accounts by email.
      ...(identity.email && identity.emailVerified && { email: identity.email }),
      social: { [provider]: identity.sub },
      country,
      locale,
      age_confirmed_at: ts,
      created_at: ts,
    };
    await this.users.put(user);
    return this.deps.tokens.issue(user.id);
  }

  async refresh(refreshToken: unknown): Promise<TokenPair> {
    if (typeof refreshToken !== "string") throw new AuthError(400, "refresh_token is required");
    try {
      const { userId, tokens } = await this.deps.tokens.rotate(refreshToken);
      if (!(await this.users.get(userId))) throw new Error("user deleted");
      return tokens;
    } catch (e) {
      throw new AuthError(401, (e as Error).message);
    }
  }

  logout(refreshToken: unknown) {
    if (typeof refreshToken === "string") this.deps.tokens.revoke(refreshToken);
  }

  /** Bearer token → user, or throws 401. */
  async authenticate(authorization: string | undefined): Promise<UserRecord> {
    const m = /^Bearer\s+(.+)$/i.exec(authorization ?? "");
    if (!m) throw new AuthError(401, "missing bearer token");
    let id: string;
    try {
      id = await this.deps.tokens.verifyAccess(m[1]!);
    } catch (e) {
      throw new AuthError(401, (e as Error).message);
    }
    const user = await this.users.get(id);
    if (!user) throw new AuthError(401, "account no longer exists");
    return user;
  }

  /**
   * DEV ONLY: create a fixed test account, skipping the email-format and
   * password-length rules (so `admin` / `admin` works). Callers must only use
   * this in dev mode; buildAuth refuses outside it. No-op if it exists.
   */
  async seedDevUser(u: { login: string; password: string; country: string; locale: Locale }) {
    const lookup = this.emailLookup(u.login);
    if (await this.users.byEmailLookup(lookup)) return;
    const ts = this.now().toISOString();
    await this.users.put({
      id: randomUUID(),
      email: u.login,
      email_lookup: lookup,
      password_hash: await hashPassword(u.password),
      social: {},
      country: u.country,
      locale: u.locale,
      age_confirmed_at: ts,
      created_at: ts,
    });
  }

  /** Remove the account and revoke every session. Caller purges owned data first. */
  async deleteAccount(userId: string) {
    this.deps.tokens.revokeUser(userId);
    await this.users.delete(userId);
  }
}

export function publicUser(u: UserRecord) {
  return {
    id: u.id,
    email: u.email,
    country: u.country,
    locale: u.locale,
    sign_in_methods: [...(u.password_hash ? ["password"] : []), ...Object.keys(u.social)],
    created_at: u.created_at,
  };
}
