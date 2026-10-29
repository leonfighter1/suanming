-- 追问 (v7.0.0, tech plan S13 WP13.2): follow-up questions on a reading or a 一生运势报告, one row each. The question
-- and its answer stay in the body, sealed under the owner's data key like every body; the columns are only what the
-- rows are found by. A row goes with its owner (ON DELETE CASCADE) and is purged with the account's other records.
CREATE TABLE followups (
  id               uuid PRIMARY KEY,
  user_id          uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  parent_kind      text NOT NULL CHECK (parent_kind IN ('report', 'life_report')),
  parent_id        uuid NOT NULL,
  status           report_status NOT NULL,
  body_ciphertext  bytea NOT NULL,
  created_at       timestamptz NOT NULL,
  updated_at       timestamptz NOT NULL,
  seq              bigint GENERATED ALWAYS AS IDENTITY
);
CREATE INDEX followups_parent_idx ON followups (parent_id, created_at);
