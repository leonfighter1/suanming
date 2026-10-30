/**
 * A template's markup (tech plan S25): what a mail's body is written in, and how a message's variables go into it.
 *
 * - `# text` the page's title; `## text` a heading;
 * - paragraphs, a blank line apart (the lines of one paragraph keep their breaks);
 * - `> text` a note in small grey; `---` a rule; `!! text` a highlight (a code shown large); `- text` a list item;
 * - `{{name}}` a variable; a message's own part (`{{report}}`, `{{records}}`) on a line of its own.
 *
 * Everything is text: the HTML renderer escapes it, so a template or a variable never makes markup of its own.
 */
import type { MailPart } from "../export/render-html.js";
import type { TemplateSpec, TemplateText } from "./templates.js";

const VAR = /\{\{\s*([A-Za-z_]\w*)\s*\}\}/g;
const PART_LINE = /^\{\{\s*([A-Za-z_]\w*)\s*\}\}$/;

/** The variables [s] names, in order, each once. */
export function variablesIn(s: string): string[] {
  return [...new Set([...s.matchAll(VAR)].map((m) => m[1]!))];
}

/** [s] with each variable's value; one without a value stays as written. */
export function fill(s: string, vars: Record<string, string>): string {
  return s.replace(VAR, (whole, name: string) => vars[name] ?? whole);
}

/**
 * The body's parts, the variables filled; each part variable's line takes that part's blocks (none when it has none).
 * A part that ends up empty (a note whose variable is empty) is left out.
 */
export function parseMarkup(
  body: string,
  vars: Record<string, string>,
  parts: Record<string, MailPart[]> = {},
): MailPart[] {
  const out: MailPart[] = [];
  let paragraph: string[] = [];
  const add = (part: MailPart) => {
    if ("text" in part && part.type !== "divider" && !(part.text ?? "").trim()) return;
    out.push(part);
  };
  const flush = () => {
    if (paragraph.length) add({ type: "p", text: fill(paragraph.join("\n"), vars) });
    paragraph = [];
  };
  for (const raw of body.replace(/\r\n?/g, "\n").split("\n")) {
    const line = raw.trimEnd();
    const part = PART_LINE.exec(line.trim());
    let m: RegExpExecArray | null;
    if (!line.trim()) {
      flush();
    } else if (part && part[1]! in parts) {
      flush();
      out.push(...parts[part[1]!]!);
    } else if ((m = /^##\s+(.*)$/.exec(line))) {
      flush();
      add({ type: "h2", text: fill(m[1]!, vars) });
    } else if ((m = /^#\s+(.*)$/.exec(line))) {
      flush();
      add({ type: "title", text: fill(m[1]!, vars) });
    } else if ((m = /^>\s?(.*)$/.exec(line))) {
      flush();
      add({ type: "note", text: fill(m[1]!, vars) });
    } else if (/^-{3,}$/.test(line.trim())) {
      flush();
      out.push({ type: "divider" });
    } else if ((m = /^!!\s+(.*)$/.exec(line))) {
      flush();
      add({ type: "code", text: fill(m[1]!, vars) });
    } else if ((m = /^-\s+(.*)$/.exec(line))) {
      flush();
      add({ type: "bullet", text: fill(m[1]!, vars) });
    } else {
      paragraph.push(line);
    }
  }
  flush();
  return out;
}

/** How long a template's parts may be. */
export const TEMPLATE_LIMITS = { subject: 200, body: 10_000, sms: 500 };

/**
 * What is wrong with [t] as [spec]'s template, in words for the editor; none when it may be saved. A mail needs its
 * subject; an SMS has none. Every variable must be the message's; each required one must be used; a part
 * (`{{report}}`) only on a line of its own.
 */
export function templateProblems(spec: TemplateSpec, t: TemplateText): string[] {
  const problems: string[] = [];
  const body = typeof t.body === "string" ? t.body : "";
  const subject = typeof t.subject === "string" ? t.subject : undefined;
  if (!body.trim()) problems.push("正文不能为空");
  if (spec.channel === "mail") {
    if (!subject?.trim()) problems.push("邮件需要标题");
    else if ([...subject].length > TEMPLATE_LIMITS.subject) {
      problems.push(`标题最多 ${TEMPLATE_LIMITS.subject} 个字`);
    }
    if ([...body].length > TEMPLATE_LIMITS.body)
      problems.push(`正文最多 ${TEMPLATE_LIMITS.body} 个字`);
  } else {
    if (subject !== undefined && subject.trim()) problems.push("短信没有标题");
    if ([...body].length > TEMPLATE_LIMITS.sms)
      problems.push(`短信最多 ${TEMPLATE_LIMITS.sms} 个字`);
  }
  const known = new Map(spec.variables.map((v) => [v.name, v]));
  const used = variablesIn(`${subject ?? ""}\n${body}`);
  for (const name of used) {
    if (!known.has(name)) problems.push(`没有 {{${name}}} 这个变量`);
  }
  for (const name of spec.required) {
    if (!used.includes(name)) problems.push(`需要用到 {{${name}}}`);
  }
  for (const v of spec.variables.filter((v) => v.part)) {
    if (variablesIn(subject ?? "").includes(v.name)) problems.push(`{{${v.name}}} 不能放在标题里`);
    for (const line of body.split("\n")) {
      if (variablesIn(line).includes(v.name) && PART_LINE.exec(line.trim())?.[1] !== v.name) {
        problems.push(`{{${v.name}}} 要单独占一行`);
        break;
      }
    }
  }
  return problems;
}
