-- 内容管理 (v18.0.0, tech plan S29): the app's texts and images as staff changed them, by key (and language for a text).
-- Without a row the app shows its own. Written by staff for everyone to see: no person's data.
CREATE TABLE content_texts (
  key         text NOT NULL,
  locale      text NOT NULL,
  text        text NOT NULL,
  updated_at  timestamptz NOT NULL,
  updated_by  uuid,
  PRIMARY KEY (key, locale)
);

CREATE TABLE content_images (
  key         text PRIMARY KEY,
  type        text NOT NULL,
  data        bytea NOT NULL,
  updated_at  timestamptz NOT NULL,
  updated_by  uuid
);
