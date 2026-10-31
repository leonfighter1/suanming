-- Sessions (v18.0.0, tech plan S29; the owner: 「登录者的登录消息存在服务器上，如果距离上次登录超过2天，那就需要重新登录」):
-- the refresh tokens, by their SHA-256 (never the token), so a restart keeps everyone signed in. Each lasts the idle
-- limit (2 days by default); a refresh marks it used and gives the next one, and a used one shown again ends its family.
CREATE TABLE sessions (
  hash        text PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  family      uuid NOT NULL,
  expires_at  timestamptz NOT NULL,
  used        boolean NOT NULL DEFAULT false
);

CREATE INDEX sessions_family ON sessions (family);
CREATE INDEX sessions_user ON sessions (user_id);
CREATE INDEX sessions_expires ON sessions (expires_at);
