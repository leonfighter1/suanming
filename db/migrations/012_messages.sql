-- 消息模板 (v13.1.0, tech plan S25): an admin's own wording of a message (a mail's subject and body, an SMS's text),
-- by message and language. Without a row the code's default goes out. Plain text written by admins: no person's data.
CREATE TABLE message_templates (
  kind        text NOT NULL,
  locale      text NOT NULL,
  subject     text,
  body        text NOT NULL,
  updated_at  timestamptz NOT NULL,
  updated_by  uuid,
  PRIMARY KEY (kind, locale)
);

-- 后台角色 (v13.1.0): besides user and admin, a manager (assigns roles and permissions) and an integrator (the mail
-- and SMS templates only).
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users
  ADD CONSTRAINT users_role_check CHECK (role IN ('user', 'integrator', 'manager', 'admin'));
