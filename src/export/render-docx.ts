/**
 * A document as Word (.docx), with `docx` (tech plan WP14.1). Word sets the Chinese text in its own East Asian font
 * (Microsoft YaHei, which Word for Windows and for Mac both carry); nothing is embedded.
 */
import {
  AlignmentType,
  BorderStyle,
  Document,
  HeadingLevel,
  Packer,
  Paragraph,
  ShadingType,
  Table,
  TableCell,
  TableRow,
  TextRun,
  WidthType,
} from "docx";
import type { Locale } from "../ai/terms.js";
import type { Doc, DocBlock } from "./document.js";

const ACCENT = "8A3B2E"; // the app's accent
const INK = "3B2A22";
const MUTED = "7A6A62";
const TINT = "F6E4DE";

/** Sizes in half-points. */
const SIZE = { title: 36, h2: 30, h3: 25, body: 22, small: 18 };

const run = (
  text: string,
  o: { bold?: boolean; color?: string; size?: number; italics?: boolean } = {},
) =>
  new TextRun({
    text,
    bold: o.bold,
    color: o.color ?? INK,
    size: o.size ?? SIZE.body,
    italics: o.italics,
  });

function block(b: DocBlock): (Paragraph | Table)[] {
  const t = b.text ?? "";
  switch (b.type) {
    case "h2":
      return [
        new Paragraph({
          heading: HeadingLevel.HEADING_1,
          spacing: { before: 360, after: 120 },
          children: [run(t, { bold: true, color: ACCENT, size: SIZE.h2 })],
        }),
      ];
    case "h3":
      return [
        new Paragraph({
          heading: HeadingLevel.HEADING_2,
          spacing: { before: 240, after: 80 },
          children: [run(t, { bold: true, size: SIZE.h3 })],
        }),
      ];
    case "meta":
      return [
        new Paragraph({
          spacing: { after: 60 },
          children: [run(t, { color: MUTED, size: SIZE.small })],
        }),
      ];
    case "summary":
      return [new Paragraph({ spacing: { after: 120 }, children: [run(t, { bold: true })] })];
    case "term":
      return [
        new Paragraph({
          spacing: { before: 160, after: 40 },
          children: [run(t, { bold: true, color: ACCENT })],
        }),
      ];
    case "example":
      return [
        new Paragraph({
          spacing: { before: 60, after: 160 },
          indent: { left: 240, right: 120 },
          shading: { type: ShadingType.CLEAR, color: "auto", fill: TINT },
          border: { left: { style: BorderStyle.SINGLE, size: 12, color: ACCENT, space: 6 } },
          children: [run(t)],
        }),
      ];
    case "quote":
      return [
        new Paragraph({
          spacing: { after: 120 },
          indent: { left: 360 },
          children: [run(t, { color: MUTED, italics: true })],
        }),
      ];
    case "bullet":
      return [new Paragraph({ bullet: { level: 0 }, spacing: { after: 60 }, children: [run(t)] })];
    case "kv":
      return [
        new Table({
          width: { size: 100, type: WidthType.PERCENTAGE },
          rows: (b.rows ?? []).map(
            ([k, v]) =>
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 28, type: WidthType.PERCENTAGE },
                    shading: { type: ShadingType.CLEAR, color: "auto", fill: TINT },
                    children: [new Paragraph({ children: [run(k, { color: MUTED })] })],
                  }),
                  new TableCell({
                    width: { size: 72, type: WidthType.PERCENTAGE },
                    children: [new Paragraph({ children: [run(v)] })],
                  }),
                ],
              }),
          ),
        }),
        new Paragraph({ children: [] }),
      ];
    case "note":
      return [
        new Paragraph({
          spacing: { after: 60 },
          children: [run(t, { color: MUTED, size: SIZE.small })],
        }),
      ];
    case "question":
      return [
        new Paragraph({
          spacing: { before: 240, after: 80 },
          alignment: AlignmentType.LEFT,
          shading: { type: ShadingType.CLEAR, color: "auto", fill: "EFE7E3" },
          children: [run(t, { bold: true })],
        }),
      ];
    case "divider":
      return [
        new Paragraph({
          spacing: { after: 120 },
          border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: "D9CCC5", space: 1 } },
          children: [],
        }),
      ];
    default:
      return [new Paragraph({ spacing: { after: 120 }, children: [run(t)] })];
  }
}

export async function renderDocx(doc: Doc, locale: Locale): Promise<Buffer> {
  const eastAsia = locale === "zh-Hant" ? "zh-TW" : "zh-CN";
  const file = new Document({
    creator: "命理大师",
    title: doc.title,
    styles: {
      default: {
        document: {
          run: {
            font: { ascii: "Calibri", hAnsi: "Calibri", eastAsia: "Microsoft YaHei" },
            size: SIZE.body,
            color: INK,
            language: { value: "en-US", eastAsia },
          },
          paragraph: { spacing: { line: 360 } },
        },
      },
    },
    sections: [
      {
        properties: { page: { margin: { top: 1134, bottom: 1134, left: 1134, right: 1134 } } },
        children: [
          new Paragraph({
            heading: HeadingLevel.TITLE,
            spacing: { after: 120 },
            children: [run(doc.title, { bold: true, color: ACCENT, size: SIZE.title })],
          }),
          ...(doc.subtitle
            ? [
                new Paragraph({
                  spacing: { after: 240 },
                  children: [run(doc.subtitle, { color: MUTED })],
                }),
              ]
            : []),
          ...doc.blocks.flatMap(block),
        ],
      },
    ],
  });
  return Packer.toBuffer(file);
}
