# Engine POC report (Phase 0)

Reproduce everything with:

```
npm test                  # unit + property tests (incl. tarot chi-square, EoT vs Swiss Ephemeris)
npm run poc:astrology     # → astrology-results.json
npm run poc:bazi-jieqi    # → bazi-jieqi-results.json
npm run poc:bazi-golden   # authoritative golden cases (0/50 present)
```

The reference throughout is Swiss Ephemeris 2.10 (`sweph`, Moshier mode, no
data files), used as a devDependency only (AGPL; see ADR-0001).

## 八字

| Check                                                             | Result                                               |
| ----------------------------------------------------------------- | ---------------------------------------------------- |
| 节 instants (2,412, 1900–2100) vs Swiss Ephemeris solar crossings | p50 0.02 min, p99 1.52 min, max 1.58 min             |
| Equation of time vs `swe_time_equ` (1900–2100)                    | < 0.1 min                                            |
| 立春 boundary ±10 min, in HK / New York / London                  | correct year and month pillars in all three          |
| Historical DST (Shanghai 1988, Hong Kong 1975)                    | correct UTC                                          |
| DST gap / fold                                                    | gap rejected; fold flagged and earlier instant taken |
| 十神 / 十二长生 tables vs lunar-javascript (400 charts)           | identical                                            |
| 60-day 日柱 cycle, 子时 sect 1/2, true-solar hour shift           | pass                                                 |
| **Golden cases vs authoritative tool**                            | **0/50, not yet collected**                          |

## 塔罗

| Check                                                   | Result     |
| ------------------------------------------------------- | ---------- |
| 78 unique RWS cards (VIII Strength, XI Justice)         | pass       |
| Chi-square per position, 1,000 three-card draws, α=0.01 | pass (3/3) |
| Reversal rate                                           | \|z\| < 3  |
| Unbiased `nextInt` (n=7, 70k samples)                   | pass       |
| Replay from key + draw_id; tamper detection             | pass       |

## 占星

See ADR-0001. `@gitstrology/engine` fails on all 10 bodies (Moon up to 8.13°).
`astronomy-engine` passes on all 10 (max 0.0049°). The POC adapter in
`src/engines/astrology` uses astronomy-engine at tier `simplified` (no houses).
