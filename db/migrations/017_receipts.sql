-- 收据 (v19.0.0, tech plan S31): one per 充值 (simulated until Phase 4's payments): what was paid, in which currency at
-- which rate and charge, the 积分 it brought and the account's email. The amounts and the email stay in the body, sealed
-- under the owner's data key; the columns are what rows are found by. A row goes with its owner (ON DELETE CASCADE).
-- The number is MLDS-<year>-<seq>. An admin's 增加积分 makes none.
CREATE TABLE receipts (
  id               uuid PRIMARY KEY,
  user_id          uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  entry_id         uuid NOT NULL,
  body_ciphertext  bytea NOT NULL,
  created_at       timestamptz NOT NULL,
  seq              bigint GENERATED ALWAYS AS IDENTITY UNIQUE
);

CREATE INDEX receipts_user_idx ON receipts (user_id, created_at);
