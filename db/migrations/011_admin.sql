-- 管理后台 (v11.2.0, tech plan S22): what an account is and may do, when it was last active, and every AI job's use.
-- All plain: a role, a status, two permissions, a time, a demo mark, and numbers; no text of a person or a reading.
ALTER TABLE users
  ADD COLUMN role text NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  ADD COLUMN status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
  ADD COLUMN permissions jsonb,
  ADD COLUMN last_seen_at timestamptz,
  ADD COLUMN demo boolean NOT NULL DEFAULT false;

-- One row per step of an AI job: who asked (until the account goes: then NULL, so the totals stay), what, which
-- model, its tokens and its cost at list price, and whether the job delivered.
CREATE TABLE ai_usage (
  seq                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  job_id              uuid NOT NULL,
  user_id             uuid,
  kind                text NOT NULL CHECK (kind IN ('report', 'life_report', 'followup', 'inquiry', 'remedy')),
  system              text,
  agent               text NOT NULL,
  model               text NOT NULL,
  input_tokens        integer NOT NULL,
  output_tokens       integer NOT NULL,
  cache_read_tokens   integer NOT NULL,
  cache_write_tokens  integer NOT NULL,
  usd                 double precision NOT NULL,
  delivered           boolean NOT NULL,
  demo                boolean NOT NULL DEFAULT false,
  created_at          timestamptz NOT NULL
);
CREATE INDEX ai_usage_time_idx ON ai_usage (created_at);
CREATE INDEX ai_usage_user_idx ON ai_usage (user_id);

-- What an admin wrote with a grant of 积分 (增加积分).
ALTER TABLE points_entries ADD COLUMN note text;
