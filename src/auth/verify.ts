/**
 * One-time codes that prove a phone number or an email is the user's own (tech plan WP15.3; the owner:
 * 手机号需要绑定用户本人): six digits, valid for ten minutes, five tries. They live in memory only, as keyed hashes,
 * so a restart voids them and the user asks for a new one.
 *
 * Sending is limited, so an account can't flood a number or an address: a new code at most once a minute per kind,
 * five an hour to one destination, ten a day per account. Every request counts, even one refused for a number bound
 * elsewhere, so the limits also slow anyone probing which numbers have accounts. The numbers are the defaults of
 * 设置's 验证码 group (S32 WP32.2).
 */
import { createHmac, randomBytes, randomInt, timingSafeEqual } from "node:crypto";
import { defaultSettings, type Settings } from "../settings/index.js";

export type ContactKind = "email" | "phone";

export interface CodeLimits {
  /** How long a code lasts. */
  ttlMs: number;
  /** The wrong tries that void it. */
  tries: number;
  /** The wait before another code of the same kind. */
  resendMs: number;
  perDestinationPerHour: number;
  perAccountPerDay: number;
}

/** [settings]' limits as they are now: the 管理后台's 验证码 group. */
export const codeLimits = (settings: Settings = defaultSettings()): CodeLimits => ({
  ttlMs: settings.number("codes.minutes") * 60_000,
  tries: settings.number("codes.tries"),
  resendMs: settings.number("codes.resend_seconds") * 1000,
  perDestinationPerHour: settings.number("codes.per_destination_hour"),
  perAccountPerDay: settings.number("codes.per_account_day"),
});

const HOUR = 3_600_000;
const DAY = 24 * HOUR;

export type VerifyCode = "wait" | "too_many" | "no_code" | "wrong_code" | "expired";

export class VerifyError extends Error {
  constructor(
    readonly status: number,
    message: string,
    readonly code: VerifyCode,
  ) {
    super(message);
  }
}

interface Pending {
  value: string;
  hash: Buffer;
  expires: number;
  tries: number;
}

export class Verifications {
  /** Per process: the codes never outlive it. */
  private readonly key = randomBytes(32);
  private readonly pending = new Map<string, Pending>();
  private requests: { user: string; kind: ContactKind; destination: string; at: number }[] = [];

  constructor(
    private readonly now: () => number = Date.now,
    /** Read at each request, so a change in the 管理后台 holds from the next one. */
    readonly limits: () => CodeLimits = () => codeLimits(),
  ) {}

  private hash(user: string, kind: ContactKind, value: string, code: string) {
    return createHmac("sha256", this.key).update(`${user}\n${kind}\n${value}\n${code}`).digest();
  }

  /** Counts a request for a code to `value`, or refuses it (429) when the account asks too often. */
  admit(user: string, kind: ContactKind, value: string): void {
    const t = this.now();
    const { resendMs, perAccountPerDay, perDestinationPerHour } = this.limits();
    this.requests = this.requests.filter((r) => t - r.at < DAY);
    const mine = this.requests.filter((r) => r.user === user);
    const last = mine.filter((r) => r.kind === kind).at(-1);
    if (last && t - last.at < resendMs) {
      const wait = Math.ceil((resendMs - (t - last.at)) / 1000);
      throw new VerifyError(429, `wait ${wait} s before asking for another code`, "wait");
    }
    if (mine.length >= perAccountPerDay) {
      throw new VerifyError(429, "too many codes asked for today; try again tomorrow", "too_many");
    }
    const destination = `${kind}:${value}`;
    const recent = this.requests.filter((r) => r.destination === destination && t - r.at < HOUR);
    if (recent.length >= perDestinationPerHour) {
      throw new VerifyError(429, "too many codes sent there; try again in an hour", "too_many");
    }
    this.requests.push({ user, kind, destination, at: t });
  }

  /** A new code for `value`, replacing the account's earlier one of this kind. */
  issue(user: string, kind: ContactKind, value: string): { code: string; expires: number } {
    const code = String(randomInt(0, 1_000_000)).padStart(6, "0");
    const expires = this.now() + this.limits().ttlMs;
    this.pending.set(`${user}:${kind}`, {
      value,
      hash: this.hash(user, kind, value, code),
      expires,
      tries: 0,
    });
    return { code, expires };
  }

  /** Checks a code for `value`. Right, it is used up; wrong as many times as the tries allow, it is void. */
  check(user: string, kind: ContactKind, value: string, code: string): void {
    const key = `${user}:${kind}`;
    const p = this.pending.get(key);
    if (!p || p.value !== value) {
      throw new VerifyError(400, "no code was sent for this; ask for one first", "no_code");
    }
    if (this.now() > p.expires) {
      this.pending.delete(key);
      throw new VerifyError(400, "the code has expired; ask for a new one", "expired");
    }
    const ok = /^\d{6}$/.test(code) && timingSafeEqual(this.hash(user, kind, value, code), p.hash);
    if (!ok) {
      p.tries += 1;
      if (p.tries >= this.limits().tries) {
        this.pending.delete(key);
        throw new VerifyError(400, "too many wrong codes; ask for a new one", "no_code");
      }
      throw new VerifyError(400, "the code is not right", "wrong_code");
    }
    this.pending.delete(key);
  }

  /** Forgets an account's codes and requests (the account was deleted). */
  forget(user: string) {
    for (const k of [...this.pending.keys()]) if (k.startsWith(`${user}:`)) this.pending.delete(k);
    this.requests = this.requests.filter((r) => r.user !== user);
  }
}
