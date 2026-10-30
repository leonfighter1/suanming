import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mingli_app/presentation/design.dart';

/// One figure on 概览: what it is, the number, and a line of detail (管理后台, tech plan S22).
class KpiTile extends StatelessWidget {
  const KpiTile({super.key, required this.label, required this.value, this.detail, this.icon, this.tone});
  final String label;
  final String value;
  final String? detail;
  final IconData? icon;

  /// The value's colour (a loss in the error colour); default the primary.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(Space.l),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(Radii.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: scheme.onSurfaceVariant), const SizedBox(width: Space.xs)],
              Expanded(child: Text(label, style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant))),
            ],
          ),
          const SizedBox(height: Space.xs),
          // A long figure shrinks rather than wraps.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              key: ValueKey<String>('kpi-$label'),
              style: theme.textTheme.headlineSmall?.copyWith(color: tone ?? scheme.primary, fontWeight: FontWeight.w700),
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: Space.xs),
            Text(detail!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

/// Tiles in even columns: as many as fit at [minWidth] or wider, up to [maxColumns]; two on a phone.
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.children, this.minWidth = 150, this.maxColumns = 4});
  final List<Widget> children;
  final double minWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          const gap = Space.m;
          final columns = math.min(maxColumns, math.max(1, ((box.maxWidth + gap) / (minWidth + gap)).floor()));
          final width = (box.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [for (final c in children) SizedBox(width: width, child: c)],
          );
        },
      );
}
