-- S5 (tech plan WP5.1): what the API's records hold beyond schema v0 + 001, for the database store
-- (src/db/pg-store.ts). Applies on top of 001_phase1_ai.sql. Every body stays application-level
-- ciphertext under the owner's data key (src/db/envelope.ts); the columns here are only what the
-- store looks rows up by.

-- A job can fail (a provider outage, output that never validated).
ALTER TYPE report_status ADD VALUE IF NOT EXISTS 'failed';

-- A pending report has no output yet: the region and matrix it ran under are set when it is done.
-- seq orders rows written in the same millisecond as they were written (the lists sort by created_at).
ALTER TABLE reports
  ALTER COLUMN region DROP NOT NULL,
  ALTER COLUMN geo_matrix_version DROP NOT NULL,
  ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN seq bigint GENERATED ALWAYS AS IDENTITY;

-- 每日一牌: the date a chart is the card of. Such charts aren't listed among the user's charts.
ALTER TABLE chart_facts
  ADD COLUMN daily date,
  ADD COLUMN seq bigint GENERATED ALWAYS AS IDENTITY;

-- Social sign-in: HMAC(pepper, subject) per provider, for lookup without the subject itself (which
-- is sealed with the email).
ALTER TABLE users ADD COLUMN social_lookup jsonb NOT NULL DEFAULT '{}'::jsonb;

-- 破除運勢 plans, one per report and topic.
CREATE TABLE remedies (
  id               uuid PRIMARY KEY,
  user_id          uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  report_id        uuid NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  topic            text NOT NULL,
  status           report_status NOT NULL,
  body_ciphertext  bytea NOT NULL,
  created_at       timestamptz NOT NULL,
  updated_at       timestamptz NOT NULL,
  seq              bigint GENERATED ALWAYS AS IDENTITY
);
CREATE INDEX remedies_report_idx ON remedies (report_id, created_at);

-- 一生运势报告 jobs.
CREATE TABLE life_reports (
  id               uuid PRIMARY KEY,
  user_id          uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  chart_fact_id    uuid NOT NULL REFERENCES chart_facts(id) ON DELETE CASCADE,
  locale           text NOT NULL CHECK (locale IN ('zh-Hant', 'zh-Hans', 'en')),
  status           report_status NOT NULL,
  body_ciphertext  bytea NOT NULL,
  created_at       timestamptz NOT NULL,
  updated_at       timestamptz NOT NULL,
  expires_at       timestamptz,
  seq              bigint GENERATED ALWAYS AS IDENTITY
);
CREATE INDEX life_reports_user_idx ON life_reports (user_id, created_at DESC);
