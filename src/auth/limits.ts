/**
 * Login protection: per-key failure counting in a sliding window. After
 * CAPTCHA_AFTER failures a captcha is required; after LOCK_AFTER the key is
 * locked for the rest of the window.
 */
export const WINDOW_MS = 15 * 60_000;
export const CAPTCHA_AFTER = 3;
export const LOCK_AFTER = 10;

export class FailureLimiter {
  private readonly failures = new Map<string, number[]>();
  constructor(private readonly now: () => number = Date.now) {}

  count(key: string): number {
    const cutoff = this.now() - WINDOW_MS;
    const list = (this.failures.get(key) ?? []).filter((t) => t > cutoff);
    this.failures.set(key, list);
    return list.length;
  }

  fail(key: string) {
    this.failures.set(key, [...(this.failures.get(key) ?? []), this.now()]);
  }

  clear(key: string) {
    this.failures.delete(key);
  }
}

export interface CaptchaVerifier {
  readonly name: string;
  verify(token: string | undefined, ip: string): Promise<boolean>;
}

/** Dev/test: no captcha. Never use in production (startup refuses it outside dev mode). */
export const noCaptcha: CaptchaVerifier = { name: "none", verify: async () => true };

/**
 * Cloudflare Turnstile. Proposed default — the provider choice (Turnstile vs an
 * image captcha vs hCaptcha) is still open; anything implementing CaptchaVerifier fits.
 */
export class TurnstileVerifier implements CaptchaVerifier {
  readonly name = "turnstile";
  constructor(
    private readonly secret: string,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  async verify(token: string | undefined, ip: string): Promise<boolean> {
    if (!token) return false;
    const res = await this.fetchFn("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ secret: this.secret, response: token, remoteip: ip }),
      signal: AbortSignal.timeout(10_000),
    });
    return res.ok && ((await res.json()) as { success?: boolean }).success === true;
  }
}
