-- 命理大师 PostgreSQL schema v0 (Phase 0). Target: PostgreSQL 16.
--
-- PII rules (docs/data-retention.md):
--   * Raw birth data is NEVER stored. Only the keyed input_digest and the ChartFact.
--   * A bazi ChartFact still reveals birth date to ~2 h (pillars + dayun start), so
--     chart_facts.facts is PII: stored as application-level ciphertext (envelope
--     encryption, data key per user, KEK in KMS). Crypto-shredding the user's data
--     key is part of deletion.
--   * Report bodies are likewise ciphertext.

-- gen_random_uuid() is core since PG13; no extension needed.

CREATE TYPE chart_system AS ENUM ('bazi', 'tarot', 'astrology');
CREATE TYPE report_status AS ENUM ('pending', 'passed', 'blocked', 'manual_review');
CREATE TYPE deletion_status AS ENUM ('received', 'in_progress', 'completed', 'failed');

CREATE TABLE users (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email_ciphertext  bytea,
  -- HMAC(pepper, lower(email)) for login lookup without storing plaintext
  email_lookup      bytea UNIQUE,
  password_hash     text,                 -- Argon2id; NULL for Apple/Google-only accounts
  country           char(2) NOT NULL,     -- ISO 3166-1 alpha-2; drives Geo-Rule
  locale            text NOT NULL CHECK (locale IN ('zh-Hant', 'zh-Hans', 'en')),
  data_key_wrapped  bytea NOT NULL,       -- per-user DEK wrapped by KMS KEK
  age_confirmed_at  timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now(),
  deleted_at        timestamptz           -- set when deletion starts; row hard-deleted on completion
);

CREATE TABLE chart_facts (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            uuid REFERENCES users(id) ON DELETE CASCADE,  -- NULL for anonymous tarot
  system             chart_system NOT NULL,
  schema_version     text NOT NULL,
  engine_version     text NOT NULL,
  input_digest       text NOT NULL CHECK (input_digest ~ '^hmac-sha256:[0-9a-f]{64}$'),
  rule_versions      jsonb NOT NULL,
  facts_ciphertext   bytea NOT NULL,      -- encrypted ChartFact.facts + provenance
  -- Tarot audit (Phase 1 §2.1): no seed stored; draw_id + digest allow replay with the draw key
  audit_log          jsonb,
  created_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX chart_facts_user_idx ON chart_facts (user_id, created_at DESC);
-- Phase 4 cache: same digest + same engine ⇒ same facts
CREATE INDEX chart_facts_digest_idx ON chart_facts (input_digest, engine_version);

CREATE TABLE reports (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            uuid REFERENCES users(id) ON DELETE CASCADE,
  chart_fact_id      uuid NOT NULL REFERENCES chart_facts(id) ON DELETE CASCADE,
  locale             text NOT NULL CHECK (locale IN ('zh-Hant', 'zh-Hans', 'en')),
  region             char(2) NOT NULL,
  geo_matrix_version text NOT NULL,
  prompt_versions    jsonb NOT NULL DEFAULT '{}'::jsonb,  -- {narrative, action, guard}
  model              text,
  status             report_status NOT NULL DEFAULT 'pending',
  violations         jsonb NOT NULL DEFAULT '[]'::jsonb,  -- rule ids only, never the text
  body_ciphertext    bytea,               -- four-layer JSON, encrypted
  created_at         timestamptz NOT NULL DEFAULT now(),
  expires_at         timestamptz           -- retention; see docs/data-retention.md
);
CREATE INDEX reports_user_idx ON reports (user_id, created_at DESC);
CREATE INDEX reports_status_idx ON reports (status) WHERE status IN ('pending', 'manual_review');
CREATE INDEX reports_expiry_idx ON reports (expires_at) WHERE expires_at IS NOT NULL;

-- Survives user deletion (no FK) so completion can be proven. Holds no PII:
-- subject is an HMAC of the user id.
CREATE TABLE deletion_requests (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_hash   bytea NOT NULL,
  channel        text NOT NULL CHECK (channel IN ('app', 'web', 'email', 'support')),
  status         deletion_status NOT NULL DEFAULT 'received',
  requested_at   timestamptz NOT NULL DEFAULT now(),
  due_at         timestamptz NOT NULL DEFAULT now() + interval '24 hours',
  completed_at   timestamptz,
  -- what was purged, for the audit trail: {"chart_facts": 3, "reports": 5, "dek_shredded": true, ...}
  evidence       jsonb NOT NULL DEFAULT '{}'::jsonb,
  CHECK (completed_at IS NULL OR status = 'completed')
);
CREATE INDEX deletion_requests_open_idx ON deletion_requests (due_at) WHERE status <> 'completed';
