import 'dart:math';

import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../design.dart';
import '../theme.dart';

/// 首页's title (owner, v9.1.0: 「命理大师的text可以添加一些效果，比如前置一个svg的decor」): the app's mark, then the
/// name in bold, spaced out, shading from 赭红 to gold. The mark is drawn, as an SVG would be, so it stays sharp at
/// any size and takes the theme's colours.
class AppTitle extends StatelessWidget {
  const AppTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final shade = [theme.colorScheme.primary, dark ? FaceDown.gold : AppColors.earth];
    // The bar's own title style (titleLarge), bolder and spaced out.
    final style = DefaultTextStyle.of(context).style.copyWith(fontWeight: FontWeight.w700, letterSpacing: 3);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ExcludeSemantics(child: BaguaMark(key: Key('title-mark'), size: 34)),
        const SizedBox(width: Space.s + 2),
        Flexible(
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(colors: shade).createShader(bounds),
            child: Text(l10n.appTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
          ),
        ),
      ],
    );
  }
}

/// The app's mark, as on its icon (scripts/app-icons.ts): the 太极 inside the 先天八卦, here without the icon's
/// ground and in the theme's colours. The trigrams sit clockwise from 乾 at the top, as on the icon, and their lines
/// are thicker for the small size.
class BaguaMark extends StatelessWidget {
  const BaguaMark({super.key, this.size = 34});
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(
        // On the light bar the dark half and the trigrams in 赭红; on a dark one the trigrams in gold.
        yin: dark ? const Color(0xFF5C1F16) : AppColors.accent,
        lines: dark ? FaceDown.gold : AppColors.accent,
      ),
    );
  }
}

/// 先天八卦 from 乾 at the top, clockwise, each from its bottom line (nearest the centre) out; 1 is a yang line. The
/// same order as TRIGRAMS in scripts/app-icons.ts.
const _trigrams = [
  [1, 1, 1], // 乾
  [0, 1, 1], // 巽
  [0, 1, 0], // 坎
  [0, 0, 1], // 艮
  [0, 0, 0], // 坤
  [1, 0, 0], // 震
  [1, 0, 1], // 离
  [1, 1, 0], // 兑
];

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.yin, required this.lines});
  final Color yin;
  final Color lines;

  static const _goldLight = Color(0xFFF0CF7E);
  static const _goldDeep = Color(0xFFC8973B);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    final gold = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_goldLight, _goldDeep],
      ).createShader(Offset.zero & size);

    // The ring round it all.
    canvas.drawCircle(
      c,
      r * 0.955,
      Paint()
        ..shader = gold.shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06,
    );

    // The trigrams: each drawn at the top, then turned to its place.
    final bar = Paint()..color = lines;
    final thick = r * 0.09;
    for (final (i, trigram) in _trigrams.indexed) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i * pi / 4);
      for (final (j, yang) in trigram.indexed) {
        final radius = r * (0.56 + 0.14 * j);
        final length = radius * 0.62;
        final top = -radius - thick / 2;
        RRect piece(double left, double width) =>
            RRect.fromRectAndRadius(Rect.fromLTWH(left, top, width, thick), Radius.circular(thick / 3));
        if (yang == 1) {
          canvas.drawRRect(piece(-length / 2, length), bar);
        } else {
          final half = length * 0.39;
          canvas.drawRRect(piece(-length / 2, half), bar);
          canvas.drawRRect(piece(length / 2 - half, half), bar);
        }
      }
      canvas.restore();
    }

    // The 太极: yang (gold) on the left with its head at the top, as on the icon.
    final t = r * 0.40;
    canvas.drawCircle(c, t, Paint()..color = yin);
    final yang = Path()
      ..moveTo(c.dx, c.dy - t)
      ..arcToPoint(Offset(c.dx, c.dy + t), radius: Radius.circular(t), clockwise: false)
      ..arcToPoint(c, radius: Radius.circular(t / 2))
      ..arcToPoint(Offset(c.dx, c.dy - t), radius: Radius.circular(t / 2), clockwise: false)
      ..close();
    canvas.drawPath(yang, gold);
    canvas.drawCircle(Offset(c.dx, c.dy - t / 2), t / 5, Paint()..color = yin);
    canvas.drawCircle(Offset(c.dx, c.dy + t / 2), t / 5, gold);
    // An edge in the dark colour, so the gold half keeps its shape on a light bar.
    canvas.drawCircle(
      c,
      t,
      Paint()
        ..color = yin
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.yin != yin || old.lines != lines;
}
