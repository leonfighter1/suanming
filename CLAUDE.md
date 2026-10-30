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
| Planning, continuing, finishing    | **dev-workflow** (`.claude/skills/dev-workflow`): tech plan, stages, versions, push rule   | work through [docs/tech-plan.md](docs/tech-plan.md); finish with harness PASS → README 更新记录 → version → records → commit; push big updates only              |
| Any AI prompt, reading or its page | **ai-reading** (`.claude/skills/ai-reading`): the owner's requirements for AI readings     | read it before changing a prompt, what a reading sends the model or writes, or its page, export or email                                                         |
| Any colour, size, layout or theme  | **ui-design** (`.claude/skills/ui-design`): tokens, light and dark, grid, spacing, type    | read it before choosing a colour, a padding, a font size or a breakpoint in `app/` or `admin/`; take colours only from `ThemeTokens`                             |

Records:

- [docs/agent/MISTAKES.md](docs/agent/MISTAKES.md): project rules
- `C:\Users\AgentSkills\mistake-memory\GLOBAL_MISTAKES.md`: machine and tooling rules
- [docs/agent/DEVLOG.md](docs/agent/DEVLOG.md): one entry per working session
- [README.md](README.md) 更新记录: one detailed entry per update or release (owner's rule)

## Hard rules for this codebase

1. **ChartFact is additive-only.** Never change the meaning of a field. Engines
   compute facts; the AI only interprets them. 八字's AI reading (owner, 2026-10-29) reads the
   排盘 alone, without the engine's judgements (strength, 喜用, weighted 五行, trend), and judges
   the chart itself: see the ai-reading skill.
2. **Every output goes through a pipeline.** Anything model-generated goes through
   `generateReport`, `generateRemedy`, `generateLifeReport` or, for 追问 (v7.0.0),
   `generateFollowUp`, or, for the 深度分析's questions (v10.0.0), `generateInquiryTurn`
   (`src/ai/`). Nothing calls a model directly. **Content review (rule-layer holds, the guard, 内容审核)
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
8. **Each method stands alone** (owner, 2026-10-27). 八字, 塔罗, 一生运势 and
   astrology each have their own engine, prompts and code paths. A change for one
   must never change another's prompts, facts or output: give a method its own
   prompt versions (`METHOD_PROMPTS` in `src/ai/prompts.ts`: each method's
   narrative, action and remedy prompt, e.g. 塔罗 reads with `narrative_tarot@N`,
   never a shared one) and keep method-specific logic behind its own branch or
   module. `test/method-prompts.test.ts` pins every released prompt's hash and
   checks that no two methods share a prompt.
9. **Every AI request is paid in 积分** (owner, 2026-10-29; v11.0.0, `src/points`). A new
   kind of AI request holds its price before its job (`holdForJob` in `src/api/server.ts`,
   402 `points_short` when short) and settles when the job ends (`settleHold`: its measured
   cost, nothing for a failed or held job); its estimate goes in `config/points.json`. While
   积分 are on, nothing makes AI output nobody pays for (no preloads). `MINGLI_POINTS=off`
   is the switch; 充值 stays simulated until the owner's Phase 4 payments.

## Map

- [README.md](README.md): layout and commands
- [docs/tech-plan.md](docs/tech-plan.md): the staged plan of open work (技术文档) and its stage summaries
- [docs/SUMMARY.md](docs/SUMMARY.md): what each phase delivered
- [docs/phase-1-status.md](docs/phase-1-status.md): current segment status
- [docs/phase-0-gate.md](docs/phase-0-gate.md): open Phase 0 gate items
- [docs/phase-3-gate.md](docs/phase-3-gate.md): the Phase 3 gate (what passed, what waits for the owner; Phase 4 waits for it)
