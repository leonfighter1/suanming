-- 汇率 (v19.0.0, tech plan S31): the last good table of exchange rates from the online service, kept so a restart
-- without the service still prices 充值 in other currencies. One row per base currency (CNY). No person's data.
CREATE TABLE exchange_rates (
  base        text PRIMARY KEY,
  body        jsonb NOT NULL,
  fetched_at  timestamptz NOT NULL
);
