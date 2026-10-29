/**
 * The mails that carry reports (tech plan WP15.4; the owner: 每当一个算法AI算完成后，可以选择给邮箱发送报告结果):
 * - when a reading or a 一生运势报告 is done and its owner turned on 测算完成后发到邮箱: the report in the message, and
 *   as a PDF;
 * - when the owner sends chosen records to their own email (发到邮箱): the Word or PDF files they chose.
 * Both go only to the account's verified email.
 */
import type { Locale } from "../ai/terms.js";
import type { Doc, DocBlock } from "../export/document.js";
import { renderHtml, renderText } from "../export/render-html.js";
import type { MailAttachment, MailMessage } from "./mime.js";

const WORDS = {
  "zh-Hans": {
    brand: "命理大师",
    done: "你的报告完成了，内容在下面，完整的 PDF 在附件里。",
    doneNoPdf: "你的报告完成了，内容在下面。",
    why: "你在命理大师开启了“测算完成后发到邮箱”，所以收到这封邮件。不想再收，在 app 的“设置 → 报告”里关掉即可。",
    records: (n: number) => `${n} 份记录`,
    sent: (n: number) =>
      n === 1 ? "你从命理大师发出的记录在附件里。" : `你从命理大师发出的 ${n} 份记录在附件里：`,
    sentWhy: "这封邮件是你在 app 里点“发到邮箱”发出的，只会发到你账号里验证过的邮箱。",
    notice: "报告由 AI 生成，仅供娱乐和玄学学习使用，不是预测。",
  },
  "zh-Hant": {
    brand: "命理大師",
    done: "你的報告完成了，內容在下面，完整的 PDF 在附件裡。",
    doneNoPdf: "你的報告完成了，內容在下面。",
    why: "你在命理大師開啟了「測算完成後發到電子郵件」，所以收到這封郵件。不想再收，在 app 的「設定 → 報告」裡關掉即可。",
    records: (n: number) => `${n} 份紀錄`,
    sent: (n: number) =>
      n === 1 ? "你從命理大師發出的紀錄在附件裡。" : `你從命理大師發出的 ${n} 份紀錄在附件裡：`,
    sentWhy: "這封郵件是你在 app 裡點「發到電子郵件」發出的，只會發到你帳戶裡驗證過的電子郵件。",
    notice: "報告由 AI 生成，僅供娛樂和玄學學習使用，不是預測。",
  },
};

const wordsOf = (l: Locale) => WORDS[l === "zh-Hant" ? "zh-Hant" : "zh-Hans"];

/** 测算完成后发到邮箱: the report itself, between a line that says what it is and one that says why it came. */
export function reportMail(o: {
  to: string;
  doc: Doc;
  locale: Locale;
  pdf?: MailAttachment;
}): MailMessage {
  const w = wordsOf(o.locale);
  const blocks: DocBlock[] = [
    { type: "p", text: o.pdf ? w.done : w.doneNoPdf },
    ...o.doc.blocks,
    { type: "divider" },
    { type: "note", text: w.why },
  ];
  const doc = { ...o.doc, blocks };
  return {
    to: o.to,
    subject: `${w.brand}：${o.doc.title}`,
    text: renderText(doc),
    html: renderHtml(doc),
    ...(o.pdf && { attachments: [o.pdf] }),
  };
}

/** 发到邮箱: the chosen records as files, the message listing them. */
export function recordsMail(o: {
  to: string;
  titles: string[];
  locale: Locale;
  files: MailAttachment[];
}): MailMessage {
  const w = wordsOf(o.locale);
  const n = o.titles.length;
  const title = n === 1 ? o.titles[0]! : w.records(n);
  const doc: Doc = {
    title,
    subtitle: w.brand,
    blocks: [
      { type: "p", text: w.sent(n) },
      ...(n > 1 ? o.titles.map((t): DocBlock => ({ type: "bullet", text: t })) : []),
      { type: "divider" },
      { type: "note", text: w.notice },
      { type: "note", text: w.sentWhy },
    ],
  };
  return {
    to: o.to,
    subject: `${w.brand}：${title}`,
    text: renderText(doc),
    html: renderHtml(doc),
    attachments: o.files,
  };
}
