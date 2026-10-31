import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringSimulation;

import '../design.dart';

// 弹性开关 (S30; owner, 2026-10-30: 「开关切换时，圆点在移动过程中横向拉长成胶囊形，到达终点后再恢复为圆形，带轻微回弹」).
// The switch's own geometry, Material 3's: a track 52 × 32, the thumb 16 across when off and 24 when on, a 2-point
// outline round the track when off.
const _trackWidth = 52.0;
const _trackHeight = 32.0;
const _thumbOff = 16.0;
const _thumbOn = 24.0;
const _outline = 2.0;

/// How much longer the thumb grows for each unit of speed (the way across a second), and the most it grows: a capsule
/// up to 1.6 times its width at the fastest.
const _stretchPerSpeed = 0.05;
const _stretchMost = 0.6;

/// A switch whose thumb stretches into a capsule as it travels, the more the faster, and comes to rest round after a
/// slight rebound ([Motion.switchSpring]). Material 3's look and colours. It is not focusable itself: [AppSwitchTile]
/// is the control (a tap on the row, Enter, Space), and this tells screen readers it is on or off. Reduce motion: it
/// jumps.
class ElasticSwitch extends StatefulWidget {
  const ElasticSwitch({super.key, required this.value, this.enabled = true});
  final bool value;
  final bool enabled;

  @override
  State<ElasticSwitch> createState() => _ElasticSwitchState();
}

class _ElasticSwitchState extends State<ElasticSwitch> with SingleTickerProviderStateMixin {
  /// 0 off, 1 on; a little past either end while it rebounds.
  late final _position = AnimationController.unbounded(vsync: this, value: widget.value ? 1 : 0);

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ElasticSwitch old) {
    super.didUpdateWidget(old);
    if (old.value == widget.value) return;
    final target = widget.value ? 1.0 : 0.0;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _position.value = target;
      return;
    }
    _position
        .animateWith(SpringSimulation(Motion.switchSpring, _position.value, target, _position.velocity))
        .whenComplete(() {
      // The spring stops within its tolerance: rest exactly at the end, round.
      if (mounted && widget.value == (target == 1)) _position.value = target;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      toggled: widget.value,
      enabled: widget.enabled,
      child: Opacity(
        // Material's disabled look.
        opacity: widget.enabled ? 1 : 0.38,
        child: AnimatedBuilder(
          animation: _position,
          builder: (context, _) => CustomPaint(
            size: const Size(_trackWidth, _trackHeight),
            painter: ElasticPainter(
              position: _position.value,
              speed: _position.isAnimating ? _position.velocity.abs() : 0,
              trackOn: scheme.primary,
              trackOff: scheme.surfaceContainerHighest,
              outline: scheme.outline,
              thumbOn: scheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The switch's drawing: public so a test can read where the thumb is and how stretched.
@visibleForTesting
class ElasticPainter extends CustomPainter {
  const ElasticPainter({
    required this.position,
    required this.speed,
    required this.trackOn,
    required this.trackOff,
    required this.outline,
    required this.thumbOn,
  });
  final double position;
  final double speed;
  final Color trackOn;
  final Color trackOff;
  final Color outline;
  final Color thumbOn;

  /// How long the thumb is for its height at [speed]: 1 at rest (round), up to 1 + [_stretchMost] at the fastest.
  static double stretchAt(double speed) => 1 + math.min(_stretchMost, speed * _stretchPerSpeed);

  @override
  void paint(Canvas canvas, Size size) {
    final on = position.clamp(0.0, 1.0);
    final track = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(_trackHeight / 2));
    canvas.drawRRect(track, Paint()..color = Color.lerp(trackOff, trackOn, on)!);
    if (on < 1) {
      canvas.drawRRect(
        track.deflate(_outline / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _outline
          ..color = outline.withValues(alpha: outline.a * (1 - on)),
      );
    }
    final height = _thumbOff + (_thumbOn - _thumbOff) * on;
    final width = height * stretchAt(speed);
    // The thumb's centre travels between the track's two round ends, a little past them while it rebounds.
    final x = _trackHeight / 2 + (_trackWidth - _trackHeight) * position;
    final thumb = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, size.height / 2), width: width, height: height),
      Radius.circular(height / 2),
    );
    canvas.drawRRect(thumb, Paint()..color = Color.lerp(outline, thumbOn, on)!);
  }

  @override
  bool shouldRepaint(ElasticPainter old) =>
      old.position != position ||
      old.speed != speed ||
      old.trackOn != trackOn ||
      old.trackOff != trackOff ||
      old.outline != outline ||
      old.thumbOn != thumbOn;
}

/// A switch with its words, as Material's SwitchListTile: the row is the control (a tap anywhere on it, Enter or
/// Space toggles it; one Tab stop), and its switch is an [ElasticSwitch].
class AppSwitchTile extends StatelessWidget {
  const AppSwitchTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.contentPadding,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: ListTile(
          contentPadding: contentPadding,
          enabled: onChanged != null,
          title: title,
          subtitle: subtitle,
          trailing: ElasticSwitch(value: value, enabled: onChanged != null),
          onTap: onChanged == null ? null : () => onChanged!(!value),
        ),
      );
}
