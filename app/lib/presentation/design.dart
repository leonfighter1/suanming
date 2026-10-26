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

/// The one card style: soft surface, hairline border, generous padding, an
/// optional header row. Content size changes animate.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.color,
    this.padding = const EdgeInsets.all(Space.l + 4),
    this.onTap,
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Color? color;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.m),
      child: Material(
        color: color ?? scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            padding: padding,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null) ...[
                    Row(
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 20, color: scheme.primary),
                          const SizedBox(width: Space.s),
                        ],
                        Expanded(child: Text(title!, style: theme.textTheme.titleMedium)),
                        ?trailing,
                      ],
                    ),
                    const SizedBox(height: Space.m),
                  ],
                  child,
                ],
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
  const Pill(this.text, {super.key, this.color, this.icon});
  final String text;
  final Color? color;
  final IconData? icon;

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
          Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
