-- 深度分析 (v10.0.0, tech plan S19 WP19.1): the master's questions before a reading and the user's answers, one row per
-- conversation. The goal, the turns and the answers stay in the body, sealed under the owner's data key like every
-- body; the columns are only what rows are found by. A row goes with its owner (ON DELETE CASCADE), with the reading
-- it was made for (report_id), and is purged with the account's other records.
CREATE TABLE inquiries (
  id               uuid PRIMARY KEY,
  user_id          uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  chart_fact_id    uuid NOT NULL,
  report_id        uuid,
  status           text NOT NULL CHECK (status IN ('thinking', 'asking', 'ready', 'failed', 'closed')),
  body_ciphertext  bytea NOT NULL,
  created_at       timestamptz NOT NULL,
  updated_at       timestamptz NOT NULL,
  seq              bigint GENERATED ALWAYS AS IDENTITY
);
CREATE INDEX inquiries_report_idx ON inquiries (report_id);
