import 'package:flutter/material.dart';

import '../../domain/life_report.dart';
import '../design.dart';
import 'life_blocks.dart';
import 'trend_chart.dart' show seriesColor;

/// One topic of 分项运势: its title, summary and points.
class LifeTopicBlock extends StatelessWidget {
  const LifeTopicBlock({super.key, required this.title, required this.topic});
  final String title;
  final LifeTopic topic;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: Key('life-topic-${topic.key}'),
      padding: const EdgeInsets.only(top: Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: Space.xs),
          Text(topic.summary, style: ReadingText.body(context)?.copyWith(fontWeight: FontWeight.w700)),
          for (final (period, text) in topic.points) period.isEmpty ? LifeBullet(text) : LifeLabeled(period, text),
        ],
      ),
    );
  }
}

/// Bars per 大运 (score 0–100); the best period highlighted.
class StageChart extends StatelessWidget {
  const StageChart({super.key, required this.stages});
  final List<LifeStage> stages;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final best = stages.isEmpty ? 0 : stages.map((s) => s.score).reduce((a, b) => a > b ? a : b);
    final color = seriesColor(context, 'overall');
    return SizedBox(
      key: const Key('life-stage-chart'),
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final s in stages)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${s.score}', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: Space.xxs),
                    Container(
                      height: 110 * s.score / 100,
                      decoration: BoxDecoration(
                        color: s.score == best ? scheme.tertiary : color,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xs)),
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(s.ages, style: Theme.of(context).textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One 大运 of the stage overview: ages, years, 干支, label and focus; the best one starred.
class LifeStageRow extends StatelessWidget {
  const LifeStageRow({super.key, required this.stage, required this.best});
  final LifeStage stage;
  final bool best;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: Space.xs),
      padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
      decoration: BoxDecoration(
        color: best ? scheme.tertiaryContainer.withValues(alpha: 0.6) : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(Radii.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stage.ages, style: theme.textTheme.titleSmall),
                Text('${stage.years} ${stage.ganzhi}', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              '${best ? '★ ' : ''}${stage.label}',
              style: theme.textTheme.titleSmall?.copyWith(color: best ? scheme.tertiary : null),
            ),
          ),
          Expanded(child: Text(stage.focus, style: ReadingText.small(context))),
        ],
      ),
    );
  }
}
