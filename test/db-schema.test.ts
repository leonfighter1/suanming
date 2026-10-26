import { readFileSync } from "node:fs";
import { PGlite } from "@electric-sql/pglite";
import { describe, expect, it } from "vitest";

// PGlite boots Postgres in WASM; under a parallel test run that alone can exceed 5 s.
const PG_TIMEOUT = 30_000;

const sql = readFileSync(new URL("../db/schema_v0.sql", import.meta.url), "utf8");

describe("db/schema_v0.sql", () => {
  it(
    "applies cleanly and enforces key constraints",
    async () => {
      const db = new PGlite();
      await db.exec(sql);

      const { rows } = await db.query<{ table_name: string }>(
        "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY 1",
      );
      expect(rows.map((r) => r.table_name)).toEqual([
        "chart_facts",
        "deletion_requests",
        "reports",
        "users",
      ]);

      const user = await db.query<{ id: string }>(
        "INSERT INTO users (country, locale, data_key_wrapped) VALUES ('HK', 'zh-Hant', decode('00','hex')) RETURNING id",
      );
      const uid = user.rows[0]!.id;

      await expect(
        db.query(
          "INSERT INTO chart_facts (user_id, system, schema_version, engine_version, input_digest, rule_versions, facts_ciphertext) VALUES ($1, 'bazi', '0.1.0', 'x', 'sha256:abc', '{}', decode('00','hex'))",
          [uid],
        ),
      ).rejects.toThrow(/check/i);

      await db.query(
        "INSERT INTO chart_facts (user_id, system, schema_version, engine_version, input_digest, rule_versions, facts_ciphertext) VALUES ($1, 'bazi', '0.1.0', 'x', $2, '{}', decode('00','hex'))",
        [uid, `hmac-sha256:${"a".repeat(64)}`],
      );

      // Deleting the user cascades to chart_facts; deletion_requests survives by design.
      await db.query(
        "INSERT INTO deletion_requests (subject_hash, channel) VALUES (decode('01','hex'), 'app')",
      );
      await db.query("DELETE FROM users WHERE id = $1", [uid]);
      const left = await db.query<{ n: number }>("SELECT count(*)::int AS n FROM chart_facts");
      expect(left.rows[0]!.n).toBe(0);
      const dr = await db.query<{ n: number }>("SELECT count(*)::int AS n FROM deletion_requests");
      expect(dr.rows[0]!.n).toBe(1);

      await db.close();
    },
    PG_TIMEOUT,
  );
});

describe("db/migrations/001_phase1_ai.sql", () => {
  it(
    "applies on v0 and enforces one active prompt per agent",
    async () => {
      const db = new PGlite();
      await db.exec(sql);
      await db.exec(
        readFileSync(new URL("../db/migrations/001_phase1_ai.sql", import.meta.url), "utf8"),
      );
      const h = "a".repeat(64);
      await db.query(
        "INSERT INTO prompt_versions (id, agent, version, body, sha256, active) VALUES ('narrative@2','narrative',1,'x',$1,true)",
        [h],
      );
      await expect(
        db.query(
          "INSERT INTO prompt_versions (id, agent, version, body, sha256, active) VALUES ('narrative@2','narrative',2,'y',$1,true)",
          [h],
        ),
      ).rejects.toThrow(/duplicate|unique/i);
      await db.query(
        "INSERT INTO model_routes (agent, provider, model, effort, max_tokens) VALUES ('narrative','anthropic','claude-opus-5-5','high',16000)",
      );
      const cols = await db.query<{ column_name: string }>(
        "SELECT column_name FROM information_schema.columns WHERE table_name = 'reports' AND column_name IN ('topics','reasons','agent_trace')",
      );
      expect(cols.rows).toHaveLength(3);
      await db.close();
    },
    PG_TIMEOUT,
  );
});
