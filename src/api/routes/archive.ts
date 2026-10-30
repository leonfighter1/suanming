/**
 * 以往记录 (v8.0.0, S14; moved here in S28 WP28.9): deleting one record, filing a chart under a person, and records
 * as Word or PDF, to download or (发到邮箱, v9.0.0) mailed to the account's verified email.
 */
import type { IncomingMessage, ServerResponse } from "node:http";
import { LOCALES, type Locale } from "../../ai/index.js";
import { maskEmail } from "../../auth/identifiers.js";
import {
  contentDisposition,
  documentName,
  DocumentInputError,
  parseDocument,
  type Doc,
} from "../../export/document.js";
import { renderDocx } from "../../export/render-docx.js";
import { renderPdf } from "../../export/render-pdf.js";
import { HttpError, readJson, send } from "../../http/util.js";
import { recordsTitle, type MailAttachment } from "../../notify/index.js";
import { changePerson, InputError, UUID_RE } from "../../service/charts.js";
import { shareFont } from "../../share/font.js";
import type { ApiContext, Caller } from "../context.js";

/** 发到邮箱 (v9.0.0): at most this many records in one message. */
export const MAIL_DOCUMENTS = 10;

/** A record deleted, a chart's person, records as documents; false for any other path. */
export async function archiveRoute(
  ctx: ApiContext,
  req: IncomingMessage,
  res: ServerResponse,
  path: string,
  c: Caller,
): Promise<boolean> {
  const { store, now, log, auth, mail, messages, takeMailQuota } = ctx;
  const dr = /^\/v1\/(reports|life-reports)\/([^/]+)$/.exec(path);
  if (dr && req.method === "DELETE") {
    const id = dr[2]!;
    const reading = dr[1] === "reports";
    const r = !UUID_RE.test(id)
      ? undefined
      : reading
        ? await store.getReport(id)
        : await store.getLifeReport(id);
    if (!r || r.owner !== c.user) throw new HttpError(404, "record not found");
    // The record with what hangs off it; its chart too when nothing else reads it. A job still running for it
    // finds the record gone and writes nothing back.
    const removed = reading ? await store.deleteReport(id) : await store.deleteLifeReport(id);
    const charts = (await store.deleteChartIfUnused(r.chart_id)) ? 1 : 0;
    send(res, 200, { deleted: { ...removed, charts }, completed_at: now().toISOString() });
    return true;
  }
  const pm2 = /^\/v1\/charts\/([^/]+)\/person$/.exec(path);
  if (pm2 && req.method === "POST") {
    const ch = UUID_RE.test(pm2[1]!) ? await store.getChart(pm2[1]!) : undefined;
    if (!ch || ch.owner !== c.user) throw new HttpError(404, "chart not found");
    const person = changePerson(ch.person, await readJson(req), ch.fact.system);
    const { person: _old, ...rest } = ch;
    await store.putChart(person ? { ...rest, person } : rest);
    send(res, 200, { chart_id: ch.id, ...(person && { person }) });
    return true;
  }
  if (path === "/v1/documents" && req.method === "POST") {
    // A long 一生运势报告 with its 追问 runs to tens of kilobytes of text.
    const body = (await readJson(req, 1024 * 1024)) as Record<string, unknown>;
    const format = body.format === "pdf" || body.format === "docx" ? body.format : undefined;
    if (!format) throw new InputError("format must be pdf or docx");
    let doc: Doc;
    try {
      doc = parseDocument(body.document);
    } catch (e) {
      if (e instanceof DocumentInputError) throw new InputError(e.message);
      throw e;
    }
    const locale = LOCALES.includes(body.locale as Locale) ? (body.locale as Locale) : "zh-Hans";
    let bytes: Buffer;
    if (format === "pdf") {
      const font = shareFont(locale);
      if (!font) {
        throw new HttpError(
          503,
          "PDF documents need a CJK font on the server: install fonts-noto-cjk or set MINGLI_SHARE_FONT",
        );
      }
      bytes = await renderPdf(doc, font);
    } else {
      bytes = await renderDocx(doc, locale);
    }
    res.writeHead(200, {
      "content-type":
        format === "pdf"
          ? "application/pdf"
          : "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "content-length": String(bytes.length),
      "content-disposition": contentDisposition(documentName(body.filename, format)),
      "cache-control": "no-store",
    });
    res.end(bytes);
    return true;
  }

  // 发到邮箱 (v9.0.0, tech plan WP15.4): the chosen records, as the app builds them for 下载, rendered to Word or PDF
  // and mailed in one message to the account's verified email. Nothing is kept.
  if (path === "/v1/documents/email" && req.method === "POST") {
    if (!auth) throw new HttpError(404, "auth not configured");
    const body = (await readJson(req, 4 * 1024 * 1024)) as Record<string, unknown>;
    const format = body.format === "pdf" || body.format === "docx" ? body.format : undefined;
    if (!format) throw new InputError("format must be pdf or docx");
    const list = body.documents;
    if (!Array.isArray(list) || list.length < 1 || list.length > MAIL_DOCUMENTS) {
      throw new InputError(`documents must hold 1 to ${MAIL_DOCUMENTS} documents`);
    }
    const owner = (await auth.users.get(c.user))!;
    if (!owner.email || !owner.email_verified_at) {
      throw new HttpError(
        409,
        "verify an email first: documents go only to a verified email",
        "email_unverified",
      );
    }
    if (mail.name === "off") {
      throw new HttpError(503, "mail is not set up on this server yet", "delivery_unavailable");
    }
    const locale = LOCALES.includes(body.locale as Locale) ? (body.locale as Locale) : "zh-Hans";
    const font = format === "pdf" ? shareFont(locale) : undefined;
    if (format === "pdf" && !font) {
      throw new HttpError(
        503,
        "PDF documents need a CJK font on the server: install fonts-noto-cjk or set MINGLI_SHARE_FONT",
      );
    }
    const docs = list.map((item, i) => {
      const { document, filename } = (item ?? {}) as Record<string, unknown>;
      try {
        return { doc: parseDocument(document), filename };
      } catch (e) {
        if (e instanceof DocumentInputError) throw new InputError(`documents[${i}]: ${e.message}`);
        throw e;
      }
    });
    takeMailQuota(c.user);
    const files: MailAttachment[] = [];
    for (const { doc, filename } of docs) {
      files.push({
        filename: documentName(filename, format),
        contentType:
          format === "pdf"
            ? "application/pdf"
            : "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        content: format === "pdf" ? await renderPdf(doc, font!) : await renderDocx(doc, locale),
      });
    }
    try {
      const titles = docs.map((d) => d.doc.title);
      await messages.send("records_mail", {
        to: owner.email,
        locale,
        vars: { title: recordsTitle(titles, locale), count: String(titles.length) },
        parts: { records: titles },
        attachments: files,
      });
    } catch (e) {
      log(
        `mailing documents failed: ${(e as Error).message?.replace(/[^\s@]+@[^\s@]+/g, "<address>")}`,
      );
      throw new HttpError(502, "the mail could not be sent; try again later", "delivery_failed");
    }
    send(res, 202, {
      sent_to: maskEmail(owner.email),
      count: files.length,
      delivery: mail.name,
    });
    return true;
  }
  return false;
}
