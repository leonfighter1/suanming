/**
 * A record as a document (tech plan S14, WP14.1, the owner: 下载后可以生成Word文档和PDF). The app builds the document
 * from what it shows (the reading, its chart, its 追问, the AI label and the disclaimer); the server renders it to
 * Word or PDF (render-docx.ts, render-pdf.ts). This is the neutral form both read, and its checks.
 */

/** What a block is; each renderer draws every one. */
export const BLOCK_TYPES = [
  "h2", // a section heading
  "h3", // a sub-heading
  "meta", // small grey line: date, method, person
  "p", // a paragraph
  "summary", // a section's main point, bold
  "term", // 术语: the facts a paragraph rests on, bold in the accent colour (v6.2.0)
  "example", // 举例: an everyday scene, in a tinted box
  "quote", // a quoted text (a 卦辭, a lot's line), indented
  "bullet", // one point of a list
  "kv", // rows of label and value
  "note", // small grey text: the disclaimer, the AI label
  "question", // a 追问 as asked
  "divider", // a rule across the page
] as const;
export type BlockType = (typeof BLOCK_TYPES)[number];

export interface DocBlock {
  type: BlockType;
  text?: string;
  /** kv only: label and value per row. */
  rows?: [string, string][];
}

export interface Doc {
  title: string;
  subtitle?: string;
  blocks: DocBlock[];
}

export const DOC_LIMITS = { title: 200, blocks: 3000, text: 6000, rows: 80, filename: 120 };

export class DocumentInputError extends Error {}

const text = (v: unknown, what: string, max: number): string => {
  if (typeof v !== "string") throw new DocumentInputError(`${what} must be text`);
  if ([...v].length > max) throw new DocumentInputError(`${what} is longer than ${max} characters`);
  return v;
};

/** The document a request carries, checked: known block types only, within the limits. */
export function parseDocument(raw: unknown): Doc {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    throw new DocumentInputError("document must be an object");
  }
  const d = raw as Record<string, unknown>;
  const title = text(d.title, "document.title", DOC_LIMITS.title).trim();
  if (!title) throw new DocumentInputError("document.title is required");
  if (!Array.isArray(d.blocks)) throw new DocumentInputError("document.blocks must be a list");
  if (d.blocks.length > DOC_LIMITS.blocks) {
    throw new DocumentInputError(`document.blocks holds more than ${DOC_LIMITS.blocks}`);
  }
  const blocks = d.blocks.map((b, i): DocBlock => {
    if (!b || typeof b !== "object") throw new DocumentInputError(`block ${i} must be an object`);
    const { type, text: body, rows } = b as Record<string, unknown>;
    if (!BLOCK_TYPES.includes(type as BlockType)) {
      throw new DocumentInputError(`block ${i}: type must be one of ${BLOCK_TYPES.join(", ")}`);
    }
    if (type === "divider") return { type };
    if (type === "kv") {
      if (!Array.isArray(rows) || rows.length > DOC_LIMITS.rows) {
        throw new DocumentInputError(
          `block ${i}: rows must be a list of at most ${DOC_LIMITS.rows}`,
        );
      }
      return {
        type,
        rows: rows.map((r, j) => {
          if (!Array.isArray(r) || r.length !== 2) {
            throw new DocumentInputError(`block ${i} row ${j}: a label and a value`);
          }
          return [
            text(r[0], `block ${i} row ${j}`, DOC_LIMITS.text),
            text(r[1], `block ${i} row ${j}`, DOC_LIMITS.text),
          ];
        }),
      };
    }
    return { type: type as BlockType, text: text(body, `block ${i}.text`, DOC_LIMITS.text) };
  });
  return {
    title,
    ...(d.subtitle !== undefined && {
      subtitle: text(d.subtitle, "document.subtitle", DOC_LIMITS.title),
    }),
    blocks,
  };
}

/**
 * The file's name: the given one without path separators, control characters or a trailing dot, cut to length, with
 * the format's extension; 命理大师 when nothing is left.
 */
export function documentName(raw: unknown, ext: "pdf" | "docx" | "csv"): string {
  const base = (typeof raw === "string" ? raw : "")
    .replace(/[\\/:*?"<>|\p{Cc}]/gu, " ")
    .replace(/\s+/g, " ")
    .trim()
    .replace(/\.+$/, "");
  const cut = [...base].slice(0, DOC_LIMITS.filename).join("").trim();
  return `${cut || "命理大师"}.${ext}`;
}

/** Content-Disposition for a download: an ASCII fallback, and the real name as RFC 5987 UTF-8. */
export function contentDisposition(name: string): string {
  const ascii = name.replace(/[^\x20-\x7e]/g, "_").replace(/"/g, "'");
  return `attachment; filename="${ascii}"; filename*=UTF-8''${encodeURIComponent(name)}`;
}
