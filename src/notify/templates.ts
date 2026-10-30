/**
 * The messages the server sends, and their templates (tech plan S25; the owner: 让后台用户可以编辑各类发送邮件的前端页面。
 * 同时还有SMS等等). Each message has a spec here: its channel, what it is and when it goes, its variables (with a
 * sample for previews and test sends), and its default wording per language. An admin's own wording is kept in the
 * store and wins until reset (dispatch.ts).
 *
 * A mail's body is a small markup (markup.ts): `# title`, `## heading`, paragraphs a blank line apart, `> note`,
 * `---`, `!! highlight` (a code shown large), `- list item`, and a message's own part (`{{report}}`, `{{records}}`)
 * on a line of its own. An SMS is its text. `{{name}}` puts in a variable.
 */
import type { Locale } from "../ai/terms.js";
import type { DocBlock } from "../export/document.js";

export const MESSAGE_KINDS = ["code_mail", "code_sms", "report_mail", "records_mail"] as const;
export type MessageKind = (typeof MESSAGE_KINDS)[number];
export type Channel = "mail" | "sms";

export interface TemplateVariable {
  name: string;
  /** What it holds, for the editor. */
  about: string;
  /** What a preview and a test send put in. */
  sample: string;
  /** A part of the message on a line of its own (the report, the records): mail only. */
  part?: boolean;
  /** Never written into the dispatch log (a verification code). */
  secret?: boolean;
}

/** A message's wording in one language: a mail's subject and body, an SMS's text (its body). */
export interface TemplateText {
  subject?: string;
  body: string;
}

export interface TemplateSpec {
  kind: MessageKind;
  channel: Channel;
  /** Its name in the dashboard. */
  name: string;
  /** When it goes. */
  about: string;
  variables: TemplateVariable[];
  /** Variables a template must use (in its subject or body): without them the message is no use. */
  required: string[];
  /** The languages it has a wording for; another language takes 简体's. */
  defaults: Partial<Record<Locale, TemplateText>>;
}

const CODE = { name: "code", about: "6 位验证码", sample: "482913", secret: true };
const MINUTES = { name: "minutes", about: "验证码几分钟内有效", sample: "10" };

export const TEMPLATE_SPECS: Record<MessageKind, TemplateSpec> = {
  code_mail: {
    kind: "code_mail",
    channel: "mail",
    name: "验证码邮件",
    about: "在设置里绑定或验证邮箱时发出",
    variables: [CODE, MINUTES],
    required: ["code"],
    defaults: {
      "zh-Hans": {
        subject: "命理大师验证码：{{code}}",
        body: [
          "# 验证你的邮箱",
          "",
          "你好：",
          "",
          "你正在为命理大师账号验证这个邮箱。验证码是：",
          "",
          "!! {{code}}",
          "",
          "{{minutes}} 分钟内有效。",
          "",
          "---",
          "",
          "> 如果不是你本人操作，请忽略本邮件，这个邮箱不会被加入任何账号。",
        ].join("\n"),
      },
      "zh-Hant": {
        subject: "命理大師驗證碼：{{code}}",
        body: [
          "# 驗證你的電子郵件",
          "",
          "你好：",
          "",
          "你正在為命理大師帳戶驗證這個電子郵件地址。驗證碼是：",
          "",
          "!! {{code}}",
          "",
          "{{minutes}} 分鐘內有效。",
          "",
          "---",
          "",
          "> 如果不是你本人操作，請忽略本郵件，這個地址不會被加入任何帳戶。",
        ].join("\n"),
      },
      en: {
        subject: "命理大师 code: {{code}}",
        body: [
          "# Verify your email",
          "",
          "Hello,",
          "",
          "You are verifying this address for a 命理大师 account. Your code is:",
          "",
          "!! {{code}}",
          "",
          "It is valid for {{minutes}} minutes.",
          "",
          "---",
          "",
          "> If this wasn't you, ignore this mail: the address won't be added to any account.",
        ].join("\n"),
      },
    },
  },
  code_sms: {
    kind: "code_sms",
    channel: "sms",
    name: "验证码短信",
    about: "在设置里绑定手机号时发出",
    variables: [CODE, MINUTES],
    required: ["code"],
    defaults: {
      "zh-Hans": {
        body: "【命理大师】你的验证码是 {{code}}，{{minutes}} 分钟内有效。如非本人操作，请忽略本短信。",
      },
      "zh-Hant": {
        body: "【命理大師】你的驗證碼是 {{code}}，{{minutes}} 分鐘內有效。如非本人操作，請忽略本訊息。",
      },
      en: {
        body: "[命理大师] Your code is {{code}}, valid for {{minutes}} minutes. If this wasn't you, ignore this message.",
      },
    },
  },
  report_mail: {
    kind: "report_mail",
    channel: "mail",
    name: "报告完成邮件",
    about: "测算完成后发到邮箱：读者开启后，每份通过的报告完成时发出，附 PDF",
    variables: [
      { name: "title", about: "报告的标题", sample: "徐梅 的命盘" },
      { name: "subtitle", about: "报告的类型和时间", sample: "AI 解读 · 2026-10-29 09:30" },
      {
        name: "pdf_note",
        about: "有 PDF 附件时是“完整的 PDF 在附件里。”，没有时为空",
        sample: "完整的 PDF 在附件里。",
      },
      { name: "report", about: "报告的全部内容", sample: "（报告内容）", part: true },
    ],
    required: ["report"],
    defaults: {
      "zh-Hans": {
        subject: "命理大师：{{title}}",
        body: [
          "# {{title}}",
          "",
          "> {{subtitle}}",
          "",
          "你的报告完成了，内容在下面。{{pdf_note}}",
          "",
          "{{report}}",
          "",
          "---",
          "",
          "> 你在命理大师开启了“测算完成后发到邮箱”，所以收到这封邮件。不想再收，在 app 的“设置 → 报告”里关掉即可。",
        ].join("\n"),
      },
      "zh-Hant": {
        subject: "命理大師：{{title}}",
        body: [
          "# {{title}}",
          "",
          "> {{subtitle}}",
          "",
          "你的報告完成了，內容在下面。{{pdf_note}}",
          "",
          "{{report}}",
          "",
          "---",
          "",
          "> 你在命理大師開啟了「測算完成後發到電子郵件」，所以收到這封郵件。不想再收，在 app 的「設定 → 報告」裡關掉即可。",
        ].join("\n"),
      },
    },
  },
  records_mail: {
    kind: "records_mail",
    channel: "mail",
    name: "记录发送邮件",
    about: "以往记录 → 发到邮箱：读者选中的记录，作 PDF 或 Word 附件",
    variables: [
      { name: "title", about: "一份记录时是它的标题，多份时是“N 份记录”", sample: "2 份记录" },
      { name: "count", about: "记录的份数", sample: "2" },
      { name: "records", about: "每份记录的标题，一行一份", sample: "（记录列表）", part: true },
    ],
    required: [],
    defaults: {
      "zh-Hans": {
        subject: "命理大师：{{title}}",
        body: [
          "# {{title}}",
          "",
          "你从命理大师发出的 {{count}} 份记录在附件里：",
          "",
          "{{records}}",
          "",
          "---",
          "",
          "> 报告由 AI 生成，仅供娱乐和玄学学习使用，不是预测。",
          "",
          "> 这封邮件是你在 app 里点“发到邮箱”发出的，只会发到你账号里验证过的邮箱。",
        ].join("\n"),
      },
      "zh-Hant": {
        subject: "命理大師：{{title}}",
        body: [
          "# {{title}}",
          "",
          "你從命理大師發出的 {{count}} 份紀錄在附件裡：",
          "",
          "{{records}}",
          "",
          "---",
          "",
          "> 報告由 AI 生成，僅供娛樂和玄學學習使用，不是預測。",
          "",
          "> 這封郵件是你在 app 裡點「發到電子郵件」發出的，只會發到你帳戶裡驗證過的電子郵件。",
        ].join("\n"),
      },
    },
  },
};

/** The languages a message has its own wording for, 简体 first. */
export const localesOf = (spec: TemplateSpec): Locale[] =>
  (["zh-Hans", "zh-Hant", "en"] as Locale[]).filter((l) => spec.defaults[l]);

/** The language a message goes out in: the reader's, if the message has it, else 简体. */
export const localeFor = (spec: TemplateSpec, locale: Locale): Locale =>
  spec.defaults[locale] ? locale : "zh-Hans";

/** The variables' samples, for a preview or a test send. */
export const sampleVars = (spec: TemplateSpec): Record<string, string> =>
  Object.fromEntries(spec.variables.filter((v) => !v.part).map((v) => [v.name, v.sample]));

/** A preview's and a test send's report: a short reading, as the report mail shows one. */
export const SAMPLE_REPORT: DocBlock[] = [
  { type: "h2", text: "五行" },
  { type: "summary", text: "木火偏旺，宜以水土调和。" },
  { type: "term", text: "日主 己土 · 生于卯月" },
  {
    type: "p",
    text: "己土生于卯月，木旺土虚。行事宜稳，先立根基，再图进取；与人合作时，把分工说在前面。",
  },
  { type: "quote", text: "日主己土，月令卯木。" },
  { type: "note", text: "内容由 AI 生成，仅供娱乐和玄学学习使用。" },
];

/** A preview's and a test send's records. */
export const SAMPLE_RECORDS = ["徐梅 的命盘", "塔罗 · 三张牌"];

/** The brand as a message in [locale] writes it. */
export const brandOf = (locale: Locale) => (locale === "zh-Hant" ? "命理大師" : "命理大师");

/** A report mail's line about its PDF, in its language. */
export const pdfNote = (locale: Locale) =>
  locale === "zh-Hant" ? "完整的 PDF 在附件裡。" : "完整的 PDF 在附件里。";

/** A records mail's title: the one record's, or how many. */
export const recordsTitle = (titles: string[], locale: Locale) =>
  titles.length === 1
    ? titles[0]!
    : locale === "zh-Hant"
      ? `${titles.length} 份紀錄`
      : `${titles.length} 份记录`;
