/**
 * How mail leaves the server (tech plan WP15.3–15.4): verification codes, and reports when their owner asks for
 * them. The provider is the owner's next step (留到下一步); until then development writes every message to an outbox
 * folder, and elsewhere mail is off.
 */
import { randomUUID } from "node:crypto";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { buildMime, mailbox, type MailMessage } from "./mime.js";

export type { MailAttachment, MailMessage } from "./mime.js";

export interface MailTransport {
  /** What delivers: "outbox" (development), "off", or a provider's name. */
  readonly name: string;
  send(m: MailMessage): Promise<{ id: string }>;
}

/** Nothing can be delivered: this server has no provider for it yet. */
export class DeliveryUnavailable extends Error {}

/** No mail goes anywhere: the default outside development, until a provider is chosen. */
export class NoMail implements MailTransport {
  readonly name = "off";
  async send(): Promise<never> {
    throw new DeliveryUnavailable("mail is not set up on this server");
  }
}

/** The sender every message carries, unless MINGLI_MAIL_FROM says otherwise. */
export const DEFAULT_FROM = mailbox("命理大师", "no-reply@mingli.local");

/** 20261029-013000: a file name that sorts by time. */
export const stamp = (d: Date) =>
  d.toISOString().replace(/[-:]/g, "").replace("T", "-").slice(0, 15);

/**
 * Development: each message is written to `<dir>/mail` as an .eml file (any mail program opens it), with a .txt
 * beside it holding the recipient, the subject and the text, for reading in an editor. The console line names only
 * the file: never the address or the content (security-baseline.md).
 */
export class OutboxMail implements MailTransport {
  readonly name = "outbox";
  constructor(
    private readonly dir: string,
    private readonly o: { from?: string; log?: (msg: string) => void; now?: () => Date } = {},
  ) {}

  async send(m: MailMessage) {
    const id = randomUUID();
    const date = this.o.now?.() ?? new Date();
    const folder = join(this.dir, "mail");
    mkdirSync(folder, { recursive: true });
    const file = join(folder, `${stamp(date)}-${id.slice(0, 8)}`);
    writeFileSync(`${file}.eml`, buildMime(m, { from: this.o.from ?? DEFAULT_FROM, date, id }));
    const files = (m.attachments ?? []).map((a) => a.filename).join(", ");
    writeFileSync(
      `${file}.txt`,
      `To: ${m.to}\nSubject: ${m.subject}\n${files && `Attachments: ${files}\n`}\n${m.text}\n`,
    );
    (this.o.log ?? console.log)(`mail (dev outbox): ${file}.eml`);
    return { id };
  }
}

/** Kept in memory, for tests. */
export class MemoryMail implements MailTransport {
  readonly name = "memory";
  readonly sent: MailMessage[] = [];
  /** Set to make the next sends fail, as a provider outage would. */
  failing = false;

  async send(m: MailMessage) {
    if (this.failing) throw new Error("mail provider unavailable");
    this.sent.push(m);
    return { id: randomUUID() };
  }
}
