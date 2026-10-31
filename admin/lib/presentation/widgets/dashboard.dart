import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/layout.dart';
import 'package:mingli_app/presentation/tokens.dart';

import '../format.dart';

// The dashboard's layout and figures (tech plan S24 WP24.3; owner, 2026-10-30: 「非对称Dashboard布局，以大数字为视觉锚点，
// 辅助数据采用紧凑网格，右侧设置独立纵向面板」). The ui-design skill holds the rules, after the dataviz skill: one hero figure
// a page, supporting figures in a compact grid, each change signed against a named period with an arrow, never colour
// alone; numbers in columns right-aligned with tabular figures.

/// The content's width from which the panel stands at the right (a window of 1200 and wider, beside the rail).
const asideFrom = 1080.0;

/// The panel's width: about a quarter of a wide window, the main column's three.
const asideWidth = 360.0;

/// The panel's width where it shows a document at a readable width: the 消息 editor's preview of a mail (S25).
const asideWide = 480.0;

/// The dashboard's container (owner, 2026-10-30: 「for wider screen user, make sure have a container to limit the size
/// of it」; 2026-10-31: 「对1620px以上的屏幕，后台管理的content也要加大置1620px」): the app's own, 1620; every page, its main
/// column and its panel together, at most this wide and centred on a wider window, the window's margin inside it. The
/// bar and the rail stay the window's.
const pageMax = Grid.container;

/// The room at each side of the container on a page [width] wide: none until the page is wider than [pageMax].
double containerSide(double width) => math.max(0, (width - pageMax) / 2);

/// A dashboard page (the ui-design skill): in the container ([pageMax]), [main] in a column and [aside], the page's
/// panel, at the right from [asideFrom]: a card of its own, with a scroll of its own. Below that the panel joins the
/// column at [narrowAt] (after that many of [main]'s parts; at the end by default), so a page whose panel holds what
/// one does (filters, actions) can keep it near the top. The panel is the same card in both places: the card colour
/// and a hairline, its parts ([PanelSection]) one under another.
class DashboardLayout extends StatelessWidget {
  const DashboardLayout({super.key, required this.main, this.aside = const [], this.narrowAt, this.panelWidth = asideWidth});
  final List<Widget> main;
  final List<Widget> aside;
  final int? narrowAt;

  /// The panel's width at the right: [asideWidth] (the constant), or [asideWide] for a document.
  final double panelWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final window = WindowClass.ofContext(context);
          // The container's edges: the margin inside it, and beyond it, on a wide window, the room left over.
          final side = containerSide(box.maxWidth) + window.margin;
          final t = ThemeTokens.of(context);
          if (aside.isEmpty || box.maxWidth < asideFrom) {
            final at = (narrowAt ?? main.length).clamp(0, main.length);
            return ListView(
              key: const Key('page-main'),
              padding: EdgeInsets.fromLTRB(side, Space.xl, side, Space.xxl),
              children: [
                ...main.take(at),
                if (aside.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.m),
                    child: _panel(
                      t,
                      Padding(
                        padding: const EdgeInsets.all(Space.xl),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: aside),
                      ),
                    ),
                  ),
                ...main.skip(at),
              ],
            );
          }
          // The main column, a gutter, then the panel, level with the column's top and as tall as the window lets it
          // be. The column's list takes the room beyond the container too, so the wheel scrolls it there.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  key: const Key('page-main'),
                  padding: EdgeInsets.fromLTRB(side, Space.xl, window.gutter, Space.xxl),
                  children: main,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(0, Space.xl, side, Space.xl),
                child: SizedBox(
                  width: panelWidth,
                  child: _panel(
                    t,
                    ListView(
                      padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.xxl),
                      children: aside,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );

  /// The panel's card, the same in both places (S28, F18): the card colour and a hairline. A Material, not a coloured
  /// box: the switches and rows inside paint their ink on it.
  Widget _panel(ThemeTokens t, Widget child) => Material(
        key: const Key('aside'),
        color: t.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: t.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

/// A part of the panel: its heading (and [trailing]), then its content; a hairline above every part but the [first].
class PanelSection extends StatelessWidget {
  const PanelSection({super.key, required this.title, required this.child, this.trailing, this.first = false});
  final String title;
  final Widget child;
  final Widget? trailing;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!first) const Divider(height: Space.xxl),
        Row(
          children: [
            Expanded(
              child: Semantics(header: true, child: Text(title, style: theme.textTheme.titleSmall)),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: Space.m),
        child,
      ],
    );
  }
}

/// A figure's change against the period before (the dataviz skill's delta).
class Change {
  const Change(this.now, this.before, {required this.against, this.upIsGood = true, this.points = false});
  final double now;
  final double before;

  /// The period it is measured against, in words: 前 30 天.
  final String against;
  final bool upIsGood;

  /// The figure is a ratio (毛利率): its change is in percentage points.
  final bool points;

  /// The change: of [before] (0.123 for +12.3 %), for [points] the difference; null when there was nothing before.
  double? get delta => points
      ? now - before
      : before == 0
          ? null
          : (now - before) / before.abs();
}

/// [Change] in a line: an arrow, the sign and the size, then 较前 30 天. Coloured by its direction and whether up is good
/// (success or danger), grey when flat; the arrow and the sign carry it without the colour.
class ChangeLabel extends StatelessWidget {
  const ChangeLabel(this.change, {super.key});
  final Change change;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = ThemeTokens.of(context);
    final d = change.delta;
    final muted = theme.textTheme.labelMedium?.copyWith(color: t.textMuted);
    if (d == null) return Text('${change.against}无数据', style: muted);
    final flat = d.abs() < 0.0005;
    final up = d > 0;
    final colour = flat
        ? t.textMuted
        : up == change.upIsGood
            ? t.success
            : t.danger;
    final size = change.points ? '${(d.abs() * 100).toStringAsFixed(1)} 个百分点' : '${(d.abs() * 100).toStringAsFixed(1)}%';
    final said = flat ? '持平' : '${up ? '+' : '-'}$size';
    // The change and its period side by side; in a narrow tile the period goes under, whole.
    return Semantics(
      label: '较${change.against}${flat ? '持平' : '${up ? '上升' : '下降'} $size'}',
      child: ExcludeSemantics(
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Space.xs,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  flat
                      ? Icons.remove
                      : up
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                  size: 16,
                  color: colour,
                ),
                const SizedBox(width: Space.xxs),
                // Loose: in a narrow tile it wraps rather than run past the edge (rule 77).
                Flexible(child: Text(said, style: theme.textTheme.labelLarge?.copyWith(color: colour))),
              ],
            ),
            Text('较${change.against}', style: muted),
          ],
        ),
      ),
    );
  }
}

/// A figure's text, keyed `kpi-<label>` unless [key] says otherwise: [number] through [format], rolling to each new
/// value (数字滚动, S30; RollingNumber), or else [value] as it is (a ratio, a dash).
Widget _figure(String label, String value, num? number, String Function(num)? format, Key? key, TextStyle? style) =>
    number != null && format != null
        ? RollingNumber<num>(number, format: format, textKey: key ?? ValueKey<String>('kpi-$label'), style: style)
        : Text(value, key: key ?? ValueKey<String>('kpi-$label'), style: style);

/// The one number a page leads with (the dataviz skill's hero figure: 48 or more, the same face as all else): its
/// label, the figure, its change, a line under it, and its days as a [Sparkline] beside it (below it on a narrow card).
class HeroFigure extends StatelessWidget {
  const HeroFigure({
    super.key,
    required this.label,
    this.value = '',
    this.number,
    this.format,
    this.valueKey,
    this.change,
    this.caption,
    this.trend = const [],
    this.trendLabel,
  });
  final String label;
  final String value;

  /// A number that rolls to its new values (数字滚动, S30), shown through [format]; [value] is not used then.
  final num? number;
  final String Function(num)? format;

  /// The value's key; `kpi-<label>` by default.
  final Key? valueKey;
  final Change? change;
  final String? caption;
  final List<double> trend;

  /// The trend in words, for screen readers.
  final String? trendLabel;

  /// The sparkline's height beside the figure, and under it on a narrow card.
  static const _trendTall = 112.0;
  static const _trendShort = 64.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = ThemeTokens.of(context);
    final figure = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.titleSmall?.copyWith(color: t.textSecondary)),
        const SizedBox(height: Space.xs),
        // A long figure shrinks rather than wraps.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: _figure(label, value, number, format, valueKey, theme.textTheme.displaySmall),
        ),
        if (change != null) ...[const SizedBox(height: Space.xs), ChangeLabel(change!)],
        if (caption != null) ...[
          const SizedBox(height: Space.m),
          Text(caption!, style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary)),
        ],
      ],
    );
    return AppCard(
      key: const Key('hero'),
      padding: const EdgeInsets.all(Space.xl),
      child: LayoutBuilder(
        builder: (context, box) {
          if (trend.length < 2) return figure;
          final spark = Sparkline(trend, label: trendLabel);
          if (box.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [figure, const SizedBox(height: Space.l), SizedBox(height: _trendShort, child: spark)],
            );
          }
          // 5 : 7, the figure first: what the number is, then how it went.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(flex: 5, child: figure),
              const SizedBox(width: Space.xl),
              Expanded(flex: 7, child: SizedBox(height: _trendTall, child: spark)),
            ],
          );
        },
      ),
    );
  }
}

/// A supporting figure (the dataviz skill's stat tile): its label, the value, its change, a line of detail.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    this.value = '',
    this.number,
    this.format,
    this.valueKey,
    this.change,
    this.detail,
    this.icon,
  });
  final String label;
  final String value;

  /// A number that rolls to its new values (数字滚动, S30), shown through [format]; [value] is not used then.
  final num? number;
  final String Function(num)? format;

  /// The value's key; `kpi-<label>` by default.
  final Key? valueKey;
  final Change? change;
  final String? detail;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = ThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.all(Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: t.textSecondary), const SizedBox(width: Space.xs)],
              Expanded(
                child: Text(label, style: theme.textTheme.labelLarge?.copyWith(color: t.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _figure(label, value, number, format, valueKey, theme.textTheme.headlineSmall),
          ),
          if (change != null) ...[const SizedBox(height: Space.xs), ChangeLabel(change!)],
          if (detail != null) ...[
            const SizedBox(height: Space.xs),
            Text(detail!, style: theme.textTheme.bodySmall?.copyWith(color: t.textMuted)),
          ],
        ],
      ),
    );
  }
}

/// Stat tiles in a compact grid inside one card: as many columns as fit at [minWidth] (up to [maxColumns] and never
/// more than there are tiles, at least two), hairlines between them, each row as tall as its tallest tile.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children, this.maxColumns = 4, this.minWidth = 176});
  final List<Widget> children;
  final int maxColumns;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    final hairline = BorderSide(color: t.border);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.m),
      child: Container(
        key: const Key('stat-grid'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: t.border),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final most = math.max(1, math.min(maxColumns, children.length));
            final columns = (box.maxWidth / minWidth).floor().clamp(math.min(2, most), most).toInt();
            final rows = (children.length / columns).ceil();
            return Column(
              children: [
                for (var r = 0; r < rows; r++)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var c = 0; c < columns; c++)
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border(
                                  right: c < columns - 1 ? hairline : BorderSide.none,
                                  bottom: r < rows - 1 ? hairline : BorderSide.none,
                                ),
                              ),
                              child: r * columns + c < children.length
                                  ? children[r * columns + c]
                                  : const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A figure's days as a small line (the dataviz skill's sparkline): no axes, the line in the accent over a soft fill,
/// the last day marked, the zero line a hairline. [label] says it in words.
class Sparkline extends StatelessWidget {
  const Sparkline(this.values, {super.key, this.label});
  final List<double> values;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    return Semantics(
      label: label,
      child: CustomPaint(
        key: const Key('sparkline'),
        size: Size.infinite,
        painter: _SparkPainter(values, line: t.accent, fill: t.accent.withValues(alpha: 0.12), base: t.border),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter(this.values, {required this.line, required this.fill, required this.base});
  final List<double> values;
  final Color line;
  final Color fill;
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final low = math.min(0.0, values.reduce(math.min));
    final high = math.max(values.reduce(math.max), low + 1);
    // Room for the line's width and the last day's mark.
    const inset = 5.0;
    double x(int i) => inset + (size.width - 2 * inset) * i / (values.length - 1);
    double y(double v) => size.height - inset - (size.height - 2 * inset) * (v - low) / (high - low);
    final path = Path()..moveTo(x(0), y(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }
    final zero = y(0);
    final area = Path.from(path)
      ..lineTo(x(values.length - 1), zero)
      ..lineTo(x(0), zero)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);
    canvas.drawLine(Offset(0, zero), Offset(size.width, zero), Paint()..color = base);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(x(values.length - 1), y(values.last)), 4, Paint()..color = line);
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.values != values || old.line != line || old.fill != fill || old.base != base;
}

/// A label and its number in a row: the number at the right with tabular figures, so a column of them lines up.
class NumberRow extends StatelessWidget {
  const NumberRow(this.label, this.value, {super.key, this.valueKey});
  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = ThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary))),
          Text(
            value,
            key: valueKey,
            style: theme.textTheme.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

/// A count out of a whole as a bar (the dataviz skill's meter): the fill in the accent on its soft step, the numbers
/// beside the label in words.
class Meter extends StatelessWidget {
  const Meter({super.key, required this.label, required this.value, required this.of});
  final String label;
  final int value;
  final int of;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NumberRow(label, '${count(value)} / ${count(of)}'),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.xs),
            child: LinearProgressIndicator(
              value: of == 0 ? 0 : value / of,
              minHeight: Space.s,
              color: t.accent,
              backgroundColor: t.accentSoft,
            ),
          ),
        ],
      ),
    );
  }
}
