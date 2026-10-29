/**
 * A document as PDF, with PDFKit (tech plan WP14.1). The server's Chinese font (shareFont, as share images use) is
 * embedded as a subset, so the file stays small and reads the same everywhere. Measured before choosing (G4):
 * pdf-lib's subsetting drew no Chinese glyphs from Noto Sans SC's OTF; PDFKit drew all of them from the OTF, the
 * variable TTF and Microsoft YaHei's TTC, and wraps Chinese lines itself (no punctuation at a line's start).
 */
import PDFDocument from "pdfkit";
import type { ShareFont } from "../share/font.js";
import type { Doc, DocBlock } from "./document.js";

const ACCENT = "#8a3b2e"; // the app's accent
const INK = "#3b2a22";
const MUTED = "#7a6a62";
const TINT = "#f6e4de";
const ASKED = "#efe7e3";
const RULE = "#d9ccc5";
const MARGIN = 56;
const SIZE = { title: 20, h2: 15, h3: 12.5, body: 11, small: 9 };
const GAP = { line: 4, after: 7 };

type Kit = InstanceType<typeof PDFDocument>;

export async function renderPdf(doc: Doc, font: ShareFont): Promise<Buffer> {
  const pdf: Kit = new PDFDocument({
    size: "A4",
    margins: { top: MARGIN, bottom: MARGIN, left: MARGIN, right: MARGIN },
    bufferPages: true,
    info: { Title: doc.title, Creator: "命理大师" },
  });
  const chunks: Buffer[] = [];
  const done = new Promise<Buffer>((resolve, reject) => {
    pdf.on("data", (c: Buffer) => chunks.push(c));
    pdf.on("end", () => resolve(Buffer.concat(chunks)));
    pdf.on("error", reject);
  });
  // A font collection (.ttc) names its face; a single font needs none.
  if (font.face) pdf.registerFont("cjk", font.file, font.face);
  else pdf.registerFont("cjk", font.file);
  pdf.font("cjk");

  const left = MARGIN;
  const width = pdf.page.width - 2 * MARGIN;
  const bottom = () => pdf.page.height - MARGIN;
  /** Starts a new page when [height] doesn't fit on this one. */
  const room = (height: number) => {
    if (pdf.y + height > bottom()) pdf.addPage();
  };
  /** Text in [color]; bold is drawn as a fill with a thin stroke of the same colour (one face is embedded). */
  const write = (
    text: string,
    o: { size: number; color: string; bold?: boolean; x?: number; w?: number; after?: number },
  ) => {
    pdf.fontSize(o.size).fillColor(o.color);
    if (o.bold) pdf.lineWidth(0.35).strokeColor(o.color);
    pdf.text(text, o.x ?? left, pdf.y, {
      width: o.w ?? width,
      lineGap: GAP.line,
      ...(o.bold && { stroke: true, fill: true }),
    });
    pdf.y += o.after ?? GAP.after;
  };
  /** Text on a tinted panel, with a bar of [bar] colour at its left when given. */
  const panel = (text: string, fill: string, o: { bold?: boolean; bar?: string }) => {
    const pad = 8;
    const w = width - 2 * pad;
    pdf.fontSize(SIZE.body);
    const h = pdf.heightOfString(text, { width: w, lineGap: GAP.line }) + 2 * pad;
    room(h);
    const top = pdf.y;
    pdf.roundedRect(left, top, width, h, 6).fill(fill);
    if (o.bar) pdf.rect(left, top, 3, h).fill(o.bar);
    pdf.y = top + pad;
    write(text, { size: SIZE.body, color: INK, bold: o.bold, x: left + pad, w, after: 0 });
    pdf.y = top + h + GAP.after + 2;
  };

  const draw = (b: DocBlock) => {
    const t = b.text ?? "";
    switch (b.type) {
      case "h2":
        room(60);
        pdf.y += 10;
        write(t, { size: SIZE.h2, color: ACCENT, bold: true, after: 6 });
        return;
      case "h3":
        room(44);
        pdf.y += 4;
        write(t, { size: SIZE.h3, color: INK, bold: true, after: 4 });
        return;
      case "meta":
        write(t, { size: SIZE.small, color: MUTED, after: 3 });
        return;
      case "summary":
        write(t, { size: SIZE.body, color: INK, bold: true });
        return;
      case "term":
        room(40);
        pdf.y += 4;
        write(t, { size: SIZE.body, color: ACCENT, bold: true, after: 3 });
        return;
      case "example":
        panel(t, TINT, { bar: ACCENT });
        return;
      case "question":
        pdf.y += 6;
        panel(t, ASKED, { bold: true });
        return;
      case "quote": {
        pdf.fontSize(SIZE.body);
        const h = pdf.heightOfString(t, { width: width - 16, lineGap: GAP.line });
        room(h);
        const top = pdf.y;
        pdf.rect(left + 2, top, 2, h).fill(RULE);
        write(t, { size: SIZE.body, color: MUTED, x: left + 14, w: width - 16 });
        return;
      }
      case "bullet": {
        const top = pdf.y;
        pdf
          .fontSize(SIZE.body)
          .fillColor(ACCENT)
          .text("•", left, top, { width: 12, lineGap: GAP.line });
        pdf.y = top;
        write(t, { size: SIZE.body, color: INK, x: left + 14, w: width - 14, after: 3 });
        return;
      }
      case "kv":
        for (const [k, v] of b.rows ?? []) {
          pdf.fontSize(SIZE.body);
          const keyW = Math.min(150, width * 0.3);
          const h = Math.max(
            pdf.heightOfString(k, { width: keyW - 8, lineGap: GAP.line }),
            pdf.heightOfString(v, { width: width - keyW, lineGap: GAP.line }),
          );
          room(h);
          const top = pdf.y;
          pdf.fillColor(MUTED).text(k, left, top, { width: keyW - 8, lineGap: GAP.line });
          pdf.fillColor(INK).text(v, left + keyW, top, { width: width - keyW, lineGap: GAP.line });
          pdf.y = top + h + 4;
        }
        pdf.y += GAP.after;
        return;
      case "note":
        write(t, { size: SIZE.small, color: MUTED, after: 4 });
        return;
      case "divider":
        room(16);
        pdf.y += 4;
        pdf
          .moveTo(left, pdf.y)
          .lineTo(left + width, pdf.y)
          .lineWidth(0.6)
          .strokeColor(RULE)
          .stroke();
        pdf.y += 10;
        return;
      default:
        write(t, { size: SIZE.body, color: INK });
    }
  };

  write(doc.title, { size: SIZE.title, color: ACCENT, bold: true, after: 4 });
  if (doc.subtitle) write(doc.subtitle, { size: SIZE.small, color: MUTED, after: 10 });
  for (const b of doc.blocks) draw(b);

  // Page numbers, in the bottom margin of every page.
  const range = pdf.bufferedPageRange();
  for (let i = range.start; i < range.start + range.count; i++) {
    pdf.switchToPage(i);
    const keep = pdf.page.margins.bottom;
    pdf.page.margins.bottom = 0;
    pdf
      .fontSize(8)
      .fillColor(MUTED)
      .text(`${i + 1} / ${range.count}`, 0, pdf.page.height - MARGIN / 2 - 4, {
        width: pdf.page.width,
        align: "center",
      });
    pdf.page.margins.bottom = keep;
  }
  pdf.end();
  return done;
}
