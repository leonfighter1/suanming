import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/keyboard.dart';

/// One line: its name, its colour and a value for each day.
class ChartSeries {
  const ChartSeries(this.label, this.color, this.values);
  final String label;
  final Color color;
  final List<double> values;
}

/// The lines' colours, in this fixed order: the dataviz skill's reference palette, whose first three slots stay
/// apart for colour-blind readers too (checked with its validator on the app's surfaces, light and dark). A light
/// aqua line is below 3:1 on the surface: the legend, the picked day's numbers and the 收益 page's daily table carry it.
List<Color> seriesColors(Brightness b) => b == Brightness.dark
    ? const [Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70)]
    : const [Color(0xFF2A78D6), Color(0xFFEB6834), Color(0xFF1BAF7A)];

String _plain(double v) => v.toStringAsFixed(0);

/// The axis's step: about a quarter of [span], rounded to 1, 2 or 5 times a power of ten (and at least 1), so the
/// axis reads 0, 50, 100 rather than 36, 87, 139.
double niceStep(double span) {
  final raw = span / 4;
  if (raw <= 1) return 1;
  final p = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final f = raw / p;
  return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * p;
}

/// Lines over the same days (管理后台, tech plan S22: the revenue curve, the tokens). Pointing at it, a tap, or ←/→
/// (Home, End) while it has the focus picks a day; its values show under the chart. [repaintKey] holds the chart's own
/// picture, for a PNG export.
class LineChart extends StatefulWidget {
  const LineChart({
    super.key,
    required this.labels,
    required this.series,
    this.format = _plain,
    this.readout,
    this.height = 240,
    this.repaintKey,
  });

  /// The days, YYYY-MM-DD.
  final List<String> labels;
  final List<ChartSeries> series;

  /// The axis's numbers; [readout] the picked day's (default the same).
  final String Function(double) format;
  final String Function(double)? readout;
  final double height;
  final GlobalKey? repaintKey;

  @override
  State<LineChart> createState() => _LineChartState();
}

class _LineChartState extends State<LineChart> {
  int? _picked;

  int get _last => widget.labels.length - 1;

  void _pick(int i) {
    if (widget.labels.isEmpty) return;
    setState(() => _picked = i.clamp(0, _last));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = widget.labels.length;
    final picked = _picked == null || n == 0 ? null : math.min(_picked!, _last);
    final text = DefaultTextStyle.of(context).style.copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant);
    final legend = Wrap(
      spacing: Space.l,
      runSpacing: Space.xs,
      children: [
        for (final s in widget.series)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 14, height: 3, color: s.color),
              const SizedBox(width: Space.xs),
              Text(s.label, style: theme.textTheme.labelMedium),
            ],
          ),
      ],
    );
    final plot = LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        void at(Offset p) {
          if (n == 0) return;
          final plot = width - _ChartPainter.left - _ChartPainter.right;
          final x = (p.dx - _ChartPainter.left) / math.max(plot, 1);
          _pick(n == 1 ? 0 : (x * (n - 1)).round());
        }

        return Pressable(
          key: const Key('chart'),
          label: '曲线：左右方向键选日期',
          keys: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _pick((picked ?? n) - 1),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () => _pick((picked ?? -1) + 1),
            const SingleActivator(LogicalKeyboardKey.home): () => _pick(0),
            const SingleActivator(LogicalKeyboardKey.end): () => _pick(_last),
          },
          onTapDown: (d) => at(d.localPosition),
          child: MouseRegion(
            onHover: (e) => at(e.localPosition),
            child: CustomPaint(
              size: Size(width, widget.height),
              painter: _ChartPainter(
                labels: widget.labels,
                series: widget.series,
                format: widget.format,
                picked: picked,
                text: text,
                grid: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
        );
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The legend and the lines, on the card's colour: the picture a PNG export saves.
        RepaintBoundary(
          key: widget.repaintKey,
          child: ColoredBox(
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [legend, const SizedBox(height: Space.s), plot],
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.s),
        Text(
          picked == null
              ? '点一下曲线，或用左右方向键，看某一天的数字'
              : [
                  widget.labels[picked],
                  for (final s in widget.series) '${s.label} ${(widget.readout ?? widget.format)(s.values[picked])}',
                ].join(' · '),
          key: const Key('chart-picked'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.labels,
    required this.series,
    required this.format,
    required this.picked,
    required this.text,
    required this.grid,
  });

  static const left = 64.0;
  static const right = 12.0;
  static const top = 8.0;
  static const bottom = 22.0;

  final List<String> labels;
  final List<ChartSeries> series;
  final String Function(double) format;
  final int? picked;
  final TextStyle text;
  final Color grid;

  void _label(Canvas canvas, String s, Offset at, {bool right = false, bool center = false}) {
    final tp = TextPainter(text: TextSpan(text: s, style: text), textDirection: TextDirection.ltr)..layout();
    final dx = right ? at.dx - tp.width : (center ? at.dx - tp.width / 2 : at.dx);
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = labels.length;
    final plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final values = [for (final s in series) ...s.values];
    var lo = values.isEmpty ? 0.0 : math.min(0.0, values.reduce(math.min));
    var hi = values.isEmpty ? 0.0 : math.max(0.0, values.reduce(math.max));
    final step = niceStep(hi - lo);
    lo = (lo / step).floor() * step;
    hi = math.max((hi / step).ceil() * step, lo + step);
    double y(double v) => plot.bottom - (v - lo) / (hi - lo) * plot.height;
    double x(int i) => n <= 1 ? plot.center.dx : plot.left + i * plot.width / (n - 1);

    final line = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var k = 0; lo + k * step <= hi + step / 2; k++) {
      final v = lo + k * step;
      canvas.drawLine(Offset(plot.left, y(v)), Offset(plot.right, y(v)), line);
      _label(canvas, format(v), Offset(plot.left - 6, y(v)), right: true);
    }
    if (lo < 0) {
      canvas.drawLine(Offset(plot.left, y(0)), Offset(plot.right, y(0)), line..strokeWidth = 1.6);
    }
    if (n > 0) {
      for (final i in {0, n ~/ 2, n - 1}) {
        _label(canvas, labels[i].length >= 10 ? labels[i].substring(5) : labels[i], Offset(x(i), plot.bottom + bottom / 2 + 2), center: true);
      }
    }
    if (picked != null) {
      canvas.drawLine(Offset(x(picked!), plot.top), Offset(x(picked!), plot.bottom), Paint()
        ..color = grid
        ..strokeWidth = 2);
    }
    for (final s in series) {
      if (s.values.isEmpty) continue;
      final path = Path()..moveTo(x(0), y(s.values[0]));
      for (var i = 1; i < s.values.length; i++) {
        path.lineTo(x(i), y(s.values[i]));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
      if (picked != null && picked! < s.values.length) {
        canvas.drawCircle(Offset(x(picked!), y(s.values[picked!])), 4, Paint()..color = s.color);
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.labels != labels || old.series != series || old.picked != picked || old.text != text;
}
