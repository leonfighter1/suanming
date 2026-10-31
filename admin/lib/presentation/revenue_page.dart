import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mingli_app/presentation/buttons.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/keyboard.dart';

import '../application/providers.dart';
import '../data/admin_api.dart';
import '../domain/models.dart';
import 'format.dart';
import 'messages.dart';
import 'widgets/common.dart';
import 'widgets/dashboard.dart';
import 'widgets/tables.dart';

/// 收益 (管理后台, tech plan S22; laid out in S24 WP24.3): 毛利 as the hero figure and the money that makes it, the
/// revenue curve, each day or added up, and every day's money, accounts and AI jobs in a table; in the panel, the
/// exports (the curve as a PNG, its numbers as CSV) and how the numbers are made.
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
    final days = series.value ?? const <DayRow>[];
    void retry() => ref.invalidate(seriesProvider);
    // A button that spans the panel's column.
    Widget wide(Widget button) => SizedBox(width: double.infinity, child: button);
    return DashboardLayout(
      main: [
        PageHeader(
          '收益',
          subtitle: series.whenOrNull(
            data: (s) => s.isEmpty ? null : '${s.first.day} 至 ${s.last.day}（北京时间）',
          ),
          trailing: const PeriodPicker(),
        ),
        AsyncView(
          ref.watch(overviewProvider),
          onRetry: () => ref.invalidate(overviewProvider),
          data: (o) => _Figures(o, days),
        ),
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
          child: AsyncView(
            series,
            onRetry: retry,
            data: (days) => RevenueChart(days, cumulative: _cumulative, repaintKey: _chart),
          ),
        ),
        AppCard(
          title: '每日明细',
          icon: Icons.table_rows_outlined,
          child: AsyncView(series, onRetry: retry, data: (days) => _Daily(days)),
        ),
      ],
      // The panel: what to take away, and how the numbers are made.
      aside: [
        PanelSection(
          first: true,
          title: '导出',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              wide(
                AppOutlinedButton.icon(
                  key: const Key('export-png'),
                  onPressed: _saving || days.isEmpty ? null : () => _png(days),
                  icon: const Icon(Icons.image_outlined),
                  label: Text(_cumulative ? '收益曲线（累计）图片 PNG' : '收益曲线图片 PNG'),
                ),
              ),
              // The numbers are the server's export, a role that may take data's (S25); the picture is drawn here.
              if (ref.watch(sessionProvider)?.can.contains(Can.userData) ?? false) ...[
                const SizedBox(height: Space.s),
                wide(
                  AppOutlinedButton.icon(
                    key: const Key('export-series-csv'),
                    onPressed: _saving ? null : _csv,
                    icon: const Icon(Icons.table_view_outlined),
                    label: const Text('每日数据 CSV'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const PanelSection(
          title: '怎么算',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Rule('净收入', '充值减去支付手续费和增值税'),
              _Rule('AI 成本', '每次 AI 请求的 tokens 按模型的公开价格，美元按汇率折成人民币'),
              _Rule('毛利', '净收入减 AI 成本'),
              _Rule('毛利率', '毛利 ÷ 净收入'),
            ],
          ),
        ),
      ],
    );
  }
}

/// A term and how it is worked out, in the panel.
class _Rule extends StatelessWidget {
  const _Rule(this.term, this.how);
  final String term;
  final String how;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(term, style: theme.textTheme.titleSmall),
          Text(how, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// 毛利 as the page's hero, with the money that makes it in the grid; each change against the period before.
class _Figures extends StatelessWidget {
  const _Figures(this.o, this.days);
  final Overview o;
  final List<DayRow> days;

  @override
  Widget build(BuildContext context) {
    final m = o.money;
    final p = o.previous?.money;
    final against = '前 ${o.days} 天';
    Change? change(double now, double? before, {bool upIsGood = true}) =>
        before == null ? null : Change(now, before, against: against, upIsGood: upIsGood);
    final best = days.isEmpty ? null : days.reduce((a, b) => b.money.topup > a.money.topup ? b : a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroFigure(
          label: '毛利',
          number: m.profit, format: yuan,
          change: change(m.profit, p?.profit),
          caption: '净收入 ${yuan(m.net)} 减 AI 成本 ${yuan(m.cost)}',
          trend: [for (final d in days) d.money.profit],
          trendLabel: '每日毛利，${o.from} 至 ${o.to}',
        ),
        StatGrid(
          maxColumns: 3,
          children: [
            StatTile(label: '充值收入', number: m.topup, format: yuan, change: change(m.topup, p?.topup)),
            StatTile(label: '净收入', number: m.net, format: yuan, change: change(m.net, p?.net)),
            StatTile(label: 'AI 成本', number: m.cost, format: yuan, change: change(m.cost, p?.cost, upIsGood: false)),
            StatTile(
              label: '毛利率',
              value: percent(m.margin),
              change: m.margin == null || p?.margin == null
                  ? null
                  : Change(m.margin!, p!.margin!, against: against, points: true),
            ),
            StatTile(label: '日均充值', number: o.days == 0 ? 0 : m.topup / o.days, format: yuan),
            StatTile(
              label: '最多的一天',
              value: best == null ? '—' : yuan(best.money.topup),
              detail: best?.day,
            ),
          ],
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
