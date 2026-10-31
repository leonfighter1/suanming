import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringSimulation;
import 'package:flutter/rendering.dart'
    show RenderAbstractViewport, RenderCustomPaint, RenderImage, RenderParagraph, RenderProxyBox;

import 'content.dart';
import 'content_text.dart';
import 'tokens.dart';

/// The spacing scale (tech plan S24, the ui-design skill): steps of 4 points named by size, then the uses with names of
/// their own. Every padding and gap is one of these; [xxs] only inside small parts (a pill, a key cap, a nudge). A
/// page's sides come from its window class (layout.dart `pagePadding`).
abstract final class Space {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;

  /// Inside a card ([AppCard]'s padding).
  static const card = 20.0;

  /// Above and below a field's text: with its 24-point line a field is 52 high, as tall as the main button.
  static const field = 14.0;

  /// Room above an empty page's message ([EmptyState]).
  static const empty = 96.0;

  /// Room at a page's foot for the floating 追问 button, so it never covers the last card (rule 55).
  static const fab = 104.0;
}

/// Corner radii (the ui-design skill), from a thin bar's to the banner's. A rounded box inside another takes a smaller
/// step than its parent.
abstract final class Radii {
  /// A bar, a thin mark, a tiny thumbnail.
  static const xxs = 2.0;

  /// A thumbnail, a key cap, a meter.
  static const xs = 4.0;

  /// A chip, a pill, a small tile.
  static const chip = 8.0;

  /// A field, a button, a segment, a box inside a card.
  static const field = 12.0;

  /// An icon's tile.
  static const tile = 16.0;

  static const card = 20.0;

  /// The banner at the top of 首页.
  static const hero = 24.0;
}

/// How long things take (the ui-design skill). A state (hover, focus, a choice) changes in [fast], a size in [medium],
/// the theme in [theme]; an entrance takes [enter].
abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const theme = Duration(milliseconds: 300);
  static const enter = Duration(milliseconds: 420);

  /// Things that move or grow.
  static const curve = Curves.easeOutCubic;

  /// A change of theme: every colour, border and state fades from one theme to the other.
  static const themeCurve = Curves.easeInOut;

  /// A press going in ([PressBounce]): quick, so a tap shows it whole.
  static const press = Duration(milliseconds: 100);

  /// A press let go ([PressBounce]): underdamped, so it passes 100 % once (about 1.4 % over) and settles in about half a
  /// second.
  static const pressSpring = SpringDescription(mass: 1, stiffness: 500, damping: 14);

  /// A switch's thumb travelling ([ElasticSwitch]): it overshoots its end by about a tenth of the way, then settles in
  /// about a third of a second.
  static const switchSpring = SpringDescription(mass: 1, stiffness: 400, damping: 22);

  /// A number rolling to a new value ([RollingNumber]), and its curve: fast at first, slower and slower as it nears the
  /// new value, until it stops there.
  static const roll = Duration(milliseconds: 600);
  static const rollCurve = Curves.decelerate;

  /// A skeleton's bars breathing while the data comes ([Skeleton]): one fade out and back.
  static const skeleton = Duration(milliseconds: 1200);

  /// The way out when the account signs out (S29, app.dart's AuthGate): 首页 sinks back and fades as the introduction
  /// page comes forward.
  static const signOut = Duration(milliseconds: 500);
}

/// 骨架屏 (S30; owner, 2026-10-30: 「骨架屏中每个占位条的宽高与真实内容一致；数据到达后在原位置替换，页面布局不发生跳动」): what
/// a page shows while its data comes. The page builds its own frame (its fixed parts, cards and paddings, as when the data
/// is there) with a [SkeletonText] or [SkeletonBox] where each text, icon or picture will be, inside a Skeleton, which
/// lets the bars breathe ([Motion.skeleton]; reduce motion: still) and hides them from screen readers, which hear
/// [label] instead.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child, required this.label});

  /// The page's own build of typical data (the same widgets, so every size is theirs) drawn as a skeleton: laid out as
  /// it is, every line of text, icon and picture covered by a bar of its size ([SkeletonCover]), nothing in it to tap,
  /// focus or read.
  Skeleton.cover({super.key, required this.label, required Widget child})
      : child = IgnorePointer(child: ExcludeFocus(child: SkeletonCover(child: child)));

  final Widget child;
  final String label;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(vsync: this, duration: Motion.skeleton);
  late final _opacity = Tween<double>(begin: 1, end: 0.55).animate(CurvedAnimation(parent: _breath, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: widget.label,
        child: ExcludeSemantics(child: FadeTransition(opacity: _opacity, child: widget.child)),
      );
}

/// A bar standing for text in [style] (the page's style merged in): the room [sample], a typical text of what will
/// come, takes there, with a bar the height of the letters on each of its lines. Like the text that replaces it, it is
/// one line, or with [maxLines] other than 1 it wraps at the width it is given, a bar per line as long as that line.
/// The text takes the same room, so nothing moves.
class SkeletonText extends StatelessWidget {
  const SkeletonText(this.sample, {super.key, this.style, this.maxLines = 1});
  final String sample;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final text = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    final letters = scaler.scale(text.fontSize ?? 14);
    Widget bars(double maxWidth) {
      final painter = TextPainter(
        text: TextSpan(text: sample, style: text),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: maxLines,
      )..layout(maxWidth: maxWidth);
      final lines = painter.computeLineMetrics();
      final size = painter.size;
      painter.dispose();
      return SizedBox.fromSize(
        size: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              SizedBox(
                height: line.height,
                child: Center(child: SkeletonBox(width: line.width, height: letters)),
              ),
          ],
        ),
      );
    }

    // One line needs no width to wrap at (and so works where sizes are measured first, as in IntrinsicHeight).
    return maxLines == 1 ? bars(double.infinity) : LayoutBuilder(builder: (context, box) => bars(box.maxWidth));
  }
}

/// A bar standing for an icon or a picture of a known size. Its colour is the hairline's, seen on a card and on a tile
/// inside one alike.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, required this.width, required this.height, this.radius = Radii.xs});
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: ThemeTokens.of(context).border,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// Lays [child] out as it is and paints it with every line of text (icons are text too), picture and drawing covered
/// by a bar of its size in the hairline's colour, within its own bounds ([Skeleton.cover]).
class SkeletonCover extends SingleChildRenderObjectWidget {
  const SkeletonCover({super.key, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSkeletonCover(ThemeTokens.of(context).border);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderSkeletonCover).color = ThemeTokens.of(context).border;
}

class _RenderSkeletonCover extends RenderProxyBox {
  _RenderSkeletonCover(this._color);
  Color _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final canvas = context.canvas;
    final bar = Paint()..color = _color;
    canvas.save();
    canvas.clipRect(offset & size);
    void cover(Rect rect) => canvas.drawRRect(
          RRect.fromRectAndRadius(rect.shift(offset), const Radius.circular(Radii.xs)),
          bar,
        );
    void visit(RenderObject node) {
      if (node is RenderBox && node.hasSize) {
        final at = node.localToGlobal(Offset.zero, ancestor: this);
        if (node is RenderParagraph) {
          final length = node.text.toPlainText().length;
          for (final line in node.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: length))) {
            cover(line.toRect().shift(at));
          }
          return;
        }
        if (node is RenderImage || node is RenderCustomPaint) {
          cover(at & node.size);
          return;
        }
      }
      node.visitChildren(visit);
    }

    final child = this.child;
    if (child != null) visit(child);
    canvas.restore();
  }
}

/// 数字滚动 (S30; owner, 2026-10-30: 「数字从旧值滚动到新值，使用减速曲线，接近目标值时逐渐变慢后停下」): [value] shown through
/// [format], rolling from the old value to a new one over [Motion.roll] on [Motion.rollCurve]. It shows its first
/// value at once; a whole number ([T] int) rolls through whole numbers. Screen readers get the value it rolls to, not
/// the ones on the way. [textKey] keys the text, so a test reads it as any. Reduce motion: it jumps.
class RollingNumber<T extends num> extends StatelessWidget {
  const RollingNumber(this.value, {super.key, required this.format, this.style, this.textKey});
  final T value;
  final String Function(T value) format;
  final TextStyle? style;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: format(value),
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.toDouble()),
          duration: still ? Duration.zero : Motion.roll,
          curve: Motion.rollCurve,
          builder: (context, shown, _) =>
              Text(format((T == int ? shown.round() : shown) as T), key: textKey, style: style),
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final outline = focusOutline(Theme.of(context).colorScheme);
    // The ring fades in and out ([Motion.fast]); hidden, it is the same outline, transparent, so nothing moves.
    return AnimatedContainer(
      duration: Motion.fast,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.fromBorderSide(shown ? outline : outline.copyWith(color: outline.color.withValues(alpha: 0))),
      ),
      child: widget.child,
    );
  }
}

/// 按压回弹 (S30; owner, 2026-10-30: 「按钮按下时缩小到 96%；松手时用弹簧动画先放大到略超过原尺寸，再回到 100%」): what
/// [builder] builds shrinks to [pressedScale] while the [WidgetStatesController] it is handed says pressed, then springs
/// back past 100 % ([Motion.pressSpring]) and settles. A quick tap still shrinks all the way before it springs back.
/// Give the controller to a button's or an InkWell's `statesController` (the app's buttons, [AppCard]), or set its
/// pressed state from the gestures ([Pressable]). Reduce motion: it stays at 100 %.
class PressBounce extends StatefulWidget {
  const PressBounce({super.key, required this.builder});

  /// The size while pressed.
  static const pressedScale = 0.96;

  final Widget Function(WidgetStatesController states) builder;

  @override
  State<PressBounce> createState() => _PressBounceState();
}

class _PressBounceState extends State<PressBounce> with SingleTickerProviderStateMixin {
  final _states = WidgetStatesController();
  late final _scale = AnimationController.unbounded(vsync: this, value: 1);
  bool _pressed = false;
  bool _still = false;
  TickerFuture? _pressIn;

  @override
  void initState() {
    super.initState();
    _states.addListener(_changed);
  }

  @override
  void dispose() {
    _states.dispose();
    _scale.dispose();
    super.dispose();
  }

  void _changed() {
    final pressed = _states.value.contains(WidgetState.pressed);
    if (pressed == _pressed) return;
    _pressed = pressed;
    if (_still) return;
    if (pressed) {
      _pressIn = _scale.animateTo(PressBounce.pressedScale, duration: Motion.press, curve: Motion.curve);
      return;
    }
    // The press goes all the way in first, so a tap shows the whole bounce.
    final pressIn = _pressIn;
    _pressIn = null;
    if (pressIn != null && _scale.isAnimating) {
      pressIn.whenCompleteOrCancel(() {
        if (mounted && !_pressed) _springBack();
      });
    } else {
      _springBack();
    }
  }

  void _springBack() {
    _scale.animateWith(SpringSimulation(Motion.pressSpring, _scale.value, 1, _scale.velocity)).whenComplete(() {
      // The spring stops within its tolerance: end exactly at 100 %, so nothing is left a hair small.
      if (mounted && !_pressed) _scale.value = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return ScaleTransition(scale: _scale, child: widget.builder(_states));
  }
}

/// The one card style: soft surface, hairline border, generous padding, an
/// optional header row. Content size changes animate. A tappable card shows
/// the focus ring while it has keyboard focus, and bounces when pressed ([PressBounce]).
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.color,
    this.padding = const EdgeInsets.all(Space.card),
    this.onTap,
    this.onLongPress,
    this.alignment = MainAxisAlignment.start,
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Color? color;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// Where its content sits when the card is made taller than it (a row of [CardGrid] takes its tallest card's
  /// height): at the top, or in the middle for a card of one row (首页's methods, S35: 「所有算卦服务的grid必须要vertically
  /// align middle」).
  final MainAxisAlignment alignment;

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
      child: PressBounce(
        builder: (states) => FocusRing(
          focused: _focused,
          radius: Radii.card,
          child: Material(
            color: widget.color ?? scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(Radii.card),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              focusNode: _node,
              statesController: states,
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              onFocusChange: (_) => setState(() => _focused = _node.hasPrimaryFocus),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.card),
                  border: Border.all(color: ThemeTokens.of(context).border),
                ),
                padding: widget.padding,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: widget.alignment,
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
      ),
    );
  }
}

/// A group's name above its cards, read out as a heading: 首页's 东方 and 西方 (owner, v6.1.0); 八字's and 算卦's groups
/// (S35).
class GroupTitle extends StatelessWidget {
  const GroupTitle({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // On the cards' left edge (the ui-design skill's alignment rule).
    return Padding(
      padding: const EdgeInsets.only(top: Space.s, bottom: Space.m),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
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

/// The time of day on the app's banner (S27; owner, 2026-10-30: 「Theme加上太阳和月亮到banner上去，表示时间」): the moon at
/// night (19:00 to 06:00, `nightProvider`), the sun by day.
IconData sunOrMoon(bool night) => night ? Icons.nightlight_round : Icons.wb_sunny_rounded;

/// The banners' art (owner, 2026-10-30: 「Update the banner background using this … luopan.svg for all pages」): 命理罗盘,
/// drawn in JingyaoPaint and made into the app's by `npm run mirror:banner`.
const bannerArt = AssetImage('assets/art/luopan.webp');

/// The night of the art's own sky, laid over the side the banner's words are on so they read on any part of it.
const _artNight = Color(0xFF090C15);

/// The words' glow on the art, against its brightest parts (the gold rings).
const _onArt = [Shadow(color: _artNight, blurRadius: 12)];

/// A banner's least height (owner, 2026-10-31: 「banner需要增加高度，至少有个最低高度，至少300px」): its words and icon in
/// its middle.
const bannerMinHeight = 300.0;

/// The header at the top of the main screens: a title, a line under it and an icon, on 命理罗盘 ([bannerArt]). The art is
/// dark in both themes, so its words and icon take the dark theme's text colours.
class HeroBanner extends StatelessWidget {
  const HeroBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.margin,
    this.contentKey,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  /// The subtitle's key in 内容, written out: it may then hold HTML (ContentText, S33).
  final String? contentKey;

  /// The room round it: by default the gap below; none beside the form on a wide sign-in page (S26).
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const on = ThemeTokens.dark;
    final radius = BorderRadius.circular(Radii.hero);
    final staff = ContentScope.imageOf(context, 'banner');
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: Space.l),
      constraints: const BoxConstraints(minHeight: bannerMinHeight),
      decoration: BoxDecoration(
        borderRadius: radius,
        // The sky's night until the art is ready.
        color: _artNight,
        // The art staff put in (内容管理, S29), else the app's own. Staff's that can't load (removed since, no network)
        // leaves the sky's night, as while art loads.
        image: DecorationImage(image: staff ?? bannerArt, fit: BoxFit.cover, onError: staff == null ? null : (_, _) {}),
        boxShadow: [
          BoxShadow(color: _artNight.withValues(alpha: 0.18), blurRadius: Space.xl, offset: const Offset(0, Space.s)),
        ],
      ),
      child: DecoratedBox(
        // The sky's night, deepest under the words, thinning towards the icon.
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            colors: [for (final a in const [0.94, 0.7, 0.15]) _artNight.withValues(alpha: a)],
            stops: const [0, 0.45, 1],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Row(
            children: [
              Expanded(
                // Its own height, so a banner made taller than its text (beside a form) holds the text in its middle.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.headlineSmall?.copyWith(color: on.text, fontWeight: FontWeight.w600, shadows: _onArt),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: Space.s),
                      if (contentKey == null)
                        Text(
                          subtitle!,
                          style: text.bodyMedium?.copyWith(color: on.text.withValues(alpha: 0.85), shadows: _onArt),
                        )
                      else
                        // Staff's colours as on the dark art: the dark theme's, whatever the app's.
                        Theme(
                          data: Theme.of(context).copyWith(
                            extensions: [
                              ...Theme.of(context).extensions.values.where((e) => e is! ThemeTokens),
                              ThemeTokens.dark,
                            ],
                          ),
                          child: ContentText(
                            subtitle!,
                            contentKey: contentKey!,
                            style: text.bodyMedium?.copyWith(color: on.text.withValues(alpha: 0.85), shadows: _onArt),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              if (icon != null) Icon(icon, size: 48, color: on.text.withValues(alpha: 0.9)),
              // What a page puts on the art (八字's day pillar in its 五行 colours) reads the dark theme's tokens.
              if (trailing != null)
                Theme(data: Theme.of(context).copyWith(extensions: const [ThemeTokens.dark]), child: trailing!),
            ],
          ),
        ),
      ),
    );
  }
}

/// A step's number in a round badge: 求签's rounds, 风水's principles (S28: each had a copy).
class StepNumber extends StatelessWidget {
  const StepNumber(this.number, {super.key});
  final int number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: 12,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Text('$number', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
    );
  }
}

/// Small rounded label (status, source level, stage). A long one wraps within its parent's width rather than run
/// past it (an AI's 喜 or 忌 can be a sentence); in a row, where its width is unbounded, it keeps to one line.
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
      padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.xs),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.chip)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: c), const SizedBox(width: Space.xs)],
          // Loose, in a row of its own size: it may wrap, and it never asks for an unbounded width (rule 49).
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: c,
                    fontWeight: FontWeight.w600,
                    decoration: dotted ? TextDecoration.underline : null,
                    decorationStyle: dotted ? TextDecorationStyle.dotted : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Long text (the ui-design skill): a reading's paragraphs at 16 / 28, its notes, examples and intros at 14 / 24, a
/// small note at 12 / 20. Short text takes the type ramp as it is.
abstract final class ReadingText {
  static TextStyle? body(BuildContext context) => Theme.of(context).textTheme.bodyLarge?.copyWith(height: 28 / 16);
  static TextStyle? small(BuildContext context) => Theme.of(context).textTheme.bodyMedium?.copyWith(height: 24 / 14);
  static TextStyle? caption(BuildContext context) => Theme.of(context).textTheme.bodySmall?.copyWith(height: 20 / 12);
}

/// How far down a mark of [size] (a bullet, an icon) goes beside text in [style] to sit centred on its first line: the
/// ui-design skill's alignment rule for a mark before text that may wrap.
double firstLineInset(TextStyle? style, double size) {
  final line = (style?.fontSize ?? 14) * (style?.height ?? 1.5);
  return math.max(0, (line - size) / 2);
}

/// A page with nothing to show yet (the ui-design skill): its icon, the message under it, centred, with room above.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text, this.contentKey});
  final IconData icon;
  final String text;

  /// [text]'s key in 内容, written out: it may then hold HTML (ContentText, S33).
  final String? contentKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = ThemeTokens.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(top: Space.empty),
      child: Column(
        children: [
          Icon(icon, size: Space.xxxl, color: t.textMuted),
          const SizedBox(height: Space.l),
          if (contentKey == null)
            Text(text, textAlign: TextAlign.center, style: style)
          else
            ContentText(text, contentKey: contentKey!, textAlign: TextAlign.center, style: style),
        ],
      ),
    );
  }
}
