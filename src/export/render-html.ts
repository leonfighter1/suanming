/**
 * A document as the body of a mail (tech plan WP15.4): HTML with every style inline, as mail programs drop style
 * sheets, and the same as plain text for the programs that show only text. It takes the neutral document the Word
 * and PDF renderers take (document.ts), in the same colours.
 */
import type { Doc, DocBlock } from "./document.js";

const ACCENT = "#8A3B2E"; // the app's accent
const INK = "#3B2A22";
const MUTED = "#7A6A62";
const TINT = "#F6E4DE";
const FONT = `'PingFang SC','PingFang TC','Microsoft YaHei','Microsoft JhengHei','Noto Sans CJK SC','Noto Sans SC',sans-serif`;

const esc = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const lines = (s: string) => esc(s).split("\n").join("<br>");

const STYLE: Record<Exclude<DocBlock["type"], "bullet" | "kv" | "divider">, string> = {
  h2: `font-size:18px;color:${ACCENT};margin:28px 0 8px;padding-bottom:4px;border-bottom:1px solid ${TINT}`,
  h3: "font-size:16px;margin:18px 0 6px",
  meta: `color:${MUTED};font-size:13px;margin:4px 0`,
  p: "margin:8px 0",
  summary: "font-weight:bold;margin:8px 0",
  term: `color:${ACCENT};font-weight:bold;margin:14px 0 4px`,
  example: `background:${TINT};border-left:3px solid ${ACCENT};padding:8px 12px;margin:6px 0 14px`,
  quote: `border-left:3px solid #CFC4BE;color:#55463E;padding:4px 12px;margin:8px 0`,
  note: `color:${MUTED};font-size:12px;margin:6px 0`,
  question: "background:#F1ECE9;border-radius:6px;padding:8px 12px;margin:14px 0 4px",
};

const TAGS: Partial<Record<DocBlock["type"], string>> = { h2: "h2", h3: "h3", quote: "blockquote" };

function htmlBlock(b: DocBlock): string {
  if (b.type === "divider")
    return `<hr style="border:none;border-top:1px solid #E5DCD7;margin:24px 0">`;
  if (b.type === "kv") {
    const rows = (b.rows ?? [])
      .map(
        ([k, v]) =>
          `<tr><td style="color:${MUTED};padding:4px 16px 4px 0;white-space:nowrap;vertical-align:top">${lines(k)}</td>` +
          `<td style="padding:4px 0;vertical-align:top">${lines(v)}</td></tr>`,
      )
      .join("");
    return `<table role="presentation" style="border-collapse:collapse;margin:8px 0 12px">${rows}</table>`;
  }
  const tag = TAGS[b.type] ?? (b.type === "example" || b.type === "question" ? "div" : "p");
  return `<${tag} style="${STYLE[b.type as keyof typeof STYLE]}">${lines(b.text ?? "")}</${tag}>`;
}

/** The whole message as one HTML page: the title, the subtitle, then every block, bullets gathered into lists. */
export function renderHtml(doc: Doc): string {
  const body: string[] = [];
  let list: string[] = [];
  const flush = () => {
    if (list.length) body.push(`<ul style="margin:8px 0;padding-left:22px">${list.join("")}</ul>`);
    list = [];
  };
  for (const b of doc.blocks) {
    if (b.type === "bullet") {
      list.push(`<li style="margin:4px 0">${lines(b.text ?? "")}</li>`);
      continue;
    }
    flush();
    body.push(htmlBlock(b));
  }
  flush();
  return (
    `<!doctype html><html><head><meta charset="utf-8">` +
    `<meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(doc.title)}</title></head>` +
    `<body style="margin:0;padding:0;background:#FBF7F4">` +
    `<div style="max-width:640px;margin:0 auto;padding:24px 20px;font-family:${FONT};color:${INK};font-size:15px;line-height:1.7">` +
    `<h1 style="font-size:22px;color:${ACCENT};margin:0 0 4px">${esc(doc.title)}</h1>` +
    (doc.subtitle
      ? `<p style="color:${MUTED};font-size:13px;margin:0 0 16px">${esc(doc.subtitle)}</p>`
      : "") +
    body.join("") +
    `</div></body></html>`
  );
}

function textBlock(b: DocBlock): string {
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
      return indent(b.text ?? "");
    case "divider":
      return "────────────";
    default:
      return b.text ?? "";
  }
}

/** The same as plain text: a blank line between blocks, list items and table rows kept together. */
export function renderText(doc: Doc): string {
  let text = doc.subtitle ? `${doc.title}\n${doc.subtitle}` : doc.title;
  let prev: DocBlock["type"] | undefined;
  for (const b of doc.blocks) {
    text += (b.type === "bullet" && prev === "bullet" ? "\n" : "\n\n") + textBlock(b);
    prev = b.type;
  }
  return `${text}\n`;
}
