/**
 * A document as the body of a mail (tech plan WP15.4; light and dark since S25): a page in the app's colours. Every
 * light style is inline, as a mail program may drop a style sheet; the dark theme is in a style block under
 * `prefers-color-scheme: dark` (and under Outlook's own dark marks), so a mail program in dark mode shows the page dark,
 * as the app follows the system. The same as plain text for the programs that show only text. It takes the neutral
 * document the Word and PDF renderers take (document.ts), and the parts a message's template adds (a title, a code box).
 */
import type { Doc, DocBlock } from "./document.js";

/**
 * The app's colours in both themes (ThemeTokens in app/lib/presentation/tokens.dart). test/mail-palette.test.ts reads
 * the Dart file and keeps these the same.
 */
export const MAIL_PALETTE = {
  light: {
    background: "#F6F3EE",
    card: "#FFFFFF",
    inset: "#F0EBE4",
    border: "#E3DCD2",
    borderStrong: "#C9BFB2",
    text: "#1F1A16",
    textSecondary: "#5A5049",
    textMuted: "#6F655D",
    accent: "#8A3B2E",
    accentSoft: "#F6E7E2",
  },
  dark: {
    background: "#121010",
    card: "#1C1917",
    inset: "#27221F",
    border: "#37302B",
    borderStrong: "#50463F",
    text: "#F2EDE7",
    textSecondary: "#C3B9AF",
    textMuted: "#A0958B",
    accent: "#E6917D",
    accentSoft: "#3D2621",
  },
} as const;
type Tone = keyof typeof MAIL_PALETTE.light;

const L = MAIL_PALETTE.light;
const FONT = `'PingFang SC','PingFang TC','Microsoft YaHei','Microsoft JhengHei','Noto Sans CJK SC','Noto Sans SC',sans-serif`;

/** What each class colours, from which token: the light value is inline, the dark one in the style block. */
const CLASSES: Record<string, [property: string, tone: Tone][]> = {
  "m-bg": [["background-color", "background"]],
  "m-card": [
    ["background-color", "card"],
    ["border-color", "border"],
  ],
  "m-ink": [["color", "text"]],
  "m-ink2": [["color", "textSecondary"]],
  "m-muted": [["color", "textMuted"]],
  "m-accent": [["color", "accent"]],
  // A box's accent bar (an example), a heading's rule, a quote's bar.
  "m-bar": [["border-color", "accent"]],
  "m-rule": [["border-color", "border"]],
  "m-quote": [["border-color", "borderStrong"]],
  "m-tint": [["background-color", "accentSoft"]],
  "m-inset": [["background-color", "inset"]],
  "m-code": [
    ["background-color", "accentSoft"],
    ["color", "accent"],
  ],
};

/** The dark theme's rules under [prefix]: every class with its dark value. */
const darkRules = (prefix: string) =>
  Object.entries(CLASSES)
    .map(
      ([cls, props]) =>
        `${prefix} .${cls}{${props.map(([p, t]) => `${p}:${MAIL_PALETTE.dark[t]} !important`).join(";")}}`,
    )
    .join("");

/**
 * The style block. Light is the page's own (inline); dark follows the reader's system, unless the page is marked
 * (`data-scheme`, a preview's choice). Outlook.com marks what it darkened itself (`data-ogsc` text, `data-ogsb`
 * backgrounds): the app's dark colours take their place.
 */
export const MAIL_CSS =
  `:root{color-scheme:light dark;supported-color-schemes:light dark}` +
  `:root[data-scheme="light"]{color-scheme:light}:root[data-scheme="dark"]{color-scheme:dark}` +
  `@media (prefers-color-scheme:dark){${darkRules(':root:not([data-scheme="light"])')}}` +
  darkRules(':root[data-scheme="dark"]') +
  darkRules("[data-ogsc]") +
  darkRules("[data-ogsb]");

const esc = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const lines = (s: string) => esc(s).split("\n").join("<br>");

/** An element's classes and its light style. */
const attrs = (classes: string, style: string) => `class="${classes}" style="${style}"`;

const BLOCK: Record<Exclude<DocBlock["type"], "bullet" | "kv" | "divider">, [string, string]> = {
  h2: [
    "m-accent m-rule",
    `font-size:18px;color:${L.accent};margin:28px 0 8px;padding-bottom:4px;border-bottom:1px solid ${L.border}`,
  ],
  h3: ["m-ink", `font-size:16px;color:${L.text};margin:18px 0 6px`],
  meta: ["m-muted", `color:${L.textMuted};font-size:13px;margin:4px 0`],
  p: ["m-ink", `color:${L.text};margin:8px 0`],
  summary: ["m-ink", `color:${L.text};font-weight:bold;margin:8px 0`],
  term: ["m-accent", `color:${L.accent};font-weight:bold;margin:14px 0 4px`],
  example: [
    "m-ink m-tint m-bar",
    `color:${L.text};background-color:${L.accentSoft};border-left:3px solid ${L.accent};padding:8px 12px;margin:6px 0 14px`,
  ],
  quote: [
    "m-ink2 m-quote",
    `color:${L.textSecondary};border-left:3px solid ${L.borderStrong};padding:4px 12px;margin:8px 0`,
  ],
  note: ["m-muted", `color:${L.textMuted};font-size:12px;margin:6px 0`],
  question: [
    "m-ink m-inset",
    `color:${L.text};background-color:${L.inset};border-radius:6px;padding:8px 12px;margin:14px 0 4px`,
  ],
};

const TAGS: Partial<Record<DocBlock["type"], string>> = { h2: "h2", h3: "h3", quote: "blockquote" };

/** A part of a message's page: a document's block, the page's title, or a code shown large (a verification code). */
export type MailPart = DocBlock | { type: "title" | "code"; text: string };

function htmlPart(b: MailPart): string {
  switch (b.type) {
    case "title":
      return `<h1 ${attrs("m-ink", `font-size:22px;line-height:1.4;color:${L.text};margin:0 0 8px`)}>${lines(b.text)}</h1>`;
    case "code":
      return (
        `<div ${attrs("m-code", `background-color:${L.accentSoft};color:${L.accent};border-radius:12px;padding:16px;margin:12px 0;` + `text-align:center;font-size:28px;font-weight:bold;letter-spacing:6px`)}>` +
        `${lines(b.text)}</div>`
      );
    case "divider":
      return `<hr ${attrs("m-rule", `border:none;border-top:1px solid ${L.border};margin:24px 0`)}>`;
    case "kv": {
      const rows = (b.rows ?? [])
        .map(
          ([k, v]) =>
            `<tr><td ${attrs("m-muted", `color:${L.textMuted};padding:4px 16px 4px 0;white-space:nowrap;vertical-align:top`)}>${lines(k)}</td>` +
            `<td ${attrs("m-ink", `color:${L.text};padding:4px 0;vertical-align:top`)}>${lines(v)}</td></tr>`,
        )
        .join("");
      return `<table role="presentation" style="border-collapse:collapse;margin:8px 0 12px">${rows}</table>`;
    }
    default: {
      const [classes, style] = BLOCK[b.type as keyof typeof BLOCK];
      const tag = TAGS[b.type] ?? (b.type === "example" || b.type === "question" ? "div" : "p");
      return `<${tag} ${attrs(classes, style)}>${lines(b.text ?? "")}</${tag}>`;
    }
  }
}

/** The parts as HTML, bullets gathered into lists. */
function htmlParts(parts: MailPart[]): string {
  const body: string[] = [];
  let list: string[] = [];
  const flush = () => {
    if (list.length)
      body.push(
        `<ul ${attrs("m-ink", `color:${L.text};margin:8px 0;padding-left:22px`)}>${list.join("")}</ul>`,
      );
    list = [];
  };
  for (const b of parts) {
    if (b.type === "bullet") {
      list.push(`<li style="margin:4px 0">${lines(b.text ?? "")}</li>`);
      continue;
    }
    flush();
    body.push(htmlPart(b));
  }
  flush();
  return body.join("");
}

/**
 * A message as one page: the brand above a card on the page's background, the parts in the card. [scheme] marks the
 * page light or dark (a preview's choice); without it the reader's system decides. Tables, as mail programs lay
 * pages out with them; the card at most 600 wide.
 */
export function renderMailPage(o: {
  title: string;
  parts: MailPart[];
  brand?: string;
  lang?: string;
  scheme?: "light" | "dark";
}): string {
  const scheme = o.scheme ? ` data-scheme="${o.scheme}"` : "";
  return (
    `<!doctype html><html lang="${esc(o.lang ?? "zh-CN")}"${scheme}><head><meta charset="utf-8">` +
    `<meta name="viewport" content="width=device-width,initial-scale=1">` +
    `<meta name="color-scheme" content="light dark"><meta name="supported-color-schemes" content="light dark">` +
    `<title>${esc(o.title)}</title><style>${MAIL_CSS}</style></head>` +
    `<body ${attrs("m-bg", `margin:0;padding:0;background-color:${L.background}`)}>` +
    `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" ${attrs("m-bg", `background-color:${L.background}`)}>` +
    `<tr><td align="center" style="padding:24px 12px">` +
    `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px"><tr>` +
    `<td ${attrs("m-accent", `padding:0 4px 12px;font-family:${FONT};font-size:13px;font-weight:bold;letter-spacing:2px;color:${L.accent}`)}>` +
    `${esc(o.brand ?? "命理大师")}</td></tr><tr>` +
    `<td ${attrs("m-card m-ink", `background-color:${L.card};border:1px solid ${L.border};border-radius:20px;padding:28px 24px;` + `font-family:${FONT};color:${L.text};font-size:15px;line-height:1.75`)}>` +
    htmlParts(o.parts) +
    `</td></tr></table></td></tr></table></body></html>`
  );
}

/** A document's page (WP15.4): its title, its subtitle in grey, then its blocks. */
export function renderHtml(
  doc: Doc,
  o: { brand?: string; scheme?: "light" | "dark" } = {},
): string {
  return renderMailPage({
    title: doc.title,
    parts: [
      { type: "title", text: doc.title },
      ...(doc.subtitle ? [{ type: "meta" as const, text: doc.subtitle }] : []),
      ...doc.blocks,
    ],
    ...o,
  });
}

function textBlock(b: MailPart): string {
  const indent = (s: string) =>
    s
      .split("\n")
      .map((l) => `  ${l}`)
      .join("\n");
  switch (b.type) {
    case "h2":
      return `■ ${b.text ?? ""}`;
    case "kv":
      return (b.rows ?? []).map(([k, v]) => `${k}：${v}`).join("\n");
    case "bullet":
      return `· ${b.text ?? ""}`;
    case "example":
    case "quote":
    case "code":
      return indent(b.text ?? "");
    case "divider":
      return "────────────";
    default:
      return b.text ?? "";
  }
}

/** Parts as plain text: a blank line between them, list items kept together. */
export function renderMailText(parts: MailPart[]): string {
  let text = "";
  let prev: MailPart["type"] | undefined;
  for (const b of parts) {
    if (prev !== undefined) text += b.type === "bullet" && prev === "bullet" ? "\n" : "\n\n";
    text += textBlock(b);
    prev = b.type;
  }
  return `${text}\n`;
}

/** The same as plain text: the title and subtitle, then the blocks a blank line apart, list items together. */
export function renderText(doc: Doc): string {
  const head = doc.subtitle ? `${doc.title}\n${doc.subtitle}` : doc.title;
  return doc.blocks.length ? `${head}\n\n${renderMailText(doc.blocks)}` : `${head}\n`;
}
