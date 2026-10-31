// S5 WP5.1 + 5.2 (docs/tech-plan.md): the database store. One contract runs on both stores; the rest
// is what only the database must do: survive a restart, hold no plaintext, refuse a wrong key, and
// delete an account as docs/data-retention.md says.
import { randomBytes, randomUUID } from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import type { AddressInfo } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterAll, describe, expect, it } from "vitest";
import { generateReport, MockProvider } from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import {
  InMemoryStore,
  type ChartRecord,
  type FollowUpRecord,
  type InquiryRecord,
  type LifeReportRecord,
  type RemedyRecord,
  type ReportRecord,
  type Store,
} from "../src/api/store.js";
import { noCaptcha } from "../src/auth/limits.js";
import {
  AuthService,
  InMemoryUserStore,
  type UserRecord,
  type UserStore,
} from "../src/auth/service.js";
import { TokenService } from "../src/auth/tokens.js";
import { open, parseKek, seal } from "../src/db/envelope.js";
import { PgStore } from "../src/db/pg-store.js";
import { computeBazi } from "../src/engines/bazi/index.js";
import { computeQiuqian } from "../src/engines/qiuqian/index.js";
import { computeTarot } from "../src/engines/tarot/index.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";

// PGlite boots PostgreSQL in WASM: a database test can take seconds under the full suite (rule 4).
const PG = 30_000;
const KEK = randomBytes(32);

const bazi = computeBazi(
  { local: "1990-03-15T14:30", timezone: "Asia/Hong_Kong", longitude: 114.17, gender: "male" },
  { digestPepper: PEPPER, now: FIXED_NOW },
);
const tarot = computeTarot(
  { spread: "single" },
  { drawKey: DRAW_KEY, digestPepper: PEPPER, now: FIXED_NOW, newDrawId: () => randomUUID() },
);
const report = await generateReport(
  bazi,
  { locale: "zh-Hant", country: "HK", topics: ["wuxing"] },
  { providers: { deepseek: new MockProvider(), anthropic: new MockProvider() }, now: FIXED_NOW },
);

const at = (minute: number) => `2026-10-25T00:${String(minute).padStart(2, "0")}:00.000Z`;
const user = (id: string, email: string): UserRecord => ({
  id,
  email,
  email_lookup: randomBytes(32).toString("hex"),
  password_hash: "$argon2id$v=19$m=19456,t=2,p=1$test",
  social: {},
  country: "HK",
  locale: "zh-Hant",
  age_confirmed_at: at(0),
  created_at: at(0),
});

/** One owner's records: a chart, a 每日一牌, a held report with a life context, a plan, a life report. */
function records(owner: string) {
  // Whose chart it is (v6.2.0): kept with the chart, sealed like it.
  const chart: ChartRecord = {
    id: randomUUID(),
    owner,
    fact: bazi,
    created_at: at(1),
    person: { name: "陳大文", birthplace: "台灣 · 高雄市" },
  };
  const daily: ChartRecord = {
    id: randomUUID(),
    owner,
    fact: tarot,
    created_at: at(2),
    daily: "2026-10-25",
  };
  const reading: ReportRecord = {
    id: randomUUID(),
    owner,
    chart_id: chart.id,
    status: "manual_review",
    locale: "zh-Hant",
    topics: ["wuxing"],
    created_at: at(3),
    updated_at: at(3),
    report,
    context: { residence: "香港 · 九龍", concern: "想知道今年換工作好不好" },
  };
  const plan: RemedyRecord = {
    id: randomUUID(),
    owner,
    report_id: reading.id,
    topic: "wuxing",
    status: "pending",
    created_at: at(4),
    updated_at: at(4),
    unlocked: true,
  };
  const life: LifeReportRecord = {
    id: randomUUID(),
    owner,
    chart_id: chart.id,
    status: "failed",
    locale: "zh-Hant",
    created_at: at(5),
    updated_at: at(5),
    error: "provider down",
  };
  // 追问 (v7.0.0): the question is the user's own words, sealed like a reading.
  const ask: FollowUpRecord = {
    id: randomUUID(),
    owner,
    parent: { kind: "report", id: reading.id },
    question: "我和同事的相处会好转吗",
    status: "pending",
    created_at: at(6),
    updated_at: at(6),
  };
  // 深度分析 (v10.0.0): the goal and the answers are the user's own words, sealed like a reading; read by the reading.
  const talk: InquiryRecord = {
    id: randomUUID(),
    owner,
    chart_id: chart.id,
    locale: "zh-Hant",
    status: "closed",
    goal: "想知道明年適不適合換工作",
    turns: [
      {
        say: "你的命盤裡，今年的流年和月柱相沖。",
        question: "你現在的工作最讓你不滿意的是什麼？",
        fact_refs: ["/pillars/month"],
        answer: "老闆一直不給加薪",
      },
    ],
    planned: 2,
    understanding: "換工作能不能多賺一些",
    report_id: reading.id,
    created_at: at(6),
    updated_at: at(6),
  };
  return { chart, daily, reading, plan, life, ask, talk };
}

async function fill(store: Store, r: ReturnType<typeof records>) {
  await store.putChart(r.chart);
  await store.putChart(r.daily);
  await store.putReport(r.reading);
  await store.putRemedy(r.plan);
  await store.putLifeReport(r.life);
  await store.putFollowUp(r.ask);
  await store.putInquiry(r.talk);
}

const dirs: string[] = [];
afterAll(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});
const folder = () => {
  const d = mkdtempSync(join(tmpdir(), "mingli-pg-"));
  dirs.push(d);
  return d;
};

// The same contract on both stores. The database keeps records only for accounts: an owner is an
// account first, there as in the app.
const kinds: [
  string,
  () => Promise<{ store: Store; users: UserStore; close: () => Promise<void> }>,
][] = [
  [
    "in memory",
    async () => ({
      store: new InMemoryStore(),
      users: new InMemoryUserStore(),
      close: async () => {},
    }),
  ],
  [
    "database",
    async () => {
      const pg = await PgStore.open({ kek: KEK, pepper: PEPPER });
      return { store: pg, users: pg, close: () => pg.close() };
    },
  ],
];

describe.each(kinds)("the store contract, %s", (_name, make) => {
  it(
    "deletes one record with what hangs off it, and a chart only once nothing reads it (v8.0.0)",
    async () => {
      const { store, users, close } = await make();
      const owner = randomUUID();
      await users.put(user(owner, "del@example.com"));
      const r = records(owner);
      await fill(store, r);
      // The chart is read by the reading and the 一生运势报告: it stays until both are gone.
      expect(await store.deleteReport(r.reading.id)).toEqual({
        reports: 1,
        remedies: 1,
        followups: 1,
        inquiries: 1,
      });
      expect(await store.getReport(r.reading.id)).toBeUndefined();
      expect(await store.getRemedy(r.plan.id)).toBeUndefined();
      expect(await store.getFollowUp(r.ask.id)).toBeUndefined();
      expect(await store.getInquiry(r.talk.id)).toBeUndefined();
      expect(await store.deleteChartIfUnused(r.chart.id)).toBe(false);
      expect(await store.deleteLifeReport(r.life.id)).toEqual({ life_reports: 1, followups: 0 });
      expect(await store.deleteChartIfUnused(r.chart.id)).toBe(true);
      expect(await store.getChart(r.chart.id)).toBeUndefined();
      // A 每日一牌 is never removed this way; nor is a chart that isn't there.
      expect(await store.deleteChartIfUnused(r.daily.id)).toBe(false);
      expect(await store.getChart(r.daily.id)).toEqual(r.daily);
      expect(await store.deleteChartIfUnused(randomUUID())).toBe(false);
      expect(await store.deleteReport(randomUUID())).toEqual({
        reports: 0,
        remedies: 0,
        followups: 0,
        inquiries: 0,
      });
      await close();
    },
    PG,
  );

  it(
    "keeps every record as it was put, and replaces it when put again",
    async () => {
      const { store, users, close } = await make();
      const owner = randomUUID();
      await users.put(user(owner, "a@example.com"));
      const r = records(owner);
      await fill(store, r);
      expect(await store.getChart(r.chart.id)).toEqual(r.chart);
      expect(await store.getChart(r.daily.id)).toEqual(r.daily);
      expect(await store.getReport(r.reading.id)).toEqual(r.reading);
      expect(await store.getRemedy(r.plan.id)).toEqual(r.plan);
      expect(await store.getLifeReport(r.life.id)).toEqual(r.life);
      expect(await store.getInquiry(r.talk.id)).toEqual(r.talk);
      expect(await store.getReport(randomUUID())).toBeUndefined();
      expect(await store.getInquiry(randomUUID())).toBeUndefined();

      const asking = {
        ...r.talk,
        status: "asking" as const,
        report_id: undefined,
        updated_at: at(9),
      };
      await store.putInquiry(asking);
      expect(await store.getInquiry(r.talk.id)).toEqual(asking);

      const passed = { ...r.reading, status: "passed" as const, updated_at: at(9) };
      await store.putReport(passed);
      expect(await store.getReport(r.reading.id)).toEqual(passed);
      await close();
    },
    PG,
  );

  it(
    "lists newest first (plans oldest first), leaves the 每日一牌 out, and holds only what is held",
    async () => {
      const { store, users, close } = await make();
      const [a, b] = [randomUUID(), randomUUID()];
      await users.put(user(a, "a@example.com"));
      await users.put(user(b, "b@example.com"));
      const ra = records(a);
      const rb = records(b);
      await fill(store, ra);
      await fill(store, rb);
      const second: ChartRecord = { id: randomUUID(), owner: a, fact: tarot, created_at: at(7) };
      await store.putChart(second);
      expect((await store.listCharts(a, 10)).map((c) => c.id)).toEqual([second.id, ra.chart.id]);
      expect((await store.listCharts(a, 1)).map((c) => c.id)).toEqual([second.id]);
      expect((await store.listReports(a, 10)).map((x) => x.id)).toEqual([ra.reading.id]);
      expect((await store.listLifeReports(b, 10)).map((x) => x.id)).toEqual([rb.life.id]);

      const later: RemedyRecord = {
        ...ra.plan,
        id: randomUUID(),
        topic: "health",
        created_at: at(8),
        updated_at: at(8),
      };
      await store.putRemedy(later);
      expect((await store.listRemedies(ra.reading.id)).map((x) => x.id)).toEqual([
        ra.plan.id,
        later.id,
      ]);

      // Both owners' held reports; the failed life reports and pending plans are not held.
      const held = await store.listHeld();
      expect(held.reports.map((x) => x.id).sort()).toEqual([ra.reading.id, rb.reading.id].sort());
      expect([held.remedies, held.life]).toEqual([[], []]);
      await close();
    },
    PG,
  );

  it(
    "an account deletion removes the owner's records and counts them, and nobody else's",
    async () => {
      const { store, users, close } = await make();
      const [a, b] = [randomUUID(), randomUUID()];
      const other = user(b, "b@example.com");
      await users.put(user(a, "a@example.com"));
      await users.put(other);
      const ra = records(a);
      const rb = records(b);
      await fill(store, ra);
      await fill(store, rb);
      expect(await store.deleteOwnerData(a)).toEqual({
        charts: 2,
        reports: 1,
        remedies: 1,
        life_reports: 1,
        followups: 1,
        inquiries: 1,
        points: 0,
      });
      expect(await store.getInquiry(ra.talk.id)).toBeUndefined();
      expect(await store.getInquiry(rb.talk.id)).toEqual(rb.talk);
      await users.delete(a);
      expect(await store.getChart(ra.chart.id)).toBeUndefined();
      expect(await store.getReport(ra.reading.id)).toBeUndefined();
      expect(await store.getFollowUp(ra.ask.id)).toBeUndefined();
      expect(await store.listFollowUps(rb.reading.id)).toEqual([rb.ask]);
      expect(await users.get(a)).toBeUndefined();
      expect(await store.getReport(rb.reading.id)).toEqual(rb.reading);
      expect(await users.get(b)).toEqual(other);
      await close();
    },
    PG,
  );
});

describe("the database store", () => {
  it(
    "keeps the sessions across a restart (S29); reuse still ends one, and so does deleting the account",
    async () => {
      const dataDir = folder();
      const owner = randomUUID();
      const first = await PgStore.open({ dataDir, kek: KEK, pepper: PEPPER });
      await first.put(user(owner, "session@example.com"));
      const t1 = await new TokenService(randomBytes(32), undefined, { sessions: first }).issue(
        owner,
      );
      await first.close();

      // Another process: another JWT secret, the same sessions.
      const again = await PgStore.open({ dataDir, kek: KEK, pepper: PEPPER });
      const tokens = new TokenService(randomBytes(32), undefined, { sessions: again });
      const { userId, tokens: t2 } = await tokens.rotate(t1.refresh_token);
      expect(userId).toBe(owner);
      await expect(tokens.rotate(t1.refresh_token)).rejects.toThrow(/reuse/);
      await expect(tokens.rotate(t2.refresh_token)).rejects.toThrow(/invalid/);

      const t3 = await tokens.issue(owner);
      await again.delete(owner);
      await expect(tokens.rotate(t3.refresh_token)).rejects.toThrow(/invalid/);
      await again.close();
    },
    PG,
  );

  it(
    "survives a restart with its key, and refuses another key",
    async () => {
      const dataDir = folder();
      const owner = randomUUID();
      const account = user(owner, "restart@example.com");
      const r = records(owner);
      const first = await PgStore.open({ dataDir, kek: KEK, pepper: PEPPER });
      await first.put(account);
      await fill(first, r);
      await first.close();

      const again = await PgStore.open({ dataDir, kek: KEK, pepper: PEPPER });
      expect(await again.get(owner)).toEqual(account);
      expect(await again.byEmailLookup(account.email_lookup!)).toEqual(account);
      expect(await again.getReport(r.reading.id)).toEqual(r.reading);
      expect((await again.listCharts(owner, 10)).map((c) => c.id)).toEqual([r.chart.id]);
      await again.close();

      const wrong = await PgStore.open({ dataDir, kek: randomBytes(32), pepper: PEPPER });
      await expect(wrong.getReport(r.reading.id)).rejects.toThrow();
      await wrong.close();
    },
    PG,
  );

  it(
    "keeps a username, a bound phone and the settings across a restart, each found by its lookup (v8.2.0)",
    async () => {
      const dataDir = folder();
      const owner = randomUUID();
      const account: UserRecord = {
        ...user(owner, "logins@example.com"),
        email_verified_at: at(1),
        username: "Restart_User",
        username_lookup: randomBytes(32).toString("hex"),
        phone: "+85291234567",
        phone_lookup: randomBytes(32).toString("hex"),
        phone_bound_at: at(2),
        settings: { email_reports: true },
      };
      const first = await PgStore.open({ dataDir, kek: KEK, pepper: PEPPER });
      await first.put(account);
      await first.close();
      const again = await PgStore.open({ dataDir, kek: KEK, pepper: PEPPER });
      expect(await again.get(owner)).toEqual(account);
      expect(await again.byUsernameLookup(account.username_lookup!)).toEqual(account);
      expect(await again.byPhoneLookup(account.phone_lookup!)).toEqual(account);
      // Unbinding writes the lookup away: the number finds nobody.
      const { phone: _p, phone_lookup: _l, phone_bound_at: _b, ...unbound } = account;
      await again.put(unbound);
      expect(await again.byPhoneLookup(account.phone_lookup!)).toBeUndefined();
      expect(await again.get(owner)).toEqual(unbound);
      // Two accounts can't hold one username: the column is unique, like the email's.
      const twin = {
        ...user(randomUUID(), "twin@example.com"),
        username_lookup: account.username_lookup,
      };
      await expect(again.put(twin)).rejects.toThrow();
      await again.close();
    },
    PG,
  );

  it(
    "keeps a 求籤 chart (migration 003 adds the method to chart_system)",
    async () => {
      const pg = await PgStore.open({ kek: KEK, pepper: PEPPER });
      const owner = randomUUID();
      await pg.put(user(owner, "qiuqian@example.com"));
      const lot: ChartRecord = {
        id: randomUUID(),
        owner,
        fact: computeQiuqian(
          {},
          {
            drawKey: DRAW_KEY,
            digestPepper: PEPPER,
            now: FIXED_NOW,
            newDrawId: () => randomUUID(),
          },
        ),
        created_at: at(6),
      };
      await pg.putChart(lot);
      expect(await pg.getChart(lot.id)).toEqual(lot);
      await pg.close();
    },
    PG,
  );

  it(
    "stores no birth date, name, reading, life context, email, username or phone in the clear",
    async () => {
      const pg = await PgStore.open({ kek: KEK, pepper: PEPPER });
      const owner = randomUUID();
      await pg.put({
        ...user(owner, "secret.person@example.com"),
        social: { google: "google-subject-42" },
        // v8.2.0: a username and a bound phone are sealed with the email.
        username: "secret_username_7",
        username_lookup: randomBytes(32).toString("hex"),
        phone: "+85298765432",
        phone_lookup: randomBytes(32).toString("hex"),
      });
      const r = records(owner);
      await fill(pg, r);
      const paragraph =
        report.layers?.interpretation[0]?.paragraphs[0]?.text ??
        report.held_layers!.interpretation[0]!.paragraphs[0]!.text;
      const needles = [
        "1990-03-15",
        paragraph,
        "九龍",
        "換工作",
        "secret.person@example.com",
        "google-subject-42",
        "secret_username_7",
        "85298765432",
        "陳大文",
        "高雄市",
        "我和同事的相处会好转吗",
        "老闆一直不給加薪",
        "適不適合換工作",
      ];
      const tables = [
        "users",
        "chart_facts",
        "reports",
        "remedies",
        "life_reports",
        "followups",
        "inquiries",
      ] as const;
      const stored: Buffer[] = [];
      for (const t of tables) {
        for (const row of await pg.rawRows(t)) {
          for (const v of Object.values(row)) {
            stored.push(
              v instanceof Uint8Array
                ? Buffer.from(v)
                : Buffer.from(JSON.stringify(v) ?? "", "utf8"),
            );
          }
        }
      }
      const all = Buffer.concat(stored);
      expect(needles.filter((n) => all.includes(Buffer.from(n, "utf8")))).toEqual([]);
      // What the rows are found by is there in the clear: ids, status, region.
      const [row] = await pg.rawRows("reports");
      expect([row!.status, row!.region, row!.locale]).toEqual(["manual_review", "HK", "zh-Hant"]);
      expect(await pg.bySocial("google", "google-subject-42")).toMatchObject({ id: owner });
      await pg.close();
    },
    PG,
  );

  it(
    "a deletion leaves only its record: completed, with counts and the shredded key, and no personal data",
    async () => {
      const pg = await PgStore.open({ kek: KEK, pepper: PEPPER });
      const owner = randomUUID();
      await pg.put(user(owner, "leaving@example.com"));
      await fill(pg, records(owner));
      await pg.deleteOwnerData(owner);
      await pg.delete(owner);
      for (const t of [
        "users",
        "chart_facts",
        "reports",
        "remedies",
        "life_reports",
        "followups",
        "inquiries",
      ] as const) {
        expect(await pg.rawRows(t), t).toEqual([]);
      }
      const [request, ...more] = await pg.rawRows("deletion_requests");
      expect(more).toEqual([]);
      expect(request).toMatchObject({
        status: "completed",
        channel: "app",
        evidence: {
          charts: 2,
          reports: 1,
          remedies: 1,
          life_reports: 1,
          account: 1,
          dek_shredded: true,
        },
      });
      expect(request!.completed_at).toBeInstanceOf(Date);
      // No personal data: neither the id in a column nor its bytes in the subject hash.
      expect(JSON.stringify(request)).not.toContain(owner);
      expect(Buffer.from(request!.subject_hash as Uint8Array).includes(Buffer.from(owner))).toBe(
        false,
      );
      expect((request!.subject_hash as Uint8Array).length).toBe(32); // an HMAC-SHA256
      await pg.close();
    },
    PG,
  );
});

describe("the API on the database store", () => {
  it(
    "signs up, reads, lists and deletes an account end to end; a reading still running when it goes is dropped",
    async () => {
      const pg = await PgStore.open({ kek: KEK, pepper: PEPPER });
      const mock = new MockProvider();
      const auth = new AuthService({
        pepper: PEPPER,
        tokens: new TokenService(Buffer.alloc(32, 5), FIXED_NOW),
        users: pg,
        captcha: noCaptcha,
        now: FIXED_NOW,
      });
      const logged: string[] = [];
      const api = createApiServer({
        secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
        providers: { deepseek: mock, anthropic: mock },
        store: pg,
        auth,
        now: FIXED_NOW,
        log: (m) => logged.push(m),
      });
      await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
      const base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
      const post = (path: string, body: unknown, token?: string) =>
        fetch(base + path, {
          method: "POST",
          headers: {
            "content-type": "application/json",
            ...(token && { authorization: `Bearer ${token}` }),
          },
          body: JSON.stringify(body),
        });
      const authed = (token: string, path: string, method = "GET") =>
        fetch(base + path, { method, headers: { authorization: `Bearer ${token}` } });
      const signUp = async (email: string) =>
        (await (
          await post("/v1/auth/register", {
            email,
            password: "long enough pw",
            country: "TW",
            locale: "zh-Hant",
            age_confirmed: true,
          })
        ).json()) as { access_token: string };
      const readTarot = async (token: string) => {
        const chart = await (
          await post(
            "/v1/charts",
            { system: "tarot", spread: "single", question: "最近的工作会顺利吗？" },
            token,
          )
        ).json();
        return (await (
          await post("/v1/reports", { chart_id: chart.chart_id, locale: "zh-Hant" }, token)
        ).json()) as {
          report_id: string;
        };
      };

      const t = await signUp("pg@example.com");
      const r = await readTarot(t.access_token);
      await api.drain();
      const view = await (await authed(t.access_token, `/v1/reports/${r.report_id}`)).json();
      expect(view.status).toBe("passed");
      const history = await (await authed(t.access_token, "/v1/reports")).json();
      expect(history.items.map((x: { report_id: string }) => x.report_id)).toEqual([r.report_id]);
      const gone = await authed(t.access_token, "/v1/account", "DELETE");
      expect((await gone.json()).deleted).toEqual({
        account: true,
        charts: 1,
        reports: 1,
        remedies: 1,
        life_reports: 0,
        followups: 0,
        inquiries: 0,
        points: 0,
      });
      expect(await pg.rawRows("reports")).toEqual([]);

      // Deleted while its reading runs: the reading isn't written back, and nothing is left unhandled.
      const u = await signUp("racing@example.com");
      const late = await readTarot(u.access_token);
      await authed(u.access_token, "/v1/account", "DELETE");
      await api.drain();
      expect(await pg.getReport(late.report_id)).toBeUndefined();
      expect((await pg.rawRows("deletion_requests")).map((d) => d.status)).toEqual([
        "completed",
        "completed",
      ]);

      await new Promise<void>((resolve) => api.close(() => resolve()));
      await pg.close();
    },
    PG,
  );
});

describe("envelope encryption", () => {
  const key = randomBytes(32);

  it("opens what it sealed, and nothing else", () => {
    const sealed = seal(key, Buffer.from("己卯日主"), "reports:1");
    expect(open(key, sealed, "reports:1").toString()).toBe("己卯日主");
    // Another key, another row, or one changed byte: each fails loudly.
    expect(() => open(randomBytes(32), sealed, "reports:1")).toThrow();
    expect(() => open(key, sealed, "reports:2")).toThrow();
    const tampered = Buffer.from(sealed);
    tampered[tampered.length - 1]! ^= 1;
    expect(() => open(key, tampered, "reports:1")).toThrow();
    // A fresh nonce each time: the same text seals differently.
    expect(seal(key, Buffer.from("x"), "a").equals(seal(key, Buffer.from("x"), "a"))).toBe(false);
  });

  it("takes MINGLI_DATA_KEY as 32 bytes in base64, and says what is wrong otherwise", () => {
    expect(parseKek(key.toString("base64")).equals(key)).toBe(true);
    expect(() => parseKek(undefined)).toThrow(/MINGLI_DATA_KEY is not set/);
    expect(() => parseKek(randomBytes(16).toString("base64"))).toThrow(/32 bytes/);
  });
});
