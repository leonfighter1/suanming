# ADR-0001: 占星引擎选型

- Status: **Proposed**. Needs sign-off from 算法 and 后端 at the Phase 0 gate.
- Date: 2026-10-25
- Evidence: `npm run poc:astrology` → `docs/poc/astrology-results.json`

## Context

Phase 0 §2.1 names `@gitstrology/engine` as the candidate, with a gate of
ecliptic longitude error ≤ 0.01° against Swiss Ephemeris. If it fails, the
fallback is "太阳星座 + 简化相位" in Phase 1–2 and a `pyswisseph` microservice
in Phase 3.

## Findings (20 cases, 1940–2030, 10 cities, reference: Swiss Ephemeris 2.10 Moshier)

| Body                     | @gitstrology/engine 0.1.0 max error | astronomy-engine 2.1.19 max error |
| ------------------------ | ----------------------------------- | --------------------------------- |
| Sun                      | 0.013°                              | 0.0005°                           |
| Moon                     | **8.13°** (mean 4.7°)               | 0.0006°                           |
| Mercury / Venus          | 0.018° / 0.020°                     | 0.003° / 0.003°                   |
| Mars / Jupiter / Saturn  | 1.07° / 0.16° / 1.48°               | 0.001° / 0.002° / 0.002°          |
| Uranus / Neptune / Pluto | 2.83° / 2.92° / 4.44°               | 0.003° / 0.005° / 0.001°          |
| **Gate ≤ 0.01°**         | **FAIL (0/10 bodies)**              | **PASS (10/10)**                  |

A separate 200-case sweep (1930–2029) put astronomy-engine's worst case at
0.005° (Neptune).

Other problems with `@gitstrology/engine`:

- The README claims "~1 arcminute", but the Moon error is ~500× that. With an
  error that large the Moon sign is often wrong.
- Its `timezone` handling parses through the **host's** local zone, so results
  depend on the server's TZ.
- Whole-sign houses only; the ascendant is documented as "~1°".
- A single 0.1.0 release with no history, which is risk one in the Phase 0
  doc.

Swiss Ephemeris (C library, `sweph`, `pyswisseph`) is **AGPL-3.0 or a paid
commercial licence**. Running it as a network service under AGPL obliges you
to publish the service's source. This affects the Phase 3 `pyswisseph` plan
too, not only Node.

## Decision (proposed)

1. Reject `@gitstrology/engine` outright. Even the fallback would show wrong
   Moon signs.
2. Use **astronomy-engine** (MIT, pure JS, zero deps) for planetary
   positions. It passes the gate with a 2× margin.
3. Implement house systems in-house (ascendant/MC are closed-form; Placidus
   is iterative). Until then the ChartFact `precision_tier` is
   `simplified`: positions, signs, retrograde and major aspects, no houses.
4. Use Swiss Ephemeris **only as a dev-time reference** in POC scripts and
   tests (devDependency). If a production need arises, buy the commercial
   licence rather than ship AGPL.
5. Replace the Phase 3 `pyswisseph` microservice plan with in-process
   astronomy-engine plus in-house houses.

## Consequences

- No native dependency in production, and no AGPL exposure.
- astronomy-engine's last release was 2023-12. It is mature and stable, but
  pin it (`2.1.19`) and keep the POC script in CI as a regression guard.
- House-system work (~1 sprint) moves into Phase 2 scope.
