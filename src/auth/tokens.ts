/**
 * Access tokens: short-lived JWTs (HS256). Refresh tokens: opaque random values,
 * stored only as SHA-256, rotated on every use. Presenting an already-used
 * refresh token revokes its whole family (stolen-token detection).
 */
import { createHash, randomBytes, randomUUID } from "node:crypto";
import { jwtVerify, SignJWT } from "jose";

export const ACCESS_TTL_S = 15 * 60;
export const REFRESH_TTL_S = 30 * 24 * 3600;
const ISSUER = "mingli";
const AUDIENCE = "mingli-app";

interface RefreshRecord {
  userId: string;
  family: string;
  expiresAt: number;
  used: boolean;
}

export interface TokenPair {
  access_token: string;
  refresh_token: string;
  token_type: "Bearer";
  expires_in: number;
}

export class TokenError extends Error {}

export class TokenService {
  private readonly refresh = new Map<string, RefreshRecord>();

  constructor(
    private readonly secret: Buffer,
    private readonly now: () => Date = () => new Date(),
  ) {
    if (secret.length < 32) throw new Error("JWT secret must be >= 32 bytes");
  }

  private sha(t: string) {
    return createHash("sha256").update(t).digest("hex");
  }

  async issue(userId: string, family: string = randomUUID()): Promise<TokenPair> {
    const nowS = Math.floor(this.now().getTime() / 1000);
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
    this.refresh.set(this.sha(refresh), {
      userId,
      family,
      expiresAt: (nowS + REFRESH_TTL_S) * 1000,
      used: false,
    });
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
    const key = this.sha(refreshToken);
    const rec = this.refresh.get(key);
    if (!rec || rec.expiresAt < this.now().getTime()) throw new TokenError("invalid refresh token");
    if (rec.used) {
      this.revokeFamily(rec.family);
      throw new TokenError("refresh token reuse detected; session revoked");
    }
    rec.used = true;
    return { userId: rec.userId, tokens: await this.issue(rec.userId, rec.family) };
  }

  revoke(refreshToken: string) {
    const rec = this.refresh.get(this.sha(refreshToken));
    if (rec) this.revokeFamily(rec.family);
  }

  revokeUser(userId: string) {
    for (const [k, r] of this.refresh) if (r.userId === userId) this.refresh.delete(k);
  }

  private revokeFamily(family: string) {
    for (const [k, r] of this.refresh) if (r.family === family) this.refresh.delete(k);
  }
}
