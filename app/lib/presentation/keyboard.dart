import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/gen/app_localizations.dart';
import 'design.dart';
import 'widgets/remedy.dart' show compactButtons;

/// The app's keyboard layer for web and desktop users. Rules and the checklist
/// for new screens: .claude/skills/keyboard-access/SKILL.md.
///
/// [KeyboardShell] (around the Navigator) adds the app-wide keys:
///  * Esc goes back one level. An open menu, dropdown or dialog closes first
///    (each answers DismissIntent itself); otherwise the page pops, through its
///    [LeaveGuard] if it has one. On the first page it does nothing.
///  * Ctrl+/ (⌘/ on a Mac), or ? outside a text field: the shortcut list.
///  * Ctrl+Enter (⌘+Enter): the current page's [SubmitShortcut].
///
/// Tab, Shift+Tab, Enter and Space stay Flutter's own. Ctrl+Tab and
/// Ctrl+Shift+Tab belong to the browser (they switch browser tabs and never
/// reach a page): switching between options is ←/→ ([SegmentKeys]).
class KeyboardShell extends StatefulWidget {
  const KeyboardShell({super.key, required this.child});
  final Widget child;

  static const shortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.escape): BackIntent(),
    SingleActivator(LogicalKeyboardKey.slash, control: true): ShowShortcutsIntent(),
    SingleActivator(LogicalKeyboardKey.slash, meta: true): ShowShortcutsIntent(),
    CharacterActivator('?'): ShowShortcutsIntent(typed: true),
    SingleActivator(LogicalKeyboardKey.enter, control: true): SubmitIntent(),
    SingleActivator(LogicalKeyboardKey.enter, meta: true): SubmitIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter, control: true): SubmitIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter, meta: true): SubmitIntent(),
  };

  @override
  State<KeyboardShell> createState() => _KeyboardShellState();
}

class _KeyboardShellState extends State<KeyboardShell> {
  final _actions = <Type, Action<Intent>>{
    BackIntent: _BackAction(),
    ShowShortcutsIntent: _ShowShortcutsAction(),
    SubmitIntent: _SubmitAction(),
  };

  @override
  void initState() {
    super.initState();
    _lastInputWasKey = false;
    HardwareKeyboard.instance.addHandler(_onKey);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent) _lastInputWasKey = true;
    return false; // only listening
  }

  void _onPointer(PointerEvent e) {
    if (e is PointerDownEvent) _lastInputWasKey = false;
  }

  @override
  Widget build(BuildContext context) => Shortcuts(
        debugLabel: 'KeyboardShell',
        shortcuts: KeyboardShell.shortcuts,
        child: Actions(actions: _actions, child: widget.child),
      );
}

bool _lastInputWasKey = false;

/// Whether the user is driving the app from the keyboard right now: their last
/// input was a key, not a tap or click. Pickers then open ready for typing.
bool get keyboardInUse => _lastInputWasKey;

/// Esc: back one level. The nearest open layer closes (dropdown, menu,
/// dialog); with none open, the page pops through its [LeaveGuard].
class BackIntent extends Intent {
  const BackIntent();
}

/// Show the shortcut list. [typed]: from the ? key, so not while typing text.
class ShowShortcutsIntent extends Intent {
  const ShowShortcutsIntent({this.typed = false});
  final bool typed;
}

/// Ctrl+Enter: the current page's main button ([SubmitShortcut]).
class SubmitIntent extends Intent {
  const SubmitIntent();
}

class _BackAction extends ContextAction<BackIntent> {
  @override
  bool isEnabled(BackIntent intent, [BuildContext? context]) =>
      context != null && (_layerAt(context) != null || _canLeavePage(context));

  @override
  Object? invoke(BackIntent intent, [BuildContext? context]) {
    final layer = _layerAt(context!);
    if (layer != null) return Actions.maybeInvoke(layer, const DismissIntent());
    return Navigator.of(context).maybePop();
  }
}

/// Where Esc closes an open layer: the context whose nearest DismissIntent
/// action is enabled (an open dropdown or menu, a dialog), or null. Above a text
/// field, because its own DismissIntent (which only hides its toolbar) is always
/// enabled and would swallow the key.
BuildContext? _layerAt(BuildContext context) {
  final from = context.findAncestorStateOfType<EditableTextState>()?.context ?? context;
  const dismiss = DismissIntent();
  final action = Actions.maybeFind<DismissIntent>(from);
  if (action == null) return null;
  final open = action is ContextAction<DismissIntent> ? action.isEnabled(dismiss, from) : action.isEnabled(dismiss);
  return open ? from : null;
}

/// Only full pages go back this way; a dialog that can't be dismissed stays.
bool _canLeavePage(BuildContext context) =>
    ModalRoute.of(context) is PageRoute && (Navigator.maybeOf(context)?.canPop() ?? false);

/// Focus is in a text field: a typed character is text, not a shortcut.
bool _typing(BuildContext context) => context.findAncestorStateOfType<EditableTextState>() != null;

class _ShowShortcutsAction extends ContextAction<ShowShortcutsIntent> {
  @override
  bool isEnabled(ShowShortcutsIntent intent, [BuildContext? context]) =>
      context != null && !_listOpen && Navigator.maybeOf(context) != null && !(intent.typed && _typing(context));

  @override
  Object? invoke(ShowShortcutsIntent intent, [BuildContext? context]) => showShortcutList(context!);
}

class _SubmitAction extends Action<SubmitIntent> {
  @override
  bool isEnabled(SubmitIntent intent) => _currentSubmit() != null;

  @override
  Object? invoke(SubmitIntent intent) {
    _currentSubmit()?.call();
    return null;
  }
}

final _submitters = <_SubmitShortcutState>{};

/// The main action of the page (or dialog) on top, if it has one right now.
VoidCallback? _currentSubmit() {
  for (final s in _submitters) {
    if (s.route?.isCurrent ?? false) return s.widget.onSubmit;
  }
  return null;
}

/// Ctrl+Enter (⌘+Enter on a Mac) presses this page's main button, wherever the
/// focus is on the page, even before anything is focused. One per page or dialog.
class SubmitShortcut extends StatefulWidget {
  const SubmitShortcut({super.key, required this.onSubmit, required this.child});

  /// Null while the main button is disabled.
  final VoidCallback? onSubmit;
  final Widget child;

  @override
  State<SubmitShortcut> createState() => _SubmitShortcutState();
}

class _SubmitShortcutState extends State<SubmitShortcut> {
  ModalRoute<Object?>? route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    route = ModalRoute.of(context);
    _submitters.add(this);
  }

  @override
  void dispose() {
    _submitters.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// What a guarded page would lose on the way back.
enum LeaveKind {
  /// An unfinished 测算: going back starts it over.
  reading,

  /// Unsaved edits.
  edits,
}

/// Asks before going back from a page (or dialog) that holds an unfinished
/// 测算 or unsaved edits. Esc, the ← button, the browser's back and tapping
/// outside a dialog all come through here; explicit Cancel / Save buttons
/// (Navigator.pop) don't.
class LeaveGuard extends StatelessWidget {
  const LeaveGuard({super.key, required this.active, required this.child, this.kind = LeaveKind.reading, this.message});

  /// Ask only while there is something to lose.
  final bool active;
  final LeaveKind kind;

  /// What is lost, in the page's own words (defaults to a general line).
  final String? message;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
        canPop: !active,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final navigator = Navigator.of(context);
          if (await confirmLeave(context, kind: kind, message: message)) navigator.pop(result);
        },
        child: child,
      );
}

/// 返回将重新开始 / 放弃未保存的修改？: true when the user chooses to go back.
/// Enter confirms the step they started (going back); Esc stays.
Future<bool> confirmLeave(BuildContext context, {LeaveKind kind = LeaveKind.reading, String? message}) async {
  final l10n = AppLocalizations.of(context);
  final reading = kind == LeaveKind.reading;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => compactButtons(
      ctx,
      AlertDialog(
        key: const Key('leave-confirm'),
        icon: Icon(reading ? Icons.restart_alt : Icons.edit_off_outlined),
        title: Text(reading ? l10n.leaveReadingTitle : l10n.leaveEditsTitle),
        content: Text(message ?? (reading ? l10n.leaveReadingBody : l10n.leaveEditsBody)),
        actions: [
          TextButton(
            key: const Key('leave-stay'),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(reading ? l10n.leaveReadingStay : l10n.leaveEditsStay),
          ),
          FilledButton(
            key: const Key('leave-go'),
            autofocus: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(reading ? l10n.leaveReadingGo : l10n.leaveEditsGo),
          ),
        ],
      ),
    ),
  );
  return go == true;
}

/// A custom tap target (anything that isn't a Material button, chip or tile)
/// made usable from the keyboard: Tab focuses it, Enter or Space presses it,
/// [keys] adds its own keys (←/→ on a chart), and the focus ring shows while
/// it has keyboard focus. Use it instead of a bare GestureDetector: a test
/// keeps GestureDetector out of the screens.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onPressed,
    this.onTapDown,
    this.keys = const {},
    this.radius = Radii.field,
    this.label,
    this.autofocus = false,
  });

  final Widget child;
  final VoidCallback? onPressed;

  /// Take the focus when it first appears (e.g. the card in an enlarged view, so Enter turns it).
  final bool autofocus;

  /// For targets that need the tap position (a chart).
  final GestureTapDownCallback? onTapDown;

  /// The target's own keys while it has focus.
  final Map<ShortcutActivator, VoidCallback> keys;
  final double radius;

  /// What a screen reader says for it.
  final String? label;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final press = widget.onPressed;
    final tappable = press != null || widget.onTapDown != null;
    return Semantics(
      button: press != null,
      label: widget.label,
      child: FocusableActionDetector(
        autofocus: widget.autofocus,
        enabled: tappable || widget.keys.isNotEmpty,
        mouseCursor: tappable ? SystemMouseCursors.click : MouseCursor.defer,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        shortcuts: {for (final e in widget.keys.entries) e.key: VoidCallbackIntent(e.value)},
        actions: {
          // Enter is ButtonActivateIntent on the web and ActivateIntent elsewhere.
          if (press != null) ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => press()),
          if (press != null) ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => press()),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: press,
          onTapDown: widget.onTapDown,
          child: FocusRing(focused: _focused, radius: widget.radius, child: widget.child),
        ),
      ),
    );
  }
}

/// ←/→ inside a single-choice [SegmentedButton]: select the neighbouring
/// segment and take the focus along (the radio-group pattern). This is the
/// app's "switch tab" key; Ctrl+Tab stays the browser's. The row shows the
/// focus ring while one of its segments has keyboard focus.
class SegmentKeys<T> extends StatefulWidget {
  const SegmentKeys({super.key, required this.child});
  final SegmentedButton<T> child;

  @override
  State<SegmentKeys<T>> createState() => _SegmentKeysState<T>();
}

class _SegmentKeysState<T> extends State<SegmentKeys<T>> {
  bool _focused = false;

  KeyEventResult _onKey(FocusNode group, KeyEvent e) {
    final child = widget.child;
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final step = switch (e.logicalKey) {
      LogicalKeyboardKey.arrowRight => 1,
      LogicalKeyboardKey.arrowLeft => -1,
      _ => 0,
    };
    final change = child.onSelectionChanged;
    // One focus node per enabled segment, in order.
    final values = [for (final s in child.segments) if (s.enabled) s.value];
    final nodes = group.traversalDescendants.toList();
    final at = nodes.indexWhere((n) => n.hasPrimaryFocus);
    if (step == 0 || change == null || at < 0 || nodes.length != values.length) return KeyEventResult.ignored;
    final to = at + step;
    if (to >= 0 && to < values.length) {
      nodes[to].requestFocus();
      change({values[to]});
    }
    return KeyEventResult.handled; // at either end: stay put
  }

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        onFocusChange: (f) => setState(() => _focused = f),
        child: FocusRing(focused: _focused, child: widget.child),
      );
}

bool _listOpen = false;

/// The 键盘快捷键 list (Ctrl+/, ?, or 设置).
Future<void> showShortcutList(BuildContext context) async {
  if (_listOpen) return;
  _listOpen = true;
  try {
    await showDialog<void>(context: context, builder: (_) => const ShortcutList());
  } finally {
    _listOpen = false;
  }
}

class ShortcutList extends StatelessWidget {
  const ShortcutList({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mod = const {TargetPlatform.macOS, TargetPlatform.iOS}.contains(defaultTargetPlatform) ? '⌘' : 'Ctrl';
    final rows = [
      (['Tab', 'Shift + Tab'], l10n.keysTab),
      (['Enter', l10n.keySpace], l10n.keysPress),
      (['Esc'], l10n.keysEsc),
      (['← →'], l10n.keysArrows),
      (['↑ ↓', 'PgUp', 'PgDn'], l10n.keysScroll),
      (['$mod + Enter'], l10n.keysSubmit),
      (['$mod + /', '?'], l10n.keysHelp),
      (['Ctrl + Tab'], l10n.keysBrowser),
    ];
    return AlertDialog(
      key: const Key('shortcut-list'),
      icon: const Icon(Icons.keyboard_outlined),
      title: Text(l10n.keysTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [for (final (keys, text) in rows) _KeyRow(keys: keys, text: text)],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close))],
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.keys, required this.text});
  final List<String> keys;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 148,
            child: Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                for (final k in keys)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.xxs),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(Radii.xs),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Text(k, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
