// S25 (v13.1.0): the messages' templates, their mail page in light and dark, the dispatcher, the 消息 API and the
// 后台 roles (the owner, 2026-10-30: 设计好邮件发送逻辑，让后台用户可以编辑各类发送邮件的前端页面…邮件的preview界面以及发送出去
// 的邮件也要符合当前app的跟随系统模式; admin, manager, editor).
import { randomBytes, randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import { beforeAll, describe, expect, it } from "vitest";
import { InMemoryStore } from "../src/api/store.js";
import type { UserRecord } from "../src/auth/service.js";
import { PgStore } from "../src/db/pg-store.js";
import { MAIL_PALETTE } from "../src/export/render-html.js";
import {
  DeliveryUnavailable,
  Dispatcher,
  localesOf,
  MemoryMail,
  MemorySms,
  MemoryTemplates,
  MESSAGE_KINDS,
  NoMail,
  NoSms,
  parseMarkup,
  renderMessage,
  smsSegments,
  TEMPLATE_SPECS,
  templateProblems,
  variablesIn,
} from "../src/notify/index.js";
import { buildAuth } from "../src/service/runtime.js";
import { staffApi } from "./api.js";
import { DRAW_KEY, PEPPER } from "./helpers.js";

const CODE_VARS = { code: "482913", minutes: "10" };

describe("the templates", () => {
  it("every message has its wording in each of its languages, savable as it is, using every variable", () => {
    for (const kind of MESSAGE_KINDS) {
      const spec = TEMPLATE_SPECS[kind];
      expect(localesOf(spec)[0], kind).toBe("zh-Hans");
      for (const locale of localesOf(spec)) {
        expect(templateProblems(spec, spec.defaults[locale]!), `${kind} ${locale}`).toEqual([]);
      }
      const hans = spec.defaults["zh-Hans"]!;
      expect(variablesIn(`${hans.subject ?? ""}\n${hans.body}`).sort(), kind).toEqual(
        spec.variables.map((v) => v.name).sort(),
      );
    }
  });

  it("the markup: a title, a paragraph's lines, a note, a rule, a highlight, a list, a part on its line", () => {
    const body = [
      "# 你好 {{name}}",
      "",
      "第一行",
      "第二行",
      "",
      "> 小字",
      "> {{empty}}",
      "---",
      "!! {{code}}",
      "- 一",
      "- 二",
      "{{report}}",
      "## 小标题",
      "{{unknown}} 留着",
    ].join("\n");
    expect(
      parseMarkup(
        body,
        { name: "徐梅", code: "123456", empty: "" },
        { report: [{ type: "p", text: "报告" }] },
      ),
    ).toEqual([
      { type: "title", text: "你好 徐梅" },
      { type: "p", text: "第一行\n第二行" },
      { type: "note", text: "小字" },
      // The note whose variable is empty is left out.
      { type: "divider" },
      { type: "code", text: "123456" },
      { type: "bullet", text: "一" },
      { type: "bullet", text: "二" },
      { type: "p", text: "报告" },
      { type: "h2", text: "小标题" },
      { type: "p", text: "{{unknown}} 留着" },
    ]);
  });

  it("what may not be saved, in words for the editor", () => {
    const { code_mail: mail, code_sms: sms, report_mail: report } = TEMPLATE_SPECS;
    expect(templateProblems(mail, { subject: "码 {{code}}", body: "{{nope}}" })).toEqual([
      "没有 {{nope}} 这个变量",
    ]);
    expect(templateProblems(mail, { subject: "验证码", body: "你好" })).toEqual([
      "需要用到 {{code}}",
    ]);
    expect(templateProblems(report, { subject: "{{title}}", body: "看：{{report}}" })).toEqual([
      "{{report}} 要单独占一行",
    ]);
    expect(templateProblems(report, { subject: "{{report}}", body: "{{report}}" })).toEqual([
      "{{report}} 不能放在标题里",
    ]);
    expect(templateProblems(mail, { subject: " ", body: "{{code}}" })).toEqual(["邮件需要标题"]);
    expect(templateProblems(mail, { subject: "{{code}}", body: "" })).toEqual(["正文不能为空"]);
    expect(templateProblems(sms, { subject: "x", body: "{{code}}" })).toEqual(["短信没有标题"]);
    // 8 + 500 characters.
    expect(templateProblems(sms, { body: `{{code}}${"长".repeat(500)}` })).toEqual([
      "短信最多 500 个字",
    ]);
  });
});

describe("a mail's page, light and dark", () => {
  const spec = TEMPLATE_SPECS.code_mail;

  it("a code mail: its subject, the code in its box, its text; dark by the reader's system, a preview's own mark", () => {
    const m = renderMessage(spec, spec.defaults["zh-Hans"]!, {
      vars: CODE_VARS,
      locale: "zh-Hans",
    });
    expect(m.subject).toBe("命理大师验证码：482913");
    expect(m.html).toMatch(/<div class="m-code" style="[^"]*">482913<\/div>/);
    expect(m.html).toContain('<html lang="zh-CN">');
    expect(m.html).toContain('<meta name="color-scheme" content="light dark">');
    expect(m.text).toBe(
      [
        "验证你的邮箱",
        "",
        "你好：",
        "",
        "你正在为命理大师账号验证这个邮箱。验证码是：",
        "",
        "  482913",
        "",
        "10 分钟内有效。",
        "",
        "────────────",
        "",
        "如果不是你本人操作，请忽略本邮件，这个邮箱不会被加入任何账号。",
        "",
      ].join("\n"),
    );
    const dark = renderMessage(spec, spec.defaults["zh-Hans"]!, {
      vars: CODE_VARS,
      locale: "zh-Hans",
      scheme: "dark",
    });
    expect(dark.html).toContain('<html lang="zh-CN" data-scheme="dark">');
    const hant = renderMessage(spec, spec.defaults["zh-Hant"]!, {
      vars: CODE_VARS,
      locale: "zh-Hant",
    });
    expect(hant.html).toContain('<html lang="zh-TW">');
    expect(hant.html).toMatch(/>命理大師<\/td>/);
  });

  it("a value is text, never markup", () => {
    const report = TEMPLATE_SPECS.report_mail;
    const m = renderMessage(report, report.defaults["zh-Hans"]!, {
      vars: { title: "<img src=x onerror=alert(1)>", subtitle: "", pdf_note: "" },
      parts: { report: [{ type: "p", text: "<b>正文</b>" }] },
      locale: "zh-Hans",
    });
    expect(m.html).not.toContain("<img");
    expect(m.html).toContain("&lt;img src=x onerror=alert(1)&gt;");
    expect(m.html).toContain("&lt;b&gt;正文&lt;/b&gt;");
  });

  it("the mail's colours are the app's, light and dark (ThemeTokens in tokens.dart)", () => {
    const dart = readFileSync(
      new URL("../app/lib/presentation/tokens.dart", import.meta.url),
      "utf8",
    );
    const light = dart.slice(
      dart.indexOf("static const light = ThemeTokens("),
      dart.indexOf("static const dark = ThemeTokens("),
    );
    const dark = dart.slice(dart.indexOf("static const dark = ThemeTokens("));
    const colour = (part: string, name: string) => {
      const m = new RegExp(`\\b${name}: Color\\(0xFF([0-9A-F]{6})\\)`).exec(part);
      return m ? `#${m[1]}` : undefined;
    };
    for (const [name, value] of Object.entries(MAIL_PALETTE.light))
      expect(colour(light, name), name).toBe(value);
    for (const [name, value] of Object.entries(MAIL_PALETTE.dark))
      expect(colour(dark, name), name).toBe(value);
  });

  it("an SMS: its text, its length and how many messages it takes", () => {
    expect(smsSegments("a".repeat(160))).toEqual({ length: 160, segments: 1 });
    expect(smsSegments("a".repeat(161))).toEqual({ length: 161, segments: 2 }); // 161 / 153, rounded up
    expect(smsSegments("长".repeat(70))).toEqual({ length: 70, segments: 1 });
    expect(smsSegments("长".repeat(135))).toEqual({ length: 135, segments: 3 }); // 135 / 67 = 2.01, rounded up
    const sms = TEMPLATE_SPECS.code_sms;
    const s = renderMessage(sms, sms.defaults["zh-Hans"]!, { vars: CODE_VARS, locale: "zh-Hans" });
    expect(s.text).toBe(
      "【命理大师】你的验证码是 482913，10 分钟内有效。如非本人操作，请忽略本短信。",
    );
    // 【命理大师】6 + 你的验证码是 6 + space 1 + 482913 6 + ， 1 + 10 2 + space 1 + 分钟内有效。6 + 如非本人操作，7
    // + 请忽略本短信。7 = 43: one message.
    expect(s.sms).toEqual({ length: 43, segments: 1 });
    expect(s.html).toBeUndefined();
  });
});

describe("the dispatcher", () => {
  it("sends by the wording in use and notes it, the address masked and the code hidden; off and failed noted too", async () => {
    const mail = new MemoryMail();
    const sms = new MemorySms();
    const templates = new MemoryTemplates();
    const d = new Dispatcher({
      mail,
      sms,
      templates,
      now: () => new Date("2026-10-30T04:00:00.000Z"),
    });
    const first = await d.send("code_mail", {
      to: "someone@example.com",
      locale: "zh-Hans",
      vars: CODE_VARS,
    });
    expect(mail.sent.at(-1)!.subject).toBe("命理大师验证码：482913");
    expect(mail.sent.at(-1)!.html).toContain('class="m-code"');
    expect(first).toMatchObject({
      kind: "code_mail",
      channel: "mail",
      locale: "zh-Hans",
      to: "s***@example.com",
      subject: "命理大师验证码：••••••",
      status: "sent",
      transport: "memory",
      custom: false,
      at: "2026-10-30T04:00:00.000Z",
    });
    // An admin's wording wins; a report for an English reader goes in 简体, the report mail having no English.
    await templates.putMessageTemplate({
      kind: "code_mail",
      locale: "zh-Hans",
      subject: "新标题 {{code}}",
      body: "!! {{code}}",
      updated_at: "2026-10-30T04:00:00.000Z",
    });
    expect(
      (await d.send("code_mail", { to: "someone@example.com", locale: "zh-Hans", vars: CODE_VARS }))
        .custom,
    ).toBe(true);
    expect(mail.sent.at(-1)!.subject).toBe("新标题 482913");
    expect((await d.template("report_mail", "en")).locale).toBe("zh-Hans");
    // +86 138 0013 8000: the country code, seven stars, the last four.
    const text = await d.send("code_sms", {
      to: "+8613800138000",
      locale: "zh-Hans",
      vars: CODE_VARS,
    });
    expect(text.to).toBe("+86 *******8000");
    expect(sms.sent.at(-1)!.text).toContain("482913");

    mail.failing = true;
    await expect(
      d.send("code_mail", { to: "someone@example.com", locale: "zh-Hans", vars: CODE_VARS }),
    ).rejects.toThrow();
    mail.failing = false;
    expect(d.recent().map((e) => e.status)).toEqual(["failed", "sent", "sent", "sent"]);
    expect(JSON.stringify(d.recent())).not.toContain("482913");
    expect(JSON.stringify(d.recent())).not.toContain("someone@");

    const off = new Dispatcher({ mail: new NoMail(), sms: new NoSms(), templates });
    await expect(
      off.send("code_mail", { to: "someone@example.com", locale: "zh-Hans", vars: CODE_VARS }),
    ).rejects.toBeInstanceOf(DeliveryUnavailable);
    expect(off.recent()[0]).toMatchObject({ status: "off", transport: "off" });
  });

  it("PGlite keeps a wording, until it is reset, and the new roles", async () => {
    const pg = await PgStore.open({ kek: randomBytes(32), pepper: PEPPER });
    const at = "2026-10-30T04:00:00.000Z";
    await pg.putMessageTemplate({
      kind: "code_sms",
      locale: "zh-Hant",
      body: "{{code}}",
      updated_at: at,
    });
    await pg.putMessageTemplate({
      kind: "code_mail",
      locale: "zh-Hans",
      subject: "a",
      body: "b",
      updated_at: at,
    });
    await pg.putMessageTemplate({
      kind: "code_mail",
      locale: "zh-Hans",
      subject: "{{code}}",
      body: "!! {{code}}",
      updated_at: at,
    });
    expect(await pg.listMessageTemplates()).toEqual([
      {
        kind: "code_mail",
        locale: "zh-Hans",
        subject: "{{code}}",
        body: "!! {{code}}",
        updated_at: at,
      },
      { kind: "code_sms", locale: "zh-Hant", body: "{{code}}", updated_at: at },
    ]);
    expect(await pg.deleteMessageTemplate("code_sms", "zh-Hant")).toBe(true);
    expect(await pg.deleteMessageTemplate("code_sms", "zh-Hant")).toBe(false);
    const id = randomUUID();
    const u: UserRecord = {
      id,
      social: {},
      country: "HK",
      locale: "zh-Hans",
      age_confirmed_at: at,
      created_at: at,
      username: "mia",
      username_lookup: randomBytes(32).toString("hex"),
      role: "manager",
    };
    await pg.put(u);
    expect((await pg.get(id))!.role).toBe("manager");
    await pg.put({ ...u, role: "editor" });
    expect((await pg.get(id))!.role).toBe("editor");
    await pg.close();
  }, 30_000);
});

// ---- the API ----

const store = new InMemoryStore();
const mail = new MemoryMail();
const sms = new MemorySms();
const auth = buildAuth({ digestPepper: PEPPER, drawKey: DRAW_KEY, ephemeral: true } as never, true);
/**
 * boss: an admin by MINGLI_ADMINS; mgr a manager, integ an editor (given below); alice, carol and dora users (dora
 * the matrix's target: signed out everywhere there).
 */
const LOGINS = ["boss", "mgr", "integ", "alice", "carol", "dora"];

/**
 * The server and the sessions, started by the first describe that calls the API, right before its tests (rule 81).
 * Started at the top of the file, the sign-ins' connections sat idle through the PGlite test above for seconds, and
 * the first call after it reused one as the server's 5 s keep-alive closed it: ECONNRESET under the full suite.
 */
const { start, call, ids } = staffApi(
  {
    auth,
    store,
    mail,
    sms,
    review: false,
    admins: ["boss"],
    now: () => new Date("2026-10-30T04:00:00.000Z"),
  },
  LOGINS,
  { mgr: "manager", integ: "editor" },
);
const json = async (who: string, path: string, method = "GET", body?: unknown) =>
  (await call(who, path, method, body)).json();

describe("the 后台 roles", () => {
  beforeAll(start);

  it("say what each may do: admin everything, a manager the numbers and roles, an editor the messages", async () => {
    expect(await json("boss", "/v1/admin/me")).toMatchObject({
      role: "admin",
      admin_by_config: true,
      can: ["view", "assign", "user_data", "messages", "content", "settings"],
      assignable_roles: ["user", "editor", "manager", "admin"],
    });
    expect(await json("mgr", "/v1/admin/me")).toMatchObject({
      role: "manager",
      can: ["view", "assign"],
      assignable_roles: ["user", "editor", "manager"],
    });
    expect(await json("integ", "/v1/admin/me")).toMatchObject({
      role: "editor",
      can: ["messages", "content"],
    });
    const no = await call("alice", "/v1/admin/me");
    expect([no.status, (await no.json()).code]).toEqual([403, "admin_only"]);
    // The app's ☰ asks /v1/me: staff for the three, nothing for a user.
    expect((await json("mgr", "/v1/me")).staff).toBe("manager");
    expect((await json("boss", "/v1/me")).staff).toBe("admin");
    expect(await json("alice", "/v1/me")).not.toHaveProperty("staff");
  });

  it("each route to each role: the server decides, 403 not_allowed beyond the role", async () => {
    const routes: [string, string, unknown?][] = [
      ["GET", "/v1/admin/overview"],
      ["GET", "/v1/admin/users"],
      ["GET", `/v1/admin/users/${ids.dora}`],
      ["PATCH", `/v1/admin/users/${ids.dora}`, { permissions: { ai: true } }],
      ["POST", `/v1/admin/users/${ids.dora}/points`, { points: 1 }],
      ["POST", `/v1/admin/users/${ids.dora}/sign-out`],
      ["GET", "/v1/admin/reports?format=csv"],
      ["GET", "/v1/admin/messages/templates"],
      ["POST", "/v1/admin/messages/preview", { kind: "code_sms", locale: "zh-Hans" }],
      ["GET", "/v1/admin/messages/log"],
    ];
    const allowed: Record<string, boolean[]> = {
      boss: [true, true, true, true, true, true, true, true, true, true],
      mgr: [true, true, true, true, false, false, false, false, false, false],
      integ: [false, false, false, false, false, false, false, true, true, true],
    };
    for (const [who, may] of Object.entries(allowed)) {
      for (const [i, [method, path, body]] of routes.entries()) {
        const res = await call(who, path, method, body);
        const why = `${who} ${method} ${path}`;
        if (may[i]) expect(res.status, why).toBeLessThan(300);
        else expect([res.status, (await res.json()).code], why).toEqual([403, "not_allowed"]);
      }
    }
  });

  it("a manager gives user, editor or manager, never admin and never on an admin; nobody changes their own role", async () => {
    const patch = (who: string, target: string, body: unknown) =>
      call(who, `/v1/admin/users/${ids[target]}`, "PATCH", body);
    expect((await patch("mgr", "carol", { role: "editor" })).status).toBe(200);
    expect((await json("carol", "/v1/admin/me")).role).toBe("editor");
    const toAdmin = await patch("mgr", "carol", { role: "admin" });
    expect([toAdmin.status, (await toAdmin.json()).code]).toEqual([403, "not_allowed"]);
    const onAdmin = await patch("mgr", "boss", { permissions: { ai: false } });
    expect([onAdmin.status, (await onAdmin.json()).code]).toEqual([403, "not_allowed"]);
    const self = await patch("mgr", "mgr", { role: "editor" });
    expect([self.status, (await self.json()).code]).toEqual([409, "admin_self"]);
    const bossSelf = await patch("boss", "boss", { role: "manager" });
    expect([bossSelf.status, (await bossSelf.json()).code]).toEqual([409, "admin_self"]);
    expect((await patch("mgr", "carol", { role: "bogus" })).status).toBe(400);
    // An admin makes carol a manager, then a user again.
    expect((await patch("boss", "carol", { role: "manager" })).status).toBe(200);
    expect((await json("carol", "/v1/admin/me")).role).toBe("manager");
    expect((await patch("boss", "carol", { role: "user" })).status).toBe(200);
    expect((await call("carol", "/v1/admin/me")).status).toBe(403);
    // The users list says each role.
    const rows = (await json("boss", "/v1/admin/users?role=manager")).items as {
      login: string;
      role: string;
    }[];
    expect(rows.map((r) => [r.login, r.role])).toEqual([["mgr", "manager"]]);
  });
});

describe("the 消息 API", () => {
  beforeAll(start);

  it("lists every message with its wordings, keeps a checked edit, previews a draft light or dark, resets", async () => {
    const list = await json("integ", "/v1/admin/messages/templates");
    expect(list.delivery).toEqual({ mail: "memory", sms: "memory" });
    expect(list.templates.map((t: { kind: string }) => t.kind)).toEqual([...MESSAGE_KINDS]);
    const code = list.templates[0];
    expect(code.locales.map((l: { locale: string }) => l.locale)).toEqual([
      "zh-Hans",
      "zh-Hant",
      "en",
    ]);
    expect(code.locales[0]).toMatchObject({ custom: false, subject: "命理大师验证码：{{code}}" });
    expect(code.variables[0]).toEqual({ name: "code", about: "6 位验证码", sample: "482913" });

    const bad = await call("integ", "/v1/admin/messages/templates/code_mail/zh-Hans", "PUT", {
      subject: "验证码",
      body: "你好 {{who}}",
    });
    const problem = await bad.json();
    expect([bad.status, problem.code]).toEqual([400, "invalid_template"]);
    expect(problem.problems).toEqual(["没有 {{who}} 这个变量", "需要用到 {{code}}"]);
    expect(
      (await call("integ", "/v1/admin/messages/templates/report_mail/en", "PUT", {})).status,
    ).toBe(404);

    const saved = await json("integ", "/v1/admin/messages/templates/code_mail/zh-Hans", "PUT", {
      subject: "【命理大师】{{code}}",
      body: "# 你的验证码\n\n!! {{code}}\n\n{{minutes}} 分钟内有效。",
    });
    expect(saved).toMatchObject({
      custom: true,
      subject: "【命理大师】{{code}}",
      locale: "zh-Hans",
    });
    // A reader asking for a code now gets the new wording.
    await call("alice", "/v1/account/email", "POST", { email: "alice@example.com" });
    expect(mail.sent.at(-1)!.subject).toMatch(/^【命理大师】\d{6}$/);
    expect(mail.sent.at(-1)!.to).toBe("alice@example.com");

    const preview = await json("integ", "/v1/admin/messages/preview", "POST", {
      kind: "code_mail",
      locale: "zh-Hans",
      subject: "{{code}}",
      body: "!! {{code}}\n\n{{nope}}",
      scheme: "dark",
    });
    expect(preview.subject).toBe("482913");
    expect(preview.html).toContain('<html lang="zh-CN" data-scheme="dark">');
    expect(preview.problems).toEqual(["没有 {{nope}} 这个变量"]);
    const sms = await json("integ", "/v1/admin/messages/preview", "POST", {
      kind: "code_sms",
      locale: "zh-Hans",
    });
    expect(sms.sms).toEqual({ length: 43, segments: 1 });

    const reset = await json("integ", "/v1/admin/messages/templates/code_mail/zh-Hans", "DELETE");
    expect(reset).toMatchObject({ custom: false, subject: "命理大师验证码：{{code}}" });
  });

  it("a test send goes through the dispatcher to the address given, noted with the code hidden", async () => {
    const res = await call("integ", "/v1/admin/messages/test", "POST", {
      kind: "code_sms",
      locale: "zh-Hans",
      to: "+86 138 0013 8000",
    });
    expect(res.status).toBe(202);
    expect((await res.json()).entry).toMatchObject({
      kind: "code_sms",
      status: "sent",
      test: true,
      to: "+86 *******8000",
    });
    expect(sms.sent.at(-1)).toEqual({
      to: "+8613800138000",
      text: "【命理大师】你的验证码是 482913，10 分钟内有效。如非本人操作，请忽略本短信。",
    });
    // A draft goes as it is, once it may be saved.
    const draft = await call("integ", "/v1/admin/messages/test", "POST", {
      kind: "records_mail",
      locale: "zh-Hant",
      to: "tester@example.com",
      subject: "測試：{{title}}",
      body: "{{records}}",
    });
    expect(draft.status).toBe(202);
    expect(mail.sent.at(-1)).toMatchObject({ to: "tester@example.com", subject: "測試：2 份记录" });
    expect(mail.sent.at(-1)!.text).toBe("· 徐梅 的命盘\n· 塔罗 · 三张牌\n");
    expect(
      (
        await call("integ", "/v1/admin/messages/test", "POST", {
          kind: "code_mail",
          locale: "zh-Hans",
          to: "nope",
        })
      ).status,
    ).toBe(400);

    const log = await json("integ", "/v1/admin/messages/log?limit=10");
    expect(log.items[0]).toMatchObject({
      kind: "records_mail",
      test: true,
      to: "t***@example.com",
    });
    expect(log.items[1]).toMatchObject({ kind: "code_sms", test: true });
    // alice's code mail, sent under the edited wording: its code hidden.
    const codeMail = log.items.find((i: { kind: string }) => i.kind === "code_mail");
    expect(codeMail).toMatchObject({ subject: "【命理大师】••••••", to: "a***@example.com" });
    expect(codeMail).not.toHaveProperty("test");
    expect(JSON.stringify(log.items)).not.toContain("482913");
  });
});
