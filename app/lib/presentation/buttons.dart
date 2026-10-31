import 'package:flutter/material.dart';

import 'design.dart';

// The app's buttons (S30; owner, 2026-10-30: 「按压回弹」): Material's FilledButton, OutlinedButton, TextButton, IconButton
// and the extended FloatingActionButton, each in a PressBounce, so every button shrinks to 96 % when pressed and springs
// back. A screen (the app's and the 管理后台's) uses these, never Material's own: design_rules.dart checks it. Each takes
// the arguments the screens use; add one here when a screen needs it.

enum _Kind { plain, icon, tonalIcon }

/// [FilledButton], [FilledButton.icon] and [FilledButton.tonalIcon], bouncing when pressed.
class AppFilledButton extends StatelessWidget {
  const AppFilledButton({super.key, required this.onPressed, required Widget this.child, this.style, this.autofocus = false})
      : _kind = _Kind.plain,
        icon = null,
        label = null;

  const AppFilledButton.icon({
    super.key,
    required this.onPressed,
    required Widget this.icon,
    required Widget this.label,
    this.autofocus = false,
  })  : _kind = _Kind.icon,
        child = null,
        style = null;

  const AppFilledButton.tonalIcon({super.key, required this.onPressed, required Widget this.icon, required Widget this.label})
      : _kind = _Kind.tonalIcon,
        child = null,
        style = null,
        autofocus = false;

  final _Kind _kind;
  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;
  final ButtonStyle? style;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => PressBounce(
        builder: (states) => switch (_kind) {
          _Kind.plain => FilledButton(
              onPressed: onPressed,
              style: style,
              autofocus: autofocus,
              statesController: states,
              child: child,
            ),
          _Kind.icon => FilledButton.icon(
              onPressed: onPressed,
              autofocus: autofocus,
              statesController: states,
              icon: icon,
              label: label!,
            ),
          _Kind.tonalIcon => FilledButton.tonalIcon(
              onPressed: onPressed,
              statesController: states,
              icon: icon,
              label: label!,
            ),
        },
      );
}

/// [OutlinedButton] and [OutlinedButton.icon], bouncing when pressed.
class AppOutlinedButton extends StatelessWidget {
  const AppOutlinedButton({super.key, required this.onPressed, required Widget this.child, this.style})
      : _kind = _Kind.plain,
        icon = null,
        label = null;

  const AppOutlinedButton.icon({super.key, required this.onPressed, required Widget this.icon, required Widget this.label})
      : _kind = _Kind.icon,
        child = null,
        style = null;

  final _Kind _kind;
  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) => PressBounce(
        builder: (states) => _kind == _Kind.plain
            ? OutlinedButton(onPressed: onPressed, style: style, statesController: states, child: child)
            : OutlinedButton.icon(onPressed: onPressed, statesController: states, icon: icon, label: label!),
      );
}

/// [TextButton] and [TextButton.icon], bouncing when pressed.
class AppTextButton extends StatelessWidget {
  const AppTextButton({
    super.key,
    required this.onPressed,
    required Widget this.child,
    this.style,
    this.autofocus = false,
    this.focusNode,
  })  : _kind = _Kind.plain,
        icon = null,
        label = null;

  const AppTextButton.icon({super.key, required this.onPressed, required Widget this.icon, required Widget this.label})
      : _kind = _Kind.icon,
        child = null,
        style = null,
        autofocus = false,
        focusNode = null;

  final _Kind _kind;
  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;
  final ButtonStyle? style;
  final bool autofocus;

  /// The button's own focus node, for a menu it opens to move into from the keyboard (MenuAnchor's childFocusNode).
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => PressBounce(
        builder: (states) => _kind == _Kind.plain
            ? TextButton(
                onPressed: onPressed,
                style: style,
                autofocus: autofocus,
                focusNode: focusNode,
                statesController: states,
                child: child!,
              )
            : TextButton.icon(onPressed: onPressed, statesController: states, icon: icon, label: label!),
      );
}

/// [IconButton], bouncing when pressed.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.style,
    this.visualDensity,
    this.focusNode,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String? tooltip;
  final ButtonStyle? style;
  final VisualDensity? visualDensity;

  /// As [AppTextButton.focusNode].
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => PressBounce(
        builder: (states) => IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          style: style,
          visualDensity: visualDensity,
          focusNode: focusNode,
          statesController: states,
          icon: icon,
        ),
      );
}

/// [FloatingActionButton.extended], bouncing when pressed. It takes no states controller, so the bounce follows the
/// pointer while the button is enabled.
class AppFab extends StatelessWidget {
  const AppFab.extended({super.key, required this.onPressed, required this.icon, required this.label, this.heroTag});

  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) => PressBounce(
        builder: (states) {
          void press(bool down) {
            if (onPressed != null) states.update(WidgetState.pressed, down);
          }

          return Listener(
            onPointerDown: (_) => press(true),
            onPointerUp: (_) => press(false),
            onPointerCancel: (_) => press(false),
            child: FloatingActionButton.extended(onPressed: onPressed, heroTag: heroTag, icon: icon, label: label),
          );
        },
      );
}
