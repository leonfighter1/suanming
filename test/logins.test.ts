// S15 WP15.3 (v8.2.0), the owner: 用户可以用用户名或者邮箱登录或者手机号登录，手机号需要绑定用户本人. How a login is
// read, the codes that bind a phone or verify an email, and the account routes, against memory transports.
import { beforeAll, describe, expect, it } from "vitest";
import { InMemoryStore } from "../src/api/store.js";
import { AccountError, AccountService } from "../src/auth/account.js";
import {
  loginKind,
  maskEmail,
  maskPhone,
  normalizePhone,
  phoneCandidates,
  usernameKey,
  usernameProblem,
} from "../src/auth/identifiers.js";
import { FailureLimiter, noCaptcha } from "../src/auth/limits.js";
import { AuthService, InMemoryUserStore } from "../src/auth/service.js";
import { TokenService } from "../src/auth/tokens.js";
import {
  CODE_TRIES,
  CODE_TTL_MS,
  PER_ACCOUNT_PER_DAY,
  PER_DESTINATION_PER_HOUR,
  RESEND_AFTER_MS,
  Verifications,
  VerifyError,
} from "../src/auth/verify.js";
import { MemoryMail, MemorySms, NoMail, NoSms } from "../src/notify/index.js";
import { PEPPER } from "./helpers.js";
import { testApi } from "./api.js";

describe("telling a login apart", () => {
  it("an @ makes an email, digits a phone, anything else a username", () => {
    expect(loginKind("someone@example.com")).toBe("email");
    for (const phone of ["+852 9123 4567", "0912-345-678", "(852) 9123-4567", "91234567"]) {
      expect(loginKind(phone), phone).toBe("phone");
    }
    for (const name of ["admin", "徐梅", "leon.fighter", "a1", "12ab"]) {
      expect(loginKind(name), name).toBe("username");
    }
  });

  it("a username: 2–24 letters, digits, Han, _ . -, starting with a letter or Han; case and width folded", () => {
    for (const ok of ["admin", "徐梅", "leon.fighter", "a_b-c", "Ａｄｍｉｎ", "a".repeat(24)]) {
      expect(usernameProblem(ok), ok).toBeUndefined();
    }
    for (const bad of ["a", "1abc", "_abc", "a@b", "a b", "a".repeat(25), "", 42]) {
      expect(usernameProblem(bad), String(bad)).toBeDefined();
    }
    // Full-width letters (a Chinese keyboard types them) and capitals name the same account.
    expect(usernameKey("Ａｄｍｉｎ")).toBe("admin");
    expect(usernameKey(" ADMIN ")).toBe("admin");
  });

  it("a phone number to E.164, written internationally or locally for the account's region", () => {
    // Hong Kong: 852 + 8 digits.
    expect(normalizePhone("+852 9123 4567")).toBe("+85291234567");
    expect(normalizePhone("00852-9123-4567")).toBe("+85291234567");
    expect(normalizePhone("9123 4567", "HK")).toBe("+85291234567");
    // Taiwan: 0912 345 678 drops its trunk 0, then 886 + 912345678 (9 digits); also when written after +886.
    expect(normalizePhone("0912 345 678", "TW")).toBe("+886912345678");
    expect(normalizePhone("+886 0912 345 678")).toBe("+886912345678");
    // Malaysia: 012-345 6789 is 10 digits; its trunk 0 goes first, leaving 123456789, then 60 in front.
    expect(normalizePhone("012-345 6789", "MY")).toBe("+60123456789");
    // A code outside the plans (Japan, 81) is taken as written: 81 + 9012345678 = 12 digits, within E.164's 15.
    expect(normalizePhone("+81 90 1234 5678")).toBe("+819012345678");
    // Not numbers: a local number without a region, 7 digits for Hong Kong, letters, a code starting with 0.
    expect(normalizePhone("9123 4567")).toBeUndefined();
    expect(normalizePhone("+852 9123 456")).toBeUndefined();
    expect(normalizePhone("call me")).toBeUndefined();
    expect(normalizePhone("+0123 4567 89")).toBeUndefined();
  });

  it("a local number at login may mean several regions; written with + it means one", () => {
    // 8 digits fit Hong Kong (852), Singapore (65) and Macao (853), in the plans' order; not Taiwan (9) or Malaysia (9–10).
    expect(phoneCandidates("9123 4567")).toEqual(["+85291234567", "+6591234567", "+85391234567"]);
    expect(phoneCandidates("+852 9123 4567")).toEqual(["+85291234567"]);
    expect(phoneCandidates("12")).toEqual([]);
  });

  it("masks for showing where a code went", () => {
    // +852, then the 8-digit number with all but its last 4 hidden.
    expect(maskPhone("+85291234567")).toBe("+852 ****4567");
    expect(maskPhone("+886912345678")).toBe("+886 *****5678");
    expect(maskEmail("someone@example.com")).toBe("s***@example.com");
  });
});

describe("one-time codes", () => {
  let t = Date.parse("2026-10-29T00:00:00Z");
  const v = new Verifications(() => t);

  it("a code works once, within ten minutes", () => {
    const { code, expires } = v.issue("u1", "phone", "+85291234567");
    expect(code).toMatch(/^\d{6}$/);
    expect(expires - t).toBe(CODE_TTL_MS);
    v.check("u1", "phone", "+85291234567", code);
    expect(() => v.check("u1", "phone", "+85291234567", code)).toThrow(/no code/);

    const late = v.issue("u1", "phone", "+85291234567");
    t += CODE_TTL_MS + 1;
    expect(() => v.check("u1", "phone", "+85291234567", late.code)).toThrow(/expired/);
  });

  it(`a code is for its own number and account, and void after ${CODE_TRIES} wrong tries`, () => {
    const { code } = v.issue("u2", "phone", "+85291234567");
    const wrong = code === "000000" ? "111111" : "000000";
    expect(() => v.check("u2", "phone", "+6591234567", code)).toThrow(/no code/);
    expect(() => v.check("u3", "phone", "+85291234567", code)).toThrow(/no code/);
    for (let i = 1; i < CODE_TRIES; i++) {
      expect(() => v.check("u2", "phone", "+85291234567", wrong)).toThrow(/not right/);
    }
    expect(() => v.check("u2", "phone", "+85291234567", wrong)).toThrow(/too many wrong/);
    // Void now, even with the right code.
    expect(() => v.check("u2", "phone", "+85291234567", code)).toThrow(/no code/);
  });

  it("sending is limited: once a minute, five an hour to one number, ten a day per account", () => {
    const limit = new Verifications(() => t);
    const refused = (user: string, value: string) => {
      try {
        limit.admit(user, "phone", value);
        return undefined;
      } catch (e) {
        return (e as VerifyError).code;
      }
    };
    expect(refused("a", "+85290000001")).toBeUndefined();
    expect(refused("a", "+85290000001")).toBe("wait");
    t += RESEND_AFTER_MS;
    // Five to one number within the hour, from different accounts a minute apart; the sixth is refused.
    for (let i = 1; i < PER_DESTINATION_PER_HOUR; i++) {
      expect(refused(`b${i}`, "+85290000001")).toBeUndefined();
    }
    expect(refused("c", "+85290000001")).toBe("too_many");
    // One account, a new number each minute: ten a day (two of them used above by "a"), then refused.
    let used = 1;
    for (; used < PER_ACCOUNT_PER_DAY; used++) {
      t += RESEND_AFTER_MS;
      expect(refused("a", `+8529100${String(used).padStart(4, "0")}`)).toBeUndefined();
    }
    t += RESEND_AFTER_MS;
    expect(refused("a", "+85291999999")).toBe("too_many");
    // A day later it may ask again.
    t += 24 * 3_600_000;
    expect(refused("a", "+85291999999")).toBeUndefined();
  });
});

// ---- the account routes ----

let clock = Date.parse("2026-10-29T01:00:00Z");
const now = () => new Date(clock);
const users = new InMemoryUserStore();
const auth = new AuthService({
  pepper: PEPPER,
  tokens: new TokenService(Buffer.alloc(32, 7), now),
  captcha: noCaptcha,
  limiter: new FailureLimiter(() => clock),
  users,
  now,
});
const mail = new MemoryMail();
const sms = new MemorySms();
let base = "";
const api = testApi(
  {
    store: new InMemoryStore(),
    auth,
    mail,
    sms,
    admins: ["admin"],
    now,
  },
  (b) => (base = b),
);

const call = async (method: string, path: string, body?: unknown, token?: string) => {
  const res = await fetch(base + path, {
    method,
    headers: {
      ...(body !== undefined && { "content-type": "application/json" }),
      ...(token && { authorization: `Bearer ${token}` }),
    },
    ...(body !== undefined && { body: JSON.stringify(body) }),
  });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : undefined };
};
const profile = { country: "HK", locale: "zh-Hans", age_confirmed: true };
const signUp = async (fields: Record<string, string>) => {
  const res = await call("POST", "/v1/auth/register", {
    password: "long enough pw",
    ...profile,
    ...fields,
  });
  expect(res.status, JSON.stringify(res.body)).toBe(201);
  return res.body.access_token as string;
};
const login = (name: string, password = "long enough pw") =>
  call("POST", "/v1/auth/login", { login: name, password });
const lastCode = (texts: string[]) => /(\d{6})/.exec(texts.at(-1) ?? "")?.[1] ?? "";
/** A minute later: the next code may be asked for. */
const later = () => (clock += RESEND_AFTER_MS);

describe("signing up and in with a username", () => {
  it("a username alone makes an account; it signs in by name in any case", async () => {
    const token = await signUp({ username: "Leon.Wong" });
    const me = await call("GET", "/v1/me", undefined, token);
    expect(me.body).toMatchObject({
      username: "Leon.Wong",
      email_verified: false,
      settings: { email_reports: false },
    });
    expect(me.body.email).toBeUndefined();
    expect(me.body.phone).toBeUndefined();
    for (const name of ["Leon.Wong", "leon.wong", "ＬＥＯＮ.ＷＯＮＧ"]) {
      expect((await login(name)).status, name).toBe(200);
    }
  });

  it("refuses a taken username (any case), a bad one, and an account with neither name nor email", async () => {
    const taken = await call("POST", "/v1/auth/register", {
      username: "leon.wong",
      password: "long enough pw",
      ...profile,
    });
    expect([taken.status, taken.body.code]).toEqual([409, "username_taken"]);
    const bad = await call("POST", "/v1/auth/register", {
      username: "9lives",
      password: "long enough pw",
      ...profile,
    });
    expect(bad.status).toBe(400);
    const none = await call("POST", "/v1/auth/register", {
      password: "long enough pw",
      ...profile,
    });
    expect(none.status).toBe(400);
  });

  it("a username and an email together: both sign in, the email not yet verified", async () => {
    await signUp({ username: "both_ways", email: "both@example.com" });
    expect((await login("both_ways")).status).toBe(200);
    expect((await login("BOTH@example.com")).status).toBe(200);
    const token = (await login("both_ways")).body.access_token;
    expect((await call("GET", "/v1/me", undefined, token)).body.email_verified).toBe(false);
  });
});

describe("binding a phone to its owner", () => {
  let token = "";
  beforeAll(async () => {
    token = await signUp({ username: "phone_owner" });
  });

  it("a code goes to the number; only the code coming back binds it", async () => {
    const start = await call("POST", "/v1/account/phone", { phone: "9123 4567" }, token);
    // A local number reads in the account's region (HK): +852 9123 4567.
    expect(start.status).toBe(202);
    expect(start.body).toMatchObject({ sent_to: "+852 ****4567", delivery: "memory" });
    expect(sms.sent.at(-1)!.to).toBe("+85291234567");
    expect(sms.sent.at(-1)!.text).toMatch(/^【命理大师】你的验证码是 \d{6}，10 分钟内有效。/);
    // Not bound yet: the number doesn't sign in.
    expect((await login("+852 9123 4567")).status).toBe(401);
    const code = lastCode(sms.sent.map((s) => s.text));
    const wrong = code === "000000" ? "111111" : "000000";
    const no = await call(
      "POST",
      "/v1/account/phone/verify",
      { phone: "91234567", code: wrong },
      token,
    );
    expect([no.status, no.body.code]).toEqual([400, "wrong_code"]);
    const yes = await call("POST", "/v1/account/phone/verify", { phone: "91234567", code }, token);
    expect(yes.status).toBe(200);
    expect(yes.body.phone).toBe("+85291234567");
  });

  it("the bound number signs in, written with or without +852", async () => {
    for (const written of ["+852 9123 4567", "91234567", "9123-4567", "00852 9123 4567"]) {
      expect((await login(written)).status, written).toBe(200);
    }
    // The same answer as any other failed login.
    const wrong = await login("91234567", "not the password");
    expect([wrong.status, wrong.body.detail]).toEqual([401, "the login or password is incorrect"]);
  });

  it("a number bound to one account can't be bound to another, and asking again too soon waits", async () => {
    later();
    const other = await signUp({ username: "someone_else" });
    const sent = sms.sent.length;
    const taken = await call("POST", "/v1/account/phone", { phone: "+85291234567" }, other);
    expect([taken.status, taken.body.code]).toEqual([409, "phone_taken"]);
    expect(sms.sent.length).toBe(sent); // nothing sent
    // Every request counts: the refused one was a minute's request too.
    const again = await call("POST", "/v1/account/phone", { phone: "+85298765432" }, other);
    expect([again.status, again.body.code]).toEqual([429, "wait"]);
    // Its owner binding it again: already done.
    later();
    const same = await call("POST", "/v1/account/phone", { phone: "+85291234567" }, token);
    expect([same.status, same.body.code]).toEqual([409, "already_bound"]);
  });

  it("unbinding stops the number signing in; the last way to sign in can't go", async () => {
    const gone = await call("DELETE", "/v1/account/phone", undefined, token);
    expect(gone.status).toBe(200);
    expect(gone.body.phone).toBeUndefined();
    expect((await login("91234567")).status).toBe(401);
    expect((await login("phone_owner")).status).toBe(200);
    // An account made with an email alone can't remove it: nothing would be left to sign in with.
    const emailOnly = await signUp({ email: "only@example.com" });
    const last = await call("DELETE", "/v1/account/email", undefined, emailOnly);
    expect([last.status, last.body.code]).toEqual([409, "last_login"]);
  });
});

describe("verifying an email", () => {
  it("a code by mail verifies it; a new email replaces the old one for signing in", async () => {
    const token = await signUp({ username: "mail_owner", email: "first@example.com" });
    later();
    const start = await call("POST", "/v1/account/email", { email: "first@example.com" }, token);
    expect(start.status).toBe(202);
    expect(start.body.sent_to).toBe("f***@example.com");
    const message = mail.sent.at(-1)!;
    expect(message.to).toBe("first@example.com");
    expect(message.subject).toMatch(/^命理大师验证码：\d{6}$/);
    const code = lastCode([message.subject]);
    const ok = await call(
      "POST",
      "/v1/account/email/verify",
      { email: "first@example.com", code },
      token,
    );
    expect(ok.body).toMatchObject({ email: "first@example.com", email_verified: true });

    later();
    await call("POST", "/v1/account/email", { email: "second@example.com" }, token);
    const second = lastCode([mail.sent.at(-1)!.subject]);
    const moved = await call(
      "POST",
      "/v1/account/email/verify",
      { email: "second@example.com", code: second },
      token,
    );
    expect(moved.body).toMatchObject({ email: "second@example.com", email_verified: true });
    expect((await login("first@example.com")).status).toBe(401);
    expect((await login("second@example.com")).status).toBe(200);
  });

  it("测算完成后发到邮箱: 否 by default, on only with a verified email, back to 否 when the email goes", async () => {
    const token = await signUp({ username: "reports_owner" });
    const get = await call("GET", "/v1/account/settings", undefined, token);
    expect(get.body).toEqual({
      settings: { email_reports: false },
      delivery: { mail: "memory", sms: "memory" },
    });
    const early = await call("PATCH", "/v1/account/settings", { email_reports: true }, token);
    expect([early.status, early.body.code]).toEqual([409, "email_unverified"]);
    later();
    await call("POST", "/v1/account/email", { email: "reports@example.com" }, token);
    const code = lastCode([mail.sent.at(-1)!.subject]);
    await call("POST", "/v1/account/email/verify", { email: "reports@example.com", code }, token);
    const on = await call("PATCH", "/v1/account/settings", { email_reports: true }, token);
    expect(on.body.settings).toEqual({ email_reports: true });
    expect((await call("GET", "/v1/me", undefined, token)).body.settings).toEqual({
      email_reports: true,
    });
    const bad = await call("PATCH", "/v1/account/settings", { email_reports: "yes" }, token);
    expect(bad.status).toBe(400);
    await call("DELETE", "/v1/account/email", undefined, token);
    const after = await call("GET", "/v1/account/settings", undefined, token);
    expect(after.body.settings).toEqual({ email_reports: false });
  });

  it("changing the username: taken names are refused", async () => {
    const token = await signUp({ username: "renamer" });
    const taken = await call("PUT", "/v1/account/username", { username: "LEON.WONG" }, token);
    expect([taken.status, taken.body.code]).toEqual([409, "username_taken"]);
    const ok = await call("PUT", "/v1/account/username", { username: "新名字" }, token);
    expect(ok.body.username).toBe("新名字");
    expect((await login("新名字")).status).toBe(200);
    expect((await login("renamer")).status).toBe(401);
  });
});

describe("without a provider", () => {
  it("asking for a code says the server can't deliver yet (503), and sends nothing", async () => {
    const store = new InMemoryUserStore();
    const a = new AuthService({
      pepper: PEPPER,
      tokens: new TokenService(Buffer.alloc(32, 8)),
      users: store,
    });
    await a.seedDevUser({
      login: "offline",
      password: "offline",
      country: "HK",
      locale: "zh-Hans",
    });
    const u = (await store.byUsernameLookup(a.usernameLookup("offline")))!;
    const service = new AccountService({ auth: a, mail: new NoMail(), sms: new NoSms() });
    for (const [kind, value] of [
      ["email", "x@example.com"],
      ["phone", "+85291234567"],
    ] as const) {
      const e = await service.startContact(u.id, kind, value).catch((err: unknown) => err);
      expect(e).toBeInstanceOf(AccountError);
      expect([(e as AccountError).status, (e as AccountError).code]).toEqual([
        503,
        "delivery_unavailable",
      ]);
    }
  });
});

describe("dev accounts and reviewers", () => {
  it("an account seeded before v8.2.0 (its login in the email's place) keeps its id under its username", async () => {
    const store = new InMemoryUserStore();
    const a = new AuthService({
      pepper: PEPPER,
      tokens: new TokenService(Buffer.alloc(32, 9)),
      users: store,
    });
    // As v8.1.0 seeded it: the login as the email.
    await store.put({
      id: "old-admin-id",
      email: "admin",
      email_lookup: a.emailLookup("admin"),
      social: {},
      country: "HK",
      locale: "zh-Hans",
      age_confirmed_at: "2026-10-26T00:00:00.000Z",
      created_at: "2026-10-26T00:00:00.000Z",
      password_hash: "$argon2id$v=19$m=19456,t=2,p=1$old",
    });
    await a.seedDevUser({ login: "admin", password: "admin", country: "HK", locale: "zh-Hans" });
    const now = (await store.byUsernameLookup(a.usernameLookup("admin")))!;
    expect(now).toMatchObject({ id: "old-admin-id", username: "admin" });
    expect(now.email).toBeUndefined();
    expect(await store.byEmailLookup(a.emailLookup("admin"))).toBeUndefined();
    // Seeding again changes nothing.
    await a.seedDevUser({ login: "admin", password: "admin", country: "HK", locale: "zh-Hans" });
    expect((await store.get("old-admin-id"))!.username).toBe("admin");
  });

  it("a reviewer is named by username: admin still opens 内容审核", async () => {
    await auth.seedDevUser({ login: "admin", password: "admin", country: "HK", locale: "zh-Hans" });
    const token = (await login("admin", "admin")).body.access_token;
    expect((await call("GET", "/v1/me", undefined, token)).body).toMatchObject({
      username: "admin",
      role: "admin",
    });
  });
});
