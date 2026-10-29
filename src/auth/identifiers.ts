/**
 * The three ways into an account (owner, 2026-10-28; tech plan WP15.3): a 用户名, an email or a bound 手机号, each
 * with the account's password. How a login is told apart, how each kind is checked, the form each is looked up by,
 * and how each is shown masked.
 */

/** An email address, loosely: something@domain.tld, without spaces. */
export const EMAIL_RE = /^[^\s@]{1,64}@[^\s@]{1,253}\.[^\s@]{2,}$/;

/**
 * A username: 2–24 letters, digits, Han characters, `_`, `.` or `-`, starting with a letter or a Han character, so
 * that a username is never read as a phone number and never holds an @.
 */
export const USERNAME_RE = /^[A-Za-z\p{Script=Han}][A-Za-z0-9_.\-\p{Script=Han}]{1,23}$/u;

/** A username as stored and shown: full-width letters and digits folded (a Chinese keyboard types them), trimmed. */
export const usernameForm = (raw: string) => raw.normalize("NFKC").trim();

/** Why a username can't be used, or undefined when it can. */
export function usernameProblem(raw: unknown): string | undefined {
  if (typeof raw === "string" && USERNAME_RE.test(usernameForm(raw))) return undefined;
  return "a username is 2–24 letters, digits, Chinese characters, _ . or -, and starts with a letter or a Chinese character";
}

/** What a username is looked up by: Admin, ADMIN and ａｄｍｉｎ are all admin. */
export const usernameKey = (raw: string) => usernameForm(raw).toLowerCase();

/** What an email is looked up by, as since v1: trimmed, lower case. */
export const emailKey = (raw: string) => raw.trim().toLowerCase();

export type LoginKind = "email" | "phone" | "username";

const PHONE_CHARS = /^\+?[\d\s().-]+$/;

/** With an @ it's an email; digits (with spaces, dashes, brackets, a leading +) a phone; anything else a username. */
export function loginKind(raw: string): LoginKind {
  const s = raw.trim();
  if (s.includes("@")) return "email";
  if (PHONE_CHARS.test(s) && /\d/.test(s)) return "phone";
  return "username";
}

/**
 * Calling codes whose national numbers this app checks: the served regions first, then where users of these regions
 * often hold a number. Any other code is taken as written, within E.164's 15 digits.
 */
export const PHONE_PLANS: readonly { region: string; code: string; national: RegExp }[] = [
  { region: "HK", code: "852", national: /^\d{8}$/ },
  { region: "TW", code: "886", national: /^\d{9}$/ },
  { region: "SG", code: "65", national: /^\d{8}$/ },
  { region: "MY", code: "60", national: /^\d{9,10}$/ },
  { region: "MO", code: "853", national: /^\d{8}$/ },
  { region: "CN", code: "86", national: /^\d{11}$/ },
  { region: "US", code: "1", national: /^\d{10}$/ },
  { region: "CA", code: "1", national: /^\d{10}$/ },
  { region: "GB", code: "44", national: /^\d{10}$/ },
  { region: "AU", code: "61", national: /^\d{9}$/ },
];

/** The plan of an international number (digits only, no +): the longest calling code it starts with. */
function planOf(digits: string) {
  return PHONE_PLANS.filter((p) => digits.startsWith(p.code)).sort(
    (a, b) => b.code.length - a.code.length,
  )[0];
}

/**
 * A national number checked against its plan, a trunk 0 dropped first (Taiwan's 09…, Malaysia's 01…, the UK's
 * 07…): no number in these plans starts with 0 itself, and Malaysia's 012-345 6789 would otherwise fit as written.
 */
function national(plan: (typeof PHONE_PLANS)[number], digits: string): string | undefined {
  if (digits.startsWith("0") && plan.national.test(digits.slice(1))) return digits.slice(1);
  return plan.national.test(digits) ? digits : undefined;
}

/**
 * A phone number in E.164 (`+85291234567`), or undefined when it isn't one. It may be written internationally (`+852
 * 9123 4567`, `00852…`) or, given the account's region, as a local number (`9123 4567`, Taiwan's `0912 345 678`).
 */
export function normalizePhone(raw: string, region?: string): string | undefined {
  const s = raw.trim();
  if (!PHONE_CHARS.test(s)) return undefined;
  let digits = s.replace(/\D/g, "");
  if (s.startsWith("+") || digits.startsWith("00")) {
    if (!s.startsWith("+")) digits = digits.slice(2);
    const plan = planOf(digits);
    if (plan) {
      const rest = national(plan, digits.slice(plan.code.length));
      if (!rest) return undefined;
      digits = plan.code + rest;
    }
  } else {
    const plan = PHONE_PLANS.find((p) => p.region === region);
    const rest = plan && national(plan, digits);
    if (!plan || !rest) return undefined;
    digits = plan.code + rest;
  }
  return /^[1-9]\d{7,14}$/.test(digits) ? `+${digits}` : undefined;
}

/**
 * The numbers a phone login may mean. Written internationally, one; written locally, its reading in each region
 * whose plan fits (an 8-digit number is a Hong Kong, Singapore or Macao number). Login takes the one bound.
 */
export function phoneCandidates(raw: string): string[] {
  const s = raw.trim();
  const digits = s.replace(/\D/g, "");
  if (s.startsWith("+") || digits.startsWith("00")) {
    const one = normalizePhone(s);
    return one ? [one] : [];
  }
  const all = PHONE_PLANS.map((p) => normalizePhone(s, p.region));
  return [...new Set(all.filter((p): p is string => p !== undefined))];
}

/** A phone number as shown to its owner elsewhere than their own account page: +852 ****4567. */
export function maskPhone(e164: string): string {
  const digits = e164.replace(/\D/g, "");
  const plan = planOf(digits);
  const code = plan?.code ?? digits.slice(0, 2);
  const rest = digits.slice(code.length);
  return `+${code} ${"*".repeat(Math.max(0, rest.length - 4))}${rest.slice(-4)}`;
}

/** An email as shown in a confirmation: s***@example.com. */
export function maskEmail(email: string): string {
  const [local = "", domain = ""] = email.split("@");
  return `${local.slice(0, 1)}***@${domain}`;
}
