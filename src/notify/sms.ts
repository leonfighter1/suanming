/**
 * How text messages leave the server (tech plan WP15.3): the codes that bind a phone number to its owner. As for
 * mail, the provider is the owner's next step; development writes each message to the outbox, elsewhere it is off.
 */
import { randomUUID } from "node:crypto";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { DeliveryUnavailable, stamp } from "./mail.js";

export interface SmsTransport {
  /** What delivers: "outbox" (development), "off", or a provider's name. */
  readonly name: string;
  /** `to` in E.164. */
  send(to: string, text: string): Promise<{ id: string }>;
}

export class NoSms implements SmsTransport {
  readonly name = "off";
  async send(): Promise<never> {
    throw new DeliveryUnavailable("text messages are not set up on this server");
  }
}

/**
 * Development: each message is written to `<dir>/sms` as a .txt file. The console line shows the message, which
 * holds the code but not the number, so the owner can test binding without a provider.
 */
export class OutboxSms implements SmsTransport {
  readonly name = "outbox";
  constructor(
    private readonly dir: string,
    private readonly o: { log?: (msg: string) => void; now?: () => Date } = {},
  ) {}

  async send(to: string, text: string) {
    const id = randomUUID();
    const folder = join(this.dir, "sms");
    mkdirSync(folder, { recursive: true });
    const file = join(folder, `${stamp(this.o.now?.() ?? new Date())}-${id.slice(0, 8)}.txt`);
    writeFileSync(file, `To: ${to}\n\n${text}\n`);
    (this.o.log ?? console.log)(`sms (dev outbox): ${file}: ${text}`);
    return { id };
  }
}

/** Kept in memory, for tests. */
export class MemorySms implements SmsTransport {
  readonly name = "memory";
  readonly sent: { to: string; text: string }[] = [];

  async send(to: string, text: string) {
    this.sent.push({ to, text });
    return { id: randomUUID() };
  }
}
