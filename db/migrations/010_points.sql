-- 积分 (v11.0.0, tech plan S20): each account's balance, every change to it, and what running AI jobs hold. Amounts,
-- what a charge paid for (its kind, id and method) and how it was priced are all a row holds: no text of a reading.
-- Rows go with their account (ON DELETE CASCADE) and are purged with its other records; the 积分 are simulated until
-- real payments (Phase 4), whose records the law keeps longer.
CREATE TABLE points_balances (
  user_id     uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  balance     integer NOT NULL CHECK (balance >= 0),
  updated_at  timestamptz NOT NULL
);

CREATE TABLE points_entries (
  id           uuid PRIMARY KEY,
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind         text NOT NULL CHECK (kind IN ('grant', 'topup', 'charge')),
  points       integer NOT NULL,
  balance      integer NOT NULL,
  for_kind     text,
  for_id       uuid,
  system       text,
  basis        text CHECK (basis IN ('measured', 'estimate', 'flat')),
  usd          double precision,
  pack_yuan    integer,
  pack_points  integer,
  reason       text,
  created_at   timestamptz NOT NULL,
  seq          bigint GENERATED ALWAYS AS IDENTITY
);
CREATE INDEX points_entries_user_idx ON points_entries (user_id, created_at DESC);
-- A grant is given once per reason (the dev accounts' start).
CREATE UNIQUE INDEX points_grants_once ON points_entries (user_id, reason) WHERE kind = 'grant';

-- What running jobs hold. No job survives a restart, so the store clears these when it opens.
CREATE TABLE points_holds (
  id          uuid PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  points      integer NOT NULL CHECK (points > 0),
  quote       integer NOT NULL,
  for_kind    text NOT NULL,
  for_id      uuid NOT NULL,
  system      text,
  created_at  timestamptz NOT NULL
);
CREATE INDEX points_holds_user_idx ON points_holds (user_id);
