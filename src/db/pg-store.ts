/**
 * The database store (tech plan WP5.1 + 5.2): the API's records ({@link Store}) and the accounts
 * ({@link UserStore}) in one PostgreSQL database: PGlite, PostgreSQL in WASM, in a folder on disk (or
 * in memory for tests). The same SQL runs on PostgreSQL 16: db/schema_v0.sql plus db/migrations.
 *
 * Every body is sealed with its owner's data key (envelope.ts): charts, reports, plans, life
 * reports, the life context inside a report, the email and social subjects. The plain columns are
 * only what rows are found or audited by: ids, owner, status, locale, topics, versions, region,
 * matrix version, model, rule ids and times. Deleting an account destroys its key with its row,
 * which makes anything left under it unreadable (crypto-shredding), and leaves a deletion record
 * without personal data (docs/data-retention.md).
 */
import { createHmac, randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import { PGlite, type Transaction } from "@electric-sql/pglite";
import type {
  ChartRecord,
  FollowUpRecord,
  InquiryRecord,
  LifeReportRecord,
  RemedyRecord,
  ReportRecord,
  Store,
} from "../api/store.js";
import type { UsageRow } from "../admin/usage.js";
import type { Locale } from "../ai/terms.js";
import type { AccountRole, UserRecord, UserStore } from "../auth/service.js";
import type { SocialProvider } from "../auth/social.js";
import type { TemplateRecord } from "../notify/dispatch.js";
import type { MessageKind } from "../notify/templates.js";
import type {
  ChargeKind,
  PointsBasis,
  PointsCharge,
  PointsCredit,
  PointsEntry,
  PointsEntryKind,
  PointsFor,
  PointsHold,
} from "../points/index.js";
import { creditEntry, newHold } from "../points/index.js";
import type { ContentLocale } from "../content/catalog.js";
import type { ContentImageRecord, ContentTextRecord } from "../content/store.js";
import type { RefreshRecord, SessionStore } from "../auth/tokens.js";
import type { SettingRecord } from "../settings/index.js";
import { newDataKey, openJson, sealJson, unwrapDataKey } from "./envelope.js";

/** Applied in order after schema_v0.sql; the store records each one it applies. */
const MIGRATIONS = [
  "001_phase1_ai",
  "002_store",
  "003_qiuqian",
  "004_fengshui",
  "005_naming",
  "006_liuyao",
  "007_followups",
  "008_logins",
  "009_inquiries",
  "010_points",
  "011_admin",
  "012_messages",
  "013_content",
  "014_sessions",
  "015_settings",
];
const sql = (path: string) => readFileSync(new URL(`../../db/${path}`, import.meta.url), "utf8");

/** Reports are kept 24 months (docs/data-retention.md); purging them is a later WP. */
const RETENTION_MONTHS = 24;
const HELD = ["manual_review", "blocked"];
/** Lists sort by creation time; rows written in the same millisecond keep the order they came in. */
const NEWEST = "ORDER BY created_at DESC, seq ASC";

export interface PgStoreOptions {
  /** The database's folder; omitted: in memory (tests). */
  dataDir?: string;
  /** The key-encryption key (MINGLI_DATA_KEY, envelope.ts parseKek). */
  kek: Buffer;
  /** The auth pepper: social lookups and the deletion record's subject hash. */
  pepper: Buffer;
}

type Db = PGlite | Transaction;
type Row = Record<string, unknown>;
const iso = (v: unknown) => (v as Date).toISOString();
const refreshOf = (r: Row): RefreshRecord => ({
  userId: r.user_id as string,
  family: r.family as string,
  expiresAt: (r.expires_at as Date).getTime(),
  used: r.used === true,
});

const ENTRY_COLUMNS =
  "id, user_id, kind, points, balance, for_kind, for_id, system, basis, usd, pack_yuan, pack_points, reason, note, created_at";

/** A 积分 change as its row holds it (v11.0.0). */
function entryOf(r: Row): PointsEntry {
  return {
    id: r.id as string,
    owner: r.user_id as string,
    kind: r.kind as PointsEntryKind,
    points: r.points as number,
    balance: r.balance as number,
    created_at: iso(r.created_at),
    ...(r.for_kind != null && {
      for: {
        kind: r.for_kind as ChargeKind,
        id: r.for_id as string,
        ...(r.system != null && { system: r.system as string }),
      },
    }),
    ...(r.basis != null && { basis: r.basis as PointsBasis }),
    ...(r.usd != null && { usd: r.usd as number }),
    ...(r.pack_yuan != null && {
      pack: { yuan: r.pack_yuan as number, points: r.pack_points as number },
    }),
    ...(r.reason != null && { reason: r.reason as string }),
    ...(r.note != null && { note: r.note as string }),
  };
}

function insertEntry(db: Db, e: PointsEntry) {
  return db.query(
    `INSERT INTO points_entries (${ENTRY_COLUMNS}) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)`,
    [
      e.id,
      e.owner,
      e.kind,
      e.points,
      e.balance,
      e.for?.kind ?? null,
      e.for?.id ?? null,
      e.for?.system ?? null,
      e.basis ?? null,
      e.usd ?? null,
      e.pack?.yuan ?? null,
      e.pack?.points ?? null,
      e.reason ?? null,
      e.note ?? null,
      e.created_at,
    ],
  );
}

/** The balance, locked for the rest of the transaction (PostgreSQL; PGlite runs one transaction at a time anyway). */
async function lockedBalance(tx: Db, owner: string): Promise<number> {
  const row = (
    await tx.query<{ balance: number }>(
      "SELECT balance FROM points_balances WHERE user_id = $1 FOR UPDATE",
      [owner],
    )
  ).rows[0];
  return row?.balance ?? 0;
}

async function setBalance(tx: Db, owner: string, balance: number, at: string) {
  await tx.query(
    `INSERT INTO points_balances (user_id, balance, updated_at) VALUES ($1, $2, $3)
     ON CONFLICT (user_id) DO UPDATE SET balance = EXCLUDED.balance, updated_at = EXCLUDED.updated_at`,
    [owner, balance, at],
  );
}

/**
 * What an account's sealed column (email_ciphertext) holds: the email and the social subjects since S5, and since
 * v8.2.0 the username, the bound phone, when each was proved, and the settings. Rows sealed before lack the new keys.
 */
interface SealedIds {
  email?: string;
  social: UserRecord["social"];
  username?: string;
  phone?: string;
  email_verified_at?: string;
  phone_bound_at?: string;
  settings?: UserRecord["settings"];
}

export class PgStore implements Store, UserStore, SessionStore {
  /** Unwrapped data keys, in memory only. */
  private readonly keys = new Map<string, Buffer>();

  private constructor(
    private readonly db: PGlite,
    private readonly o: PgStoreOptions,
  ) {}

  /** Opens (or creates) the database and brings its schema up to date. */
  static async open(o: PgStoreOptions): Promise<PgStore> {
    const db = o.dataDir ? new PGlite(o.dataDir) : new PGlite();
    await db.waitReady;
    const store = new PgStore(db, o);
    await store.migrate();
    // 积分 holds belong to running jobs, and no job survives a restart: whatever a last run left held is free again.
    await db.exec("DELETE FROM points_holds");
    return store;
  }

  async close() {
    await this.db.close();
  }

  private async migrate() {
    const exists = async (table: string) =>
      (await this.db.query<{ t: string | null }>("SELECT to_regclass($1)::text AS t", [table]))
        .rows[0]?.t != null;
    if (!(await exists("public.users"))) await this.db.exec(sql("schema_v0.sql"));
    await this.db.exec(
      "CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())",
    );
    const done = new Set(
      (await this.db.query<{ name: string }>("SELECT name FROM schema_migrations")).rows.map(
        (r) => r.name,
      ),
    );
    for (const m of MIGRATIONS) {
      if (done.has(m)) continue;
      await this.db.exec(sql(`migrations/${m}.sql`));
      await this.db.query("INSERT INTO schema_migrations (name) VALUES ($1)", [m]);
    }
  }

  private hmac(text: string) {
    return createHmac("sha256", this.o.pepper).update(text).digest();
  }

  /** The owner's data key; an owner without an account has none, and nothing can be stored for it. */
  private async dek(userId: string, db: Db = this.db): Promise<Buffer> {
    const cached = this.keys.get(userId);
    if (cached) return cached;
    const row = (
      await db.query<{ w: Uint8Array }>("SELECT data_key_wrapped AS w FROM users WHERE id = $1", [
        userId,
      ])
    ).rows[0];
    if (!row) throw new Error(`no account ${userId.slice(0, 8)}: nothing can be stored for it`);
    const dek = unwrapDataKey(this.o.kek, Buffer.from(row.w), userId);
    this.keys.set(userId, dek);
    return dek;
  }

  private async open<T>(table: string, row: Row, column = "body_ciphertext"): Promise<T> {
    const dek = await this.dek(row.user_id as string);
    return openJson<T>(dek, Buffer.from(row[column] as Uint8Array), `${table}:${row.id as string}`);
  }

  // ---- accounts (UserStore) ----

  private async user(row: Row | undefined): Promise<UserRecord | undefined> {
    if (!row) return undefined;
    const dek = await this.dek(row.id as string);
    const ids: SealedIds = row.email_ciphertext
      ? openJson<SealedIds>(
          dek,
          Buffer.from(row.email_ciphertext as Uint8Array),
          `users:${row.id as string}`,
        )
      : { social: {} };
    const hex = (column: string) =>
      row[column] != null && Buffer.from(row[column] as Uint8Array).toString("hex");
    const emailLookup = hex("email_lookup");
    const usernameLookup = hex("username_lookup");
    const phoneLookup = hex("phone_lookup");
    return {
      id: row.id as string,
      ...(ids.email !== undefined && { email: ids.email }),
      ...(emailLookup && { email_lookup: emailLookup }),
      ...(ids.email_verified_at !== undefined && { email_verified_at: ids.email_verified_at }),
      ...(ids.username !== undefined && { username: ids.username }),
      ...(usernameLookup && { username_lookup: usernameLookup }),
      ...(ids.phone !== undefined && { phone: ids.phone }),
      ...(phoneLookup && { phone_lookup: phoneLookup }),
      ...(ids.phone_bound_at !== undefined && { phone_bound_at: ids.phone_bound_at }),
      ...(ids.settings !== undefined && { settings: ids.settings }),
      ...(row.password_hash != null && { password_hash: row.password_hash as string }),
      social: ids.social,
      country: row.country as string,
      locale: row.locale as UserRecord["locale"],
      age_confirmed_at: iso(row.age_confirmed_at),
      created_at: iso(row.created_at),
      // 管理后台 (v11.2.0): plain columns; the defaults stay off the record, as on one made before them.
      // Any role but the default (S25: integrator and manager besides admin).
      ...(row.role != null && row.role !== "user" && { role: row.role as AccountRole }),
      ...(row.status === "suspended" && { status: "suspended" as const }),
      ...(row.permissions != null && {
        permissions: row.permissions as UserRecord["permissions"],
      }),
      ...(row.last_seen_at != null && { last_seen_at: iso(row.last_seen_at) }),
      ...(row.demo === true && { demo: true }),
    };
  }

  async get(id: string) {
    return this.user((await this.db.query<Row>("SELECT * FROM users WHERE id = $1", [id])).rows[0]);
  }

  async byEmailLookup(lookup: string) {
    const rows = await this.db.query<Row>("SELECT * FROM users WHERE email_lookup = $1", [
      Buffer.from(lookup, "hex"),
    ]);
    return this.user(rows.rows[0]);
  }

  async byUsernameLookup(lookup: string) {
    const rows = await this.db.query<Row>("SELECT * FROM users WHERE username_lookup = $1", [
      Buffer.from(lookup, "hex"),
    ]);
    return this.user(rows.rows[0]);
  }

  async byPhoneLookup(lookup: string) {
    const rows = await this.db.query<Row>("SELECT * FROM users WHERE phone_lookup = $1", [
      Buffer.from(lookup, "hex"),
    ]);
    return this.user(rows.rows[0]);
  }

  async bySocial(provider: SocialProvider, sub: string) {
    const rows = await this.db.query<Row>("SELECT * FROM users WHERE social_lookup ->> $1 = $2", [
      provider,
      this.hmac(`${provider}:${sub}`).toString("hex"),
    ]);
    return this.user(rows.rows[0]);
  }

  async put(u: UserRecord) {
    const social = Object.fromEntries(
      Object.entries(u.social).map(([p, sub]) => [p, this.hmac(`${p}:${sub}`).toString("hex")]),
    );
    const known =
      this.keys.has(u.id) ||
      (await this.db.query("SELECT 1 FROM users WHERE id = $1", [u.id])).rows.length > 0;
    // A new account gets its data key here; it is cached only once the row is in.
    const fresh = known ? undefined : newDataKey(this.o.kek, u.id);
    const dek = fresh?.dek ?? (await this.dek(u.id));
    const sealed: SealedIds = {
      email: u.email,
      social: u.social,
      username: u.username,
      phone: u.phone,
      email_verified_at: u.email_verified_at,
      phone_bound_at: u.phone_bound_at,
      settings: u.settings,
    };
    const ids = sealJson(dek, sealed, `users:${u.id}`);
    const bytes = (lookup: string | undefined) => (lookup ? Buffer.from(lookup, "hex") : null);
    const values = [
      u.id,
      ids,
      bytes(u.email_lookup),
      u.password_hash ?? null,
      u.country,
      u.locale,
      u.age_confirmed_at,
      u.created_at,
      social,
      bytes(u.username_lookup),
      bytes(u.phone_lookup),
      u.role ?? "user",
      u.status ?? "active",
      u.permissions ?? null,
      u.last_seen_at ?? null,
      u.demo === true,
    ];
    if (fresh) {
      await this.db.query(
        `INSERT INTO users (id, email_ciphertext, email_lookup, password_hash, country, locale, age_confirmed_at, created_at, social_lookup, username_lookup, phone_lookup,
           role, status, permissions, last_seen_at, demo, data_key_wrapped)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)`,
        [...values, fresh.wrapped],
      );
      this.keys.set(u.id, fresh.dek);
    } else {
      // last_seen_at only moves forward here: touch() may have written a later one meanwhile.
      await this.db.query(
        `UPDATE users SET email_ciphertext = $2, email_lookup = $3, password_hash = $4, country = $5, locale = $6,
           age_confirmed_at = $7, created_at = $8, social_lookup = $9, username_lookup = $10, phone_lookup = $11,
           role = $12, status = $13, permissions = $14, demo = $16,
           last_seen_at = GREATEST(last_seen_at, $15::timestamptz)
         WHERE id = $1`,
        values,
      );
    }
  }

  async list() {
    const rows = await this.db.query<Row>("SELECT * FROM users ORDER BY created_at, id");
    const users: UserRecord[] = [];
    for (const r of rows.rows) users.push((await this.user(r))!);
    return users;
  }

  async touch(id: string, at: string) {
    await this.db.query(
      "UPDATE users SET last_seen_at = GREATEST(last_seen_at, $2::timestamptz) WHERE id = $1",
      [id, at],
    );
  }

  /**
   * The last step of deleting an account (docs/data-retention.md): its row goes, with its data key,
   * so anything still sealed under the key can't be read (crypto-shredding); everything it owns
   * cascades; the deletion record [deleteOwnerData] opened is completed, or one is made.
   */
  async delete(id: string) {
    await this.db.transaction(async (tx) => {
      const subject = this.hmac(`subject:${id}`);
      const open = (
        await tx.query<{ id: string; evidence: Record<string, unknown> }>(
          "SELECT id, evidence FROM deletion_requests WHERE subject_hash = $1 AND status <> 'completed' ORDER BY requested_at DESC LIMIT 1",
          [subject],
        )
      ).rows[0];
      const request =
        open?.id ??
        (
          await tx.query<{ id: string }>(
            "INSERT INTO deletion_requests (subject_hash, channel, status) VALUES ($1, 'app', 'in_progress') RETURNING id",
            [subject],
          )
        ).rows[0]!.id;
      const gone = await tx.query("DELETE FROM users WHERE id = $1", [id]);
      await tx.query(
        "UPDATE deletion_requests SET status = 'completed', completed_at = now(), evidence = $2 WHERE id = $1",
        [request, { ...open?.evidence, account: gone.affectedRows ?? 0, dek_shredded: true }],
      );
    });
    this.keys.delete(id);
  }

  // ---- records (Store) ----

  async putChart(c: ChartRecord) {
    const f = c.fact;
    const body = sealJson(await this.dek(c.owner), c, `chart_facts:${c.id}`);
    await this.db.query(
      `INSERT INTO chart_facts (id, user_id, system, schema_version, engine_version, input_digest, rule_versions, facts_ciphertext, created_at, daily)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       ON CONFLICT (id) DO UPDATE SET facts_ciphertext = EXCLUDED.facts_ciphertext, daily = EXCLUDED.daily`,
      [
        c.id,
        c.owner,
        f.system,
        f.schema_version,
        f.engine.version,
        f.input_digest,
        f.rule_versions,
        body,
        c.created_at,
        c.daily ?? null,
      ],
    );
  }

  async getChart(id: string) {
    const row = (
      await this.db.query<Row>(
        "SELECT id, user_id, facts_ciphertext FROM chart_facts WHERE id = $1",
        [id],
      )
    ).rows[0];
    return row && this.open<ChartRecord>("chart_facts", row, "facts_ciphertext");
  }

  async listCharts(owner: string, limit: number) {
    // A 每日一牌 isn't a chart the user made: one a day would bury the rest.
    const rows = await this.db.query<Row>(
      `SELECT id, user_id, facts_ciphertext FROM chart_facts WHERE user_id = $1 AND daily IS NULL ${NEWEST} LIMIT $2`,
      [owner, limit],
    );
    return Promise.all(
      rows.rows.map((r) => this.open<ChartRecord>("chart_facts", r, "facts_ciphertext")),
    );
  }

  async putReport(r: ReportRecord) {
    const out = r.report;
    const body = sealJson(await this.dek(r.owner), r, `reports:${r.id}`);
    await this.db.query(
      `INSERT INTO reports (id, user_id, chart_fact_id, locale, region, geo_matrix_version, model, status, violations, topics,
         body_ciphertext, created_at, updated_at, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $12::timestamptz + make_interval(months => $14))
       ON CONFLICT (id) DO UPDATE SET region = EXCLUDED.region, geo_matrix_version = EXCLUDED.geo_matrix_version,
         model = EXCLUDED.model, status = EXCLUDED.status, violations = EXCLUDED.violations, topics = EXCLUDED.topics,
         body_ciphertext = EXCLUDED.body_ciphertext, updated_at = EXCLUDED.updated_at`,
      [
        r.id,
        r.owner,
        r.chart_id,
        r.locale,
        out?.region ?? null,
        out?.compliance.geo_matrix_version ?? null,
        out?.ai_disclosure.model ?? null,
        r.status,
        // Rule ids only, never the matched text (schema v0).
        (out?.compliance.rule_violations ?? []).map((v) => v.rule_id),
        r.topics,
        body,
        r.created_at,
        r.updated_at,
        RETENTION_MONTHS,
      ],
    );
  }

  async getReport(id: string) {
    const row = (
      await this.db.query<Row>("SELECT id, user_id, body_ciphertext FROM reports WHERE id = $1", [
        id,
      ])
    ).rows[0];
    return row && this.open<ReportRecord>("reports", row);
  }

  async listReports(owner: string, limit: number) {
    const rows = await this.db.query<Row>(
      `SELECT id, user_id, body_ciphertext FROM reports WHERE user_id = $1 ${NEWEST} LIMIT $2`,
      [owner, limit],
    );
    return Promise.all(rows.rows.map((r) => this.open<ReportRecord>("reports", r)));
  }

  async putRemedy(r: RemedyRecord) {
    const body = sealJson(await this.dek(r.owner), r, `remedies:${r.id}`);
    await this.db.query(
      `INSERT INTO remedies (id, user_id, report_id, topic, status, body_ciphertext, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status, body_ciphertext = EXCLUDED.body_ciphertext,
         updated_at = EXCLUDED.updated_at`,
      [r.id, r.owner, r.report_id, r.topic, r.status, body, r.created_at, r.updated_at],
    );
  }

  async getRemedy(id: string) {
    const row = (
      await this.db.query<Row>("SELECT id, user_id, body_ciphertext FROM remedies WHERE id = $1", [
        id,
      ])
    ).rows[0];
    return row && this.open<RemedyRecord>("remedies", row);
  }

  async listRemedies(reportId: string) {
    // Oldest first, as the in-memory store gives them.
    const rows = await this.db.query<Row>(
      "SELECT id, user_id, body_ciphertext FROM remedies WHERE report_id = $1 ORDER BY created_at ASC, seq DESC LIMIT 100",
      [reportId],
    );
    return Promise.all(rows.rows.map((r) => this.open<RemedyRecord>("remedies", r)));
  }

  async putLifeReport(r: LifeReportRecord) {
    const body = sealJson(await this.dek(r.owner), r, `life_reports:${r.id}`);
    await this.db.query(
      `INSERT INTO life_reports (id, user_id, chart_fact_id, locale, status, body_ciphertext, created_at, updated_at, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $7::timestamptz + make_interval(months => $9))
       ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status, body_ciphertext = EXCLUDED.body_ciphertext,
         updated_at = EXCLUDED.updated_at`,
      [
        r.id,
        r.owner,
        r.chart_id,
        r.locale,
        r.status,
        body,
        r.created_at,
        r.updated_at,
        RETENTION_MONTHS,
      ],
    );
  }

  async getLifeReport(id: string) {
    const row = (
      await this.db.query<Row>(
        "SELECT id, user_id, body_ciphertext FROM life_reports WHERE id = $1",
        [id],
      )
    ).rows[0];
    return row && this.open<LifeReportRecord>("life_reports", row);
  }

  async listLifeReports(owner: string, limit: number) {
    const rows = await this.db.query<Row>(
      `SELECT id, user_id, body_ciphertext FROM life_reports WHERE user_id = $1 ${NEWEST} LIMIT $2`,
      [owner, limit],
    );
    return Promise.all(rows.rows.map((r) => this.open<LifeReportRecord>("life_reports", r)));
  }

  async putFollowUp(f: FollowUpRecord) {
    const body = sealJson(await this.dek(f.owner), f, `followups:${f.id}`);
    await this.db.query(
      `INSERT INTO followups (id, user_id, parent_kind, parent_id, status, body_ciphertext, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status, body_ciphertext = EXCLUDED.body_ciphertext,
         updated_at = EXCLUDED.updated_at`,
      [f.id, f.owner, f.parent.kind, f.parent.id, f.status, body, f.created_at, f.updated_at],
    );
  }

  async getFollowUp(id: string) {
    const row = (
      await this.db.query<Row>("SELECT id, user_id, body_ciphertext FROM followups WHERE id = $1", [
        id,
      ])
    ).rows[0];
    return row && this.open<FollowUpRecord>("followups", row);
  }

  async listFollowUps(parentId: string) {
    // Oldest first, as the in-memory store gives them.
    const rows = await this.db.query<Row>(
      "SELECT id, user_id, body_ciphertext FROM followups WHERE parent_id = $1 ORDER BY created_at ASC, seq DESC LIMIT 100",
      [parentId],
    );
    return Promise.all(rows.rows.map((r) => this.open<FollowUpRecord>("followups", r)));
  }

  async putInquiry(i: InquiryRecord) {
    const body = sealJson(await this.dek(i.owner), i, `inquiries:${i.id}`);
    await this.db.query(
      `INSERT INTO inquiries (id, user_id, chart_fact_id, report_id, status, body_ciphertext, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (id) DO UPDATE SET report_id = EXCLUDED.report_id, status = EXCLUDED.status,
         body_ciphertext = EXCLUDED.body_ciphertext, updated_at = EXCLUDED.updated_at`,
      [i.id, i.owner, i.chart_id, i.report_id ?? null, i.status, body, i.created_at, i.updated_at],
    );
  }

  async getInquiry(id: string) {
    const row = (
      await this.db.query<Row>("SELECT id, user_id, body_ciphertext FROM inquiries WHERE id = $1", [
        id,
      ])
    ).rows[0];
    return row && this.open<InquiryRecord>("inquiries", row);
  }

  // ---- 积分 (v11.0.0, tech plan S20): plain columns, no text of a reading ----

  async pointsOf(owner: string) {
    const row = (
      await this.db.query<{ balance: number; held: number }>(
        `SELECT COALESCE((SELECT balance FROM points_balances WHERE user_id = $1), 0) AS balance,
                COALESCE((SELECT sum(points) FROM points_holds WHERE user_id = $1), 0)::integer AS held`,
        [owner],
      )
    ).rows[0]!;
    return { balance: row.balance, held: row.held };
  }

  async holdPoints(owner: string, need: number, want: number, what: PointsFor, at: string) {
    return this.db.transaction(async (tx) => {
      const balance = await lockedBalance(tx, owner);
      const held = (
        await tx.query<{ held: number }>(
          "SELECT COALESCE(sum(points), 0)::integer AS held FROM points_holds WHERE user_id = $1",
          [owner],
        )
      ).rows[0]!.held;
      const hold = newHold(owner, balance - held, need, want, what, at);
      if (!hold) return undefined;
      await tx.query(
        `INSERT INTO points_holds (id, user_id, points, quote, for_kind, for_id, system, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [hold.id, owner, hold.points, hold.quote, what.kind, what.id, what.system ?? null, at],
      );
      return hold;
    });
  }

  async settlePoints(hold: PointsHold, charge: PointsCharge | undefined, at: string) {
    return this.db.transaction(async (tx) => {
      const gone = await tx.query("DELETE FROM points_holds WHERE id = $1", [hold.id]);
      if (!gone.affectedRows || !charge || charge.points < 1) return undefined;
      const before = await lockedBalance(tx, hold.owner);
      const taken = Math.min(charge.points, before);
      await setBalance(tx, hold.owner, before - taken, at);
      const entry: PointsEntry = {
        id: randomUUID(),
        owner: hold.owner,
        kind: "charge",
        points: -taken,
        balance: before - taken,
        created_at: at,
        for: { ...hold.for },
        basis: charge.basis,
        ...(charge.usd !== undefined && { usd: charge.usd }),
      };
      await insertEntry(tx, entry);
      return entry;
    });
  }

  async creditPoints(owner: string, points: number, credit: PointsCredit, at: string) {
    return this.db.transaction(async (tx) => {
      if (credit.kind === "grant") {
        const had = await tx.query(
          "SELECT 1 FROM points_entries WHERE user_id = $1 AND kind = 'grant' AND reason = $2",
          [owner, credit.reason],
        );
        if (had.rows.length) return undefined;
      }
      const balance = (await lockedBalance(tx, owner)) + points;
      await setBalance(tx, owner, balance, at);
      const entry = creditEntry(owner, credit, points, balance, at);
      await insertEntry(tx, entry);
      return entry;
    });
  }

  async listPoints(owner: string, limit: number) {
    const rows = await this.db.query<Row>(
      `SELECT ${ENTRY_COLUMNS} FROM points_entries WHERE user_id = $1 ORDER BY created_at DESC, seq DESC LIMIT $2`,
      [owner, limit],
    );
    return rows.rows.map(entryOf);
  }

  async listHolds(owner: string) {
    const rows = await this.db.query<Row>(
      "SELECT id, user_id, points, quote, for_kind, for_id, system, created_at FROM points_holds WHERE user_id = $1 ORDER BY created_at, id",
      [owner],
    );
    return rows.rows.map((r): PointsHold => ({
      id: r.id as string,
      owner: r.user_id as string,
      points: r.points as number,
      quote: r.quote as number,
      for: {
        kind: r.for_kind as ChargeKind,
        id: r.for_id as string,
        ...(r.system != null && { system: r.system as string }),
      },
      created_at: iso(r.created_at),
    }));
  }

  async allPoints(since?: string) {
    const rows = await this.db.query<Row>(
      `SELECT ${ENTRY_COLUMNS} FROM points_entries WHERE created_at >= COALESCE($1::timestamptz, '-infinity')
       ORDER BY created_at, seq`,
      [since ?? null],
    );
    return rows.rows.map(entryOf);
  }

  async allBalances() {
    const rows = await this.db.query<{ user_id: string; balance: number; held: number }>(
      `SELECT u.user_id, COALESCE(b.balance, 0) AS balance, COALESCE(h.held, 0)::integer AS held
       FROM (SELECT user_id FROM points_balances UNION SELECT user_id FROM points_holds) u
       LEFT JOIN points_balances b ON b.user_id = u.user_id
       LEFT JOIN (SELECT user_id, sum(points) AS held FROM points_holds GROUP BY user_id) h ON h.user_id = u.user_id`,
    );
    return new Map(rows.rows.map((r) => [r.user_id, { balance: r.balance, held: r.held }]));
  }

  // ---- 管理后台 (v11.2.0): every AI job's steps, numbers only ----

  async recordUsage(rows: UsageRow[]) {
    if (!rows.length) return;
    await this.db.transaction(async (tx) => {
      for (const r of rows) {
        await tx.query(
          `INSERT INTO ai_usage (job_id, user_id, kind, system, agent, model, input_tokens, output_tokens,
             cache_read_tokens, cache_write_tokens, usd, delivered, demo, created_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
          [
            r.job_id,
            r.owner ?? null,
            r.kind,
            r.system ?? null,
            r.agent,
            r.model,
            r.input_tokens,
            r.output_tokens,
            r.cache_read_tokens,
            r.cache_write_tokens,
            r.usd,
            r.delivered,
            r.demo === true,
            r.created_at,
          ],
        );
      }
    });
  }

  async listUsage(since?: string) {
    const rows = await this.db.query<Row>(
      `SELECT * FROM ai_usage WHERE created_at >= COALESCE($1::timestamptz, '-infinity') ORDER BY created_at, seq`,
      [since ?? null],
    );
    return rows.rows.map((r): UsageRow => ({
      job_id: r.job_id as string,
      ...(r.user_id != null && { owner: r.user_id as string }),
      kind: r.kind as UsageRow["kind"],
      ...(r.system != null && { system: r.system as string }),
      agent: r.agent as string,
      model: r.model as string,
      input_tokens: r.input_tokens as number,
      output_tokens: r.output_tokens as number,
      cache_read_tokens: r.cache_read_tokens as number,
      cache_write_tokens: r.cache_write_tokens as number,
      usd: r.usd as number,
      delivered: r.delivered as boolean,
      ...(r.demo === true && { demo: true }),
      created_at: iso(r.created_at),
    }));
  }

  // ---- 消息模板 (v13.1.0, S25): admins' wordings of the messages, plain text ----

  async listMessageTemplates() {
    const rows = await this.db.query<Row>("SELECT * FROM message_templates ORDER BY kind, locale");
    return rows.rows.map((r): TemplateRecord => ({
      kind: r.kind as MessageKind,
      locale: r.locale as Locale,
      ...(r.subject != null && { subject: r.subject as string }),
      body: r.body as string,
      updated_at: iso(r.updated_at),
      ...(r.updated_by != null && { updated_by: r.updated_by as string }),
    }));
  }

  async putMessageTemplate(t: TemplateRecord) {
    await this.db.query(
      `INSERT INTO message_templates (kind, locale, subject, body, updated_at, updated_by)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (kind, locale) DO UPDATE SET subject = EXCLUDED.subject, body = EXCLUDED.body,
         updated_at = EXCLUDED.updated_at, updated_by = EXCLUDED.updated_by`,
      [t.kind, t.locale, t.subject ?? null, t.body, t.updated_at, t.updated_by ?? null],
    );
  }

  async deleteMessageTemplate(kind: MessageKind, locale: Locale) {
    const r = await this.db.query("DELETE FROM message_templates WHERE kind = $1 AND locale = $2", [
      kind,
      locale,
    ]);
    return (r.affectedRows ?? 0) > 0;
  }
  // ---- sessions (v18.0.0, S29): the refresh tokens by their SHA-256, so a restart keeps everyone signed in ----

  async putRefresh(hash: string, r: RefreshRecord, now: number) {
    await this.db.query("DELETE FROM sessions WHERE expires_at < $1", [
      new Date(now).toISOString(),
    ]);
    await this.db.query(
      "INSERT INTO sessions (hash, user_id, family, expires_at, used) VALUES ($1, $2, $3, $4, $5)",
      [hash, r.userId, r.family, new Date(r.expiresAt).toISOString(), r.used],
    );
  }

  async useRefresh(hash: string) {
    return this.db.transaction(async (tx) => {
      const r = (await tx.query<Row>("SELECT * FROM sessions WHERE hash = $1", [hash])).rows[0];
      if (r && !r.used) await tx.query("UPDATE sessions SET used = true WHERE hash = $1", [hash]);
      return r && refreshOf(r);
    });
  }

  async getRefresh(hash: string) {
    const r = (await this.db.query<Row>("SELECT * FROM sessions WHERE hash = $1", [hash])).rows[0];
    return r && refreshOf(r);
  }

  async dropFamily(family: string) {
    await this.db.query("DELETE FROM sessions WHERE family = $1", [family]);
  }

  async dropUser(userId: string) {
    await this.db.query("DELETE FROM sessions WHERE user_id = $1", [userId]);
  }

  // ---- 设置 (v19.0.0, S31): what the 管理后台's 设置 page changed, plain ----

  async listSettings() {
    const rows = await this.db.query<Row>("SELECT * FROM settings ORDER BY key");
    return rows.rows.map((r): SettingRecord => ({
      key: r.key as string,
      value: r.value,
      updated_at: iso(r.updated_at),
      ...(r.updated_by != null && { updated_by: r.updated_by as string }),
    }));
  }

  async putSetting(s: SettingRecord) {
    await this.db.query(
      `INSERT INTO settings (key, value, updated_at, updated_by) VALUES ($1, $2, $3, $4)
       ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = EXCLUDED.updated_at,
         updated_by = EXCLUDED.updated_by`,
      [s.key, JSON.stringify(s.value), s.updated_at, s.updated_by ?? null],
    );
  }

  async deleteSetting(key: string) {
    const r = await this.db.query("DELETE FROM settings WHERE key = $1", [key]);
    return (r.affectedRows ?? 0) > 0;
  }

  // ---- 内容管理 (v18.0.0, S29): staff's changes to the app's texts and images, plain ----

  async listContentTexts() {
    const rows = await this.db.query<Row>("SELECT * FROM content_texts ORDER BY key, locale");
    return rows.rows.map((r): ContentTextRecord => ({
      key: r.key as string,
      locale: r.locale as ContentLocale,
      text: r.text as string,
      updated_at: iso(r.updated_at),
      ...(r.updated_by != null && { updated_by: r.updated_by as string }),
    }));
  }

  async putContentText(c: ContentTextRecord) {
    await this.db.query(
      `INSERT INTO content_texts (key, locale, text, updated_at, updated_by) VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (key, locale) DO UPDATE SET text = EXCLUDED.text, updated_at = EXCLUDED.updated_at,
         updated_by = EXCLUDED.updated_by`,
      [c.key, c.locale, c.text, c.updated_at, c.updated_by ?? null],
    );
  }

  async deleteContentText(key: string, locale: ContentLocale) {
    const r = await this.db.query("DELETE FROM content_texts WHERE key = $1 AND locale = $2", [
      key,
      locale,
    ]);
    return (r.affectedRows ?? 0) > 0;
  }

  async listContentImages() {
    const rows = await this.db.query<Row>(
      "SELECT key, type, updated_at, updated_by FROM content_images ORDER BY key",
    );
    return rows.rows.map((r) => ({
      key: r.key as string,
      type: r.type as string,
      updated_at: iso(r.updated_at),
      ...(r.updated_by != null && { updated_by: r.updated_by as string }),
    }));
  }

  async getContentImage(key: string) {
    const r = (await this.db.query<Row>("SELECT * FROM content_images WHERE key = $1", [key]))
      .rows[0];
    return (
      r && {
        key: r.key as string,
        type: r.type as string,
        data: Buffer.from(r.data as Uint8Array),
        updated_at: iso(r.updated_at),
        ...(r.updated_by != null && { updated_by: r.updated_by as string }),
      }
    );
  }

  async putContentImage(i: ContentImageRecord) {
    await this.db.query(
      `INSERT INTO content_images (key, type, data, updated_at, updated_by) VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (key) DO UPDATE SET type = EXCLUDED.type, data = EXCLUDED.data, updated_at = EXCLUDED.updated_at,
         updated_by = EXCLUDED.updated_by`,
      [i.key, i.type, i.data, i.updated_at, i.updated_by ?? null],
    );
  }

  async deleteContentImage(key: string) {
    const r = await this.db.query("DELETE FROM content_images WHERE key = $1", [key]);
    return (r.affectedRows ?? 0) > 0;
  }

  async deleteReport(id: string) {
    return this.db.transaction(async (tx) => {
      const n = async (sql: string) => (await tx.query(sql, [id])).affectedRows ?? 0;
      const followups = await n("DELETE FROM followups WHERE parent_id = $1");
      const remedies = await n("DELETE FROM remedies WHERE report_id = $1");
      const inquiries = await n("DELETE FROM inquiries WHERE report_id = $1");
      const reports = await n("DELETE FROM reports WHERE id = $1");
      return { reports, remedies, followups, inquiries };
    });
  }

  async deleteLifeReport(id: string) {
    return this.db.transaction(async (tx) => {
      const n = async (sql: string) => (await tx.query(sql, [id])).affectedRows ?? 0;
      const followups = await n("DELETE FROM followups WHERE parent_id = $1");
      const life_reports = await n("DELETE FROM life_reports WHERE id = $1");
      return { life_reports, followups };
    });
  }

  async deleteChartIfUnused(id: string) {
    return this.db.transaction(async (tx) => {
      const row = (await tx.query<Row>("SELECT daily FROM chart_facts WHERE id = $1", [id]))
        .rows[0];
      if (!row || row.daily != null) return false;
      const read = await tx.query(
        "SELECT 1 FROM reports WHERE chart_fact_id = $1 UNION ALL SELECT 1 FROM life_reports WHERE chart_fact_id = $1 LIMIT 1",
        [id],
      );
      if (read.rows.length) return false;
      return (
        ((await tx.query("DELETE FROM chart_facts WHERE id = $1", [id])).affectedRows ?? 0) > 0
      );
    });
  }

  async listHeld() {
    const held = async <T>(table: string) => {
      // The statuses inline: PGlite sends a JS array for an enum array as "a,b", which PostgreSQL refuses.
      const rows = await this.db.query<Row>(
        `SELECT id, user_id, body_ciphertext FROM ${table} WHERE status IN (${HELD.map((s) => `'${s}'`).join(", ")}) ${NEWEST} LIMIT 500`,
      );
      return Promise.all(rows.rows.map((r) => this.open<T>(table, r)));
    };
    return {
      reports: await held<ReportRecord>("reports"),
      remedies: await held<RemedyRecord>("remedies"),
      life: await held<LifeReportRecord>("life_reports"),
      followups: await held<FollowUpRecord>("followups"),
    };
  }

  /**
   * The first steps of deleting an account (docs/data-retention.md): a deletion record, then
   * everything the user owns, counted for the receipt. [delete] completes it with the account.
   */
  async deleteOwnerData(owner: string) {
    return this.db.transaction(async (tx) => {
      // Children first, so each count is the table's own and not a cascade's.
      const purge = async (table: string) =>
        (await tx.query(`DELETE FROM ${table} WHERE user_id = $1`, [owner])).affectedRows ?? 0;
      const followups = await purge("followups");
      const inquiries = await purge("inquiries");
      const remedies = await purge("remedies");
      const life_reports = await purge("life_reports");
      const reports = await purge("reports");
      const charts = await purge("chart_facts");
      const points = await purge("points_entries");
      await purge("points_holds");
      await purge("points_balances");
      // Its AI use stays for the totals, without its owner.
      await tx.query("UPDATE ai_usage SET user_id = NULL WHERE user_id = $1", [owner]);
      const counts = { charts, reports, remedies, life_reports, followups, inquiries, points };
      await tx.query(
        "INSERT INTO deletion_requests (subject_hash, channel, status, evidence) VALUES ($1, 'app', 'in_progress', $2)",
        [this.hmac(`subject:${owner}`), counts],
      );
      return counts;
    });
  }

  /** For tests: every row of one of the store's tables, as stored. */
  async rawRows(table: (typeof TABLES)[number]): Promise<Row[]> {
    if (!TABLES.includes(table)) throw new Error(`not a store table: ${table}`);
    return (await this.db.query<Row>(`SELECT * FROM ${table}`)).rows;
  }
}

const TABLES = [
  "users",
  "chart_facts",
  "reports",
  "remedies",
  "life_reports",
  "followups",
  "inquiries",
  "points_balances",
  "points_entries",
  "points_holds",
  "ai_usage",
  "deletion_requests",
] as const;
