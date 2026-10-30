import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/keyboard.dart';

import '../application/providers.dart';
import '../data/admin_api.dart';
import '../domain/models.dart';
import 'format.dart';
import 'messages.dart';
import 'widgets/common.dart';
import 'widgets/tables.dart';

/// 收益 (管理后台, tech plan S22): the revenue curve, each day or added up, saved as a PNG or its numbers as CSV, and
/// every day's money, accounts and AI jobs in a table.
class RevenuePage extends ConsumerStatefulWidget {
  const RevenuePage({super.key});

  @override
  ConsumerState<RevenuePage> createState() => _RevenuePageState();
}

class _RevenuePageState extends ConsumerState<RevenuePage> {
  final _chart = GlobalKey();
  bool _cumulative = false;
  bool _saving = false;

  Future<void> _save(Future<AdminFile> Function() make) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final f = await make();
      await ref.read(saveFileProvider)(f);
      if (mounted) say(context, '已导出 ${f.name}');
    } catch (e) {
      if (mounted) say(context, problemText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The chart's own picture (its legend and lines), twice the screen's size.
  Future<void> _png(List<DayRow> days) => _save(() async {
        final boundary = _chart.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final name = '命理大师-收益曲线${_cumulative ? '-累计' : ''}-${days.first.day}_${days.last.day}.png';
          return AdminFile(data!.buffer.asUint8List(), name, 'image/png');
        } finally {
          image.dispose();
        }
      });

  Future<void> _csv() =>
      _save(() => ref.read(adminApiProvider).report(days: ref.read(daysProvider), format: 'csv', kind: 'series'));

  @override
  Widget build(BuildContext context) {
    final series = ref.watch(seriesProvider);
    return PageBody(
      children: [
        PageHeader(
          '收益',
          subtitle: series.whenOrNull(
            data: (s) => s.isEmpty ? null : '${s.first.day} 至 ${s.last.day}（北京时间）',
          ),
          trailing: const PeriodPicker(),
        ),
        AsyncView(
          series,
          onRetry: () => ref.invalidate(seriesProvider),
          data: (days) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                title: '收益曲线',
                icon: Icons.show_chart,
                trailing: SegmentKeys<bool>(
                  child: SegmentedButton<bool>(
                    key: const Key('cumulative'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: false, label: Text('每日')),
                      ButtonSegment(value: true, label: Text('累计')),
                    ],
                    selected: {_cumulative},
                    onSelectionChanged: (s) => setState(() => _cumulative = s.first),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RevenueChart(days, cumulative: _cumulative, repaintKey: _chart),
                    const SizedBox(height: Space.m),
                    Wrap(
                      spacing: Space.s,
                      runSpacing: Space.s,
                      children: [
                        OutlinedButton.icon(
                          key: const Key('export-png'),
                          onPressed: _saving || days.isEmpty ? null : () => _png(days),
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('导出图片（PNG）'),
                        ),
                        OutlinedButton.icon(
                          key: const Key('export-series-csv'),
                          onPressed: _saving ? null : _csv,
                          icon: const Icon(Icons.table_view_outlined),
                          label: const Text('导出数据（CSV）'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AppCard(title: '每日明细', icon: Icons.table_rows_outlined, child: _Daily(days)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Every day of the period, the latest first, under the period's sums.
class _Daily extends StatelessWidget {
  const _Daily(this.days);
  final List<DayRow> days;

  DataRow _row(String day, Money m, int newAccounts, String active, int jobs, int sold, {bool bold = false}) {
    final weight = bold ? FontWeight.w700 : null;
    Text t(String s) => Text(s, style: TextStyle(fontWeight: weight, fontFeatures: const [FontFeature.tabularFigures()]));
    return DataRow(
      cells: [
        DataCell(Text(day, style: TextStyle(fontWeight: weight))),
        DataCell(t(yuan(m.topup))),
        DataCell(t(yuan(m.net))),
        DataCell(t(yuan(m.cost))),
        DataCell(t(yuan(m.profit))),
        DataCell(t(count(newAccounts))),
        DataCell(t(active)),
        DataCell(t(count(jobs))),
        DataCell(t(count(sold))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    double sum(double Function(DayRow d) of) => days.fold(0, (s, d) => s + of(d));
    int total(int Function(DayRow d) of) => days.fold(0, (s, d) => s + of(d));
    final net = sum((d) => d.money.net);
    final cost = sum((d) => d.money.cost);
    final all = Money(topup: sum((d) => d.money.topup), net: net, cost: cost, profit: net - cost);
    return DataGrid(
      label: '每日明细',
      columns: const [
        DataColumn(label: Text('日期')),
        DataColumn(label: Text('充值'), numeric: true),
        DataColumn(label: Text('净收入'), numeric: true),
        DataColumn(label: Text('AI 成本'), numeric: true),
        DataColumn(label: Text('毛利'), numeric: true),
        DataColumn(label: Text('新账户'), numeric: true),
        DataColumn(label: Text('活跃账户'), numeric: true),
        DataColumn(label: Text('AI 次数'), numeric: true),
        DataColumn(label: Text('售出积分'), numeric: true),
      ],
      rows: [
        // Accounts active on some day of the period aren't the sum of each day's: that sum is left out.
        _row('合计', all, total((d) => d.newAccounts), '—', total((d) => d.jobs), total((d) => d.pointsSold), bold: true),
        for (final d in days.reversed)
          _row(d.day, d.money, d.newAccounts, count(d.activeAccounts), d.jobs, d.pointsSold),
      ],
    );
  }
}
