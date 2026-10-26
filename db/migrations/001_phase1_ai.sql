-- Phase 1, AI Interp: prompt versions, model routing, report traces.
-- Applies on top of db/schema_v0.sql.

-- Versioned prompts (Phase 1 §2.2). Rows are immutable: a changed prompt is a new version.
CREATE TABLE prompt_versions (
  id          text PRIMARY KEY CHECK (id ~ '^(narrative|action|guard)@[0-9]+$'),
  agent       text NOT NULL CHECK (agent IN ('narrative', 'action', 'guard')),
  version     integer NOT NULL CHECK (version > 0),
  body        text NOT NULL,
  sha256      text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
  active      boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (agent, version)
);
-- At most one active version per agent (A/B rollout in Phase 4 uses experiments instead).
CREATE UNIQUE INDEX prompt_versions_one_active ON prompt_versions (agent) WHERE active;

-- Model routing table (config/model_routing.json shape), hot-updatable.
CREATE TABLE model_routes (
  agent       text NOT NULL CHECK (agent IN ('narrative', 'action', 'guard')),
  locale      text NOT NULL DEFAULT 'default' CHECK (locale IN ('default', 'zh-Hant', 'zh-Hans', 'en')),
  provider    text NOT NULL,
  model       text NOT NULL,
  effort      text NOT NULL CHECK (effort IN ('low', 'medium', 'high', 'xhigh', 'max')),
  max_tokens  integer NOT NULL CHECK (max_tokens > 0),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (agent, locale)
);

-- Report traces: which attempts ran, why a report was held, token usage.
ALTER TABLE reports
  ADD COLUMN topics      text[] NOT NULL DEFAULT '{}',
  ADD COLUMN reasons     jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN agent_trace jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN reviewed_by text,          -- manual_review outcome (Phase 1 ops)
  ADD COLUMN reviewed_at timestamptz;
