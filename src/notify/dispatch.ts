/**
 * Every message leaves the server here (tech plan S25; the owner: 设计好邮件发送逻辑…只在server端先做简单的分发测试，暂时
 * 不用第三方的服务): the message's template (an admin's wording from the store, else the default), its rendering, its
 * channel's transport (mail or SMS: the dev outbox until the owner picks providers), and a note of the dispatch. The
 * notes are the latest few hundred, in memory: who it went to masked, a verification code never written down.
 */
import { randomUUID } from "node:crypto";
import type { Locale } from "../ai/terms.js";
import { maskEmail, maskPhone } from "../auth/identifiers.js";
import { DeliveryUnavailable, type MailAttachment, type MailTransport } from "./mail.js";
import { fill } from "./markup.js";
import { renderMessage, type MessageParts, type RenderedMessage } from "./render-message.js";
import type { SmsTransport } from "./sms.js";
import {
  localeFor,
  TEMPLATE_SPECS,
  type Channel,
  type MessageKind,
  type TemplateText,
} from "./templates.js";

/** An admin's wording of a message in a language, as the store keeps it. */
export interface TemplateRecord extends TemplateText {
  kind: MessageKind;
  locale: Locale;
  updated_at: string;
  /** The admin who saved it. */
  updated_by?: string;
}

/** Where admins' wordings are kept (the Store). */
export interface TemplateStore {
  listMessageTemplates(): Promise<TemplateRecord[]>;
  putMessageTemplate(t: TemplateRecord): Promise<void>;
  /** True when there was one. */
  deleteMessageTemplate(kind: MessageKind, locale: Locale): Promise<boolean>;
}

/** Admins' wordings kept in memory: a server or a test without a store. */
export class MemoryTemplates implements TemplateStore {
  private readonly rows = new Map<string, TemplateRecord>();
  async listMessageTemplates() {
    return [...this.rows.values()].map((t) => ({ ...t }));
  }
  async putMessageTemplate(t: TemplateRecord) {
    this.rows.set(`${t.kind}/${t.locale}`, { ...t });
  }
  async deleteMessageTemplate(kind: MessageKind, locale: Locale) {
    return this.rows.delete(`${kind}/${locale}`);
  }
}

/** The wording a message goes out with: an admin's (custom) or the default. */
export interface TemplateInUse extends TemplateText {
  locale: Locale;
  custom: boolean;
  updated_at?: string;
}

/** One dispatch, as the log keeps it. */
export interface DispatchEntry {
  id: string;
  at: string;
  kind: MessageKind;
  channel: Channel;
  locale: Locale;
  /** Masked: s***@example.com, +86 *******5678. */
  to: string;
  /** A mail's subject, a secret variable (a code) hidden. */
  subject?: string;
  /** sent; off: this server has no way to send it; failed: the transport refused. */
  status: "sent" | "off" | "failed";
  transport: string;
  custom: boolean;
  /** An admin's test send. */
  test?: boolean;
  /** Why it failed, without any address. */
  error?: string;
}

/** What a dispatch carries. */
export interface DispatchInput {
  to: string;
  locale: Locale;
  vars: Record<string, string>;
  parts?: MessageParts;
  attachments?: MailAttachment[];
  /** A wording to send instead of the saved one (a test send of a draft). */
  draft?: TemplateText;
  test?: boolean;
}

const HIDDEN = "••••••";
const noAddresses = (s: string) =>
  s.replace(/[^\s@]+@[^\s@]+/g, "<address>").replace(/\+?\d[\d\s-]{6,}\d/g, "<number>");

export class Dispatcher {
  private readonly log: DispatchEntry[] = [];

  constructor(
    private readonly d: {
      mail: MailTransport;
      sms: SmsTransport;
      templates: TemplateStore;
      now?: () => Date;
      /** How many dispatches the log keeps. */
      keep?: number;
    },
  ) {}

  /** The transport of [channel]. */
  transport(channel: Channel): MailTransport | SmsTransport {
    return channel === "mail" ? this.d.mail : this.d.sms;
  }

  /** What [kind] goes out with in [locale]: an admin's wording, else the default; 简体's for a language it hasn't. */
  async template(kind: MessageKind, locale: Locale): Promise<TemplateInUse> {
    const spec = TEMPLATE_SPECS[kind];
    const lang = localeFor(spec, locale);
    const saved = (await this.d.templates.listMessageTemplates()).find(
      (t) => t.kind === kind && t.locale === lang,
    );
    if (saved) {
      return {
        locale: lang,
        body: saved.body,
        ...(saved.subject !== undefined && { subject: saved.subject }),
        custom: true,
        updated_at: saved.updated_at,
      };
    }
    return { locale: lang, ...spec.defaults[lang]!, custom: false };
  }

  /** [kind]'s message from [t] and the values, without sending it (a preview). */
  render(
    kind: MessageKind,
    t: TemplateText,
    o: {
      vars: Record<string, string>;
      parts?: MessageParts;
      locale: Locale;
      scheme?: "light" | "dark";
    },
  ): RenderedMessage {
    return renderMessage(TEMPLATE_SPECS[kind], t, o);
  }

  /**
   * Renders and sends [kind] to [o.to] and notes it. A server that can't send on the channel throws
   * DeliveryUnavailable (noted as off); a transport's failure is rethrown (noted as failed).
   */
  async send(kind: MessageKind, o: DispatchInput): Promise<DispatchEntry> {
    const spec = TEMPLATE_SPECS[kind];
    const inUse = o.draft
      ? { ...o.draft, locale: localeFor(spec, o.locale), custom: true }
      : await this.template(kind, o.locale);
    const message = renderMessage(spec, inUse, {
      vars: o.vars,
      parts: o.parts,
      locale: inUse.locale,
    });
    const secret = Object.fromEntries(
      spec.variables.filter((v) => v.secret).map((v) => [v.name, HIDDEN]),
    );
    const transport = this.transport(spec.channel);
    const entry: DispatchEntry = {
      id: randomUUID(),
      at: (this.d.now?.() ?? new Date()).toISOString(),
      kind,
      channel: spec.channel,
      locale: inUse.locale,
      to: spec.channel === "mail" ? maskEmail(o.to) : maskPhone(o.to),
      ...(spec.channel === "mail" && {
        subject: fill(inUse.subject ?? "", { ...o.vars, ...secret }).trim(),
      }),
      status: "sent",
      transport: transport.name,
      custom: inUse.custom,
      ...(o.test && { test: true }),
    };
    try {
      if (spec.channel === "mail") {
        await this.d.mail.send({
          to: o.to,
          subject: message.subject!,
          text: message.text,
          html: message.html!,
          ...(o.attachments?.length && { attachments: o.attachments }),
        });
      } else {
        await this.d.sms.send(o.to, message.text);
      }
    } catch (e) {
      entry.status = e instanceof DeliveryUnavailable ? "off" : "failed";
      entry.error = noAddresses((e as Error).message ?? String(e)).slice(0, 200);
      this.note(entry);
      throw e;
    }
    this.note(entry);
    return entry;
  }

  /** The latest dispatches, newest first. */
  recent(limit = 50): DispatchEntry[] {
    return this.log.slice(0, Math.max(0, limit));
  }

  private note(entry: DispatchEntry) {
    this.log.unshift(entry);
    this.log.length = Math.min(this.log.length, this.d.keep ?? 200);
  }
}
