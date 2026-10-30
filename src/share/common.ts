/**
 * What the share images share (S28 WP28.5; docs/refactor-plan.md F6): the canvas, its colours, the brand, and text set
 * in the share font. Each image keeps its own method's label and layout.
 */
import sharp from "sharp";
import type { Locale } from "../ai/terms.js";
import type { ShareFont } from "./font.js";

export const W = 1080;
export const H = 1350;
export const MARGIN = 60;
export const PAPER = "#fbf3ec";
export const INK = "#3b2a22";
export const ACCENT = "#8a3b2e"; // the app's accent (AppColors.accent)

export const BRAND: Record<Locale, string> = {
  "zh-Hans": "命理大师",
  "zh-Hant": "命理大師",
  en: "Mingli Master",
};

/** Pango markup needs these escaped; a reading's text may hold any of them. */
export const escape = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

/** At most [max] characters, cut at a character, with an ellipsis. */
export const clip = (s: string, max: number) =>
  [...s].length <= max ? s : `${[...s].slice(0, max - 1).join("")}…`;

/** [markup] set in [font] at [px], [width] wide and centred: its PNG and its size. */
export async function text(
  font: ShareFont,
  markup: string,
  width: number,
  px: number,
  color = INK,
) {
  const buf = await sharp({
    text: {
      text: `<span foreground="${color}" size="${px * 1024}">${markup}</span>`,
      font: font.family,
      fontfile: font.file,
      width,
      rgba: true,
      dpi: 72,
      align: "centre",
      wrap: "word-char",
    },
  })
    .png()
    .toBuffer();
  const { width: w = 0, height: h = 0 } = await sharp(buf).metadata();
  return { buf, w, h };
}
