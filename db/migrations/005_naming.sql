-- 起名 (v4.5.0, tech plan WP6.4): a sixth method. Additive: the enum gains a value, no row changes.
ALTER TYPE chart_system ADD VALUE IF NOT EXISTS 'naming';
