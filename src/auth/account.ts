/**
 * What a signed-in user changes about their own account (tech plan WP15.3–15.4): the username, the email and the
 * phone they sign in with, and the settings. An email or a phone counts only once a code sent to it comes back: that
 * is what binds a number to its owner (the owner: 手机号需要绑定用户本人). Codes go out through the transports, the
 * development outbox until the owner picks providers.
 */
import { Dispatcher, MemoryTemplates } from "../notify/dispatch.js";
import { DeliveryUnavailable, type MailTransport } from "../notify/mail.js";
import type { SmsTransport } from "../notify/sms.js";
import {
  EMAIL_RE,
  emailKey,
  maskEmail,
  maskPhone,
  normalizePhone,
  usernameForm,
  usernameProblem,
} from "./identifiers.js";
import {
  DEFAULT_SETTINGS,
  type AccountSettings,
  type AuthService,
  type UserRecord,
} from "./service.js";
import { CODE_TTL_MS, Verifications, type ContactKind } from "./verify.js";

export type AccountErrorCode =
  | "invalid"
  | "username_taken"
  | "email_taken"
  | "phone_taken"
  | "already_bound"
  | "last_login"
  | "email_unverified"
  | "delivery_unavailable";

export class AccountError extends Error {
  constructor(
    readonly status: number,
    message: string,
    readonly code: AccountErrorCode,
  ) {
    super(message);
  }
}

export interface CodeSent {
  /** Where the code went, masked: s***@example.com, +852 ****4567. */
  sent_to: string;
  expires_at: string;
  /** What delivered it: "outbox" while the server has no provider (the app says so). */
  delivery: string;
}

const MINUTES = CODE_TTL_MS / 60_000;

export class AccountService {
  readonly verifications: Verifications;
  /** How codes leave: the templates and the transports (S25). */
  private readonly messages: Dispatcher;

  constructor(
    private readonly d: {
      auth: AuthService;
      mail: MailTransport;
      sms: SmsTransport;
      /** The server's dispatcher; without one, the default wordings over [mail] and [sms]. */
      messages?: Dispatcher;
      verifications?: Verifications;
      now?: () => Date;
    },
  ) {
    this.verifications =
      d.verifications ?? new Verifications(() => (d.now?.() ?? new Date()).getTime());
    this.messages =
      d.messages ??
      new Dispatcher({
        mail: d.mail,
        sms: d.sms,
        templates: new MemoryTemplates(),
        ...(d.now && { now: d.now }),
      });
  }

  private get users() {
    return this.d.auth.users;
  }

  private now() {
    return (this.d.now?.() ?? new Date()).toISOString();
  }

  private async user(id: string): Promise<UserRecord> {
    const u = await this.users.get(id);
    if (!u) throw new AccountError(404, "account not found", "invalid");
    return u;
  }

  /** Sets or changes the username. */
  async setUsername(id: string, raw: unknown): Promise<UserRecord> {
    const problem = usernameProblem(raw);
    if (problem) throw new AccountError(400, problem, "invalid");
    const username = usernameForm(raw as string);
    const lookup = this.d.auth.usernameLookup(username);
    const other = await this.users.byUsernameLookup(lookup);
    if (other && other.id !== id) {
      throw new AccountError(409, "this username is taken", "username_taken");
    }
    const next = { ...(await this.user(id)), username, username_lookup: lookup };
    await this.users.put(next);
    return next;
  }

  /** The email or phone a request names, checked, in the form it is kept: an email trimmed, a phone in E.164. */
  private value(kind: ContactKind, raw: unknown, u: UserRecord): string {
    if (typeof raw !== "string") throw new AccountError(400, `${kind} is required`, "invalid");
    if (kind === "email") {
      const email = raw.trim();
      if (!EMAIL_RE.test(email))
        throw new AccountError(400, "a valid email is required", "invalid");
      return email;
    }
    // A local number reads in the account's region; any other number needs its country code.
    const phone = normalizePhone(raw, u.country);
    if (!phone) {
      throw new AccountError(
        400,
        "a valid mobile number is required, with its country code",
        "invalid",
      );
    }
    return phone;
  }

  private holder(kind: ContactKind, value: string) {
    return kind === "email"
      ? this.users.byEmailLookup(this.d.auth.emailLookup(value))
      : this.users.byPhoneLookup(this.d.auth.phoneLookup(value));
  }

  private taken(kind: ContactKind) {
    return kind === "email"
      ? new AccountError(409, "this email belongs to another account", "email_taken")
      : new AccountError(409, "this number is bound to another account", "phone_taken");
  }

  /** Sends a code to an email or a phone. It counts for the account only once the code comes back. */
  async startContact(id: string, kind: ContactKind, raw: unknown): Promise<CodeSent> {
    const u = await this.user(id);
    const value = this.value(kind, raw, u);
    const transport = kind === "email" ? this.d.mail : this.d.sms;
    if (transport.name === "off") {
      throw new AccountError(
        503,
        kind === "email"
          ? "mail is not set up on this server yet"
          : "text messages are not set up on this server yet",
        "delivery_unavailable",
      );
    }
    // Counted before anything is looked up, so the limits also slow probing for numbers with accounts.
    this.verifications.admit(id, kind, value);
    const proved =
      kind === "email"
        ? u.email !== undefined &&
          u.email_verified_at !== undefined &&
          emailKey(u.email) === emailKey(value)
        : u.phone === value;
    if (proved) {
      throw new AccountError(
        409,
        kind === "email" ? "this email is already verified" : "this number is already bound",
        "already_bound",
      );
    }
    const other = await this.holder(kind, value);
    if (other && other.id !== id) throw this.taken(kind);
    const { code, expires } = this.verifications.issue(id, kind, value);
    try {
      // The account's language's wording, an admin's if they changed it (S25: 消息模板).
      await this.messages.send(kind === "email" ? "code_mail" : "code_sms", {
        to: value,
        locale: u.locale,
        vars: { code, minutes: String(MINUTES) },
      });
    } catch (e) {
      if (e instanceof DeliveryUnavailable) {
        throw new AccountError(503, e.message, "delivery_unavailable");
      }
      throw e;
    }
    return {
      sent_to: kind === "email" ? maskEmail(value) : maskPhone(value),
      expires_at: new Date(expires).toISOString(),
      delivery: transport.name,
    };
  }

  /**
   * The code came back: the email becomes the account's (verified), or the phone is bound. An email replaces the one
   * before, which stops signing in.
   */
  async confirmContact(
    id: string,
    kind: ContactKind,
    raw: unknown,
    code: unknown,
  ): Promise<UserRecord> {
    const u = await this.user(id);
    const value = this.value(kind, raw, u);
    this.verifications.check(id, kind, value, typeof code === "string" ? code.trim() : "");
    // Bound elsewhere while the code was on its way.
    const other = await this.holder(kind, value);
    if (other && other.id !== id) throw this.taken(kind);
    const ts = this.now();
    const next: UserRecord =
      kind === "email"
        ? {
            ...u,
            email: value,
            email_lookup: this.d.auth.emailLookup(value),
            email_verified_at: ts,
          }
        : { ...u, phone: value, phone_lookup: this.d.auth.phoneLookup(value), phone_bound_at: ts };
    await this.users.put(next);
    return next;
  }

  /** Removes the email or unbinds the phone. A password account keeps one way to sign in at least. */
  async removeContact(id: string, kind: ContactKind): Promise<UserRecord> {
    const u = await this.user(id);
    if (kind === "email" ? u.email === undefined : u.phone === undefined) return u;
    const left = [u.username, kind === "email" ? u.phone : u.email].filter((v) => v !== undefined);
    if (u.password_hash && left.length === 0) {
      throw new AccountError(
        409,
        "keep at least one way to sign in: a username, an email or a phone",
        "last_login",
      );
    }
    let next: UserRecord;
    if (kind === "email") {
      const { email: _email, email_lookup: _lookup, email_verified_at: _at, ...rest } = u;
      // Without a verified email no report can be mailed (WP15.4): the setting goes back to 否.
      next = { ...rest, settings: { ...u.settings, email_reports: false } };
    } else {
      const { phone: _phone, phone_lookup: _lookup, phone_bound_at: _at, ...rest } = u;
      next = rest;
    }
    await this.users.put(next);
    return next;
  }

  async settings(id: string): Promise<AccountSettings> {
    return { ...DEFAULT_SETTINGS, ...(await this.user(id)).settings };
  }

  /** Changes settings. 测算完成后发到邮箱 can be turned on only with a verified email. */
  async updateSettings(id: string, patch: unknown): Promise<AccountSettings> {
    if (!patch || typeof patch !== "object" || Array.isArray(patch)) {
      throw new AccountError(400, "settings must be an object", "invalid");
    }
    const u = await this.user(id);
    const next: AccountSettings = { ...DEFAULT_SETTINGS, ...u.settings };
    for (const [key, v] of Object.entries(patch)) {
      if (key !== "email_reports") throw new AccountError(400, `unknown setting ${key}`, "invalid");
      if (typeof v !== "boolean") {
        throw new AccountError(400, "email_reports must be true or false", "invalid");
      }
      if (v && (u.email === undefined || u.email_verified_at === undefined)) {
        throw new AccountError(
          409,
          "verify an email first: reports go only to a verified email",
          "email_unverified",
        );
      }
      next.email_reports = v;
    }
    await this.users.put({ ...u, settings: next });
    return next;
  }

  /** The account is gone: its pending codes go too. */
  forget(id: string) {
    this.verifications.forget(id);
  }
}
