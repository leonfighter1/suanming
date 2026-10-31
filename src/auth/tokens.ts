/**
 * Access tokens: short-lived JWTs (HS256). Refresh tokens: opaque random values,
 * stored only as SHA-256, rotated on every use. Presenting an already-used
 * refresh token revokes its whole family (stolen-token detection).
 *
 * Sessions (S29; the owner: 「登录者的登录消息存在服务器上，如果距离上次登录超过2天，那就需要重新登录」): the refresh
 * tokens live in a SessionStore, the database's when there is one, so a restart keeps everyone signed in. Each lasts
 * the idle limit (2 days by default) and every refresh gives a new one, so a session ends after that long unused.
 */
import { createHash, randomBytes, randomUUID } from "node:crypto";
import { jwtVerify, SignJWT } from "jose";

export const ACCESS_TTL_S = 15 * 60;
/** How long a session may go unused before its owner signs in again: the owner's 2 days. */
export const SESSION_IDLE_S = 2 * 24 * 3600;
const ISSUER = "mingli";
const AUDIENCE = "mingli-app";

/** A refresh token's record (by its SHA-256): whose, its family (a sign-in and its rotations), until when, used yet. */
export interface RefreshRecord {
  userId: string;
  family: string;
  expiresAt: number;
  used: boolean;
}

/** Where the refresh tokens are kept (S29): in memory, or the database (PgStore). */
export interface SessionStore {
  /** Keeps a new refresh token, and lets go of those expired by [now] (ms). */
  putRefresh(hash: string, rec: RefreshRecord, now: number): Promise<void>;
  /** The token as it was, marked used in the same step; undefined for none. */
  useRefresh(hash: string): Promise<RefreshRecord | undefined>;
  getRefresh(hash: string): Promise<RefreshRecord | undefined>;
  dropFamily(family: string): Promise<void>;
  dropUser(userId: string): Promise<void>;
}

/** The sessions in memory, gone with the process: the API's in-memory store, and tests. */
export class InMemorySessionStore implements SessionStore {
  private readonly refresh = new Map<string, RefreshRecord>();

  async putRefresh(hash: string, rec: RefreshRecord, now: number) {
    for (const [k, r] of this.refresh) if (r.expiresAt < now) this.refresh.delete(k);
    this.refresh.set(hash, rec);
  }

  async useRefresh(hash: string) {
    const rec = this.refresh.get(hash);
    if (!rec) return undefined;
    const before = { ...rec };
    rec.used = true;
    return before;
  }

  async getRefresh(hash: string) {
    return this.refresh.get(hash);
  }

  async dropFamily(family: string) {
    for (const [k, r] of this.refresh) if (r.family === family) this.refresh.delete(k);
  }

  async dropUser(userId: string) {
    for (const [k, r] of this.refresh) if (r.userId === userId) this.refresh.delete(k);
  }
}

export interface TokenOptions {
  /** Where the refresh tokens are kept: in memory by default. */
  sessions?: SessionStore;
  /** How long a session may go unused, in seconds, read at each sign-in and refresh: [SESSION_IDLE_S] by default. */
  idleSeconds?: () => number;
}

export interface TokenPair {
  access_token: string;
  refresh_token: string;
  token_type: "Bearer";
  expires_in: number;
}

export class TokenError extends Error {}

export class TokenService {
  private readonly sessions: SessionStore;
  private readonly idleSeconds: () => number;

  constructor(
    private readonly secret: Buffer,
    private readonly now: () => Date = () => new Date(),
    o: TokenOptions = {},
  ) {
    if (secret.length < 32) throw new Error("JWT secret must be >= 32 bytes");
    this.sessions = o.sessions ?? new InMemorySessionStore();
    this.idleSeconds = o.idleSeconds ?? (() => SESSION_IDLE_S);
  }

  private sha(t: string) {
    return createHash("sha256").update(t).digest("hex");
  }

  async issue(userId: string, family: string = randomUUID()): Promise<TokenPair> {
    const nowMs = this.now().getTime();
    const nowS = Math.floor(nowMs / 1000);
    const access = await new SignJWT({})
      .setProtectedHeader({ alg: "HS256" })
      .setSubject(userId)
      .setIssuer(ISSUER)
      .setAudience(AUDIENCE)
      .setIssuedAt(nowS)
      .setExpirationTime(nowS + ACCESS_TTL_S)
      .setJti(randomUUID())
      .sign(this.secret);
    const refresh = randomBytes(32).toString("base64url");
    await this.sessions.putRefresh(
      this.sha(refresh),
      { userId, family, expiresAt: nowMs + this.idleSeconds() * 1000, used: false },
      nowMs,
    );
    return {
      access_token: access,
      refresh_token: refresh,
      token_type: "Bearer",
      expires_in: ACCESS_TTL_S,
    };
  }

  /** Returns the user id, or throws TokenError. */
  async verifyAccess(token: string): Promise<string> {
    try {
      const { payload } = await jwtVerify(token, this.secret, {
        issuer: ISSUER,
        audience: AUDIENCE,
        algorithms: ["HS256"],
        currentDate: this.now(),
      });
      if (!payload.sub) throw new TokenError("no subject");
      return payload.sub;
    } catch (e) {
      throw e instanceof TokenError ? e : new TokenError("invalid or expired access token");
    }
  }

  async rotate(refreshToken: string): Promise<{ userId: string; tokens: TokenPair }> {
    const rec = await this.sessions.useRefresh(this.sha(refreshToken));
    if (!rec || rec.expiresAt < this.now().getTime()) throw new TokenError("invalid refresh token");
    if (rec.used) {
      await this.sessions.dropFamily(rec.family);
      throw new TokenError("refresh token reuse detected; session revoked");
    }
    return { userId: rec.userId, tokens: await this.issue(rec.userId, rec.family) };
  }

  async revoke(refreshToken: string) {
    const rec = await this.sessions.getRefresh(this.sha(refreshToken));
    if (rec) await this.sessions.dropFamily(rec.family);
  }

  async revokeUser(userId: string) {
    await this.sessions.dropUser(userId);
  }
}
