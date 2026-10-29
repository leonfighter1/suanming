/**
 * One-time codes that prove a phone number or an email is the user's own (tech plan WP15.3; the owner:
 * 手机号需要绑定用户本人): six digits, valid for ten minutes, five tries. They live in memory only, as keyed hashes,
 * so a restart voids them and the user asks for a new one.
 *
 * Sending is limited, so an account can't flood a number or an address: a new code at most once a minute per kind,
 * five an hour to one destination, ten a day per account. Every request counts, even one refused for a number bound
 * elsewhere, so the limits also slow anyone probing which numbers have accounts.
 */
import { createHmac, randomBytes, randomInt, timingSafeEqual } from "node:crypto";

export type ContactKind = "email" | "phone";

export const CODE_TTL_MS = 10 * 60_000;
export const CODE_TRIES = 5;
export const RESEND_AFTER_MS = 60_000;
export const PER_DESTINATION_PER_HOUR = 5;
export const PER_ACCOUNT_PER_DAY = 10;

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

  constructor(private readonly now: () => number = Date.now) {}

  private hash(user: string, kind: ContactKind, value: string, code: string) {
    return createHmac("sha256", this.key).update(`${user}\n${kind}\n${value}\n${code}`).digest();
  }

  /** Counts a request for a code to `value`, or refuses it (429) when the account asks too often. */
  admit(user: string, kind: ContactKind, value: string): void {
    const t = this.now();
    this.requests = this.requests.filter((r) => t - r.at < DAY);
    const mine = this.requests.filter((r) => r.user === user);
    const last = mine.filter((r) => r.kind === kind).at(-1);
    if (last && t - last.at < RESEND_AFTER_MS) {
      const wait = Math.ceil((RESEND_AFTER_MS - (t - last.at)) / 1000);
      throw new VerifyError(429, `wait ${wait} s before asking for another code`, "wait");
    }
    if (mine.length >= PER_ACCOUNT_PER_DAY) {
      throw new VerifyError(429, "too many codes asked for today; try again tomorrow", "too_many");
    }
    const destination = `${kind}:${value}`;
    const recent = this.requests.filter((r) => r.destination === destination && t - r.at < HOUR);
    if (recent.length >= PER_DESTINATION_PER_HOUR) {
      throw new VerifyError(429, "too many codes sent there; try again in an hour", "too_many");
    }
    this.requests.push({ user, kind, destination, at: t });
  }

  /** A new code for `value`, replacing the account's earlier one of this kind. */
  issue(user: string, kind: ContactKind, value: string): { code: string; expires: number } {
    const code = String(randomInt(0, 1_000_000)).padStart(6, "0");
    const expires = this.now() + CODE_TTL_MS;
    this.pending.set(`${user}:${kind}`, {
      value,
      hash: this.hash(user, kind, value, code),
      expires,
      tries: 0,
    });
    return { code, expires };
  }

  /** Checks a code for `value`. Right, it is used up; wrong five times, it is void. */
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
      if (p.tries >= CODE_TRIES) {
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
