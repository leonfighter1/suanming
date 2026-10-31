import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../content_text.dart';
import '../design.dart';
import '../keyboard.dart';
import '../labels.dart';
import '../tokens.dart';

/// Series colours: one fixed slot per entity (the theme's series, ThemeTokens.series), so a series keeps its colour
/// whatever the filter shows.
const _seriesOrder = ['overall', 'wuxing', 'personality', 'career_wealth', 'relationships', 'dayun_liunian', 'health'];

Color seriesColor(BuildContext context, String key) =>
    ThemeTokens.of(context).series[math.max(0, _seriesOrder.indexOf(key))];

/// Report header: 運勢走勢 by age (大運) or by year (流年), per topic or combined,
/// with the total score. Tap a period for its scores and the reason.
class TrendCard extends StatefulWidget {
  const TrendCard({super.key, required this.trend, this.nowYear});
  final TrendLayer trend;

  /// The year to select first (defaults to this year).
  final int? nowYear;

  @override
  State<TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<TrendCard> {
  bool _byYear = false;
  final Set<String> _series = {'overall'};
  int? _selected;

  List<TrendPoint> get _points => _byYear ? widget.trend.liunian : widget.trend.dayun;

  int _defaultIndex() {
    final y = widget.nowYear ?? DateTime.now().year;
    final i = _points.indexWhere((p) => p.covers(y));
    return i < 0 ? 0 : i;
  }

  int _value(TrendPoint p, String key) => key == 'overall' ? p.overall : (p.scores[key] ?? 0);

  void _toggle(String key) => setState(() {
        if (_series.contains(key)) {
          if (_series.length > 1) _series.remove(key);
        } else {
          _series.add(key);
        }
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final points = _points;
    final sel = math.min(math.max(_selected ?? _defaultIndex(), 0), math.max(0, points.length - 1));
    final keys = ['overall', ...widget.trend.topics];
    String label(String k) => k == 'overall' ? l10n.trendCombined : l10n.topic(k);
    final shown = keys.where(_series.contains).toList();

    return AppCard(
      key: const Key('trend-card'),
      title: l10n.trendTitle,
      icon: Icons.show_chart,
      trailing: _TotalBadge(total: widget.trend.total, label: l10n.trendTotal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentKeys(
            child: SegmentedButton<bool>(
              key: const Key('trend-mode'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text(l10n.trendDayun)),
                ButtonSegment(value: true, label: Text(l10n.trendLiunian)),
              ],
              selected: {_byYear},
              onSelectionChanged: (s) => setState(() {
                _byYear = s.first;
                _selected = null;
              }),
            ),
          ),
          const SizedBox(height: Space.m),
          // Filters: 綜合 or any topics, several at once to compare. They double as the legend.
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              for (final k in keys)
                FilterChip(
                  key: Key('trend-series-$k'),
                  avatar: CircleAvatar(backgroundColor: seriesColor(context, k), radius: 6),
                  label: Text(label(k)),
                  selected: _series.contains(k),
                  showCheckmark: false,
                  onSelected: (_) => _toggle(k),
                ),
            ],
          ),
          const SizedBox(height: Space.m),
          if (points.isNotEmpty)
            LayoutBuilder(
              builder: (context, box) => Pressable(
                key: const Key('trend-plot'),
                label: '${l10n.trendTitle} · ${_byYear ? '${points[sel].year}' : points[sel].label}',
                // Tab to the chart: ←/→ step through the periods, Home/End jump to either end.
                keys: {
                  const SingleActivator(LogicalKeyboardKey.arrowLeft): () => setState(() => _selected = math.max(0, sel - 1)),
                  const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                      setState(() => _selected = math.min(points.length - 1, sel + 1)),
                  const SingleActivator(LogicalKeyboardKey.home): () => setState(() => _selected = 0),
                  const SingleActivator(LogicalKeyboardKey.end): () => setState(() => _selected = points.length - 1),
                },
                onTapDown: (d) {
                  final plotW = box.maxWidth - _TrendPainter.leftPad;
                  final step = plotW / points.length;
                  final i = ((d.localPosition.dx - _TrendPainter.leftPad) / step).floor();
                  setState(() => _selected = i.clamp(0, points.length - 1));
                },
                child: CustomPaint(
                  size: Size(box.maxWidth, 220),
                  painter: _TrendPainter(
                    labels: [for (final p in points) _byYear ? '${p.year! % 100}'.padLeft(2, '0') : p.label],
                    series: [
                      for (final k in shown) (color: seriesColor(context, k), values: [for (final p in points) _value(p, k)], bold: k == 'overall'),
                    ],
                    selected: sel,
                    grid: scheme.outlineVariant,
                    ink: scheme.onSurfaceVariant,
                    surface: theme.cardColor,
                    // The ramp's smallest, in the page's own font (rule 50).
                    tick: theme.textTheme.labelSmall!.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),
          if (points.isNotEmpty) ...[
            const SizedBox(height: Space.m),
            _Detail(point: points[sel], byYear: _byYear, keys: keys, label: label, value: _value),
          ],
          const SizedBox(height: Space.s),
          ContentText(
            l10n.trendTapHint,
            contentKey: 'trendTapHint',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Space.xs),
          Text(
            widget.trend.methodNote,
            key: const Key('trend-method'),
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _TotalBadge extends StatelessWidget {
  const _TotalBadge({required this.total, required this.label});
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      key: const Key('trend-total'),
      padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.xs),
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(Radii.chip)),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$label '),
          TextSpan(text: '$total', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer)),
          const TextSpan(text: ' /100'),
        ]),
        style: text.labelMedium?.copyWith(color: scheme.onPrimaryContainer),
      ),
    );
  }
}

/// The selected period: its 干支, every score (table view of the chart) and the reason.
class _Detail extends StatelessWidget {
  const _Detail({required this.point, required this.byYear, required this.keys, required this.label, required this.value});
  final TrendPoint point;
  final bool byYear;
  final List<String> keys;
  final String Function(String) label;
  final int Function(TrendPoint, String) value;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final head = byYear
        ? '${point.year} ${point.ganzhi}'
        : '${point.ganzhi} · ${l10n.trendAge(point.label)}${point.startYear == null ? '' : ' · ${point.startYear}–${point.startYear! + 9}'}';
    return Container(
      key: const Key('trend-detail'),
      width: double.infinity,
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(Radii.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(head, style: theme.textTheme.titleSmall),
          const SizedBox(height: Space.s),
          Wrap(
            spacing: Space.m,
            runSpacing: Space.xs,
            children: [
              for (final k in keys)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: seriesColor(context, k), shape: BoxShape.circle)),
                    const SizedBox(width: Space.xs),
                    Text('${label(k)} ${value(point, k)}', style: theme.textTheme.bodyMedium),
                  ],
                ),
            ],
          ),
          const SizedBox(height: Space.s),
          Text(point.note, textAlign: TextAlign.start, style: ReadingText.small(context)),
        ],
      ),
    );
  }
}

typedef _Series = ({Color color, List<int> values, bool bold});

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.labels,
    required this.series,
    required this.selected,
    required this.grid,
    required this.ink,
    required this.surface,
    required this.tick,
  });

  static const leftPad = 28.0;
  static const bottomPad = 22.0;
  static const topPad = 8.0;

  final List<String> labels;
  final List<_Series> series;
  final int selected;
  final Color grid;
  final Color ink;
  final Color surface;

  /// The axis's labels: the type ramp's label small.
  final TextStyle tick;

  @override
  void paint(Canvas canvas, Size size) {
    final plotW = size.width - leftPad;
    final plotH = size.height - bottomPad - topPad;
    final step = plotW / labels.length;
    double x(int i) => leftPad + step * (i + 0.5);
    double y(int v) => topPad + plotH * (1 - v / 100);
    final textStyle = tick;

    void text(String s, Offset at, {bool center = false}) {
      final tp = TextPainter(text: TextSpan(text: s, style: textStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, at - Offset(center ? tp.width / 2 : tp.width, tp.height / 2));
    }

    // Recessive grid: 0, 50 (steady, dashed), 100.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in [0, 100]) {
      canvas.drawLine(Offset(leftPad, y(v)), Offset(size.width, y(v)), gridPaint);
      text('$v', Offset(leftPad - 4, y(v)));
    }
    for (var dx = leftPad; dx < size.width; dx += 8) {
      canvas.drawLine(Offset(dx, y(50)), Offset(math.min(dx + 4, size.width), y(50)), gridPaint);
    }
    text('50', Offset(leftPad - 4, y(50)));

    // Crosshair on the selected period.
    canvas.drawLine(
      Offset(x(selected), topPad),
      Offset(x(selected), topPad + plotH),
      Paint()
        ..color = ink.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );

    for (var i = 0; i < labels.length; i++) {
      text(labels[i], Offset(x(i), size.height - bottomPad / 2), center: true);
    }

    for (final s in series) {
      final line = Paint()
        ..color = s.color
        ..strokeWidth = s.bold ? 3 : 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      final path = Path();
      for (var i = 0; i < s.values.length; i++) {
        final p = Offset(x(i), y(s.values[i]));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, line);
      for (var i = 0; i < s.values.length; i++) {
        final p = Offset(x(i), y(s.values[i]));
        final r = i == selected ? 5.0 : 3.5;
        // Surface ring keeps overlapping markers apart.
        canvas.drawCircle(p, r + 2, Paint()..color = surface);
        canvas.drawCircle(p, r, Paint()..color = s.color);
      }
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.selected != selected ||
      old.labels != labels ||
      old.series != series ||
      old.grid != grid ||
      old.ink != ink ||
      old.tick != tick;
}
