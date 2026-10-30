import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mingli_app/presentation/design.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import 'format.dart';
import 'widgets/common.dart';
import 'widgets/kpi_tile.dart';
import 'widgets/line_chart.dart';
import 'widgets/tables.dart';

/// 用量 (管理后台, tech plan S22): the period's AI requests, their tokens and what they cost, each day, by kind of job
/// and by model.
class UsagePage extends ConsumerWidget {
  const UsagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdown = ref.watch(breakdownProvider);
    return PageBody(
      children: [
        const PageHeader('用量', subtitle: 'AI 请求、tokens 和成本', trailing: PeriodPicker()),
        AsyncView(
          ref.watch(overviewProvider),
          onRetry: () => ref.invalidate(overviewProvider),
          data: (o) => KpiGrid(
            children: [
              KpiTile(
                label: 'Tokens',
                value: compact(o.tokens),
                icon: Icons.data_usage,
                detail: '输入 ${count(o.inputTokens)} · 输出 ${count(o.outputTokens)}',
              ),
              KpiTile(
                label: 'AI 请求',
                value: count(o.jobs),
                icon: Icons.memory_outlined,
                detail: '完成 ${count(o.deliveredJobs)}',
              ),
              KpiTile(
                label: 'AI 成本',
                value: yuan(o.money.cost),
                icon: Icons.payments_outlined,
                detail: '${usd(o.costUsd)}（按各模型的公开价格）',
              ),
              KpiTile(
                label: '每次平均',
                value: o.jobs == 0 ? '—' : yuan(o.money.cost / o.jobs),
                icon: Icons.functions,
                detail: o.jobs == 0 ? null : '${compact((o.tokens / o.jobs).round())} tokens',
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.l),
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
        AppCard(
          title: '各模型',
          icon: Icons.hub_outlined,
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
    final colors = seriesColors(Theme.of(context).brightness);
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

class _Models extends StatelessWidget {
  const _Models(this.rows);
  final List<ModelRow> rows;

  @override
  Widget build(BuildContext context) => DataGrid(
        label: '各模型',
        empty: '这段时间没有 AI 请求',
        columns: const [
          DataColumn(label: Text('模型')),
          DataColumn(label: Text('AI 次数'), numeric: true),
          DataColumn(label: Text('输入 tokens'), numeric: true),
          DataColumn(label: Text('输出 tokens'), numeric: true),
          DataColumn(label: Text('AI 成本'), numeric: true),
        ],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                DataCell(Text(r.model)),
                DataCell(numText(count(r.jobs))),
                DataCell(numText(compact(r.inputTokens))),
                DataCell(numText(compact(r.outputTokens))),
                DataCell(numText(yuan(r.cost))),
              ],
            ),
        ],
      );
}
