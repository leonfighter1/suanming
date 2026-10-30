/**
 * A tarot reading as a share image (tech plan S7, WP7.1; the owner's phase document: the server makes
 * the share image, with a watermark and the disclaimer). 1080 × 1350 JPEG:
 *   - 命理大师 · 塔羅 at the top, in the reader's script;
 *   - every card with its position, its name and 逆位 when reversed (drawn upside down);
 *   - the 综合解读's main point;
 *   - the report's own AI label (the disclaimer) and the watermark with the date.
 * Never the question, the life context or a name: those stay private.
 */
import { fileURLToPath } from "node:url";
import sharp, { type OverlayOptions } from "sharp";
import type { Report } from "../ai/index.js";
import { term, type Locale } from "../ai/terms.js";
import type { ChartFact } from "../chart-fact/index.js";
import { DECK, POSITION_LABELS } from "../engines/tarot/deck.js";
import { ACCENT, BRAND, clip, escape, H, MARGIN, PAPER, text, W } from "./common.js";
import type { ShareFont } from "./font.js";

const GAP = 30;
const ART = new URL("../../app/assets/tarot/", import.meta.url);

const TAROT: Record<Locale, string> = { "zh-Hans": "塔罗", "zh-Hant": "塔羅", en: "Tarot" };

interface Card {
  position: number;
  position_key: string;
  card_id: string;
  reversed: boolean;
}

/** The texts the image shows, in order (exported so a test can check what is, and isn't, on it). */
export function shareTexts(report: Report, chart: ChartFact, locale: Locale) {
  const cards = (chart.facts as { cards: Card[] }).cards;
  const name = (id: string) => DECK.find((c) => c.id === id)?.name[locale] ?? id;
  const synthesis = report.layers?.interpretation.find((s) => s.topic === "tarot_synthesis");
  const point = synthesis?.summary ?? synthesis?.paragraphs[0]?.text ?? "";
  return {
    title: `${BRAND[locale]} · ${TAROT[locale]}`,
    cards: cards.map((c) => ({
      card_id: c.card_id,
      reversed: c.reversed,
      position: POSITION_LABELS[c.position_key]?.[locale] ?? c.position_key,
      name: c.reversed ? `${name(c.card_id)} · ${term("逆位", locale)}` : name(c.card_id),
    })),
    point: clip(point, 90),
    label: report.layers?.expectation.ai_label ?? "",
    mark: `${BRAND[locale]} · ${report.created_at.slice(0, 10)}`,
  };
}

/** The share image of a passed tarot reading, as a JPEG. */
export async function renderTarotShare(
  report: Report,
  chart: ChartFact,
  opts: { font: ShareFont; locale: Locale },
): Promise<Buffer> {
  const t = shareTexts(report, chart, opts.locale);
  const n = t.cards.length;
  // One row up to five cards; a Celtic Cross (10) takes two rows of five.
  const perRow = n <= 5 ? n : Math.ceil(n / 2);
  const cardW = Math.min(
    n === 1 ? 360 : 300,
    Math.floor((W - 2 * MARGIN - (perRow - 1) * GAP) / perRow),
  );
  const layers: OverlayOptions[] = [];
  const centre = (w: number) => Math.round((W - w) / 2);

  const title = await text(opts.font, escape(t.title), W - 2 * MARGIN, 52, ACCENT);
  layers.push({ input: title.buf, top: 70, left: centre(title.w) });

  let y = 190;
  const rows = Math.ceil(n / perRow);
  for (let row = 0; row < rows; row++) {
    const inRow = t.cards.slice(row * perRow, (row + 1) * perRow);
    const rowW = inRow.length * cardW + (inRow.length - 1) * GAP;
    let rowH = 0;
    for (const [i, c] of inRow.entries()) {
      const art = await sharp(fileURLToPath(new URL(`${c.card_id}.webp`, ART)))
        .rotate(c.reversed ? 180 : 0)
        .resize({ width: cardW })
        .png()
        .toBuffer();
      const { height: artH = 0 } = await sharp(art).metadata();
      const left = centre(rowW) + i * (cardW + GAP);
      layers.push({ input: art, top: y, left });
      const caption = await text(
        opts.font,
        `<span size="${(n > 5 ? 18 : 22) * 1024}">${escape(c.position)}</span>\n${escape(c.name)}`,
        cardW + GAP - 4,
        n > 5 ? 20 : 26,
      );
      layers.push({
        input: caption.buf,
        top: y + artH + 10,
        left: left + Math.round((cardW - caption.w) / 2),
      });
      rowH = Math.max(rowH, artH + 10 + caption.h);
    }
    y += rowH + 24;
  }

  if (t.point) {
    const point = await text(opts.font, escape(t.point), W - 2 * MARGIN - 40, 34);
    layers.push({ input: point.buf, top: y + 16, left: centre(point.w) });
  }
  // The watermark at the foot, the label above it however many lines it wraps to (English: two).
  const mark = await text(opts.font, escape(t.mark), W - 2 * MARGIN, 24, ACCENT);
  const markTop = H - 60 - mark.h;
  layers.push({ input: mark.buf, top: markTop, left: centre(mark.w) });
  const label = await text(opts.font, escape(t.label), W - 2 * MARGIN, 24);
  layers.push({ input: label.buf, top: markTop - 20 - label.h, left: centre(label.w) });

  return sharp({ create: { width: W, height: H, channels: 4, background: PAPER } })
    .composite(layers)
    .jpeg({ quality: 85 })
    .toBuffer();
}
