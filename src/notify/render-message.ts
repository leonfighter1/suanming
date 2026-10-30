/**
 * A message from its template (tech plan S25): a mail as the app's page, light and dark (render-html.ts), with its
 * plain text; an SMS as its text, with its length and how many messages it takes.
 */
import type { Locale } from "../ai/terms.js";
import type { DocBlock } from "../export/document.js";
import { renderMailPage, renderMailText, type MailPart } from "../export/render-html.js";
import { fill, parseMarkup } from "./markup.js";
import { brandOf, type TemplateSpec, type TemplateText } from "./templates.js";

/** A message's own parts: a report's blocks, the records' titles. */
export interface MessageParts {
  report?: DocBlock[];
  records?: string[];
}

export interface RenderedMessage {
  subject?: string;
  text: string;
  html?: string;
  /** An SMS: its length in characters and the messages it takes. */
  sms?: { length: number; segments: number };
}

/**
 * How many messages an SMS takes: 160 characters in one (153 a part when split) for plain ASCII, 70 (67) once any
 * other character is in it, as Chinese always is.
 */
export function smsSegments(text: string): { length: number; segments: number } {
  const length = [...text].length;
  const ascii = /^[\x20-\x7E\n\r]*$/.test(text);
  const [one, part] = ascii ? [160, 153] : [70, 67];
  return { length, segments: length === 0 ? 0 : length <= one ? 1 : Math.ceil(length / part) };
}

const htmlLang = (l: Locale) => (l === "zh-Hant" ? "zh-TW" : l === "en" ? "en" : "zh-CN");

/**
 * [spec]'s message from [t] and the values: [scheme] marks a mail's page light or dark (a preview); a sent mail has
 * none, so the reader's system decides.
 */
export function renderMessage(
  spec: TemplateSpec,
  t: TemplateText,
  o: {
    vars: Record<string, string>;
    parts?: MessageParts;
    locale: Locale;
    scheme?: "light" | "dark";
  },
): RenderedMessage {
  if (spec.channel === "sms") {
    const text = fill(t.body, o.vars).trim();
    return { text, sms: smsSegments(text) };
  }
  const parts: Record<string, MailPart[]> = {};
  if (spec.variables.some((v) => v.name === "report")) parts.report = o.parts?.report ?? [];
  if (spec.variables.some((v) => v.name === "records")) {
    parts.records = (o.parts?.records ?? []).map((text) => ({ type: "bullet" as const, text }));
  }
  const subject = fill(t.subject ?? "", o.vars).trim();
  const body = parseMarkup(t.body, o.vars, parts);
  return {
    subject,
    text: renderMailText(body),
    html: renderMailPage({
      title: subject,
      parts: body,
      brand: brandOf(o.locale),
      lang: htmlLang(o.locale),
      ...(o.scheme && { scheme: o.scheme }),
    }),
  };
}
