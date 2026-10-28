# 命理大师: agent instructions

Read this before working in this repository.

## Skills: use them on every task

Installed in `C:\Users\AgentSkills` (see its README). They call each other's
scripts and don't copy them.

| When                               | Skill                                                                                      | Command                                                                                                                                                          |
| ---------------------------------- | ------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Start of every task                | **mistake-memory**: load the rules learned so far                                          | `powershell -ExecutionPolicy Bypass -File C:\Users\AgentSkills\mistake-memory\scripts\show-rules.ps1 -Project .`                                                 |
| Before writing any new code        | **reuse-first**: find the existing module first                                            | `powershell -ExecutionPolicy Bypass -File C:\Users\AgentSkills\reuse-first\scripts\find-existing.ps1 -Project . -Terms <a,b>`, and read [MODULES.md](MODULES.md) |
| Before saying "done" or committing | **harness-check**: run every gate in `.harness.json`                                       | `powershell -ExecutionPolicy Bypass -File C:\Users\AgentSkills\harness-check\scripts\check.ps1 -Project .`                                                       |
| After fixing any failure           | **mistake-memory**: record it as a rule                                                    | `...\mistake-memory\scripts\add-mistake.ps1 -Project . -Title ... -Rule ...` (`-Scope global` for tooling lessons)                                               |
| Flutter app work                   | **appdev** (`~/.claude/skills/appdev`): its check is what harness-check runs for `app/`    | through harness-check                                                                                                                                            |
| Any app screen, dialog or widget   | **keyboard-access** (`.claude/skills/keyboard-access`): keyboard rules and building blocks | read its checklist; reuse `app/lib/presentation/keyboard.dart`                                                                                                   |
| Finishing every update             | **keyboard-access**, section "Finishing every update"                                      | harness PASS → README 更新记录 entry → version → records → commit                                                                                                |

Records:

- [docs/agent/MISTAKES.md](docs/agent/MISTAKES.md): project rules
- `C:\Users\AgentSkills\mistake-memory\GLOBAL_MISTAKES.md`: machine and tooling rules
- [docs/agent/DEVLOG.md](docs/agent/DEVLOG.md): one entry per working session
- [README.md](README.md) 更新记录: one detailed entry per update or release (owner's rule)

## Hard rules for this codebase

1. **ChartFact is additive-only.** Never change the meaning of a field. Engines
   compute facts; the AI only interprets them.
2. **Every output goes through a pipeline.** Anything model-generated goes through
   `generateReport`, `generateRemedy` or `generateLifeReport` (`src/ai/`). Nothing
   calls a model directly. **Content review (rule-layer holds, the guard, 内容审核)
   is PAUSED by owner decision (2026-10-26)** until the legal & obligations work:
   hits are still scanned and recorded. `MINGLI_REVIEW=on` turns it back on; tests
   run with it on. Don't re-enable or remove it without the owner.
3. **Geo-Rule before any model call.** The region comes from the account
   (set at sign-up), never from a client header outside dev mode.
4. **One source per fact.** Terms, the tarot deck and positions, and topics
   live on the server and reach the app via `npm run sync:app`. Never hand-edit
   `app/assets/i18n`, `app/test/fixtures` or `app/lib/generated`. The tarot card
   art comes from JingyaoPaint through `npm run mirror:tarot`; never edit
   `app/assets/tarot` by hand either.
5. **Secrets only in `.env`** (git-ignored) or the secrets manager. Tests force
   the mock AI provider and never spend money. **The owner's AI switch:**
   `IS_AI_MOCK=TRUE` in `.env` keeps every AI step on the mock to save tokens
   (docs/web-test.md). Never flip or bypass it; only the owner turns the real model on.
6. Write files that contain backslashes with the Write/Edit tool, not shell heredocs.
7. Flutter/Dart tooling needs an ASCII path on this machine. harness-check
   handles it; for manual runs use a junction.

## Map

- [README.md](README.md): layout and commands
- [docs/SUMMARY.md](docs/SUMMARY.md): what each phase delivered
- [docs/phase-1-status.md](docs/phase-1-status.md): current segment status
- [docs/phase-0-gate.md](docs/phase-0-gate.md): open Phase 0 gate items
