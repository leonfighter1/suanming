import { readFileSync } from "node:fs";

export type Locale = "zh-Hant" | "zh-Hans" | "en";
export const LOCALES: readonly Locale[] = ["zh-Hant", "zh-Hans", "en"];

interface TermTable {
  version: string;
  terms: Record<string, Record<Locale, string>>;
}

let cached: TermTable | undefined;
export function loadTerms(): TermTable {
  cached ??= JSON.parse(
    readFileSync(new URL("../../i18n/terms.json", import.meta.url), "utf8"),
  ) as TermTable;
  return cached;
}

/** Display form of an engine term (canonical key) for a locale; unknown terms pass through. */
export function term(key: string, locale: Locale): string {
  return loadTerms().terms[key]?.[locale] ?? key;
}

/**
 * Character-wise display of a short engine string (e.g. 农历 month "闰二月" → "閏二月").
 * Only for short fixed vocabularies like month names and 生肖, never free text.
 */
export function termChars(text: string, locale: Locale): string {
  if (locale === "en") return text;
  return [...text].map((ch) => loadTerms().terms[ch]?.[locale] ?? ch).join("");
}

/** Glossary of the protected terms that occur in `text`, for prompt injection. */
export function glossaryFor(text: string, locale: Locale): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(loadTerms().terms)) {
    if (k.length > 1 && text.includes(k)) out[k] = v[locale];
  }
  return out;
}

/**
 * Force protected terms into the locale's form, e.g. 劫财 → 劫財 in zh-Hant.
 * Only multi-character terms are rewritten: single characters (阳, 绝, 养) are
 * too ambiguous inside free text and are checked by review instead.
 */
export function normalizeTerms(text: string, locale: Locale): { text: string; fixes: string[] } {
  if (locale === "en") return { text, fixes: [] };
  const other: Locale = locale === "zh-Hant" ? "zh-Hans" : "zh-Hant";
  const fixes: string[] = [];
  let out = text;
  for (const forms of Object.values(loadTerms().terms)) {
    const wrong = forms[other];
    const right = forms[locale];
    if (wrong.length > 1 && wrong !== right && out.includes(wrong)) {
      out = out.split(wrong).join(right);
      fixes.push(`${wrong}→${right}`);
    }
  }
  return { text: out, fixes };
}
