import 'dart:math';

import 'package:flutter/material.dart';

import '../design.dart';
import 'lot_card.dart';

/// 求籤's altar, drawn (owner, v9.1.0: 「求签要添加新的动画效果。目前太单调了。比如有个甩签的画面」). Each [round] the
/// 籤筒 tilts forward and is shaken until one stick works its way out and drops to the floor in front of it; then
/// [onShaken]. Given the round's [blocks], the two 筊杯 are thrown and land beside the stick on those faces; then
/// [onThrown]. A new round puts the stick back and shakes again. [settled] (直接看结果) and the system's animations
/// being off show each step's end at once. The rows under the stage say in words what it shows.
class QiuqianStage extends StatefulWidget {
  const QiuqianStage({
    super.key,
    required this.round,
    required this.blocks,
    required this.label,
    required this.onShaken,
    required this.onThrown,
    this.settled = false,
  });

  final int round;

  /// The round's blocks once thrown, 'flat' or 'round' each; null before.
  final List<String>? blocks;

  /// The character on the cylinder's label: 签, or 籤.
  final String label;
  final ValueChanged<int> onShaken;
  final ValueChanged<int> onThrown;
  final bool settled;

  /// The shake, until the stick lies still, and the throw, until both blocks do.
  static const shake = Duration(milliseconds: 1800);
  static const toss = Duration(milliseconds: 1100);

  @override
  State<QiuqianStage> createState() => _QiuqianStageState();
}

class _QiuqianStageState extends State<QiuqianStage> with TickerProviderStateMixin {
  late final _shake = AnimationController(vsync: this, duration: QiuqianStage.shake);
  late final _toss = AnimationController(vsync: this, duration: QiuqianStage.toss);
  var _started = false;

  bool get _still => widget.settled || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _play(_shake, (w, round) => w.onShaken(round));
    if (widget.blocks != null) _play(_toss, (w, round) => w.onThrown(round));
  }

  @override
  void didUpdateWidget(QiuqianStage old) {
    super.didUpdateWidget(old);
    if (widget.settled) {
      if (!old.settled) {
        _shake.value = 1;
        _toss.value = widget.blocks == null ? 0 : 1;
      }
      return;
    }
    if (widget.round != old.round) {
      _toss.value = 0; // the blocks are picked up, the stick goes back
      _play(_shake, (w, round) => w.onShaken(round));
    }
    if (widget.blocks != null && (old.blocks == null || widget.round != old.round)) {
      _play(_toss, (w, round) => w.onThrown(round));
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    _toss.dispose();
    super.dispose();
  }

  /// Plays [step] from its start, or shows its end at once, then tells the page through [done] for this round.
  void _play(AnimationController step, void Function(QiuqianStage widget, int round) done) {
    final round = widget.round;
    if (_still) {
      step.value = 1;
      // Not in the build that brought the step in.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.settled) done(widget, round);
      });
      return;
    }
    step.forward(from: 0).orCancel.then(
      (_) {
        if (mounted) done(widget, round);
      },
      onError: (Object _) {}, // cut short: 直接看结果, or the page closed
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final blocks = widget.blocks;
    // The label's character in the page's own font, as any text on the page.
    final font = DefaultTextStyle.of(context).style;
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) {
          final size = Size(min(box.maxWidth, 320), 176);
          return Center(
            child: SizedBox.fromSize(
              size: size,
              child: AnimatedBuilder(
                animation: Listenable.merge([_shake, _toss]),
                builder: (context, _) {
                  final scene = _Scene(size, _shake.value);
                  final foot = scene.foot;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _FloorPainter(scene, theme.colorScheme.outlineVariant, dark)),
                      ),
                      // The cylinder, turned about its foot.
                      Positioned(
                        left: foot.dx - _Cylinder.width / 2,
                        top: foot.dy - _Cylinder.height,
                        width: _Cylinder.width,
                        height: _Cylinder.height,
                        child: Transform(
                          alignment: Alignment.bottomCenter,
                          transform: Matrix4.rotationZ(scene.tilt),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(child: CustomPaint(painter: _CylinderPainter(scene))),
                              Positioned.fromRect(
                                rect: _Cylinder.label,
                                child: Center(
                                  child: Text(
                                    widget.label,
                                    key: const Key('qiuqian-cylinder-label'),
                                    style: font.copyWith(
                                      color: FaceDown.gold,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned.fill(child: CustomPaint(painter: _FrontPainter(scene, _toss.value, blocks, dark))),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The cylinder's own box: the foot at its bottom centre, the sticks rising out of the mouth above the body.
abstract final class _Cylinder {
  static const width = 64.0, height = 150.0;

  /// The body: its height and its width at the mouth and at the foot.
  static const body = 88.0, top = 54.0, bottom = 46.0;

  /// Half the height of the mouth seen from the front.
  static const lip = 5.5;
  static const mouth = height - body;

  /// The red paper label, halfway down.
  static final label = Rect.fromCenter(center: const Offset(width / 2, mouth + body * 0.52), width: 22, height: 30);
}

/// The sticks in the cylinder: how far each stands out of the mouth. The one in the middle ([_chosen]) works its
/// way out.
const _standOut = [24.0, 33.0, 28.0, 36.0, 30.0, 38.0, 27.0, 32.0, 25.0];
const _chosen = 4;

/// Each stick's length below the mouth, inside the body.
const _inside = 30.0;
const _stickWidth = 4.6;

/// A shake, as fractions of its time: rest, lean forward, shake, the stick drops out as the cylinder rights itself,
/// it lands and bounces once.
const _leanFrom = 0.08, _shakeFrom = 0.2, _out = 0.72, _upright = 0.9, _landed = 0.92;
const _lean = 0.62; // radians, about 35°
const _jerks = 5; // thrusts during the shake

double _part(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

/// Where everything is at [t] (0 → 1) of a shake.
class _Scene {
  _Scene(this.size, this.t);
  final Size size;
  final double t;

  double get floor => size.height - 20;

  /// The shake's own progress, 0 → 1 while it lasts.
  double get _s => _part(t, _shakeFrom, _out);
  bool get _shaking => t > _shakeFrom && t < _out;

  /// The cylinder's lean (clockwise, radians), rocking a little with each thrust.
  double get tilt {
    if (t < _shakeFrom) return _lean * Curves.easeOutCubic.transform(_part(t, _leanFrom, _shakeFrom));
    if (t < _out) return _lean + 0.04 * sin(pi * _jerks * _s);
    return _lean * (1 - Curves.easeInOutCubic.transform(_part(t, _out, _upright)));
  }

  /// How far each thrust pushes the cylinder up along its length.
  double get jolt => _shaking ? 6 * sin(pi * _jerks * _s).abs() : 0;

  /// The cylinder's foot: on the floor, pushed along its length by the thrust.
  Offset get foot => Offset(size.width * 0.3, floor) + Offset(sin(tilt), -cos(tilt)) * jolt;

  /// How far a stick has risen out of its place: the chosen one works its way out, the others rattle.
  double rise(int k) {
    if (k == _chosen) return (_inside + 4) * Curves.easeInCubic.transform(_part(t, 0.28, _out));
    return _shaking ? 2 * sin(pi * _jerks * _s + k * 1.3) : 0;
  }

  /// The chosen stick has left the cylinder.
  bool get out => t >= _out;

  /// The chosen stick, once out: its centre and its angle (clockwise from upright), falling to lie in front.
  (Offset, double) get stick {
    final length = _inside + _standOut[_chosen];
    // As it leaves: upright in the cylinder, its foot at the mouth, turned with the cylinder at full lean.
    final local = Offset(0, -_Cylinder.body - (_inside + 4) + _inside - length / 2);
    final from = Offset(size.width * 0.3, floor) + _turn(local, _lean);
    final to = Offset(size.width * 0.56, floor - _stickWidth / 2 - 1);
    const lying = pi / 2 - 0.04; // flat on the floor, its red top a little up
    final f = _part(t, _out, _landed);
    var centre = Offset(
      from.dx + (to.dx - from.dx) * Curves.easeOutQuad.transform(f),
      from.dy + (to.dy - from.dy) * f * f - 16 * sin(pi * f) * (1 - f),
    );
    var angle = _lean + (lying - _lean) * Curves.easeInQuad.transform(f);
    if (t > _landed) {
      final b = _part(t, _landed, 1);
      centre -= Offset(0, 5 * sin(pi * b) * (1 - b));
      angle += 0.08 * sin(pi * b) * (1 - b);
    }
    return (centre, angle);
  }

  static Offset _turn(Offset p, double angle) =>
      Offset(p.dx * cos(angle) - p.dy * sin(angle), p.dx * sin(angle) + p.dy * cos(angle));
}

/// A stick from its foot [base], [length] long, turned [angle] clockwise from upright: bamboo, its top painted red.
void _paintStick(Canvas canvas, Offset base, double angle, double length) {
  canvas.save();
  canvas.translate(base.dx, base.dy);
  canvas.rotate(angle);
  final body = RRect.fromRectAndRadius(
    Rect.fromLTWH(-_stickWidth / 2, -length, _stickWidth, length),
    const Radius.circular(2),
  );
  canvas.drawRRect(body, Paint()..color = const Color(0xFFE6CB8F));
  canvas.drawRRect(
    body,
    Paint()
      ..color = const Color(0xFF9C7A3F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8,
  );
  canvas.drawRRect(
    RRect.fromRectAndCorners(
      Rect.fromLTWH(-_stickWidth / 2, -length, _stickWidth, 7),
      topLeft: const Radius.circular(2),
      topRight: const Radius.circular(2),
    ),
    Paint()..color = const Color(0xFFB03A2E),
  );
  canvas.restore();
}

/// The floor line and the cylinder's shadow, behind everything.
class _FloorPainter extends CustomPainter {
  _FloorPainter(this.scene, this.line, this.dark);
  final _Scene scene;
  final Color line;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final floor = scene.floor;
    canvas.drawRect(
      Rect.fromLTWH(0, floor, size.width, 1),
      Paint()
        ..shader = LinearGradient(
          colors: [line.withValues(alpha: 0), line, line.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, floor, size.width, 1)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * 0.3, floor + 1), width: 66, height: 9),
      Paint()
        ..color = Colors.black.withValues(alpha: dark ? 0.4 : 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(_FloorPainter old) => true;
}

/// The cylinder in its own box: the dark mouth, the sticks, the body over their feet, its bamboo nodes, label and lip.
class _CylinderPainter extends CustomPainter {
  _CylinderPainter(this.scene);
  final _Scene scene;

  @override
  void paint(Canvas canvas, Size size) {
    const cx = _Cylinder.width / 2;
    const mouthY = _Cylinder.mouth;
    final mouth = Rect.fromCenter(center: const Offset(cx, mouthY), width: _Cylinder.top, height: _Cylinder.lip * 2);
    // The inside: dark wood, not black, so the chosen stick's empty place reads as depth.
    canvas.drawOval(mouth, Paint()..color = const Color(0xFF55361A));
    for (var k = 0; k < _standOut.length; k++) {
      if (k == _chosen && scene.out) continue;
      _paintStick(canvas, Offset(cx + (k - 4) * 5.0, mouthY + _inside - scene.rise(k)), (k - 4) * 0.03, _inside + _standOut[k]);
    }
    const foot = _Cylinder.height;
    final body = Path()
      ..moveTo(cx - _Cylinder.top / 2, mouthY)
      ..lineTo(cx - _Cylinder.bottom / 2, foot - 4)
      ..quadraticBezierTo(cx, foot + 3, cx + _Cylinder.bottom / 2, foot - 4)
      ..lineTo(cx + _Cylinder.top / 2, mouthY)
      ..arcTo(mouth, 0, pi, false)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF5E3A1A), Color(0xFFA8743A), Color(0xFFC99556), Color(0xFF8E5E2C), Color(0xFF5A3717)],
          stops: [0, 0.32, 0.46, 0.74, 1],
        ).createShader(Rect.fromLTRB(cx - _Cylinder.top / 2, mouthY, cx + _Cylinder.top / 2, foot)),
    );
    // Two bamboo nodes, curved with the body.
    for (final at in [0.28, 0.8]) {
      final y = mouthY + _Cylinder.body * at;
      final half = (_Cylinder.top + (_Cylinder.bottom - _Cylinder.top) * at) / 2;
      canvas.drawPath(
        Path()
          ..moveTo(cx - half, y)
          ..quadraticBezierTo(cx, y + 5, cx + half, y),
        Paint()
          ..color = const Color(0xFF4A2C12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
    final label = RRect.fromRectAndRadius(_Cylinder.label, const Radius.circular(3));
    canvas.drawRRect(label, Paint()..color = const Color(0xFFA8382B));
    canvas.drawRRect(
      label,
      Paint()
        ..color = FaceDown.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawOval(
      mouth,
      Paint()
        ..color = const Color(0xFFD8A963)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(_CylinderPainter old) => true;
}

/// In front: the stick that fell, glowing once it lies still, and the two blocks thrown beside it.
class _FrontPainter extends CustomPainter {
  _FrontPainter(this.scene, this.toss, this.blocks, this.dark);
  final _Scene scene;
  final double toss;
  final List<String>? blocks;
  final bool dark;

  static const _block = Size(40, 20);

  @override
  void paint(Canvas canvas, Size size) {
    final floor = scene.floor;
    if (scene.out) {
      final (centre, angle) = scene.stick;
      final length = _inside + _standOut[_chosen];
      final base = centre - Offset(sin(angle), -cos(angle)) * (length / 2);
      if (scene.t >= _landed) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(centre.dx, floor + 1), width: length * 0.9, height: 6),
          Paint()
            ..color = Colors.black.withValues(alpha: dark ? 0.35 : 0.15)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
        // The one that fell: a soft gold glow round it.
        canvas.save();
        canvas.translate(base.dx, base.dy);
        canvas.rotate(angle);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(-4, -length - 2, 8, length + 4), const Radius.circular(4)),
          Paint()
            ..color = FaceDown.gold.withValues(alpha: 0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.restore();
      }
      _paintStick(canvas, base, angle, length);
    }
    final faces = blocks;
    if (faces == null) return;
    for (final (j, face) in faces.indexed) {
      // The second leaves the hand a moment after the first.
      final u = _part(toss, 0.06 * j, 0.94 + 0.06 * j);
      final fly = _part(u, 0, 0.82);
      final start = Offset(size.width * (0.52 + 0.05 * j), size.height + 24);
      final land = Offset(size.width * (0.74 + 0.15 * j), floor - _block.height / 2);
      const top = 16.0;
      final lift = (start.dy + land.dy) / 2 - top;
      var y = start.dy + (land.dy - start.dy) * fly - lift * 4 * fly * (1 - fly);
      if (u > 0.82) y -= 6 * sin(pi * _part(u, 0.82, 1));
      final x = start.dx + (land.dx - start.dx) * fly;
      // Over and over in the air: six half-turns end on the face it lands on.
      final flip = pi * 6 * Curves.easeOutCubic.transform(fly);
      final shown = ((flip + pi / 2) / pi).floor().isEven ? face : (face == 'flat' ? 'round' : 'flat');
      final rest = j == 0 ? -0.1 : 0.16;
      final spin = rest + (1 - Curves.easeOutCubic.transform(fly)) * (j == 0 ? 3.2 : -2.6);
      final near = (1 - (land.dy - y) / (land.dy - top)).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, floor + 1), width: 34 * (0.4 + 0.6 * near), height: 5),
        Paint()
          ..color = Colors.black.withValues(alpha: (dark ? 0.35 : 0.16) * near)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(spin);
      canvas.scale(1, max(cos(flip).abs(), 0.12));
      canvas.translate(-_block.width / 2, -_block.height / 2);
      JiaobeiPainter(flat: shown == 'flat', dark: dark).paint(canvas, _block);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FrontPainter old) => true;
}
