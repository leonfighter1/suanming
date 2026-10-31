-- 设置 (v19.0.0, tech plan S31): what the 管理后台's 设置 page changed, by key, as JSON. Without a row the setting's
-- default holds (config/settings.json, or the env variable it names). Written by admins for the server: no person's data.
CREATE TABLE settings (
  key         text PRIMARY KEY,
  value       jsonb NOT NULL,
  updated_at  timestamptz NOT NULL,
  updated_by  uuid
);
