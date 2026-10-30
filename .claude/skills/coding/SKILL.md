---
name: coding
description:
  How code is written in 命理大师 (the owner, 2026-10-30) - build from what already exists, restructure so each thing
  has one home rather than copying it, and keep every change as small as it can be. Use before and while writing or
  changing any code in src/, app/, admin/, scripts/ or test/, and when reading a diff before committing. Finding what
  exists is the reuse-first skill's job; the steps that finish every update are in the dev-workflow skill.
---

# Coding (命理大师, the owner's rules)

The owner asked for this on 2026-10-30 (tech plan S27):

> 「require coding using existing functionalities or mehtods as much as possible. refactoring the code structure，
> everytime make change, do little change as much as possible.」

## 1. Use what exists

- **Search first.** Before writing a function, widget, provider, route, test helper or script, look for one that does
  the job:
  - the reuse-first skill's `find-existing.ps1` and [MODULES.md](../../../MODULES.md);
  - the code next to the change: the page, the service, the test file's own helpers;
  - the project's skills for their building blocks (ui-design, keyboard-access, ai-reading).
- **Use it as it is.** Import it; never copy it.
- **If it almost fits, extend it** with a parameter whose default keeps every caller as it was, never a second version
  beside it. Examples: `pagePadding(margin: false)` for a list whose rows carry their own inset, and
  `HexagramLines(room: 0)` for a picture without the moving-line marks.

## 2. One home for each thing

- **Before writing something that exists elsewhere, restructure.** That covers a copied block, a second helper under
  another name, or the same constant twice. Move it to one home (extract the function or widget, or widen the one that
  exists), point every caller at it, then build on it. Register a new home in MODULES.md.
- **A restructuring changes no behaviour,** and the tests pass before and after it. When a change needs both, the
  restructuring comes first, as its own step.
- **Remove what the change leaves unused** (a parameter, a constant, a helper, a test fake) in the same change.

## 3. The smallest change that does the job

- **Change only the lines the task needs.**
  - Don't reformat code you didn't change: never `dart format` an existing file (rule P15), and never round-trip a
    hand-formatted file (rule 45).
  - No renames, reordering or edits on the side.
- **Prefer one change in a shared place to many at the callers.** When `pagePadding` became the container, every page
  moved in one edit.
- **Keep public names and signatures.** When one must change, change its callers in the same commit and nothing else.
- **One concern per commit:** a restructuring and a behaviour change are separate commits.
- **Read the diff before calling the work done.** `git diff --stat` should list only the files the task needs, and
  every hunk should be needed. A file that changed far more than intended was reformatted: undo that.

## 4. Check

- **Run the tests that cover what changed,** then the harness (dev-workflow).
- **A failure seen twice is a cause to find, not a flake to retry** (rule 81): name the failing test, then find why.
