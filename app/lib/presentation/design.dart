import 'dart:async';

import 'package:flutter/material.dart';

/// Spacing scale. Use these instead of ad-hoc numbers so screens line up.
abstract final class Space {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Horizontal page gutter.
  static const page = EdgeInsets.fromLTRB(l, m, l, xxl);
}

abstract final class Radii {
  static const card = 20.0;
  static const field = 14.0;
  static const chip = 10.0;
}

/// Anything lying face down, a tarot card's back or a covered coin (v6.1.0): navy, with a gold edge and gold marks.
abstract final class FaceDown {
  static const navy = Color(0xFF1E2546);
  static const navyLight = Color(0xFF34407A);
  static const gold = Color(0xFFE4BC62);
}

/// The keyboard focus outline, one look on every control: the text colour
/// (dark in light mode, light in dark mode) outside the edge, which stands out
/// on any fill. Buttons and chips get it from the theme; cards and custom
/// targets from [FocusRing]. Material's own focus tint alone is too faint.
BorderSide focusOutline(ColorScheme scheme) =>
    BorderSide(color: scheme.onSurface, width: 2.5, strokeAlign: BorderSide.strokeAlignOutside);

/// The keyboard focus ring: drawn around [child] while [focused] and the user
/// is on the keyboard (never for touch). Material buttons and chips get the same
/// outline from the theme; this is for cards and custom targets.
class FocusRing extends StatefulWidget {
  const FocusRing({super.key, required this.focused, required this.child, this.radius = Radii.field});
  final bool focused;
  final double radius;
  final Widget child;

  @override
  State<FocusRing> createState() => FocusRingState();
}

class FocusRingState extends State<FocusRing> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onMode);
    super.dispose();
  }

  void _onMode(FocusHighlightMode _) => setState(() {});

  /// Whether the ring is drawn now.
  bool get shown => widget.focused && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: shown
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(widget.radius),
                border: Border.fromBorderSide(focusOutline(Theme.of(context).colorScheme)),
              )
            : const BoxDecoration(),
        child: widget.child,
      );
}

/// The one card style: soft surface, hairline border, generous padding, an
/// optional header row. Content size changes animate. A tappable card shows
/// the focus ring while it has keyboard focus.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.color,
    this.padding = const EdgeInsets.all(Space.l + 4),
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Color? color;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// A long press (v8.0.0: starts selecting in 以往记录).
  final VoidCallback? onLongPress;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  /// The card itself has focus (not a button inside it).
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.m),
      child: FocusRing(
        focused: _focused,
        radius: Radii.card,
        child: Material(
          color: widget.color ?? scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(Radii.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onFocusChange: (f) => setState(() => _focused = f),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              padding: widget.padding,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.title != null) ...[
                      Row(
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, size: 20, color: scheme.primary),
                            const SizedBox(width: Space.s),
                          ],
                          Expanded(child: Text(widget.title!, style: theme.textTheme.titleMedium)),
                          ?widget.trailing,
                        ],
                      ),
                      const SizedBox(height: Space.m),
                    ],
                    widget.child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fade + slide-up entrance, optionally delayed for a staggered list.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});
  final Widget child;

  /// Position in a list; each step delays the entrance by 60 ms (max 6 steps).
  final int index;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    _delay = Timer(Duration(milliseconds: 60 * widget.index.clamp(0, 6)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(_curve),
          child: widget.child,
        ),
      );
}

/// Large gradient header used at the top of the main screens.
class HeroBanner extends StatelessWidget {
  const HeroBanner({super.key, required this.title, this.subtitle, this.icon, this.trailing});
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: Space.l),
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.card + 4),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, Color.lerp(scheme.primary, scheme.tertiary, 0.6)!],
        ),
        boxShadow: [
          BoxShadow(color: scheme.primary.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.headlineSmall?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: Space.s),
                  Text(subtitle!, style: text.bodyMedium?.copyWith(color: scheme.onPrimary.withValues(alpha: 0.85))),
                ],
              ],
            ),
          ),
          if (icon != null) Icon(icon, size: 48, color: scheme.onPrimary.withValues(alpha: 0.9)),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small rounded label (status, source level, stage).
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.icon, this.dotted = false});
  final String text;
  final Color? color;
  final IconData? icon;

  /// Underline the text with dots: a term that opens its tip (TermTip).
  final bool dotted;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s + 2, vertical: Space.xs),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.chip)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: c), const SizedBox(width: Space.xs)],
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: c,
                  fontWeight: FontWeight.w600,
                  decoration: dotted ? TextDecoration.underline : null,
                  decorationStyle: dotted ? TextDecorationStyle.dotted : null,
                ),
          ),
        ],
      ),
    );
  }
}
