/**
 * Sign in with Apple / Google: verify the ID token the client obtained from the
 * provider's SDK, against the provider's published JWKS.
 */
import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from "jose";

export type SocialProvider = "apple" | "google";

const PROVIDERS: Record<SocialProvider, { jwks: string; issuers: string[] }> = {
  apple: { jwks: "https://appleid.apple.com/auth/keys", issuers: ["https://appleid.apple.com"] },
  google: {
    jwks: "https://www.googleapis.com/oauth2/v3/certs",
    issuers: ["https://accounts.google.com", "accounts.google.com"],
  },
};

export interface SocialIdentity {
  provider: SocialProvider;
  sub: string;
  email?: string;
  emailVerified: boolean;
}

export class SocialAuthError extends Error {}

export interface SocialConfig {
  /** Accepted `aud` values: Apple services/bundle ids, Google OAuth client ids. */
  audiences: Partial<Record<SocialProvider, string[]>>;
  /** Override key lookup (tests). Defaults to the provider's remote JWKS. */
  keys?: Partial<Record<SocialProvider, JWTVerifyGetKey>>;
  now?: () => Date;
}

export class SocialVerifier {
  private readonly keys: Partial<Record<SocialProvider, JWTVerifyGetKey>>;

  constructor(private readonly cfg: SocialConfig) {
    this.keys = { ...cfg.keys };
  }

  static fromEnv(): SocialVerifier {
    const list = (v?: string) =>
      v
        ? v
            .split(",")
            .map((s) => s.trim())
            .filter(Boolean)
        : [];
    return new SocialVerifier({
      audiences: {
        apple: list(process.env.APPLE_CLIENT_IDS),
        google: list(process.env.GOOGLE_CLIENT_IDS),
      },
    });
  }

  enabled(p: SocialProvider) {
    return (this.cfg.audiences[p]?.length ?? 0) > 0;
  }

  async verify(provider: SocialProvider, idToken: string): Promise<SocialIdentity> {
    if (!(provider in PROVIDERS)) throw new SocialAuthError("unsupported provider");
    if (!this.enabled(provider)) throw new SocialAuthError(`${provider} sign-in is not configured`);
    const key = (this.keys[provider] ??= createRemoteJWKSet(new URL(PROVIDERS[provider].jwks)));
    try {
      const { payload } = await jwtVerify(idToken, key, {
        issuer: PROVIDERS[provider].issuers,
        audience: this.cfg.audiences[provider],
        algorithms: ["RS256", "ES256"],
        currentDate: this.cfg.now?.(),
      });
      if (!payload.sub) throw new SocialAuthError("token has no subject");
      const ev = payload.email_verified;
      return {
        provider,
        sub: payload.sub,
        email: typeof payload.email === "string" ? payload.email : undefined,
        // Apple sends email_verified as a string.
        emailVerified: ev === true || ev === "true",
      };
    } catch (e) {
      throw e instanceof SocialAuthError ? e : new SocialAuthError(`invalid ${provider} id token`);
    }
  }
}
