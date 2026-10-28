---
name: keyboard-access
description: Keyboard access for the 命理大师 app, plus the steps that finish every update. Use when adding or changing a screen, dialog, widget, tap target or shortcut in app/ (so Tab, Enter/Space, Esc and the arrow keys keep working for web users), and when finishing any update or release (harness, README 更新记录, version, records).
---

# Keyboard access (命理大师 app)

Web users drive the app from the keyboard. Since v1.0.0 every screen works without a mouse. Keep it that way: every new
screen and widget follows the rules below, and every update ends with the finishing steps at the bottom.

Where things are:

| What                                     | File                                                                                         |
| ---------------------------------------- | -------------------------------------------------------------------------------------------- |
| The keyboard layer (all building blocks) | `app/lib/presentation/keyboard.dart`                                                         |
| Focus look: `FocusRing`, `focusOutline`  | `app/lib/presentation/design.dart`                                                           |
| Focus outline on buttons and chips       | `app/lib/presentation/theme.dart` (`focusSide`, `focusColor`)                                |
| Tests of the layer on its own            | `app/test/keyboard_shell_test.dart` (no fixtures)                                            |
| Tests of every area of the app           | `app/test/keyboard_test.dart` (also bans a bare `GestureDetector`)                           |
| Test helpers                             | `app/test/keys.dart`: `press`, `frames`, `systemBack`, `focusedKey`, `tabStops`, `ringShown` |
| Strings (shortcut list, leave questions) | `app/lib/l10n/app_{en,zh,zh_Hant}.arb`, keys `keys*`, `leave*`                               |

## The keys users get

| Key                                               | Does                                                                                                                |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Tab / Shift+Tab                                   | next / previous control, in reading order (Flutter). On the web, Tab past the end leaves to the browser.            |
| Enter / Space                                     | press the focused control; expand or collapse a section (`ExpansionTile`)                                           |
| Esc                                               | back one level: an open dropdown or menu, then a dialog, then the page. A `LeaveGuard` asks first. Nothing on 首页. |
| ← / →                                             | option rows (`SegmentKeys`), chart periods, the 大运 / 流年 strips; Home / End jump to the ends                     |
| Ctrl+Enter (⌘+Enter)                              | the page's main button (`SubmitShortcut`): 登录, 排盘, 保存                                                         |
| Ctrl+/ (⌘/), or ? outside a text field            | the 键盘快捷键 list (also 设置 → 键盘快捷键)                                                                        |
| Ctrl+Tab, Ctrl+Shift+Tab, Ctrl+W/T/L, F5, Alt+←/→ | the browser's own. Never bind them: Chrome doesn't pass Ctrl+Tab to a page at all.                                  |

## Building blocks: reuse, don't re-implement

| Need                                                    | Use                                                                                                  |
| ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| App-wide keys (Esc, Ctrl+/, Ctrl+Enter)                 | `KeyboardShell`, already in `MaterialApp.builder`. Never add a second one.                           |
| Ask before leaving an unfinished 测算 or unsaved edits  | `LeaveGuard(active:, kind: LeaveKind.reading or edits, message:)` around the page or the dialog      |
| Ctrl+Enter presses the main button                      | `SubmitShortcut(onSubmit:)`: one per page or dialog, `onSubmit` null while the button is disabled    |
| A tap target that isn't a Material button, chip or tile | `Pressable(onPressed:, label:)`. A bare `GestureDetector` fails a test.                              |
| A chart or anything that needs the tap position         | `Pressable(onTapDown:, keys: {←, →, Home, End})` (see `trend_chart.dart`)                            |
| A horizontal strip that scrolls                         | `Pressable(keys:)` around it plus a `ScrollController` (see `_Timeline` in `bazi_chart_page.dart`)   |
| A single-choice `SegmentedButton`                       | wrap it: `SegmentKeys(child: SegmentedButton<T>(...))`                                               |
| The focus look                                          | buttons and chips: the theme; cards: `AppCard` (built in); custom: `Pressable` or `FocusRing`        |
| A picker that should open ready for typing              | `keyboardInUse` (the last input was a key): date/time pickers open in input mode, search autofocuses |
| A new shortcut                                          | add it, a row in `ShortcutList`, and its text in the three ARB files                                 |
| A dialog whose main target should take the focus        | `Pressable(autofocus: true)` (the enlarged tarot card: Enter turns it at once)                       |
| Targets waiting their turn (tarot cards not yet next)   | `ExcludeFocus(excluding: true)`, so Tab only reaches what can be pressed now                         |

## Checklist for a new screen or widget

1. **Tab reaches every control**, in reading order, and nothing hidden takes focus. Give controls a `Key` and add a test
   that reaches them with `tabTo` / `tabStops`.
2. **Enter and Space press it.** Material buttons, chips, tiles and `InkWell` do this already; anything else goes
   through `Pressable`.
3. **Esc goes back** by itself (`KeyboardShell`). If going back throws work away, wrap the page in `LeaveGuard`:
   `reading` for a 测算 in progress (八字 form once edited, 命盘, 塔罗 once drawn), `edits` for editors. Explicit 取消 /
   保存 buttons call `Navigator.pop` and don't ask.
4. **Forms**: Enter moves on (`textInputAction: TextInputAction.next`), Enter in the last field submits
   (`onSubmitted`), and `SubmitShortcut` gives Ctrl+Enter.
5. **Option rows** get `SegmentKeys`. **Strips and charts** get arrow keys through `Pressable(keys:)`.
6. **Focus is visible**: check with `ringShown`, or render a golden and look at it. Material's own focus tint alone is
   too faint.
7. **After every `await`** that ends in navigation or `setState`: `if (!mounted) return;`. The user may have left
   with Esc in the meantime.
8. **New keys** go into `ShortcutList` and the ARB files, then `flutter gen-l10n`.
9. **Never bind a browser-reserved combination** (table above).

## Testing

- `press(tester, key, control:, shift:, character:)` pumps a frame first, as real time passes between inputs (a key
  sent in the same frame as `enterText` meets the page before its rebuild; MISTAKES rule 19).
- `systemBack(tester)` is the browser's or phone's Back (the engine's `popRoute`).
- `focusedKey()` names the focused control by the nearest string `Key`; `tabStops` lists the Tab order.
- Is a dropdown open? `find.text(entry).hitTestable()`: a closed `DropdownMenu` keeps an invisible copy (rule 20).
- VM tests use desktop keys (Enter = `ActivateIntent`); the web uses Enter = `ButtonActivateIntent` and the arrows
  scroll. Custom actions handle both (`Pressable` does). `flutter test --platform chrome` doesn't load on this
  machine (rule 21): rely on the VM tests and the web build gate.

## Pitfalls already met

- A focused text field answers `DismissIntent` itself (to hide its toolbar) and would swallow Esc. `_layerAt` looks
  above the field (rule 18). Edge: on a desktop build, Esc with the text toolbar open goes back instead of only closing
  the toolbar; on the web the browser draws that menu, so it doesn't arise.
- `PopScope.canPop` only changes on rebuild: in tests, pump between a change and the key (see `press`).
- `DropdownMenu(requestFocusOnTap: false)` (为谁排盘): the text box can't take focus; its arrow button is the Tab stop.
  Enter opens it, ↓ / ↑ move, Enter picks.
- Only full pages leave on Esc. A dialog closes only through its own `DismissIntent`, so a dialog that must not be
  dismissed stays open.

## Finishing every update (the owner's rules, for every change, not only keyboard work)

1. **Run the harness** and make it pass. It runs every gate, including the app gate (pub get, analyze, all tests,
   web build), which shows the app still works:

   ```
   powershell -ExecutionPolicy Bypass -File C:\Users\AgentSkills\harness-check\scripts\check.ps1 -Project .
   ```

   Fix and run again until `HARNESS: PASS`. Never call work done on a red run, and report any gate that was skipped.

2. **README.md → 更新记录**: a new entry at the top, `### vX.Y.Z (YYYY-MM-DD): title`. Under it, by area: what
   changed for users, how to use it (keys, buttons, settings), what was fixed, and how it was verified (test counts,
   harness result). Detail is wanted: someone reading only the README should know what the update did.
3. **Version** for anything users notice: `version:` in `app/pubspec.yaml` (`X.Y.Z+build`, raise the build number
   on every release) and `package.json` (`npm version X.Y.Z --no-git-tag-version`). A release gets the git tag
   `vX.Y.Z`.
4. **Records**: `docs/agent/DEVLOG.md` entry; `MODULES.md` rows for new reusable modules; every failure fixed on the
   way goes in through `add-mistake.ps1` (mistake-memory skill).
5. **Commit** with the attribution trailer and push; for a release, push the tag too.
