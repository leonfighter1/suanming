/**
 * Login protection: per-key failure counting in a sliding window. After
 * captchaAfter failures a captcha is required; after lockAfter the key is
 * locked for the rest of the window. The three are 设置's (S32 WP32.1).
 */
import { defaultSettings, type Settings } from "../settings/index.js";

export interface FailureLimits {
  windowMs: number;
  captchaAfter: number;
  lockAfter: number;
}

/** [settings]' limits as they are now: the 管理后台's 登录 group. */
export const failureLimits = (settings: Settings = defaultSettings()): FailureLimits => ({
  windowMs: settings.number("sessions.failure_window_minutes") * 60_000,
  captchaAfter: settings.number("sessions.captcha_after"),
  lockAfter: settings.number("sessions.lock_after"),
});

export class FailureLimiter {
  private readonly failures = new Map<string, number[]>();
  constructor(
    private readonly now: () => number = Date.now,
    /** Read at each sign-in, so a change in the 管理后台 holds from the next one. */
    readonly limits: () => FailureLimits = () => failureLimits(),
  ) {}

  count(key: string): number {
    const cutoff = this.now() - this.limits().windowMs;
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
