import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mingli_app/presentation/design.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import 'format.dart';
import 'widgets/common.dart';
import 'widgets/dashboard.dart';
import 'widgets/line_chart.dart';
import 'widgets/tables.dart';

/// 用量 (管理后台, tech plan S22; laid out in S24 WP24.3): the period's tokens as the hero figure, the requests and
/// what they cost in the grid, each day's tokens and each kind of job; in the panel, each model.
class UsagePage extends ConsumerWidget {
  const UsagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdown = ref.watch(breakdownProvider);
    final days = ref.watch(seriesProvider).value ?? const <DayRow>[];
    return DashboardLayout(
      main: [
        const PageHeader('用量', subtitle: 'AI 请求、tokens 和成本', trailing: PeriodPicker()),
        AsyncView(
          ref.watch(overviewProvider),
          onRetry: () => ref.invalidate(overviewProvider),
          data: (o) {
            final p = o.previous;
            final against = '前 ${o.days} 天';
            Change? change(num now, num? before, {bool upIsGood = true}) =>
                before == null ? null : Change(now.toDouble(), before.toDouble(), against: against, upIsGood: upIsGood);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HeroFigure(
                  label: 'Tokens',
                  number: o.tokens, format: compact,
                  change: change(o.tokens, p?.tokens),
                  caption: '输入 ${count(o.inputTokens)} · 输出 ${count(o.outputTokens)}',
                  trend: [for (final d in days) d.tokens.toDouble()],
                  trendLabel: '每日 tokens，${o.from} 至 ${o.to}',
                ),
                StatGrid(
                  children: [
                    StatTile(
                      label: 'AI 请求',
                      number: o.jobs, format: count,
                      change: change(o.jobs, p?.jobs),
                      detail: '完成 ${count(o.deliveredJobs)}',
                    ),
                    StatTile(
                      label: 'AI 成本',
                      number: o.money.cost, format: yuan,
                      change: change(o.money.cost, p?.money.cost, upIsGood: false),
                      detail: '${usd(o.costUsd)}（按各模型的公开价格）',
                    ),
                    StatTile(
                      label: '每次平均',
                      value: o.jobs == 0 ? '—' : yuan(o.money.cost / o.jobs),
                      detail: o.jobs == 0 ? null : '${compact((o.tokens / o.jobs).round())} tokens',
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        AppCard(
          title: '每日 tokens',
          icon: Icons.stacked_line_chart,
          child: AsyncView(
            ref.watch(seriesProvider),
            onRetry: () => ref.invalidate(seriesProvider),
            data: (days) => _TokensChart(days),
          ),
        ),
        AppCard(
          title: '各项目',
          icon: Icons.category_outlined,
          child: AsyncView(breakdown, onRetry: () => ref.invalidate(breakdownProvider), data: (b) => MethodTable(b.byMethod)),
        ),
      ],
      aside: [
        PanelSection(
          first: true,
          title: '各模型',
          child: AsyncView(breakdown, onRetry: () => ref.invalidate(breakdownProvider), data: (b) => _Models(b.byModel)),
        ),
      ],
    );
  }
}

class _TokensChart extends StatelessWidget {
  const _TokensChart(this.days);
  final List<DayRow> days;

  @override
  Widget build(BuildContext context) {
    final colors = seriesColors(context);
    return LineChart(
      labels: [for (final d in days) d.day],
      series: [
        ChartSeries('输入', colors[0], [for (final d in days) d.inputTokens.toDouble()]),
        ChartSeries('输出', colors[1], [for (final d in days) d.outputTokens.toDouble()]),
      ],
      format: (v) => compact(v.round()),
      readout: (v) => count(v.round()),
    );
  }
}

/// Each model in the panel, the most costly first: its name, then its requests, tokens and cost, the numbers at the
/// right.
class _Models extends StatelessWidget {
  const _Models(this.rows);
  final List<ModelRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (rows.isEmpty) {
      return Text('这段时间没有 AI 请求', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, r) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: Space.l),
          Text(r.model, key: ValueKey<String>('model-${r.model}'), style: theme.textTheme.titleSmall),
          NumberRow('AI 次数', count(r.jobs)),
          NumberRow('输入 / 输出 tokens', '${compact(r.inputTokens)} / ${compact(r.outputTokens)}'),
          NumberRow('AI 成本', yuan(r.cost)),
        ],
      ],
    );
  }
}
