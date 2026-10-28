import 'dart:math';

import 'package:flutter/material.dart';

import '../design.dart';

/// 算卦's coin (owner, v6.1.0): a 銅錢, round with a square hole, in bronze. 字, the side with the inscription,
/// reads 乾隆通寶 round the hole (top, bottom, right, left, as a 通寶 is read); 背 is plain. [face] is `'zi'`,
/// `'bei'`, or null for a coin still covered: face down in the colours of a tarot card's back ([FaceDown]).
///
/// When [face] arrives the coin turns over as a tarot card does (tarot_spread.dart): half a turn, after [delay], so
/// a reveal can turn the coins one after another. With [toss] it is thrown instead: it rises and spins from its
/// other face through five half-turns, landing on [face]. With the system's animations off it shows [face] at once.
/// The side on show is keyed `coin-side-zi`, `coin-side-bei` or `coin-side-cover`.
class CopperCoin extends StatelessWidget {
  const CopperCoin({
    super.key,
    required this.face,
    this.size = 44,
    this.toss = false,
    this.delay = Duration.zero,
    this.number,
    this.glow = false,
  });

  final String? face;
  final double size;
  final bool toss;
  final Duration delay;

  /// The pick's number: large on the cover, moving to a corner badge as the coin turns over.
  final int? number;

  /// A gold glow on the cover, as on the tarot card to turn next (a picked coin).
  final bool glow;

  /// A tarot card's turn, and a toss's longer spin.
  static const turn = Duration(milliseconds: 500);
  static const spin = Duration(milliseconds: 900);

  @override
  Widget build(BuildContext context) {
    final to = _Side.of(face);
    final from = toss ? (to == _Side.zi ? _Side.bei : _Side.zi) : _Side.cover;
    final halfTurns = toss ? 5 : 1;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final total = still ? Duration.zero : delay + (toss ? spin : turn);
    final start = total == Duration.zero ? 0.0 : delay.inMicroseconds / total.inMicroseconds;
    // The inscription in the app's own font, as any text on the page.
    final font = DefaultTextStyle.of(context).style;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: face == null ? 0 : 1),
      duration: total,
      curve: Interval(start, 1, curve: toss ? Curves.easeOutCubic : Curves.easeInOut),
      builder: (context, v, _) {
        final angle = pi * halfTurns * v;
        // Each half-turn brings the other side round; that side is drawn mirrored back so it reads right.
        final over = ((angle + pi / 2) / pi).floor().isOdd;
        final side = over ? to : from;
        final drawn = CustomPaint(
          key: ValueKey<String>('coin-side-${side.name}'),
          size: Size.square(size),
          painter: _CoinPainter(side, font, glow: glow && side == _Side.cover),
        );
        final coin = Transform.translate(
          // A thrown coin rises and falls back as it spins.
          offset: Offset(0, toss ? -size * 0.25 * sin(pi * v) : 0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: over
                ? Transform(alignment: Alignment.center, transform: Matrix4.rotationY(pi), child: drawn)
                : drawn,
          ),
        );
        final n = number;
        if (n == null) return coin;
        return SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              coin,
              Align(
                alignment: Alignment.lerp(Alignment.center, const Alignment(-1.3, -1.3), v)!,
                child: Container(
                  width: size * (0.66 - 0.2 * v),
                  height: size * (0.66 - 0.2 * v),
                  alignment: Alignment.center,
                  padding: EdgeInsets.all(size * 0.04),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: FaceDown.navy.withValues(alpha: v),
                    border: Border.all(color: FaceDown.gold.withValues(alpha: v)),
                  ),
                  // Two digits (10–18) stay on one line: smaller rather than wrapped.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$n',
                      maxLines: 1,
                      style: TextStyle(
                        color: FaceDown.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: size * (0.36 - 0.1 * v),
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _Side {
  zi,
  bei,
  cover;

  static _Side of(String? face) => switch (face) {
    'zi' => zi,
    'bei' => bei,
    _ => cover,
  };
}

// Bronze lit from the upper left, its rims (郭) a shade darker, the inscription darker still.
const _bronzeLight = Color(0xFFEBCB8B);
const _bronze = Color(0xFFC4924A);
const _bronzeDark = Color(0xFF7D5426);
const _ink = Color(0xFF5C3B17);

/// 字's inscription and where each character sits: 乾 above the hole, 隆 below, 通 right, 寶 left.
const _inscription = [('乾', Offset(0, -1)), ('隆', Offset(0, 1)), ('通', Offset(1, 0)), ('寶', Offset(-1, 0))];

class _CoinPainter extends CustomPainter {
  _CoinPainter(this.side, this.font, {this.glow = false});
  final _Side side;

  /// The page's text style, for its font.
  final TextStyle font;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    final disc = Rect.fromCircle(center: c, radius: r);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08;
    if (glow) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = FaceDown.gold.withValues(alpha: 0.8)
          ..maskFilter = MaskFilter.blur(BlurStyle.outer, r * 0.3),
      );
    }
    if (side == _Side.cover) {
      // Covered: a token in the tarot back's colours, a gold edge and a gold ring inside it.
      canvas.drawCircle(
        c,
        r,
        Paint()..shader = const RadialGradient(colors: [FaceDown.navyLight, FaceDown.navy]).createShader(disc),
      );
      canvas.drawCircle(c, r - rim.strokeWidth / 2, rim..color = FaceDown.gold);
      canvas.drawCircle(
        c,
        r * 0.72,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.04
          ..color = FaceDown.gold.withValues(alpha: 0.6),
      );
      return;
    }
    // The coin, with its square hole cut through.
    final hole = Rect.fromCenter(center: c, width: r * 0.5, height: r * 0.5);
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(disc)
        ..addRect(hole),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          radius: 1.1,
          colors: [_bronzeLight, _bronze, _bronzeDark],
          stops: [0, 0.55, 1],
        ).createShader(disc),
    );
    rim.color = _bronzeDark;
    canvas.drawCircle(c, r - rim.strokeWidth / 2, rim);
    canvas.drawRect(hole.inflate(rim.strokeWidth / 2), rim);
    if (side != _Side.zi) return; // 背: plain
    for (final (ch, at) in _inscription) {
      final text = TextPainter(
        text: TextSpan(
          text: ch,
          style: TextStyle(
            color: _ink,
            fontFamily: font.fontFamily,
            fontFamilyFallback: font.fontFamilyFallback,
            fontSize: r * 0.42,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, c + at * (r * 0.62) - Offset(text.width / 2, text.height / 2));
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(_CoinPainter old) => old.side != side || old.glow != glow || old.font != font;
}
