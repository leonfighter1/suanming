/**
 * HTML and CSS in 内容 (S33 WP33.4; the owner, 2026-10-31: 「同时可以让当前的改动支持HTML和CSS，不仅仅只是resource」):
 * the subset a text may hold where the app shows it as content, through ContentText (a description, a note, an
 * introduction; usage.ts finds them by their `contentKey:`). Buttons, titles and fields take words alone: there the
 * server refuses a tag, and the app takes any out, so nothing ever shows a raw `<b>`.
 *
 * - Tags: b, strong, i, em, u, s, small, br, p, span, a (href http, https or mailto), ul, ol, li.
 * - Inline CSS (`style="…"`): color and background-color from the theme (`var(--accent)` …, right in light and dark),
 *   font-weight, font-style, font-size (11 to 32 px), text-decoration.
 *
 * The app reads the same lists (`npm run sync:app` → app/lib/generated/content_rich.dart): one source.
 */

export const RICH_TAGS = [
  "b",
  "strong",
  "i",
  "em",
  "u",
  "s",
  "small",
  "br",
  "p",
  "span",
  "a",
  "ul",
  "ol",
  "li",
] as const;

/** The theme's colours a style may name (`var(--text-secondary)`), each its ThemeTokens field. */
export const RICH_COLORS: Record<string, string> = {
  text: "text",
  "text-secondary": "textSecondary",
  "text-muted": "textMuted",
  accent: "accent",
  success: "success",
  warning: "warning",
  danger: "danger",
  info: "info",
  wood: "wood",
  fire: "fire",
  earth: "earth",
  metal: "metal",
  water: "water",
  "accent-soft": "accentSoft",
  "success-soft": "successSoft",
  "warning-soft": "warningSoft",
  "danger-soft": "dangerSoft",
  "info-soft": "infoSoft",
  inset: "inset",
};

/** A style's font sizes, in px. */
export const RICH_FONT_SIZE = { min: 11, max: 32 } as const;

/** Whether [text] holds HTML: a tag or an entity. */
export const hasMarkup = (text: string) => /<\/?[A-Za-z][^>]*>|&(?:[A-Za-z]+|#\d+);/.test(text);

const VOID = new Set(["br"]);
const ENTITIES = new Set(["amp", "lt", "gt", "quot", "apos", "nbsp"]);

/** What is wrong with a style's declaration, in the panel's words; undefined when it fits. */
function styleProblem(property: string, value: string): string | undefined {
  const color = /^var\(--([a-z-]+)\)$/.exec(value)?.[1];
  switch (property) {
    case "color":
    case "background-color":
      return color && color in RICH_COLORS
        ? undefined
        : `${property} 要用主题色：${Object.keys(RICH_COLORS)
            .map((c) => `var(--${c})`)
            .join("、")}`;
    case "font-weight":
      return /^(?:bold|normal|[1-9]00)$/.test(value)
        ? undefined
        : "font-weight 要是 bold、normal 或 100 到 900";
    case "font-style":
      return /^(?:italic|normal)$/.test(value) ? undefined : "font-style 要是 italic 或 normal";
    case "font-size": {
      const px = /^(\d+(?:\.\d+)?)px$/.exec(value)?.[1];
      return px && +px >= RICH_FONT_SIZE.min && +px <= RICH_FONT_SIZE.max
        ? undefined
        : `font-size 要在 ${RICH_FONT_SIZE.min}px 到 ${RICH_FONT_SIZE.max}px 之间`;
    }
    case "text-decoration":
      return /^(?:underline|line-through|none)$/.test(value)
        ? undefined
        : "text-decoration 要是 underline、line-through 或 none";
    default:
      return `不支持的样式：${property}（可以用 color、background-color、font-weight、font-style、font-size、text-decoration）`;
  }
}

/** What is wrong with [html] for 内容, in the panel's words; undefined when the app can show it as it is. */
export function richProblem(html: string): string | undefined {
  const open: string[] = [];
  const token =
    /<(\/?)([A-Za-z][\w-]*)((?:\s+[^\s=>]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+))?)*)\s*(\/?)>|&(#\d+|[A-Za-z]+);|<|>/g;
  for (const m of html.matchAll(token)) {
    const [whole, closing, rawTag, attrs = "", selfClose, entity] = m;
    if (entity !== undefined) {
      if (!entity.startsWith("#") && !ENTITIES.has(entity)) return `不认识的字符代码：&${entity};`;
      continue;
    }
    if (rawTag === undefined) return `「${whole}」要写成 ${whole === "<" ? "&lt;" : "&gt;"}`;
    const tag = rawTag.toLowerCase();
    if (!(RICH_TAGS as readonly string[]).includes(tag)) {
      return `不支持的标签：<${tag}>（可以用 ${RICH_TAGS.map((t) => `<${t}>`).join(" ")}）`;
    }
    if (closing) {
      if (VOID.has(tag)) continue;
      if (open.at(-1) !== tag) {
        return open.length
          ? `</${tag}> 之前要先关上 <${open.at(-1)}>`
          : `</${tag}> 没有对应的 <${tag}>`;
      }
      open.pop();
      continue;
    }
    for (const a of attrs.matchAll(/([^\s=>]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g)) {
      const name = a[1]!.toLowerCase();
      const value = a[2] ?? a[3] ?? a[4] ?? "";
      if (name === "style") {
        for (const d of value
          .split(";")
          .map((x) => x.trim())
          .filter(Boolean)) {
          const at = d.indexOf(":");
          if (at < 0) return `样式「${d}」要写成 名称: 值`;
          const problem = styleProblem(d.slice(0, at).trim().toLowerCase(), d.slice(at + 1).trim());
          if (problem) return problem;
        }
      } else if (name === "href" && tag === "a") {
        if (!/^(?:https?:\/\/|mailto:)\S+$/.test(value))
          return "链接要以 https://、http:// 或 mailto: 开头";
      } else {
        return `<${tag}> 不能有 ${name}（只能有 style${tag === "a" ? " 和 href" : ""}）`;
      }
    }
    if (tag === "a" && !/\bhref\s*=/.test(attrs)) return "<a> 要有 href";
    if (!VOID.has(tag) && !selfClose) open.push(tag);
  }
  return open.length ? `<${open.at(-1)}> 没有关上` : undefined;
}
