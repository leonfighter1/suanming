/**
 * A mail message as MIME (RFC 5322, 2045–2047, 2231): the form a mail provider takes (SMTP's DATA, an API's raw
 * message) and any mail program opens as an .eml file. UTF-8 throughout: headers as encoded words, the text, the
 * HTML and every attachment in base64.
 */

export interface MailAttachment {
  filename: string;
  contentType: string;
  content: Buffer;
}

export interface MailMessage {
  to: string;
  subject: string;
  /** The plain-text body, always there (some mail programs show only it). */
  text: string;
  html?: string;
  attachments?: MailAttachment[];
}

const CRLF = "\r\n";

const printable = (s: string) =>
  [...s].every((c) => c.charCodeAt(0) >= 32 && c.charCodeAt(0) < 127);

/** base64 in lines of 76 characters, as MIME wants them. */
function base64Lines(b: Buffer): string {
  return (b.toString("base64").match(/.{1,76}/g) ?? []).join(CRLF);
}

/**
 * A header value as RFC 2047 encoded words. Each word holds at most 45 bytes of UTF-8 (60 in base64, 72 with its
 * markers, under the limit of 75), split between characters, never inside one.
 */
export function encodeWords(s: string): string {
  if (printable(s)) return s;
  const chunks: string[] = [];
  let chunk = "";
  for (const ch of s) {
    if (chunk && Buffer.byteLength(chunk + ch) > 45) {
      chunks.push(chunk);
      chunk = "";
    }
    chunk += ch;
  }
  if (chunk) chunks.push(chunk);
  return chunks.map((c) => `=?UTF-8?B?${Buffer.from(c).toString("base64")}?=`).join(`${CRLF} `);
}

/** A display name and an address: 命理大师 <no-reply@mingli.local>. */
export function mailbox(name: string, address: string) {
  return `${encodeWords(name)} <${address}>`;
}

/** An attachment's file name: an ASCII stand-in for old programs, and the real one (RFC 2231). */
function filenameParams(name: string) {
  const ascii = printable(name) ? name : `attachment.${name.split(".").pop() ?? "bin"}`;
  return `filename="${ascii.replace(/["\\]/g, "")}"; filename*=UTF-8''${encodeURIComponent(name)}`;
}

function part(headers: string[], body: string) {
  return [...headers, "", body].join(CRLF);
}

function multipart(kind: "mixed" | "alternative", boundary: string, parts: string[]) {
  return {
    header: `Content-Type: multipart/${kind}; boundary="${boundary}"`,
    body: [...parts.map((p) => `--${boundary}${CRLF}${p}`), `--${boundary}--`].join(CRLF),
  };
}

/** Date in RFC 5322 form: Thu, 29 Oct 2026 01:30:00 +0000. */
const mailDate = (d: Date) => d.toUTCString().replace(/GMT$/, "+0000");

/** The whole message, ready to write as .eml or hand to a provider. */
export function buildMime(
  m: MailMessage,
  o: { from: string; date: Date; id: string; domain?: string },
): string {
  const textPart = part(
    ["Content-Type: text/plain; charset=UTF-8", "Content-Transfer-Encoding: base64"],
    base64Lines(Buffer.from(m.text)),
  );
  let content: { header: string; body: string };
  if (m.html) {
    const htmlPart = part(
      ["Content-Type: text/html; charset=UTF-8", "Content-Transfer-Encoding: base64"],
      base64Lines(Buffer.from(m.html)),
    );
    const alt = multipart("alternative", `=_alt_${o.id}`, [textPart, htmlPart]);
    content = { header: alt.header, body: alt.body };
  } else {
    content = {
      header: ["Content-Type: text/plain; charset=UTF-8", "Content-Transfer-Encoding: base64"].join(
        CRLF,
      ),
      body: base64Lines(Buffer.from(m.text)),
    };
  }
  if (m.attachments?.length) {
    const inner = part([content.header], content.body);
    const files = m.attachments.map((a) =>
      part(
        [
          `Content-Type: ${a.contentType}; name="${encodeWords(a.filename)}"`,
          `Content-Disposition: attachment; ${filenameParams(a.filename)}`,
          "Content-Transfer-Encoding: base64",
        ],
        base64Lines(a.content),
      ),
    );
    content = multipart("mixed", `=_mixed_${o.id}`, [inner, ...files]);
  }
  const headers = [
    `From: ${o.from}`,
    `To: ${m.to}`,
    `Subject: ${encodeWords(m.subject)}`,
    `Date: ${mailDate(o.date)}`,
    `Message-ID: <${o.id}@${o.domain ?? "mingli.local"}>`,
    "MIME-Version: 1.0",
    content.header,
  ];
  return [...headers, "", content.body, ""].join(CRLF);
}
