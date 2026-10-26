# ADR-0002: 八字时间基准（节气用瞬时，日时柱用当地太阳时）

- Status: **Proposed**. Needs sign-off from 算法.
- Date: 2026-10-25
- Code: `src/engines/bazi/index.ts`, `src/engines/bazi/time.ts`

## Context

`lunar-javascript` takes a wall clock and compares it with a 节气 table that
it expresses in **UTC+8**. Giving it a non-UTC+8 local time (New York,
London, Vancouver) shifts every month and year boundary by the offset
difference, up to 13 hours. That is wrong for overseas users, the Phase 2
audience.

## Decision

| What                                 | Clock used                                                                     | Why                                                                        |
| ------------------------------------ | ------------------------------------------------------------------------------ | -------------------------------------------------------------------------- |
| 年柱, 月柱, 大运 direction and start | UTC+8 wall clock of the **birth instant**                                      | 节 are astronomical instants and the comparison must be instant vs instant |
| 日柱, 时柱                           | **true solar time** at the birth longitude (configurable; civil time when off) | day and hour follow the local sun                                          |
| 十神, 十二长生 for all pillars       | re-based on the local 日主                                                     | the year/month chart's own 日干 can differ from the local one              |

The civil-to-UTC step uses IANA tzdb, including historical DST (China
1986–91, Hong Kong to 1979, Taiwan). Times inside a DST gap are rejected and
the client must ask the user. Times in a DST fold take the earlier instant
and are flagged `civil_ambiguity: ambiguous_earlier`.

Default options: `trueSolarTime: true`, `ziHourSect: 2` (晚子时日柱算当天).
Both are recorded in `facts.time_basis` and in `input_digest`.

## Evidence

- `test/bazi.test.ts`: births 10 min either side of 2024 立春 give 癸卯/乙丑 →
  甲辰/丙寅 in Hong Kong, New York and London alike.
- `npm run poc:bazi-jieqi`: lunar-javascript's 节 instants versus Swiss
  Ephemeris solar crossings, 1900–2100 (2,412 节). Median error 0.02 min,
  max 1.58 min.
- Equation of time agrees with Swiss Ephemeris `swe_time_equ` to < 0.1 min,
  1900–2100.

## Open for 算法 review

- `ziHourSect` default (1 or 2) is a school choice. Expose it in UI?
- A birth within ~2 min of a 节 is astronomically ambiguous at this
  precision, and real birth times are rarely that exact. Proposal for v1.0:
  add `facts.boundary_warning` when |birth − 节| < 30 min.
- The 50 golden cases from an authoritative tool are still missing
  (`test/fixtures/bazi-golden.json`). The month-boundary policy above may
  disagree with tools that feed local time straight to the table. Each such
  disagreement must be checked by hand, not "fixed" to match.
