---
name: dev-workflow
description: How work is planned, versioned and finished in 命理大师. The staged tech plan (docs/tech-plan.md) and its stage summaries, which version a change gets (big X.0.0, medium X.Y.0, small X.Y.Z), the steps that finish every update (harness, README 更新记录, version, records, commit), when to push (big updates only), and how past mistakes are kept in mind. Use at the start and end of every task, when planning or continuing work, and before any release.
---

# Development workflow (命理大师, the owner's rules)

## The plan

- Open work lives in [docs/tech-plan.md](../../../docs/tech-plan.md), split into stages (阶段 S1, S2, …), each made of
  work packages (WP) with a spec and acceptance tests.
- When a task is done, look for leftover work: review findings, TODOs, owner requests not yet done. If there is any,
  add it to the plan (a new WP, or a new stage), then carry on with the plan in order. Keep its status table current.
- Before a WP: re-read its spec and the lessons it lists (rules from docs/agent/MISTAKES.md and the global list).

## Stages and versions

| Size   | What                                                            | Version                     | Push                            |
| ------ | --------------------------------------------------------------- | --------------------------- | ------------------------------- |
| Big    | a stage of the plan is complete (several WPs, a new capability) | X.0.0, with a stage summary | yes, after a fresh harness PASS |
| Medium | a work package or a feature set                                 | X.Y.0                       | no: commit and tag locally      |
| Small  | a fix, a small UI change, a small refactor                      | X.Y.Z                       | no: commit and tag locally      |

- Every update gets its README 更新记录 entry, whatever its size.
- Push only big updates (owner, 2026-10-27): `git push origin main` and `git push origin --tags`. Medium and small
  updates stay as local commits and tags until the next big update takes them up.
- Before pushing a big update, run the harness once more on the final tree (every local commit it carries) and push
  only on `HARNESS: PASS` (owner, 2026-10-27).
- Changes that users don't notice (docs, plans, tooling) need no version.

## Stage summary (阶段性总结)

When a stage completes, before its X.0.0 release, write its summary in docs/tech-plan.md under 阶段总结:

1. What the stage delivered, per WP, with the version each went out in.
2. Numbers: server and app test counts, verification runs, sizes.
3. What changed against the plan, and why.
4. Mistakes recorded during the stage (rule numbers) and what they teach.
5. What comes next: the next stage, and any WPs found on the way.

The README entry of the X.0.0 release sums the stage up for users.

## Finishing every update

1. **Run the harness** and make it pass. It runs every gate, including the app gate (pub get, analyze, all tests,
   web build), which shows the app still works:

   ```
   powershell -ExecutionPolicy Bypass -File C:\Users\AgentSkills\harness-check\scripts\check.ps1 -Project .
   ```

   Fix and run again until `HARNESS: PASS`. Never call work done on a red run, and report any gate that was skipped.
   After a pubspec change, follow MISTAKES rule 23 first.

2. **README.md → 更新记录**: a new entry at the top, `### vX.Y.Z (YYYY-MM-DD): title`. Under it, by area: what
   changed for users, how to use it (keys, buttons, settings), what was fixed, and how it was verified (test counts,
   harness result). Detail is wanted: someone reading only the README should know what the update did.
3. **Version** by the table above: `version:` in `app/pubspec.yaml` (`X.Y.Z+build`, the build number goes up on every
   release) and `package.json` (`npm version X.Y.Z --no-git-tag-version`); git tag `vX.Y.Z`.
4. **Records**: `docs/agent/DEVLOG.md` entry; `MODULES.md` rows for new reusable modules; the tech plan's status table;
   every failure fixed on the way goes in through `add-mistake.ps1` (mistake-memory skill); at a stage's end, its
   summary.
5. **Commit** with the attribution trailer and tag it. Push only a big update, after a fresh harness PASS (above).

## Never forget past mistakes

- At the start of every task: `show-rules.ps1` (mistake-memory skill).
- The tech plan names the rules each WP is most likely to break; read them before the WP.
- After fixing anything that failed: `add-mistake.ps1 -Project .` with symptom, cause, fix and rule. When a rule turns
  out to be wrong, correct it in place (as with rule 23) rather than adding a contradicting one.
