/**
 * 消息 in the 管理后台 (tech plan S25 WP25.2; the owner: 让后台用户可以编辑各类发送邮件的前端页面。同时还有SMS等等): the mail
 * and SMS templates (each message's wording per language, an admin's or the default), a draft's preview with sample
 * values, a test send through the server's dispatcher (the dev outbox: no provider yet), and the latest dispatches.
 * For admins and editors (roles.ts). A wording is checked before it is kept (markup.ts).
 */
import type { IncomingMessage, ServerResponse } from "node:http";
import type { Locale } from "../ai/terms.js";
import { EMAIL_RE, normalizePhone } from "../auth/identifiers.js";
import type { UserRecord } from "../auth/service.js";
import { HttpError, readJson, send } from "../http/util.js";
import { DeliveryUnavailable, type Dispatcher } from "../notify/index.js";
import { templateProblems } from "../notify/markup.js";
import {
  localesOf,
  MESSAGE_KINDS,
  SAMPLE_RECORDS,
  SAMPLE_REPORT,
  sampleVars,
  TEMPLATE_SPECS,
  type MessageKind,
  type TemplateSpec,
  type TemplateText,
} from "../notify/templates.js";
import type { AdminContext } from "./routes.js";

const loginOf = (u: UserRecord) => u.username ?? u.email ?? u.id.slice(0, 8);

/** [kind] as a message's, or 404. */
function specOf(kind: unknown): TemplateSpec {
  if (typeof kind !== "string" || !(MESSAGE_KINDS as readonly string[]).includes(kind)) {
    throw new HttpError(404, "no such message");
  }
  return TEMPLATE_SPECS[kind as MessageKind];
}

/** [locale] as one [spec] has a wording for, or 404. */
function localeOf(spec: TemplateSpec, locale: unknown): Locale {
  if (typeof locale !== "string" || !localesOf(spec).includes(locale as Locale)) {
    throw new HttpError(404, `the ${spec.kind} message has no ${String(locale)} wording`);
  }
  return locale as Locale;
}

/** A draft from a request's body: its subject (a mail's) and its body. */
function draftOf(spec: TemplateSpec, b: Record<string, unknown>): TemplateText {
  const body = typeof b.body === "string" ? b.body : "";
  const subject = typeof b.subject === "string" ? b.subject : undefined;
  return { body, ...(spec.channel === "mail" && { subject: subject ?? "" }) };
}

/** 400 invalid_template with what is wrong, when the draft can't be kept or sent. */
function check(spec: TemplateSpec, t: TemplateText) {
  const problems = templateProblems(spec, t);
  if (problems.length) {
    throw new HttpError(400, problems.join("；"), "invalid_template", { problems });
  }
}

/** Each message as the dashboard lists it: what it is, its variables, and per language its wording and default. */
async function listing(ctx: AdminContext & { messages: Dispatcher }) {
  const out = [];
  for (const kind of MESSAGE_KINDS) {
    const spec = TEMPLATE_SPECS[kind];
    const locales = [];
    for (const locale of localesOf(spec)) {
      const inUse = await ctx.messages.template(kind, locale);
      locales.push({ ...inUse, default: spec.defaults[locale] });
    }
    out.push({
      kind,
      channel: spec.channel,
      name: spec.name,
      about: spec.about,
      variables: spec.variables.map(({ secret: _s, ...v }) => v),
      required: spec.required,
      locales,
    });
  }
  return out;
}

/** Handles `/v1/admin/messages/*`; false when the path is none of them. */
export async function messagesRoute(
  ctx: AdminContext & { messages: Dispatcher },
  req: IncomingMessage,
  res: ServerResponse,
  path: string,
  me: UserRecord,
): Promise<boolean> {
  const url = new URL(req.url ?? "/", "http://localhost");

  if (path === "/v1/admin/messages/templates" && req.method === "GET") {
    send(res, 200, {
      templates: await listing(ctx),
      // What delivers each channel: the dev outbox, or off (no provider yet; settings come later).
      delivery: { mail: ctx.messages.transport("mail").name, sms: ctx.messages.transport("sms").name },
    });
    return true;
  }

  const tm = /^\/v1\/admin\/messages\/templates\/([^/]+)\/([^/]+)$/.exec(path);
  if (tm) {
    const spec = specOf(tm[1]);
    const locale = localeOf(spec, tm[2]);
    if (req.method === "PUT") {
      const draft = draftOf(spec, (await readJson(req)) as Record<string, unknown>);
      check(spec, draft);
      await ctx.store.putMessageTemplate({
        kind: spec.kind,
        locale,
        ...draft,
        updated_at: ctx.now().toISOString(),
        updated_by: me.id,
      });
      ctx.log(`admin ${loginOf(me)}: message ${spec.kind} (${locale}) saved`);
      send(res, 200, { ...(await ctx.messages.template(spec.kind, locale)), default: spec.defaults[locale] });
      return true;
    }
    if (req.method === "DELETE") {
      await ctx.store.deleteMessageTemplate(spec.kind, locale);
      ctx.log(`admin ${loginOf(me)}: message ${spec.kind} (${locale}) back to its default`);
      send(res, 200, { ...(await ctx.messages.template(spec.kind, locale)), default: spec.defaults[locale] });
      return true;
    }
    return false;
  }

  // A draft (or the saved wording) with the sample values: what a reader would get, light or dark as asked (the
  // dashboard's 外观), else as the viewer's system has it. Its problems come along, so the editor can show them.
  if (path === "/v1/admin/messages/preview" && req.method === "POST") {
    const b = (await readJson(req)) as Record<string, unknown>;
    const spec = specOf(b.kind);
    const locale = localeOf(spec, b.locale);
    const draft =
      typeof b.body === "string" ? draftOf(spec, b) : await ctx.messages.template(spec.kind, locale);
    if (b.scheme !== undefined && b.scheme !== "light" && b.scheme !== "dark") {
      throw new HttpError(400, "scheme must be light or dark");
    }
    const rendered = ctx.messages.render(spec.kind, draft, {
      vars: sampleVars(spec),
      parts: { report: SAMPLE_REPORT, records: SAMPLE_RECORDS },
      locale,
      ...(b.scheme !== undefined && { scheme: b.scheme as "light" | "dark" }),
    });
    send(res, 200, { ...rendered, problems: templateProblems(spec, draft) });
    return true;
  }

  // A test send with the sample values, to the address or number the admin gives, through the dispatcher.
  if (path === "/v1/admin/messages/test" && req.method === "POST") {
    const b = (await readJson(req)) as Record<string, unknown>;
    const spec = specOf(b.kind);
    const locale = localeOf(spec, b.locale);
    const raw = typeof b.to === "string" ? b.to.trim() : "";
    const to = spec.channel === "mail" ? (EMAIL_RE.test(raw) ? raw : undefined) : normalizePhone(raw);
    if (!to) {
      throw new HttpError(400, spec.channel === "mail" ? "to must be an email address" : "to must be a phone number");
    }
    const draft = typeof b.body === "string" ? draftOf(spec, b) : undefined;
    if (draft) check(spec, draft);
    try {
      const entry = await ctx.messages.send(spec.kind, {
        to,
        locale,
        vars: sampleVars(spec),
        parts: { report: SAMPLE_REPORT, records: SAMPLE_RECORDS },
        test: true,
        ...(draft && { draft }),
      });
      ctx.log(`admin ${loginOf(me)}: test ${spec.kind} (${locale}) by ${entry.transport}`);
      send(res, 202, { entry });
    } catch (e) {
      if (e instanceof DeliveryUnavailable) {
        throw new HttpError(503, e.message, "delivery_unavailable");
      }
      throw new HttpError(502, "the message could not be sent", "delivery_failed");
    }
    return true;
  }

  if (path === "/v1/admin/messages/log" && req.method === "GET") {
    const limit = Math.min(200, Math.max(1, Number(url.searchParams.get("limit") ?? 50) || 50));
    send(res, 200, { items: ctx.messages.recent(limit) });
    return true;
  }
  return false;
}
