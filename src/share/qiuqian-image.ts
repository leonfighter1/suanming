/**
 * A 求籤 reading as a share image (v4.3.0, WP6.1; the owner's phase document: the server makes the share
 * image, with a watermark and the disclaimer). Its own layout (rule 8). 1080 × 1350 JPEG:
 *   - 命理大師 · 求籤 at the top, in the reader's script;
 *   - the 籤詩 slip: the set, the lot's title and label, and its four lines;
 *   - the main point of the reading of the poem;
 *   - the report's own AI label (the disclaimer) and the watermark with the date.
 * Never the question, the life context or a name, nor the section that answers the question (it could
 * repeat it): those stay private.
 */
import sharp, { type OverlayOptions } from "sharp";
import type { Report } from "../ai/index.js";
import { lotBrief } from "../ai/qiuqian.js";
import type { Locale } from "../ai/terms.js";
import type { ChartFact } from "../chart-fact/index.js";
import { ACCENT, BRAND, clip, escape, H, MARGIN, PAPER, text, W } from "./common.js";
import type { ShareFont } from "./font.js";

const SLIP = "#f3dca6"; // 籤紙, the yellow paper a temple prints its lots on

const METHOD: Record<Locale, string> = {
  "zh-Hans": "求签",
  "zh-Hant": "求籤",
  en: "Fortune Sticks",
};

/** The texts the image shows, in order (exported so a test can check what is, and isn't, on it). */
export function qiuqianShareTexts(report: Report, chart: ChartFact, locale: Locale) {
  const lot = lotBrief(chart, locale);
  const poem = report.layers?.interpretation.find((s) => s.topic === "qiuqian_poem");
  const point = poem?.summary ?? poem?.paragraphs[0]?.text ?? "";
  return {
    title: `${BRAND[locale]} · ${METHOD[locale]}`,
    set: lot.set,
    lot: `${lot.title} · ${lot.ganzhi}`,
    lines: lot.lines.map((l) => l.text),
    point: clip(point, 90),
    label: report.layers?.expectation.ai_label ?? "",
    mark: `${BRAND[locale]} · ${report.created_at.slice(0, 10)}`,
  };
}

/** The share image of a passed 求籤 reading, as a JPEG. */
export async function renderQiuqianShare(
  report: Report,
  chart: ChartFact,
  opts: { font: ShareFont; locale: Locale },
): Promise<Buffer> {
  const t = qiuqianShareTexts(report, chart, opts.locale);
  const layers: OverlayOptions[] = [];
  const centre = (w: number) => Math.round((W - w) / 2);

  const title = await text(opts.font, escape(t.title), W - 2 * MARGIN, 52, ACCENT);
  layers.push({ input: title.buf, top: 70, left: centre(title.w) });

  // The watermark at the foot, the label above it however many lines it wraps to (English: two).
  const mark = await text(opts.font, escape(t.mark), W - 2 * MARGIN, 24, ACCENT);
  const markTop = H - 60 - mark.h;
  layers.push({ input: mark.buf, top: markTop, left: centre(mark.w) });
  const label = await text(opts.font, escape(t.label), W - 2 * MARGIN, 24);
  const labelTop = markTop - 20 - label.h;
  layers.push({ input: label.buf, top: labelTop, left: centre(label.w) });

  // The slip: the set and the lot's title above its four lines, on 籤紙 with an accent border. It and the
  // point sit in the middle of the room between the title and the label.
  const slipW = 820;
  const inner = slipW - 120;
  const set = await text(opts.font, escape(t.set), inner, 28);
  const lot = await text(opts.font, escape(t.lot), inner, 42, ACCENT);
  const lines = await text(
    opts.font,
    `<span line_height="1.25">${t.lines.map(escape).join("\n")}</span>`,
    inner,
    64,
  );
  const point = t.point
    ? await text(opts.font, escape(t.point), W - 2 * MARGIN - 40, 34)
    : undefined;
  const slipH = 64 + set.h + 18 + lot.h + 44 + lines.h + 64;
  const room = { top: 190, bottom: labelTop - 40 };
  const block = slipH + (point ? 44 + point.h : 0);
  const slipTop = room.top + Math.max(0, Math.round((room.bottom - room.top - block) / 2));
  const slip = Buffer.from(
    `<svg width="${slipW}" height="${slipH}"><rect x="4" y="4" width="${slipW - 8}" height="${slipH - 8}" rx="18" fill="${SLIP}" stroke="${ACCENT}" stroke-width="6"/><rect x="22" y="22" width="${slipW - 44}" height="${slipH - 44}" rx="10" fill="none" stroke="${ACCENT}" stroke-width="2"/></svg>`,
  );
  layers.push({ input: slip, top: slipTop, left: centre(slipW) });
  let y = slipTop + 64;
  layers.push({ input: set.buf, top: y, left: centre(set.w) });
  y += set.h + 18;
  layers.push({ input: lot.buf, top: y, left: centre(lot.w) });
  y += lot.h + 44;
  layers.push({ input: lines.buf, top: y, left: centre(lines.w) });
  if (point) layers.push({ input: point.buf, top: slipTop + slipH + 44, left: centre(point.w) });

  return sharp({ create: { width: W, height: H, channels: 4, background: PAPER } })
    .composite(layers)
    .jpeg({ quality: 85 })
    .toBuffer();
}
