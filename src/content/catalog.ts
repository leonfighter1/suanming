/**
 * 内容管理 (S29; owner, 2026-10-30: 「create a CMS system, that can modify the resources of context for different places of
 * the text, images … extract as much text as possible into the content integration pages」): what staff can change.
 *
 * The texts are the app's own, every one it shows: their keys, defaults and placeholders come from its message files
 * (app/lib/l10n/app_zh.arb for 简体, app_zh_Hant.arb for 繁體), read here, so they keep one source. Left out: a message
 * with a plural or a select (its syntax is easy to break) and one whose placeholder the app formats (a date, a sum).
 * The images are the ones the app takes from content: the banners' art and the introduction page's mark.
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

export const CONTENT_LOCALES = ["zh-Hans", "zh-Hant"] as const;
export type ContentLocale = (typeof CONTENT_LOCALES)[number];

const ARB: Record<ContentLocale, string> = {
  "zh-Hans": fileURLToPath(new URL("../../app/lib/l10n/app_zh.arb", import.meta.url)),
  "zh-Hant": fileURLToPath(new URL("../../app/lib/l10n/app_zh_Hant.arb", import.meta.url)),
};

/** A text staff can change. */
export interface ContentText {
  key: string;
  /** Where it shows, as the key's first word says: home, tarot, points … */
  area: string;
  /** Its placeholders, {name} …: a change keeps each of them, no more. */
  placeholders: string[];
  defaults: Record<ContentLocale, string>;
}

export const CONTENT_IMAGES = [
  { key: "banner", label: "横幅背景（命理罗盘）" },
  { key: "logo", label: "介绍页标志" },
] as const;
export type ContentImageKey = (typeof CONTENT_IMAGES)[number]["key"];
export const isContentImage = (key: string): key is ContentImageKey =>
  CONTENT_IMAGES.some((i) => i.key === key);

/** Where an image staff put in is served; its time ([at]) gives each version an address of its own. */
export const contentImageUrl = (key: string, at: string) =>
  `/v1/content/images/${key}?v=${encodeURIComponent(at)}`;

/** Whether [data] begins as an image of [type] does: a PNG's, a JPEG's or a WebP's signature. */
export function looksLike(type: string, data: Buffer): boolean {
  if (type === "image/png")
    return data.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  if (type === "image/jpeg") return data.subarray(0, 3).equals(Buffer.from([255, 216, 255]));
  if (type === "image/webp") {
    return data.toString("latin1", 0, 4) === "RIFF" && data.toString("latin1", 8, 12) === "WEBP";
  }
  return false;
}

/** The types an image may have; its size and a text's length are 设置's (content.*, S32). */
export const CONTENT_IMAGE_TYPES = ["image/png", "image/jpeg", "image/webp"] as const;

/** A message's placeholders, {name} …, each once, in order. */
export function placeholdersOf(text: string): string[] {
  return [...new Set([...text.matchAll(/\{(\w+)\}/g)].map((m) => m[1]!))];
}

/** A key's area: its first word (homeTarot → home). */
export const areaOf = (key: string) => /^[a-z]+/.exec(key)?.[0] ?? key;

let texts: ContentText[] | undefined;

/** Every text staff can change, read once from the app's message files. */
export function contentTexts(): ContentText[] {
  if (texts) return texts;
  const read = (l: ContentLocale) =>
    JSON.parse(readFileSync(ARB[l], "utf8")) as Record<string, unknown>;
  const hans = read("zh-Hans");
  const hant = read("zh-Hant");
  const out: ContentText[] = [];
  for (const [key, value] of Object.entries(hans)) {
    const other = hant[key];
    if (key.startsWith("@") || typeof value !== "string" || typeof other !== "string") continue;
    if (/\{\s*\w+\s*,\s*(plural|select)\b/.test(value)) continue;
    const meta = hans[`@${key}`] as
      { placeholders?: Record<string, { format?: string }> } | undefined;
    if (Object.values(meta?.placeholders ?? {}).some((p) => p.format)) continue;
    out.push({
      key,
      area: areaOf(key),
      placeholders: placeholdersOf(value),
      defaults: { "zh-Hans": value, "zh-Hant": other },
    });
  }
  return (texts = out);
}

/** The text staff can change under [key], if any. */
export const contentText = (key: string) => contentTexts().find((t) => t.key === key);
