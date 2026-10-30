import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;

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
  /// The card's own node: onFocusChange reports a field or button inside the card as the card's focus too, so the
  /// ring asks this node whether the card itself has it (v12.0.1).
  final _node = FocusNode(debugLabel: 'AppCard');

  /// The card itself has focus (not a button inside it).
  bool _focused = false;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

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
            focusNode: _node,
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onFocusChange: (_) => setState(() => _focused = _node.hasPrimaryFocus),
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

/// What a tap brings up comes into view by itself (owner, v9.1.0: 「新生成的component 要避免用户下滑后再点击」): the
/// tarot ritual after 抽牌, a room's principles after 看布局, a lot, a hexagram. Wrap the new part in this. When it
/// first shows (after [delay]), and again whenever [trigger] changes (a card that grows a row per tap), the page
/// scrolls as little as it takes to show all of it; one taller than the screen comes to the top. Wrap it outside
/// [FadeSlideIn], whose slide would otherwise be measured too.
class BringIntoView extends StatefulWidget {
  const BringIntoView({super.key, required this.child, this.trigger, this.delay = Duration.zero});
  final Widget child;

  /// A new value brings the part into view again, once the card round it has grown ([AppCard] animates its size).
  final Object? trigger;

  /// How long to wait at first, e.g. while the coins that lead to it turn over.
  final Duration delay;

  /// [AppCard]'s change of size, and a frame.
  static const settle = Duration(milliseconds: 300);

  @override
  State<BringIntoView> createState() => _BringIntoViewState();
}

class _BringIntoViewState extends State<BringIntoView> {
  Timer? _wait;

  /// When parts ask at once, the last to ask (the newest, lowest on the page) is the one shown: the lot after the
  /// throw that brought it, not the rounds card the throw grew.
  static var _latest = 0;

  @override
  void initState() {
    super.initState();
    _schedule(widget.delay);
  }

  @override
  void didUpdateWidget(BringIntoView old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _schedule(BringIntoView.settle);
  }

  @override
  void dispose() {
    _wait?.cancel();
    super.dispose();
  }

  void _schedule(Duration wait) {
    _wait?.cancel();
    final ask = ++_latest;
    void show() {
      if (mounted && ask == _latest) bringIntoView(context);
    }

    if (wait == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) => show());
    } else {
      _wait = Timer(wait, show);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Scrolls the list round [context] as little as it takes to show its box whole, [margin] clear of the edges; a box
/// taller than the list's view comes to its top. Does nothing when the box is in view already. See [BringIntoView].
Future<void> bringIntoView(BuildContext context, {double margin = Space.l}) async {
  final box = context.findRenderObject();
  final position = Scrollable.maybeOf(context)?.position;
  if (box is! RenderBox || !box.attached || !box.hasSize || position == null) return;
  final viewport = RenderAbstractViewport.maybeOf(box);
  if (viewport == null) return;
  // The scroll offsets that put the box's top at the view's top, and its bottom at the view's bottom.
  final top = viewport.getOffsetToReveal(box, 0).offset - margin;
  final bottom = viewport.getOffsetToReveal(box, 1).offset + margin;
  final now = position.pixels;
  final double to;
  if (bottom > top || now > top) {
    to = top; // taller than the view, or its top is above it
  } else if (now < bottom) {
    to = bottom; // below the fold: just far enough for its bottom
  } else {
    return;
  }
  final target = to.clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
  if ((target - now).abs() < 1) return;
  const duration = Duration(milliseconds: 400);
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
    position.jumpTo(target);
  } else if (position is ScrollActivityDelegate) {
    final scroll = _RevealScroll(
      position as ScrollActivityDelegate,
      from: now,
      to: target,
      duration: duration,
      curve: Curves.easeOutCubic,
      vsync: position.context.vsync,
    );
    position.beginActivity(scroll);
    await scroll.done;
  } else {
    await position.animateTo(target, duration: duration, curve: Curves.easeOutCubic);
  }
}

/// [bringIntoView]'s scroll: animateTo's, except that taps reach the page while it moves. Flutter ignores them during
/// an animated scroll, so a button that has just come up (擲筊 as the stick lands) lost the tap that pressed it at
/// once. A touch on the list still stops the scroll, as it stops any.
class _RevealScroll extends DrivenScrollActivity {
  _RevealScroll(
    super.delegate, {
    required super.from,
    required super.to,
    required super.duration,
    required super.curve,
    required super.vsync,
  });

  @override
  bool get shouldIgnorePointer => false;
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
