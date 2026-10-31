/**
 * Account lifecycle: register, login, social sign-in, refresh, logout, delete.
 * Region and age gate come from the Geo-Rule matrix at sign-up, before any
 * account exists. A login is a username, an email or a bound phone (v8.2.0),
 * each looked up by keyed hash; the values themselves are kept for the account
 * and its mail (encrypted in the PostgreSQL store).
 */
import { createHmac, randomBytes, randomUUID } from "node:crypto";
import { LOCALES, type Locale } from "../ai/terms.js";
import { loadGeoMatrix, resolveRegion } from "../compliance/index.js";
import {
  EMAIL_RE,
  emailKey,
  loginKind,
  phoneCandidates,
  usernameForm,
  usernameKey,
  usernameProblem,
  type LoginKind,
} from "./identifiers.js";
import { FailureLimiter, noCaptcha, type CaptchaVerifier } from "./limits.js";
import { dummyHash, hashPassword, passwordProblem, verifyPassword } from "./passwords.js";
import { SocialVerifier, type SocialProvider } from "./social.js";
import { TokenService, type TokenPair } from "./tokens.js";

/** What an account can change about itself (v8.2.0, tech plan WP15.4). */
export interface AccountSettings {
  /** 测算完成后发到邮箱: mail every passed reading to the verified email. 否 by default (the owner). */
  email_reports: boolean;
}

export const DEFAULT_SETTINGS: AccountSettings = { email_reports: false };

/** 管理后台 (v11.2.0, tech plan S22): what an account is and may do. */
/** An account's role (v11.2.0; integrator and manager since v13.1.0, src/admin/roles.ts). */
export type AccountRole = "user" | "integrator" | "manager" | "admin";
export type AccountStatus = "active" | "suspended";
export interface AccountPermissions {
  /** AI readings, 一生运势报告, 追问, plans and the 深度分析. */
  ai: boolean;
  /** 充值. */
  top_up: boolean;
}
export const DEFAULT_PERMISSIONS: AccountPermissions = { ai: true, top_up: true };

/** What an account may do: its own permissions over the defaults. */
export const permissionsOf = (u: Pick<UserRecord, "permissions">): AccountPermissions => ({
  ...DEFAULT_PERMISSIONS,
  ...u.permissions,
});

export interface UserRecord {
  id: string;
  email?: string;
  email_lookup?: string;
  /** When a code proved the email the user's own (v8.2.0). Reports are mailed only to a verified email. */
  email_verified_at?: string;
  /** As chosen (v8.2.0); found by `username_lookup`, case and width folded. */
  username?: string;
  username_lookup?: string;
  /** E.164 (v8.2.0), only once bound: a code sent to it proved it the user's own. */
  phone?: string;
  phone_lookup?: string;
  phone_bound_at?: string;
  /** Absent: the defaults. */
  settings?: Partial<AccountSettings>;
  password_hash?: string;
  social: Partial<Record<SocialProvider, string>>;
  country: string;
  locale: Locale;
  age_confirmed_at: string;
  created_at: string;
  /** Absent: a user (v11.2.0). */
  role?: AccountRole;
  /** Absent: active. A suspended account can't sign in, and its sessions end. */
  status?: AccountStatus;
  /** Absent: everything allowed. */
  permissions?: Partial<AccountPermissions>;
  /** Its last request, to the minute; written at most every five minutes (active users). */
  last_seen_at?: string;
  /** Preset data for the dashboard (v11.4.0): no person's; it has no password, so it can't sign in. */
  demo?: boolean;
}

export interface UserStore {
  get(id: string): Promise<UserRecord | undefined>;
  byEmailLookup(lookup: string): Promise<UserRecord | undefined>;
  byUsernameLookup(lookup: string): Promise<UserRecord | undefined>;
  byPhoneLookup(lookup: string): Promise<UserRecord | undefined>;
  bySocial(provider: SocialProvider, sub: string): Promise<UserRecord | undefined>;
  put(u: UserRecord): Promise<void>;
  delete(id: string): Promise<void>;
  /** Every account (管理后台, v11.2.0), oldest first. */
  list(): Promise<UserRecord[]>;
  /**
   * Notes an account's last activity, and nothing else: a request's own changes to the account (a setting, a
   * username) may be written at the same time, and must not be undone by a copy read before them.
   */
  touch(id: string, at: string): Promise<void>;
}

export class InMemoryUserStore implements UserStore {
  private users = new Map<string, UserRecord>();
  async get(id: string) {
    const u = this.users.get(id);
    return u && structuredClone(u);
  }
  async byEmailLookup(l: string) {
    const u = [...this.users.values()].find((u) => u.email_lookup === l);
    return u && structuredClone(u);
  }
  async byUsernameLookup(l: string) {
    const u = [...this.users.values()].find((u) => u.username_lookup === l);
    return u && structuredClone(u);
  }
  async byPhoneLookup(l: string) {
    const u = [...this.users.values()].find((u) => u.phone_lookup === l);
    return u && structuredClone(u);
  }
  async bySocial(p: SocialProvider, sub: string) {
    return [...this.users.values()].find((u) => u.social[p] === sub);
  }
  async put(u: UserRecord) {
    // The last activity only moves forward: touch() may have written a later one since this copy was read.
    const seen = [this.users.get(u.id)?.last_seen_at, u.last_seen_at].filter(Boolean).sort().at(-1);
    this.users.set(u.id, { ...structuredClone(u), ...(seen && { last_seen_at: seen }) });
  }
  async delete(id: string) {
    this.users.delete(id);
  }
  async list() {
    return [...this.users.values()]
      .sort((a, b) => (a.created_at < b.created_at ? -1 : a.created_at > b.created_at ? 1 : 0))
      .map((u) => structuredClone(u));
  }
  async touch(id: string, at: string) {
    const u = this.users.get(id);
    if (u) u.last_seen_at = at;
  }
}

/** 管理后台 (v11.2.0): the refusal a suspended account meets everywhere. */
const suspended = () =>
  new AuthError(403, "this account has been suspended by an administrator", "account_suspended");

/** Auth failures carry an HTTP status. */
export class AuthError extends Error {
  constructor(
    readonly status: number,
    message: string,
    readonly code?:
      | "captcha_required"
      | "locked"
      | "region"
      | "age"
      // Sign-up (v8.2.0), so the app can say what is wrong in the reader's language.
      | "username_invalid"
      | "username_taken"
      | "email_invalid"
      | "email_taken"
      | "password_weak"
      // 管理后台 (v11.2.0): an admin suspended the account.
      | "account_suspended"
      // ☰ → 管理后台 without a second sign-in (S33): the one-time code was used, was late or never was.
      | "handoff_invalid",
  ) {
    super(message);
  }
}

/** A one-time code's life (S33): long enough to open the 管理后台 from the app's menu, no longer. */
export const HANDOFF_TTL_MS = 2 * 60_000;

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

export class AuthService {
  readonly users: UserStore;
  private readonly social: SocialVerifier;
  private readonly captcha: CaptchaVerifier;
  private readonly limiter: FailureLimiter;
  private readonly now: () => Date;

  constructor(private readonly deps: AuthDeps) {
    this.users = deps.users ?? new InMemoryUserStore();
    this.social = deps.social ?? new SocialVerifier({ audiences: {} });
    this.captcha = deps.captcha ?? noCaptcha;
    this.limiter = deps.limiter ?? new FailureLimiter();
    this.now = deps.now ?? (() => new Date());
  }

  private keyed(text: string) {
    return createHmac("sha256", this.deps.pepper).update(text).digest("hex");
  }

  /** The one-time codes given out (S33), by their keyed hash: in memory only, so a restart voids them. */
  private readonly handoffs = new Map<string, { user: string; expires: number }>();

  /**
   * A one-time code that signs [userId] in elsewhere (S33; the owner: 「如果当前登录进去的用户有dashboard access，那么
   * 不需要重复登录了」): the app's ☰ → 管理后台 opens the dashboard with it. Two minutes, one use.
   */
  handoff(userId: string): { code: string; expires_at: string } {
    const now = this.now().getTime();
    for (const [key, h] of this.handoffs) if (h.expires <= now) this.handoffs.delete(key);
    const code = randomBytes(32).toString("base64url");
    const expires = now + HANDOFF_TTL_MS;
    this.handoffs.set(this.keyed(`handoff:${code}`), { user: userId, expires });
    return { code, expires_at: new Date(expires).toISOString() };
  }

  /** [code]'s account signed in, with a session of its own; once. 401 handoff_invalid when used, late or unknown. */
  async redeemHandoff(code: unknown): Promise<TokenPair> {
    const key = typeof code === "string" && code ? this.keyed(`handoff:${code}`) : undefined;
    const h = key === undefined ? undefined : this.handoffs.get(key);
    if (key !== undefined) this.handoffs.delete(key);
    const user = h && h.expires > this.now().getTime() ? await this.users.get(h.user) : undefined;
    if (!user)
      throw new AuthError(401, "the link has expired or was used; sign in", "handoff_invalid");
    if (user.status === "suspended") throw suspended();
    return this.deps.tokens.issue(user.id);
  }

  emailLookup(email: string) {
    return this.keyed(`email:${emailKey(email)}`);
  }

  usernameLookup(username: string) {
    return this.keyed(`username:${usernameKey(username)}`);
  }

  /** `phone` in E.164. */
  phoneLookup(phone: string) {
    return this.keyed(`phone:${phone}`);
  }

  /**
   * The account a login names. A phone written without its country code may read as a number in several regions;
   * it names an account only when exactly one of them is bound.
   */
  async findLogin(kind: LoginKind, login: string): Promise<UserRecord | undefined> {
    if (kind === "email") return this.users.byEmailLookup(this.emailLookup(login));
    if (kind === "username") return this.users.byUsernameLookup(this.usernameLookup(login));
    const found = new Map<string, UserRecord>();
    for (const phone of phoneCandidates(login)) {
      const u = await this.users.byPhoneLookup(this.phoneLookup(phone));
      if (u) found.set(u.id, u);
    }
    return found.size === 1 ? [...found.values()][0] : undefined;
  }

  /** Geo-Rule + age gate + locale, checked before an account is created. */
  private profile(p: SignupProfile) {
    const country = String(p.country ?? "").toUpperCase();
    if (!/^[A-Z]{2}$/.test(country)) throw new AuthError(400, "country must be ISO 3166-1 alpha-2");
    // Read per sign-up, so a region the owner signs off is open without a restart (v5.1.0).
    const region = resolveRegion(loadGeoMatrix(), country);
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

  /**
   * A new account with a username, an email, or both (v8.2.0: the app asks for a username, the email optional). The
   * email counts as unverified until a code proves it; a phone is bound later, in 设置.
   */
  async register(
    body: { username?: unknown; email?: unknown; password?: unknown } & SignupProfile,
  ): Promise<TokenPair> {
    const given = (v: unknown) => (typeof v === "string" && v.trim() ? v : undefined);
    const rawName = given(body.username);
    const email = given(body.email)?.trim();
    if (!rawName && !email)
      throw new AuthError(400, "a username or an email is required", "username_invalid");
    const username = rawName && usernameForm(rawName);
    if (rawName) {
      const problem = usernameProblem(rawName);
      if (problem) throw new AuthError(400, problem, "username_invalid");
    }
    if (email !== undefined && !EMAIL_RE.test(email)) {
      throw new AuthError(400, "a valid email is required", "email_invalid");
    }
    const pwProblem = passwordProblem(body.password);
    if (pwProblem) throw new AuthError(400, pwProblem, "password_weak");
    const { country, locale } = this.profile(body);
    // Same response time and shape either way would be ideal; a 409 is the usual
    // trade-off for a consumer app with an explicit "log in instead" path.
    if (username && (await this.users.byUsernameLookup(this.usernameLookup(username)))) {
      throw new AuthError(409, "this username is taken", "username_taken");
    }
    if (email && (await this.users.byEmailLookup(this.emailLookup(email)))) {
      throw new AuthError(409, "an account with this email already exists", "email_taken");
    }
    const ts = this.now().toISOString();
    const user: UserRecord = {
      id: randomUUID(),
      ...(username && { username, username_lookup: this.usernameLookup(username) }),
      ...(email && { email, email_lookup: this.emailLookup(email) }),
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

  /** `login` is a username, an email or a bound phone (v8.2.0); `email` is the same field from before. */
  async login(
    body: { login?: unknown; email?: unknown; password?: unknown; captcha_token?: unknown },
    ip: string,
  ): Promise<TokenPair> {
    const raw = typeof body.login === "string" ? body.login : body.email;
    const login = typeof raw === "string" ? raw.trim() : "";
    const kind = loginKind(login);
    const named =
      kind === "email"
        ? this.emailLookup(login)
        : kind === "username"
          ? this.usernameLookup(login)
          : this.keyed(`phone-login:${login.replace(/\D/g, "")}`);
    const keys = [`login:${named}`, `ip:${ip}`];
    const { captchaAfter, lockAfter } = this.limiter.limits();
    const failures = Math.max(...keys.map((k) => this.limiter.count(k)));
    if (failures >= lockAfter)
      throw new AuthError(429, "too many attempts; try again later", "locked");
    if (failures >= captchaAfter) {
      const ok = await this.captcha.verify(
        typeof body.captcha_token === "string" ? body.captcha_token : undefined,
        ip,
      );
      if (!ok) throw new AuthError(400, "captcha required", "captcha_required");
    }
    const user = login ? await this.findLogin(kind, login) : undefined;
    const ok = user?.password_hash
      ? await verifyPassword(user.password_hash, String(body.password ?? ""))
      : (await verifyPassword(await dummyHash(), String(body.password ?? "")), false);
    if (!user || !ok) {
      keys.forEach((k) => this.limiter.fail(k));
      // One answer for every kind of login, whether or not it names an account.
      throw new AuthError(401, "the login or password is incorrect");
    }
    keys.forEach((k) => this.limiter.clear(k));
    // Said only to someone who knows the password.
    if (user.status === "suspended") throw suspended();
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
      ...(identity.email &&
        identity.emailVerified && { email: identity.email, email_verified_at: ts }),
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
    let rotated: Awaited<ReturnType<TokenService["rotate"]>>;
    try {
      rotated = await this.deps.tokens.rotate(refreshToken);
    } catch (e) {
      throw new AuthError(401, (e as Error).message);
    }
    const user = await this.users.get(rotated.userId);
    if (!user) throw new AuthError(401, "user deleted");
    if (user.status === "suspended") {
      await this.deps.tokens.revokeUser(user.id);
      throw suspended();
    }
    return rotated.tokens;
  }

  /** 管理后台 (v11.2.0): ends every session of an account; its access tokens lapse within their 15 minutes. */
  async signOutEverywhere(userId: string) {
    await this.deps.tokens.revokeUser(userId);
  }

  async logout(refreshToken: unknown) {
    if (typeof refreshToken === "string") await this.deps.tokens.revoke(refreshToken);
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
    if (user.status === "suspended") throw suspended();
    return user;
  }

  /**
   * DEV ONLY: create a fixed test account, skipping the password-length rule
   * (so `admin` / `admin` works). A login with an @ is its email, any other its
   * username (v8.2.0). Callers must only use this in dev mode; buildAuth refuses
   * outside it. No-op if it exists.
   */
  async seedDevUser(u: { login: string; password: string; country: string; locale: Locale }) {
    if (loginKind(u.login) === "email") {
      if (await this.users.byEmailLookup(this.emailLookup(u.login))) return;
    } else {
      if (await this.users.byUsernameLookup(this.usernameLookup(u.login))) return;
      // Seeded before v8.2.0 with the login in the email's place: the same account (its records stay), now under
      // its username, with no email until its user adds one.
      const old = await this.users.byEmailLookup(this.emailLookup(u.login));
      if (old) {
        const { email: _email, email_lookup: _lookup, email_verified_at: _at, ...rest } = old;
        await this.users.put({
          ...rest,
          username: u.login,
          username_lookup: this.usernameLookup(u.login),
        });
        return;
      }
    }
    const ts = this.now().toISOString();
    await this.users.put({
      id: randomUUID(),
      ...(loginKind(u.login) === "email"
        ? { email: u.login, email_lookup: this.emailLookup(u.login) }
        : { username: u.login, username_lookup: this.usernameLookup(u.login) }),
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
    await this.deps.tokens.revokeUser(userId);
    await this.users.delete(userId);
  }
}

export function publicUser(u: UserRecord) {
  return {
    id: u.id,
    ...(u.username !== undefined && { username: u.username }),
    email: u.email,
    email_verified: u.email_verified_at !== undefined,
    ...(u.phone !== undefined && { phone: u.phone }),
    country: u.country,
    locale: u.locale,
    sign_in_methods: [...(u.password_hash ? ["password"] : []), ...Object.keys(u.social)],
    settings: { ...DEFAULT_SETTINGS, ...u.settings },
    created_at: u.created_at,
  };
}
