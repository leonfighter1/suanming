/**
 * Mail and text messages (tech plan S15): the transports, chosen from the environment.
 *
 * MINGLI_MAIL / MINGLI_SMS = outbox | off. In dev mode both default to the outbox (MINGLI_OUTBOX_DIR, default
 * `.outbox`, git-ignored); elsewhere to off. A provider (SMTP, an email API, an SMS gateway) is the owner's next step:
 * it plugs in as another transport here.
 */
import { NoMail, OutboxMail, type MailTransport } from "./mail.js";
import { NoSms, OutboxSms, type SmsTransport } from "./sms.js";

export * from "./mail.js";
export * from "./sms.js";
export { buildMime, encodeWords, mailbox } from "./mime.js";

export interface Notify {
  mail: MailTransport;
  sms: SmsTransport;
  /** Where the outbox is, when either transport writes to it. */
  outbox?: string;
}

function kind(name: string, raw: string | undefined, devMode: boolean): "outbox" | "off" {
  const v = raw?.trim().toLowerCase() || (devMode ? "outbox" : "off");
  if (v !== "outbox" && v !== "off") {
    throw new Error(`${name} must be outbox or off (a provider comes with the owner's choice)`);
  }
  return v;
}

export function notifyFromEnv(
  devMode: boolean,
  env: Record<string, string | undefined> = process.env,
  log: (msg: string) => void = console.log,
): Notify {
  const dir = env.MINGLI_OUTBOX_DIR?.trim() || ".outbox";
  const mailKind = kind("MINGLI_MAIL", env.MINGLI_MAIL, devMode);
  const smsKind = kind("MINGLI_SMS", env.MINGLI_SMS, devMode);
  const from = env.MINGLI_MAIL_FROM?.trim();
  return {
    mail:
      mailKind === "outbox" ? new OutboxMail(dir, { log, ...(from && { from }) }) : new NoMail(),
    sms: smsKind === "outbox" ? new OutboxSms(dir, { log }) : new NoSms(),
    ...((mailKind === "outbox" || smsKind === "outbox") && { outbox: dir }),
  };
}
